import http from 'k6/http';
import { check, sleep } from 'k6';

const baseUrl = (__ENV.BASE_URL || '').replace(/\/$/, '');

if (!baseUrl) {
  throw new Error('BASE_URL is required');
}

export const options = {
  vus: 1,
  duration: '15s',
  discardResponseBodies: true,
  tags: {
    milestone: 'm8',
    profile: 'foundation-smoke',
  },
};

export default function () {
  const response = http.get(`${baseUrl}/api/v1/programs?size=1`, {
    tags: {
      endpoint_family: 'program-list',
      scenario: 'foundation-public-programs',
      name: 'GET /api/v1/programs',
    },
  });

  check(response, {
    'public programs API returns 200': (r) => r.status === 200,
  });

  sleep(1);
}
