import http from 'k6/http';
import { check, sleep } from 'k6';
import exec from 'k6/execution';
import { Counter, Rate, Trend } from 'k6/metrics';

const baseUrl = (__ENV.BASE_URL || '').replace(/\/$/, '');
const applicantUsername = __ENV.APPLICANT_USERNAME || 'm6-applicant';
const applicantPassword = __ENV.APPLICANT_PASSWORD || '';
const runId = __ENV.RUN_ID || '';
const attachmentPath = __ENV.ATTACHMENT_PATH || '../fixtures/w1-attachment.txt';
const attachmentBody = open(attachmentPath);
const duration = __ENV.M10_DURATION || '4m';

for (const [name, value] of [
  ['BASE_URL', baseUrl],
  ['APPLICANT_PASSWORD', applicantPassword],
  ['RUN_ID', runId],
]) {
  if (!value) {
    throw new Error(`${name} is required`);
  }
}

const attachmentAttempts = new Counter('m10_r3a_attachment_attempts');
const attachmentErrors = new Rate('m10_r3a_attachment_errors');
const attachmentUploadErrors = new Rate('m10_r3a_attachment_upload_errors');
const attachmentDownloadErrors = new Rate('m10_r3a_attachment_download_errors');
const attachmentDeleteErrors = new Rate('m10_r3a_attachment_delete_errors');
const attachmentDuration = new Trend('m10_r3a_attachment_duration', true);

const nonAttachmentAttempts = new Counter('m10_r3a_non_attachment_attempts');
const nonAttachmentErrors = new Rate('m10_r3a_non_attachment_errors');
const nonAttachmentDuration = new Trend('m10_r3a_non_attachment_duration', true);

const supportErrors = new Rate('m10_r3a_support_errors');

export const options = {
  noCookiesReset: true,
  scenarios: {
    attachment_continuity: {
      executor: 'constant-vus',
      exec: 'attachmentContinuity',
      vus: 2,
      duration,
      gracefulStop: '10s',
    },
    non_attachment_continuity: {
      executor: 'constant-vus',
      exec: 'nonAttachmentContinuity',
      vus: 2,
      duration,
      gracefulStop: '10s',
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
    profile: 'r3a-garage-non-endpoint',
  },
  summaryTrendStats: ['min', 'med', 'avg', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

let authenticated = false;
let attachmentReadyLogged = false;
let nonAttachmentReadyLogged = false;

function tags(name, scope) {
  return {
    scenario: exec.scenario.name,
    scope,
    name,
  };
}

function pace(startedAtMs, targetSeconds) {
  const elapsed = (Date.now() - startedAtMs) / 1000;
  if (elapsed < targetSeconds) {
    sleep(targetSeconds - elapsed);
  }
}

function csrf() {
  const response = http.get(`${baseUrl}/api/v1/auth/csrf`, {
    tags: tags('GET /api/v1/auth/csrf', 'support'),
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
  supportErrors.add(!ok);
  return ok ? body : null;
}

function ensureApplicant() {
  if (authenticated) {
    return true;
  }

  const token = csrf();
  if (!token) {
    return false;
  }

  const response = http.post(
    `${baseUrl}/api/v1/auth/login`,
    JSON.stringify({
      username: applicantUsername,
      password: applicantPassword,
    }),
    {
      headers: {
        [token.headerName]: token.token,
        'Content-Type': 'application/json',
      },
      tags: tags('POST /api/v1/auth/login', 'support'),
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
  supportErrors.add(!ok);
  if (ok) {
    authenticated = true;
  }
  return ok;
}

const APPLICATION_BASE = 8200000000;

function draftId(slot) {
  return APPLICATION_BASE + 1 + 12 * slot;
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

export function attachmentContinuity() {
  const started = Date.now();
  attachmentAttempts.add(1);
  let overallOk = true;

  if (!ensureApplicant()) {
    attachmentErrors.add(true);
    pace(started, 2.0);
    return;
  }

  const slot = 7800 + (exec.vu.idInTest % 100);
  const applicationId = draftId(slot);

  const uploadToken = csrf();
  if (!uploadToken) {
    attachmentErrors.add(true);
    pace(started, 2.0);
    return;
  }

  const uploaded = http.post(
    `${baseUrl}/api/v1/applications/${applicationId}/attachments`,
    {
      file: http.file(
        attachmentBody,
        `m10-r3a-${runId}-${exec.vu.idInTest}.txt`,
        'text/plain',
      ),
    },
    {
      headers: { [uploadToken.headerName]: uploadToken.token },
      tags: tags('POST attachment', 'attachment'),
    },
  );

  const uploadOk = uploaded.status === 201;
  attachmentUploadErrors.add(!uploadOk);
  overallOk = overallOk && uploadOk;

  const attachment = jsonOrNull(uploaded);
  if (uploadOk && attachment && attachment.id !== undefined) {
    const downloaded = http.get(
      `${baseUrl}/api/v1/applications/${applicationId}/attachments/${attachment.id}`,
      {
        responseType: 'text',
        tags: tags('GET attachment', 'attachment'),
      },
    );

    const downloadOk =
      downloaded.status === 200 && downloaded.body === attachmentBody;
    attachmentDownloadErrors.add(!downloadOk);
    overallOk = overallOk && downloadOk;

    check(downloaded, {
      'R3a attachment payload matches fixture': () => downloadOk,
    });

    const deleteToken = csrf();
    if (deleteToken) {
      const deleted = http.del(
        `${baseUrl}/api/v1/applications/${applicationId}/attachments/${attachment.id}`,
        null,
        {
          headers: { [deleteToken.headerName]: deleteToken.token },
          tags: tags('DELETE attachment', 'attachment'),
        },
      );
      const deleteOk = deleted.status === 204;
      attachmentDeleteErrors.add(!deleteOk);
      overallOk = overallOk && deleteOk;
    } else {
      attachmentDeleteErrors.add(true);
      overallOk = false;
    }
  } else {
    attachmentDownloadErrors.add(true);
    attachmentDeleteErrors.add(true);
    overallOk = false;
  }

  attachmentErrors.add(!overallOk);
  attachmentDuration.add(Date.now() - started);

  if (overallOk && !attachmentReadyLogged) {
    attachmentReadyLogged = true;
    console.log(`M10_R3A_ATTACHMENT_OK|at=${new Date().toISOString()}`);
  }

  pace(started, 2.0);
}

export function nonAttachmentContinuity() {
  const started = Date.now();
  nonAttachmentAttempts.add(1);

  if (!ensureApplicant()) {
    nonAttachmentErrors.add(true);
    pace(started, 1.0);
    return;
  }

  const list = http.get(`${baseUrl}/api/v1/applications?size=20`, {
    tags: tags('GET /api/v1/applications', 'non-attachment'),
  });

  const slot = 7900 + (exec.vu.idInTest % 50);
  const detail = http.get(
    `${baseUrl}/api/v1/applications/${draftId(slot)}`,
    {
      tags: tags('GET /api/v1/applications/{id}', 'non-attachment'),
    },
  );

  const ok = list.status === 200 && detail.status === 200;
  nonAttachmentErrors.add(!ok);
  nonAttachmentDuration.add(Date.now() - started);

  check(list, {
    'R3a application list remains available': () => list.status === 200,
  });
  check(detail, {
    'R3a application detail remains available': () => detail.status === 200,
  });

  if (ok && !nonAttachmentReadyLogged) {
    nonAttachmentReadyLogged = true;
    console.log(`M10_R3A_NON_ATTACHMENT_OK|at=${new Date().toISOString()}`);
  }

  pace(started, 1.0);
}
