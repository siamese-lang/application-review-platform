import http from 'k6/http';
import { check, sleep } from 'k6';
import exec from 'k6/execution';
import { Counter, Rate, Trend } from 'k6/metrics';

const baseUrl = (__ENV.BASE_URL || '').replace(/\/$/, '');
const applicantUsername = __ENV.APPLICANT_USERNAME || 'm6-applicant';
const applicantPassword = __ENV.APPLICANT_PASSWORD || '';
const duration = __ENV.M10_DURATION || '3m';

for (const [name, value] of [
  ['BASE_URL', baseUrl],
  ['APPLICANT_PASSWORD', applicantPassword],
]) {
  if (!value) {
    throw new Error(`${name} is required`);
  }
}

const sessionRequests = new Counter('m10_r1_session_requests');
const sessionErrors = new Rate('m10_r1_session_errors');
const sessionDuration = new Trend('m10_r1_session_duration', true);
const sessionLoginAttempts = new Counter('m10_r1_session_login_attempts');

const publicApiRequests = new Counter('m10_r1_public_api_requests');
const publicApiErrors = new Rate('m10_r1_public_api_errors');
const publicApiDuration = new Trend('m10_r1_public_api_duration', true);

const staticEdgeRequests = new Counter('m10_r1_static_edge_requests');
const staticEdgeErrors = new Rate('m10_r1_static_edge_errors');
const staticEdgeDuration = new Trend('m10_r1_static_edge_duration', true);

export const options = {
  noCookiesReset: true,
  scenarios: {
    session_continuity: {
      executor: 'constant-vus',
      exec: 'sessionContinuity',
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
    profile: 'r1-process-failure',
  },
  summaryTrendStats: ['min', 'med', 'avg', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

const states = {};
let sessionReady = false;

function tag(name) {
  return {
    scenario: exec.scenario.name,
    scope: 'reliability-probe',
    name,
  };
}

function transition(probe, response, ok) {
  const state = ok ? 'UP' : 'DOWN';
  if (states[probe] === state) {
    return;
  }
  states[probe] = state;
  const status = response && response.status !== undefined ? response.status : 0;
  const errorCode = response && response.error_code ? response.error_code : '';
  console.log(
    `M10_R1_STATE|probe=${probe}|at=${new Date().toISOString()}|state=${state}|status=${status}|error_code=${errorCode}`,
  );
}

function record(response, ok, requests, errors, durationMetric, probe) {
  requests.add(1);
  errors.add(!ok);
  durationMetric.add(response.timings.duration);
  transition(probe, response, ok);
  return ok;
}

function csrf() {
  return http.get(`${baseUrl}/api/v1/auth/csrf`, {
    tags: tag('GET /api/v1/auth/csrf'),
  });
}

function loginApplicantOnce() {
  sessionLoginAttempts.add(1);

  const tokenResponse = csrf();
  if (tokenResponse.status !== 200) {
    return false;
  }

  let token;
  try {
    token = tokenResponse.json();
  } catch (_) {
    return false;
  }

  if (!token.headerName || !token.token) {
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
      tags: tag('POST /api/v1/auth/login'),
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
  if (ok) {
    sessionReady = true;
    console.log(`M10_R1_SESSION_READY|at=${new Date().toISOString()}`);
  }
  return ok;
}

export function sessionContinuity() {
  if (!sessionReady) {
    if (!loginApplicantOnce()) {
      sleep(0.25);
      return;
    }
  }

  const response = http.get(`${baseUrl}/api/v1/auth/me`, {
    tags: tag('GET /api/v1/auth/me'),
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
  record(response, ok, sessionRequests, sessionErrors, sessionDuration, 'session');
  check(response, {
    'persisted applicant session is usable': () => ok,
  });
  sleep(0.25);
}

export function publicApiProbe() {
  const response = http.get(`${baseUrl}/api/v1/programs?size=1`, {
    tags: tag('GET /api/v1/programs'),
  });
  const ok = response.status === 200;
  record(
    response,
    ok,
    publicApiRequests,
    publicApiErrors,
    publicApiDuration,
    'public_api',
  );
  sleep(0.25);
}

export function staticEdgeProbe() {
  const response = http.get(`${baseUrl}/`, {
    tags: tag('GET /'),
  });
  const ok = response.status === 200;
  record(
    response,
    ok,
    staticEdgeRequests,
    staticEdgeErrors,
    staticEdgeDuration,
    'static_edge',
  );
  sleep(0.25);
}
