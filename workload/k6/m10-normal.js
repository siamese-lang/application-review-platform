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
    requests: new Counter(`m10_${family}_requests`),
    errors: new Rate(`m10_${family}_errors`),
    duration: new Trend(`m10_${family}_duration`, true),
  };
}

const nonFileRequests = new Counter('m10_non_file_requests');
const nonFileErrors = new Rate('m10_non_file_errors');
const nonFileDuration = new Trend('m10_non_file_duration', true);

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
    profile: 'normal-control',
  },
  summaryTrendStats: ['min', 'med', 'avg', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

let authenticatedRole = null;

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

function supportCsrf() {
  const response = http.get(`${baseUrl}/api/v1/auth/csrf`, {
    tags: tags('support', 'GET /api/v1/auth/csrf', 'support'),
  });
  if (response.status !== 200) {
    exec.test.abort(`CSRF support request failed with status ${response.status}`);
  }
  let body;
  try {
    body = response.json();
  } catch (error) {
    exec.test.abort(`CSRF support response is not JSON: ${error}`);
  }
  if (!body.headerName || !body.token) {
    exec.test.abort('CSRF support response is missing headerName/token');
  }
  return body;
}

function ensureRole(role) {
  if (authenticatedRole === role) {
    return;
  }
  const username = role === 'APPLICANT' ? applicantUsername : reviewerUsername;
  const password = role === 'APPLICANT' ? applicantPassword : reviewerPassword;
  const token = supportCsrf();
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
  if (response.status !== 200) {
    exec.test.abort(`${role} login failed with status ${response.status}`);
  }
  const body = response.json();
  if (body.role !== role) {
    exec.test.abort(`${role} login returned unexpected role ${body.role}`);
  }
  authenticatedRole = role;
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
  ensureRole('APPLICANT');

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
  ensureRole('APPLICANT');
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
  if (created.status === 201 && application && application.id !== undefined) {
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
  ensureRole('APPLICANT');

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
  ensureRole('REVIEWER');

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
  ensureRole('REVIEWER');

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
  if (startedReview.status === 200 && application && application.version !== undefined) {
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
  ensureRole('APPLICANT');

  const slot = 7800 + (exec.vu.idInTest % 100);
  const applicationId = draftId(slot);

  const token = supportCsrf();
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
    if (deleted.status !== 204) {
      exec.test.abort(
        `attachment cleanup failed with status ${deleted.status}`,
      );
    }
  }

  pace(started, 2.666667);
}
