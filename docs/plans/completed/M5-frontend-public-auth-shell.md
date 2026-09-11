# M5 frontend public/auth shell slice

## Goal

Add the first React/TypeScript/Vite frontend slice for public program discovery and applicant registration/session authentication on the accepted M5 REST contract.

## Files/Components

- `frontend/`: Vite application, typed API client, auth context, shell, pages, styles, and focused tests.
- `.github/workflows/baseline-ci.yml`: reproducible frontend install, type, test, and build checks.

## Constraints

- Keep the same-origin Spring Session JDBC and CSRF architecture; do not add JWT, CORS, SSR, a production Node server, or global state frameworks.
- Match TypeScript DTOs to the implemented REST controller records.
- Do not implement applicant, reviewer, or admin workflow screens, production Nginx routing, or M6 delivery work.

## Verification

- `npm ci`, `npm run typecheck`, `npm test -- --run`, and `npm run build` in `frontend/`.
- Existing repository baseline and backend verification remain green.
