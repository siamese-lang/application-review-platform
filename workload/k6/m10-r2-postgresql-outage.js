import http from 'k6/http';
import { check, sleep } from 'k6';
import exec from 'k6/execution';
import { Counter, Rate, Trend } from 'k6/metrics';

const baseUrl = (__ENV.BASE_URL || '').replace(/\/$/, '');
const applicantUsername = __ENV.APPLICANT_USERNAME || 'm6-applicant';
const applicantPassword = __ENV.APPLICANT_PASSWORD || '';
const reviewerUsername = __ENV.REVIEWER_USERNAME || 'm6-reviewer';
const reviewerPassword = __ENV.REVIEWER_PASSWORD || '';
const runId = __ENV.RUN_ID || '';
const attachmentPath = __ENV.ATTACHMENT_PATH || '../fixtures/w1-attachment.txt';
const attachmentBody = open(attachmentPath);
const duration = __ENV.M10_DURATION || '5m';

for (const [name, value] of [
  ['BASE_URL', baseUrl],
  ['APPLICANT_PASSWORD', applicantPassword],
  ['REVIEWER_PASSWORD', reviewerPassword],
  ['RUN_ID', runId],
]) {
  if (!value) {
    throw new Error(`${name} is required`);
  }
}

const familyNames = [
  'list_detail',
  'create_save',
  'submit_resubmit',
  'reviewer_queue_detail',
  'review_action',
  'attachment',
];

const familyMetrics = {};
for (const family of familyNames) {
  familyMetrics[family] = {
    requests: new Counter(`m10_r2_${family}_requests`),
    errors: new Rate(`m10_r2_${family}_errors`),
    duration: new Trend(`m10_r2_${family}_duration`, true),
  };
}

const nonFileRequests = new Counter('m10_r2_non_file_requests');
const nonFileErrors = new Rate('m10_r2_non_file_errors');
const nonFileDuration = new Trend('m10_r2_non_file_duration', true);
const supportRequests = new Counter('m10_r2_support_requests');
const supportErrors = new Rate('m10_r2_support_errors');
const sessionProbeRequests = new Counter('m10_r2_session_probe_requests');
const sessionProbeErrors = new Rate('m10_r2_session_probe_errors');
const publicApiProbeRequests = new Counter('m10_r2_public_api_probe_requests');
const publicApiProbeErrors = new Rate('m10_r2_public_api_probe_errors');
const staticEdgeProbeRequests = new Counter('m10_r2_static_edge_probe_requests');
const staticEdgeProbeErrors = new Rate('m10_r2_static_edge_probe_errors');
const sessionLoginAttempts = new Counter('m10_r2_session_login_attempts');

