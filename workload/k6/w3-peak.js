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
    requests: new Counter(`m8_${family}_requests`),
    errors: new Rate(`m8_${family}_errors`),
    duration: new Trend(`m8_${family}_duration`, true),
  };
}

const nonFileRequests = new Counter('m8_non_file_requests');
const nonFileErrors = new Rate('m8_non_file_errors');
const nonFileDuration = new Trend('m8_non_file_duration', true);
const supportRequests = new Counter('m8_support_requests');
const supportErrors = new Rate('m8_support_errors');
const supportDuration = new Trend('m8_support_duration', true);

export const options = {
  noCookiesReset: true,
  scenarios: {
    list_detail: {
      executor: 'constant-arrival-rate',
      exec: 'listDetail',
      rate: 20,
      timeUnit: '1s',
      duration: '10m',
      preAllocatedVUs: 40,
      maxVUs: 40,
      gracefulStop: '30s',
    },
    create_save: {
      executor: 'constant-arrival-rate',
      exec: 'createSave',
      rate: 15,
      timeUnit: '2s',
      duration: '10m',
      preAllocatedVUs: 14,
      maxVUs: 14,
      gracefulStop: '30s',
    },
    submit_resubmit: {
      executor: 'constant-arrival-rate',
      exec: 'submitResubmit',
      rate: 10,
      timeUnit: '1s',
      duration: '10m',
      preAllocatedVUs: 10,
      maxVUs: 10,
      gracefulStop: '30s',
    },
    reviewer_queue_detail: {
      executor: 'constant-arrival-rate',
      exec: 'reviewerQueueDetail',
      rate: 10,
      timeUnit: '1s',
      duration: '10m',
      preAllocatedVUs: 20,
      maxVUs: 20,
      gracefulStop: '30s',
    },
    review_action: {
      executor: 'constant-arrival-rate',
      exec: 'reviewAction',
      rate: 5,
      timeUnit: '1s',
      duration: '10m',
      preAllocatedVUs: 10,
      maxVUs: 10,
      gracefulStop: '30s',
    },
    attachment: {
      executor: 'constant-arrival-rate',
      exec: 'attachment',
      rate: 5,
      timeUnit: '2s',
      duration: '10m',
      preAllocatedVUs: 6,
      maxVUs: 6,
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
    milestone: 'm8',
    profile: 'w3-arrival-peak',
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

function recordSupport(response, ok) {
  supportRequests.add(1);
  supportErrors.add(!ok);
  supportDuration.add(response.timings.duration);
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
  if (!ensureRole('APPLICANT')) {
    return;
  }

  businessGet(
    'list_detail',
    '/api/v1/applications?size=20',
    'GET /api/v1/applications',
  );

  const slot = 7000 + (exec.scenario.iterationInTest % 1000);
  businessGet(
    'list_detail',
    `/api/v1/applications/${draftId(slot)}`,
    'GET /api/v1/applications/{id}',
  );

}

export function createSave() {
  if (!ensureRole('APPLICANT')) {
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
      applicantOrganizationName: 'M8 W3 Synthetic Organization',
      projectTitle: `M8 W3 ${unique}`,
      shortSummary: 'M8 W3 mixed baseline create/save request.',
      requestedAmount: 1234567,
      detailedPlan: 'M8 W3 mixed baseline draft created through the deployed API.',
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
        applicantOrganizationName: 'M8 W3 Synthetic Organization',
        projectTitle: `M8 W3 ${unique}`,
        shortSummary: 'M8 W3 mixed baseline saved draft.',
        requestedAmount: 1234567,
        detailedPlan: 'M8 W3 mixed baseline draft saved through the deployed API.',
      },
      [200],
    );
  }

}

export function submitResubmit() {
  if (!ensureRole('APPLICANT')) {
    return;
  }

  const slot = exec.scenario.iterationInTest;
  if (slot >= 7000) {
    exec.test.abort(`W3 submit DRAFT pool exhausted at slot ${slot}`);
  }

  businessJson(
    'POST',
    'submit_resubmit',
    `/api/v1/applications/${draftId(slot)}/submit`,
    'POST /api/v1/applications/{id}/submit',
    { version: 0 },
    [200],
  );

}

export function reviewerQueueDetail() {
  if (!ensureRole('REVIEWER')) {
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

}

export function reviewAction() {
  if (!ensureRole('REVIEWER')) {
    return;
  }

  const slot = exec.scenario.iterationInTest;
  if (slot >= 3500) {
    exec.test.abort(`W3 review SUBMITTED pool exhausted at slot ${slot}`);
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
  if (
    startedReview &&
    startedReview.status === 200 &&
    application &&
    application.version !== undefined
  ) {
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
        { version: application.version, reason: 'M8 W3 synthetic rejection' },
        [200],
      );
    } else {
      businessJson(
        'POST',
        'review_action',
        `/api/v1/review/applications/${applicationId}/request-revision`,
        'POST /api/v1/review/applications/{id}/request-revision',
        { version: application.version, reason: 'M8 W3 synthetic revision request' },
        [200],
      );
    }
  }

}

export function attachment() {
  if (!ensureRole('APPLICANT')) {
    return;
  }

  const slot = 7800 + (exec.vu.idInTest % 100);
  const applicationId = draftId(slot);

  const token = supportCsrf();
  if (!token) {
    return;
  }
  const uploaded = http.post(
    `${baseUrl}/api/v1/applications/${applicationId}/attachments`,
    {
      file: http.file(attachmentBody, 'm8-w3-attachment.txt', 'text/plain'),
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
      pace(started, 2.4);
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

}
