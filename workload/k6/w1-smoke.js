import http from 'k6/http';
import { check, sleep } from 'k6';

const baseUrl = (__ENV.BASE_URL || '').replace(/\/$/, '');
const applicantUsername = __ENV.APPLICANT_USERNAME || 'm6-applicant';
const applicantPassword = __ENV.APPLICANT_PASSWORD || '';
const reviewerUsername = __ENV.REVIEWER_USERNAME || 'm6-reviewer';
const reviewerPassword = __ENV.REVIEWER_PASSWORD || '';
const runId = __ENV.RUN_ID || '';
const attachmentPath = __ENV.ATTACHMENT_PATH || '../fixtures/w1-attachment.txt';
const thinkTime = Number(__ENV.THINK_TIME_SECONDS || '0.2');
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

export const options = {
  scenarios: {
    w1_business_flow: {
      executor: 'per-vu-iterations',
      vus: 1,
      iterations: 1,
      maxDuration: '2m',
    },
  },
  thresholds: {
    checks: ['rate==1'],
    http_req_failed: ['rate==0'],
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
    profile: 'w1-smoke',
  },
  summaryTrendStats: ['min', 'med', 'avg', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

function requestTags(endpointFamily, name) {
  return {
    scenario: 'w1-business-flow',
    endpoint_family: endpointFamily,
    name,
  };
}

function requireCheck(response, label, predicate) {
  const ok = check(response, {
    [label]: predicate,
  });
  if (!ok) {
    throw new Error(`${label}: status=${response.status}`);
  }
}

function requireCondition(label, condition) {
  const ok = check(null, {
    [label]: () => Boolean(condition),
  });
  if (!ok) {
    throw new Error(label);
  }
}

function json(response, label) {
  try {
    return response.json();
  } catch (error) {
    requireCondition(`${label} is valid JSON`, false);
    throw error;
  }
}

function csrf(endpointFamily) {
  const response = http.get(`${baseUrl}/api/v1/auth/csrf`, {
    tags: requestTags(endpointFamily, 'GET /api/v1/auth/csrf'),
  });
  requireCheck(response, 'CSRF endpoint returns 200', (r) => r.status === 200);
  const body = json(response, 'CSRF response');
  requireCondition(
    'CSRF response contains headerName/token',
    Boolean(body.headerName && body.token),
  );
  return body;
}

function writeJson(method, path, body, endpointFamily, name) {
  const token = csrf(endpointFamily);
  const response = http.request(method, `${baseUrl}${path}`, JSON.stringify(body), {
    headers: {
      [token.headerName]: token.token,
      'Content-Type': 'application/json',
    },
    tags: requestTags(endpointFamily, name),
  });
  return response;
}

function login(username, password, role) {
  const response = writeJson(
    'POST',
    '/api/v1/auth/login',
    { username, password },
    'auth',
    'POST /api/v1/auth/login',
  );
  requireCheck(response, `${role} login succeeds`, (r) => r.status === 200);
  const body = json(response, `${role} login response`);
  requireCondition(`${role} login returns expected role`, body.role === role);
}

function logout() {
  const token = csrf('auth');
  const response = http.post(`${baseUrl}/api/v1/auth/logout`, null, {
    headers: { [token.headerName]: token.token },
    tags: requestTags('auth', 'POST /api/v1/auth/logout'),
  });
  requireCheck(response, 'logout succeeds', (r) => r.status === 204);
}

function pause() {
  if (thinkTime > 0) {
    sleep(thinkTime);
  }
}

export default function () {
  const unique = `${runId}-vu${__VU}-it${__ITER}`;
  const projectTitle = `M8 W1 ${unique}`;

  const programList = http.get(`${baseUrl}/api/v1/programs?size=5`, {
    tags: requestTags('list-detail', 'GET /api/v1/programs'),
  });
  requireCheck(programList, 'program list succeeds', (r) => r.status === 200);

  const programDetail = http.get(`${baseUrl}/api/v1/programs/8000000001`, {
    tags: requestTags('list-detail', 'GET /api/v1/programs/{id}'),
  });
  requireCheck(programDetail, 'program detail succeeds', (r) => r.status === 200);
  requireCondition(
    'program detail is deterministic M8-P001',
    json(programDetail, 'program detail').code === 'M8-P001',
  );
  pause();

  login(applicantUsername, applicantPassword, 'APPLICANT');

  const applicantList = http.get(`${baseUrl}/api/v1/applications?size=5`, {
    tags: requestTags('list-detail', 'GET /api/v1/applications'),
  });
  requireCheck(applicantList, 'applicant list succeeds', (r) => r.status === 200);

  let response = writeJson(
    'POST',
    '/api/v1/applications',
    {
      programId: 8000000001,
      applicantOrganizationName: 'M8 W1 Synthetic Organization',
      projectTitle,
      shortSummary: 'M8 W1 correctness smoke application.',
      requestedAmount: 1234567,
      detailedPlan: 'M8 W1 initial detailed plan for workload harness correctness.',
    },
    'create-save',
    'POST /api/v1/applications',
  );
  requireCheck(response, 'application create succeeds', (r) => r.status === 201);
  let application = json(response, 'application create');
  const applicationId = application.id;
  let version = application.version;
  requireCondition(
    'created application is a DRAFT with an id',
    Boolean(applicationId) && application.status === 'DRAFT',
  );

  response = writeJson(
    'PUT',
    `/api/v1/applications/${applicationId}`,
    {
      version,
      applicantOrganizationName: 'M8 W1 Synthetic Organization',
      projectTitle,
      shortSummary: 'M8 W1 edited correctness smoke application.',
      requestedAmount: 1234567,
      detailedPlan: 'M8 W1 edited detailed plan before first submission.',
    },
    'create-save',
    'PUT /api/v1/applications/{id}',
  );
  requireCheck(response, 'draft edit succeeds', (r) => r.status === 200);
  application = json(response, 'draft edit');
  version = application.version;
  pause();

  const uploadToken = csrf('attachment');
  response = http.post(
    `${baseUrl}/api/v1/applications/${applicationId}/attachments`,
    {
      file: http.file(attachmentBody, 'm8-w1-attachment.txt', 'text/plain'),
    },
    {
      headers: { [uploadToken.headerName]: uploadToken.token },
      tags: requestTags('attachment', 'POST /api/v1/applications/{id}/attachments'),
    },
  );
  requireCheck(response, 'attachment upload succeeds', (r) => r.status === 201);
  const attachment = json(response, 'attachment upload');
  requireCondition(
    'uploaded attachment is AVAILABLE',
    Boolean(attachment.id) && attachment.status === 'AVAILABLE',
  );

  response = http.get(
    `${baseUrl}/api/v1/applications/${applicationId}/attachments/${attachment.id}`,
    {
      responseType: 'text',
      tags: requestTags(
        'attachment',
        'GET /api/v1/applications/{id}/attachments/{attachmentId}',
      ),
    },
  );
  requireCheck(
    response,
    'attachment download preserves fixture',
    (r) => r.status === 200 && r.body === attachmentBody,
  );

  const deleteToken = csrf('attachment');
  response = http.del(
    `${baseUrl}/api/v1/applications/${applicationId}/attachments/${attachment.id}`,
    null,
    {
      headers: { [deleteToken.headerName]: deleteToken.token },
      tags: requestTags(
        'attachment',
        'DELETE /api/v1/applications/{id}/attachments/{attachmentId}',
      ),
    },
  );
  requireCheck(response, 'attachment cleanup succeeds', (r) => r.status === 204);
  pause();

  response = writeJson(
    'POST',
    `/api/v1/applications/${applicationId}/submit`,
    { version },
    'submit-resubmit',
    'POST /api/v1/applications/{id}/submit',
  );
  requireCheck(response, 'first submit succeeds', (r) => r.status === 200);
  application = json(response, 'first submit');
  version = application.version;
  requireCondition('first submit reaches SUBMITTED', application.status === 'SUBMITTED');
  logout();
  pause();

  login(reviewerUsername, reviewerPassword, 'REVIEWER');

  const reviewerQueue = http.get(
    `${baseUrl}/api/v1/review/applications?status=SUBMITTED&size=5`,
    {
      tags: requestTags('reviewer-queue-detail', 'GET /api/v1/review/applications'),
    },
  );
  requireCheck(reviewerQueue, 'reviewer queue succeeds', (r) => r.status === 200);

  response = http.get(`${baseUrl}/api/v1/review/applications/${applicationId}`, {
    tags: requestTags(
      'reviewer-queue-detail',
      'GET /api/v1/review/applications/{id}',
    ),
  });
  requireCheck(response, 'reviewer detail succeeds', (r) => r.status === 200);

  response = writeJson(
    'POST',
    `/api/v1/review/applications/${applicationId}/start`,
    { version },
    'review-action',
    'POST /api/v1/review/applications/{id}/start',
  );
  requireCheck(response, 'review start succeeds', (r) => r.status === 200);
  application = json(response, 'review start');
  version = application.version;

  response = writeJson(
    'POST',
    `/api/v1/review/applications/${applicationId}/request-revision`,
    { version, reason: 'M8 W1 synthetic revision request' },
    'review-action',
    'POST /api/v1/review/applications/{id}/request-revision',
  );
  requireCheck(response, 'revision request succeeds', (r) => r.status === 200);
  application = json(response, 'revision request');
  version = application.version;
  requireCondition(
    'revision request reaches NEEDS_REVISION',
    application.status === 'NEEDS_REVISION',
  );
  logout();
  pause();

  login(applicantUsername, applicantPassword, 'APPLICANT');

  response = http.get(`${baseUrl}/api/v1/applications/${applicationId}`, {
    tags: requestTags('list-detail', 'GET /api/v1/applications/{id}'),
  });
  requireCheck(response, 'revision applicant detail succeeds', (r) => r.status === 200);
  application = json(response, 'revision applicant detail');
  version = application.version;

  response = writeJson(
    'PUT',
    `/api/v1/applications/${applicationId}`,
    {
      version,
      applicantOrganizationName: 'M8 W1 Synthetic Organization',
      projectTitle,
      shortSummary: 'M8 W1 revised correctness smoke application.',
      requestedAmount: 1234567,
      detailedPlan: 'M8 W1 revised detailed plan before resubmission.',
    },
    'create-save',
    'PUT /api/v1/applications/{id}',
  );
  requireCheck(response, 'revision edit succeeds', (r) => r.status === 200);
  application = json(response, 'revision edit');
  version = application.version;

  response = writeJson(
    'POST',
    `/api/v1/applications/${applicationId}/submit`,
    { version },
    'submit-resubmit',
    'POST /api/v1/applications/{id}/submit',
  );
  requireCheck(response, 'resubmit succeeds', (r) => r.status === 200);
  application = json(response, 'resubmit');
  version = application.version;
  requireCondition('resubmit returns to SUBMITTED', application.status === 'SUBMITTED');
  logout();
  pause();

  login(reviewerUsername, reviewerPassword, 'REVIEWER');

  response = writeJson(
    'POST',
    `/api/v1/review/applications/${applicationId}/start`,
    { version },
    'review-action',
    'POST /api/v1/review/applications/{id}/start',
  );
  requireCheck(response, 'review restart succeeds', (r) => r.status === 200);
  application = json(response, 'review restart');
  version = application.version;

  response = writeJson(
    'POST',
    `/api/v1/review/applications/${applicationId}/approve`,
    { version },
    'review-action',
    'POST /api/v1/review/applications/{id}/approve',
  );
  requireCheck(response, 'approval succeeds', (r) => r.status === 200);
  application = json(response, 'approval');
  requireCondition('approval reaches APPROVED', application.status === 'APPROVED');

  response = http.get(
    `${baseUrl}/api/v1/review/applications/${applicationId}/history`,
    {
      tags: requestTags(
        'reviewer-queue-detail',
        'GET /api/v1/review/applications/{id}/history',
      ),
    },
  );
  requireCheck(response, 'reviewer history succeeds', (r) => r.status === 200);
  const history = json(response, 'reviewer history');
  const transitions = history.map((row) => `${row.fromStatus}->${row.toStatus}`);
  for (const required of [
    'DRAFT->SUBMITTED',
    'SUBMITTED->IN_REVIEW',
    'IN_REVIEW->NEEDS_REVISION',
    'NEEDS_REVISION->SUBMITTED',
    'IN_REVIEW->APPROVED',
  ]) {
    requireCondition(
      `history contains ${required}`,
      transitions.includes(required),
    );
  }
  logout();
  pause();
}