export const options = {
  noCookiesReset: true,
  scenarios: {
    list_detail: {
      executor: 'constant-vus',
      exec: 'listDetail',
      vus: 12,
      duration,
      gracefulStop: '30s',
    },
    create_save: {
      executor: 'constant-vus',
      exec: 'createSave',
      vus: 4,
      duration,
      gracefulStop: '30s',
    },
    submit_resubmit: {
      executor: 'constant-vus',
      exec: 'submitResubmit',
      vus: 3,
      duration,
      gracefulStop: '30s',
    },
    reviewer_queue_detail: {
      executor: 'constant-vus',
      exec: 'reviewerQueueDetail',
      vus: 6,
      duration,
      gracefulStop: '30s',
    },
    review_action: {
      executor: 'constant-vus',
      exec: 'reviewAction',
      vus: 3,
      duration,
      gracefulStop: '30s',
    },
    attachment: {
      executor: 'constant-vus',
      exec: 'attachment',
      vus: 2,
      duration,
      gracefulStop: '30s',
    },
    persisted_session_probe: {
      executor: 'constant-vus',
      exec: 'persistedSessionProbe',
      vus: 1,
      duration,
      gracefulStop: '5s',
    },
    public_api_probe: {
      executor: 'constant-vus',
      exec: 'publicApiProbe',
      vus: 1,
      duration,
      gracefulStop: '5s',
    },
    static_edge_probe: {
      executor: 'constant-vus',
      exec: 'staticEdgeProbe',
      vus: 1,
      duration,
      gracefulStop: '5s',
    },
  },
  systemTags: [
    'status',
    'method',
    'name',
    'group',
    'check',
    'error',
    'error_code',
    'scenario',
    'expected_response',
  ],
  tags: {
    milestone: 'm10',
    profile: 'r2-postgresql-outage',
  },
  summaryTrendStats: ['min', 'med', 'avg', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

let authenticatedRole = null;
let probeSessionReady = false;
const probeStates = {};

function tags(family, name, scope = 'business') {
  const result = {
    scenario: exec.scenario.name,
    endpoint_family: family,
    scope,
    name,
  };
  if (scope === 'business') {
    result.regression_target = family === 'attachment' ? 'file' : 'non-file';
  }
  return result;
}

function recordSupport(response, ok) {
  supportRequests.add(1);
  supportErrors.add(!ok);
  return ok;
}

function supportCsrf() {
  const response = http.get(`${baseUrl}/api/v1/auth/csrf`, {
    tags: tags('support', 'GET /api/v1/auth/csrf', 'support'),
  });

  let body = null;
  if (response.status === 200) {
    try {
      body = response.json();
    } catch (_) {
      body = null;
    }
  }

  const ok =
    response.status === 200 &&
    body !== null &&
    Boolean(body.headerName) &&
    Boolean(body.token);

  recordSupport(response, ok);
  return ok ? body : null;
}

function ensureRole(role) {
  if (authenticatedRole === role) {
    return true;
  }

  const username = role === 'APPLICANT' ? applicantUsername : reviewerUsername;
  const password = role === 'APPLICANT' ? applicantPassword : reviewerPassword;
  const token = supportCsrf();
  if (!token) {
    return false;
  }

  const response = http.post(
    `${baseUrl}/api/v1/auth/login`,
    JSON.stringify({ username, password }),
    {
      headers: {
        [token.headerName]: token.token,
        'Content-Type': 'application/json',
      },
      tags: tags('support', 'POST /api/v1/auth/login', 'support'),
    },
  );

  let body = null;
  if (response.status === 200) {
    try {
      body = response.json();
    } catch (_) {
      body = null;
    }
  }

  const ok = response.status === 200 && body !== null && body.role === role;
  recordSupport(response, ok);
  if (!ok) {
    return false;
  }

  authenticatedRole = role;
  return true;
}

function recordBusiness(family, response, expectedStatuses, extraOk = true) {
  const ok = expectedStatuses.includes(response.status) && extraOk;
  familyMetrics[family].requests.add(1);
  familyMetrics[family].errors.add(!ok);
  familyMetrics[family].duration.add(response.timings.duration);
  if (family !== 'attachment') {
    nonFileRequests.add(1);
    nonFileErrors.add(!ok);
    nonFileDuration.add(response.timings.duration);
  }
  check(response, {
    [`${family} expected status`]: () => ok,
  });
  return ok;
}

function businessGet(family, path, name, expectedStatuses = [200], params = {}) {
  const response = http.get(`${baseUrl}${path}`, {
    ...params,
    tags: tags(family, name),
  });
  recordBusiness(family, response, expectedStatuses);
  return response;
}

function businessJson(method, family, path, name, body, expectedStatuses) {
  const token = supportCsrf();
  if (!token) {
    return null;
  }
  const response = http.request(method, `${baseUrl}${path}`, JSON.stringify(body), {
    headers: {
      [token.headerName]: token.token,
      'Content-Type': 'application/json',
    },
    tags: tags(family, name),
  });
  recordBusiness(family, response, expectedStatuses);
  return response;
}

function pace(startedAtMs, targetSeconds) {
  const elapsed = (Date.now() - startedAtMs) / 1000;
  if (elapsed < targetSeconds) {
    sleep(targetSeconds - elapsed);
  }
}

function jsonOrNull(response) {
  if (!response) {
    return null;
  }
  try {
    return response.json();
  } catch (_) {
    return null;
  }
}

const APPLICATION_BASE = 8200000000;

function draftId(slot) {
  return APPLICATION_BASE + 1 + 12 * slot;
}

function submittedId(slot) {
  return APPLICATION_BASE + 2 + 12 * slot;
}

export function listDetail() {
  const started = Date.now();
  if (!ensureRole('APPLICANT')) {
    pace(started, 0.25);
    return;
  }

  businessGet(
    'list_detail',
    '/api/v1/applications?size=20',
    'GET /api/v1/applications',
  );

  const slot = 4000 + (exec.scenario.iterationInTest % 2500);
  businessGet(
    'list_detail',
    `/api/v1/applications/${draftId(slot)}`,
    'GET /api/v1/applications/{id}',
  );

  pace(started, 2.0);
}

export function createSave() {
  const started = Date.now();
  if (!ensureRole('APPLICANT')) {
    pace(started, 0.25);
    return;
  }
  const unique = `${runId}-create-${exec.scenario.iterationInTest}`;

  const created = businessJson(
    'POST',
    'create_save',
    '/api/v1/applications',
    'POST /api/v1/applications',
    {
      programId: 8000000001,
      applicantOrganizationName: 'M10 control Synthetic Organization',
      projectTitle: `M10 control ${unique}`,
      shortSummary: 'M10 control mixed baseline create/save request.',
      requestedAmount: 1234567,
      detailedPlan: 'M10 control mixed baseline draft created through the deployed API.',
    },
    [201],
  );

  const application = jsonOrNull(created);
  if (created && created.status === 201 && application && application.id !== undefined) {
    businessJson(
      'PUT',
      'create_save',
      `/api/v1/applications/${application.id}`,
      'PUT /api/v1/applications/{id}',
      {
        version: application.version,
        applicantOrganizationName: 'M10 control Synthetic Organization',
        projectTitle: `M10 control ${unique}`,
        shortSummary: 'M10 control mixed baseline saved draft.',
        requestedAmount: 1234567,
        detailedPlan: 'M10 control mixed baseline draft saved through the deployed API.',
      },
      [200],
    );
  }

  pace(started, 1.777778);
}

export function submitResubmit() {
  const started = Date.now();
  if (!ensureRole('APPLICANT')) {
    pace(started, 0.25);
    return;
  }

  const slot = exec.scenario.iterationInTest;
  if (slot >= 4000) {
    exec.test.abort(`M10 submit DRAFT pool exhausted at slot ${slot}`);
  }

  businessJson(
    'POST',
    'submit_resubmit',
    `/api/v1/applications/${draftId(slot)}/submit`,
    'POST /api/v1/applications/{id}/submit',
    { version: 0 },
    [200],
  );

  pace(started, 1.0);
}

export function reviewerQueueDetail() {
  const started = Date.now();
  if (!ensureRole('REVIEWER')) {
    pace(started, 0.25);
    return;
  }

  businessGet(
    'reviewer_queue_detail',
    '/api/v1/review/applications?status=SUBMITTED&size=20',
    'GET /api/v1/review/applications',
  );

  const slot = 4000 + (exec.scenario.iterationInTest % 2500);
  businessGet(
    'reviewer_queue_detail',
    `/api/v1/review/applications/${submittedId(slot)}`,
    'GET /api/v1/review/applications/{id}',
  );

  pace(started, 2.0);
}

export function reviewAction() {
  const started = Date.now();
  if (!ensureRole('REVIEWER')) {
    pace(started, 0.25);
    return;
  }

  const slot = exec.scenario.iterationInTest;
  if (slot >= 3500) {
    exec.test.abort(`M10 review SUBMITTED pool exhausted at slot ${slot}`);
  }

  const applicationId = submittedId(slot);
  const startedReview = businessJson(
    'POST',
    'review_action',
    `/api/v1/review/applications/${applicationId}/start`,
    'POST /api/v1/review/applications/{id}/start',
    { version: 1 },
    [200],
  );

  const application = jsonOrNull(startedReview);
  if (startedReview && startedReview.status === 200 && application && application.version !== undefined) {
    const decision = slot % 3;
    if (decision === 0) {
      businessJson(
        'POST',
        'review_action',
        `/api/v1/review/applications/${applicationId}/approve`,
        'POST /api/v1/review/applications/{id}/approve',
        { version: application.version },
        [200],
      );
    } else if (decision === 1) {
      businessJson(
        'POST',
        'review_action',
        `/api/v1/review/applications/${applicationId}/reject`,
        'POST /api/v1/review/applications/{id}/reject',
        { version: application.version, reason: 'M10 control synthetic rejection' },
        [200],
      );
    } else {
      businessJson(
        'POST',
        'review_action',
        `/api/v1/review/applications/${applicationId}/request-revision`,
        'POST /api/v1/review/applications/{id}/request-revision',
        { version: application.version, reason: 'M10 control synthetic revision request' },
        [200],
      );
    }
  }

  pace(started, 2.0);
}

export function attachment() {
  const started = Date.now();
  if (!ensureRole('APPLICANT')) {
    pace(started, 0.25);
    return;
  }

  const slot = 7800 + (exec.vu.idInTest % 100);
  const applicationId = draftId(slot);

  const token = supportCsrf();
  if (!token) {
    pace(started, 0.25);
    return;
  }
  const uploaded = http.post(
    `${baseUrl}/api/v1/applications/${applicationId}/attachments`,
    {
      file: http.file(attachmentBody, 'm10-control-attachment.txt', 'text/plain'),
    },
    {
      headers: { [token.headerName]: token.token },
      tags: tags(
        'attachment',
        'POST /api/v1/applications/{id}/attachments',
      ),
    },
  );
  recordBusiness('attachment', uploaded, [201]);

  const attachmentResponse = jsonOrNull(uploaded);
  if (
    uploaded.status === 201 &&
    attachmentResponse &&
    attachmentResponse.id !== undefined
  ) {
    const downloaded = http.get(
      `${baseUrl}/api/v1/applications/${applicationId}/attachments/${attachmentResponse.id}`,
      {
        responseType: 'text',
        tags: tags(
          'attachment',
          'GET /api/v1/applications/{id}/attachments/{attachmentId}',
        ),
      },
    );
    const bodyMatches =
      downloaded.status === 200 && downloaded.body === attachmentBody;
    recordBusiness(
      'attachment',
      downloaded,
      [200],
      downloaded.body === attachmentBody,
    );
    check(downloaded, {
      'attachment payload matches bounded fixture': () => bodyMatches,
    });

    const deleteToken = supportCsrf();
    if (!deleteToken) {
      pace(started, 2.666667);
      return;
    }
    const deleted = http.del(
      `${baseUrl}/api/v1/applications/${applicationId}/attachments/${attachmentResponse.id}`,
      null,
      {
        headers: { [deleteToken.headerName]: deleteToken.token },
        tags: tags(
          'support',
          'DELETE /api/v1/applications/{id}/attachments/{attachmentId}',
          'support',
        ),
      },
    );
    recordSupport(deleted, deleted.status === 204);
  }

  pace(started, 2.666667);
}


function probeTransition(probe, response, ok) {
  const state = ok ? 'UP' : 'DOWN';
  if (probeStates[probe] === state) {
    return;
  }
  probeStates[probe] = state;
  const status = response && response.status !== undefined ? response.status : 0;
  const errorCode = response && response.error_code ? response.error_code : '';
  console.log(
    `M10_R2_STATE|probe=${probe}|at=${new Date().toISOString()}|state=${state}|status=${status}|error_code=${errorCode}`,
  );
}

function probeLoginApplicantOnce() {
  sessionLoginAttempts.add(1);
  const token = supportCsrf();
  if (!token) {
    return false;
  }

  const response = http.post(
    `${baseUrl}/api/v1/auth/login`,
    JSON.stringify({ username: applicantUsername, password: applicantPassword }),
    {
      headers: {
        [token.headerName]: token.token,
        'Content-Type': 'application/json',
      },
      tags: tags('support', 'POST /api/v1/auth/login r2 probe', 'support'),
    },
  );

  let body = null;
  if (response.status === 200) {
    try {
      body = response.json();
    } catch (_) {
      body = null;
    }
  }

  const ok = response.status === 200 && body !== null && body.role === 'APPLICANT';
  recordSupport(response, ok);
  if (ok) {
    probeSessionReady = true;
    console.log(`M10_R2_SESSION_READY|at=${new Date().toISOString()}`);
  }
  return ok;
}

export function persistedSessionProbe() {
  if (!probeSessionReady) {
    if (!probeLoginApplicantOnce()) {
      sleep(0.25);
      return;
    }
  }

  const response = http.get(`${baseUrl}/api/v1/auth/me`, {
    tags: tags('support', 'GET /api/v1/auth/me r2 probe', 'support'),
  });

  let body = null;
  if (response.status === 200) {
    try {
      body = response.json();
    } catch (_) {
      body = null;
    }
  }

  const ok = response.status === 200 && body !== null && body.role === 'APPLICANT';
  sessionProbeRequests.add(1);
  sessionProbeErrors.add(!ok);
  probeTransition('session', response, ok);
  check(response, {
    'R2 persisted applicant session is usable': () => ok,
  });
  sleep(0.25);
}

export function publicApiProbe() {
  const response = http.get(`${baseUrl}/api/v1/programs?size=1`, {
    tags: tags('support', 'GET /api/v1/programs r2 probe', 'support'),
  });
  const ok = response.status === 200;
  publicApiProbeRequests.add(1);
  publicApiProbeErrors.add(!ok);
  probeTransition('public_api', response, ok);
  sleep(0.25);
}

export function staticEdgeProbe() {
  const response = http.get(`${baseUrl}/`, {
    tags: tags('support', 'GET / r2 probe', 'support'),
  });
  const ok = response.status === 200;
  staticEdgeProbeRequests.add(1);
  staticEdgeProbeErrors.add(!ok);
  probeTransition('static_edge', response, ok);
  sleep(0.25);
}
