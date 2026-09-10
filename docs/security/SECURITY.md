# SECURITY — M0 Baseline amended by ADR-001

Status: FROZEN EXCEPT AS AMENDED BY ACCEPTED ADRS

## Identity and authorization

- Spring Security uses session-based authentication.
- Spring Session JDBC stores session state in PostgreSQL so login state is not tied to one WAS.
- React does not change the authentication authority: the server-side authenticated session remains authoritative.
- Passwords are hashed; no real personal data is used.
- Server-side identity comes from the authenticated session. Browser-supplied `user_id`, owner, reviewer, or role values are never trusted as authority.
- Ownership, role authorization, and application-state authorization remain enforced in service/domain logic.
- UI route guards and hidden buttons are convenience only and are never security controls.

## Browser/API security

- Production SPA and API use one HTTPS origin through Nginx.
- Session cookies must be Secure and HttpOnly and use an explicit SameSite policy appropriate to the first-party workflow.
- JavaScript must never read or persist the session identifier.
- CSRF protection remains enabled for unsafe methods.
- The SPA obtains an explicit CSRF token through a controlled bootstrap endpoint/mechanism and sends it using the configured request header.
- API authentication and authorization failures return JSON 401/403 responses instead of redirecting API clients to an HTML login page.
- Login and logout behavior must be covered by integration/browser tests.
- Do not store bearer/session credentials in `localStorage` or `sessionStorage`.

## CORS

The intended production topology is same-origin: Nginx serves the SPA and proxies `/api/**` to the private Spring application. No permissive CORS configuration is needed for this normal path.

Local React development should use the Vite `/api` development proxy rather than adding wildcard CORS.

If a real cross-origin client is later introduced:

- add only the specific allowed origin(s), methods, and headers required;
- never combine credentialed browser requests with `Access-Control-Allow-Origin: *`;
- process CORS before Spring Security authentication handling;
- add explicit tests for allowed and rejected origins.

## API input/output boundary

- REST controllers accept explicit validated request DTOs and return explicit response DTOs.
- JPA entities are not exposed directly as JSON contracts.
- Client-supplied workflow status, role, owner, reviewer, object key, hash, or other authoritative server facts are ignored/rejected unless the endpoint explicitly owns that transition.
- Stale application edits fail with a conflict rather than silently overwriting a newer version.
- Error responses must not leak stack traces, credentials, internal filesystem paths, storage secrets, or unnecessary implementation details.

## File handling

- Existing Garage attachment lifecycle and server-side ownership/state checks remain authoritative.
- Upload size/content-type controls must be explicit and consistent between Nginx and Spring.
- Object keys and storage credentials are never supplied by the browser as authority.
- Attachment downloads are authorized by the backend before object access is granted/streamed.

## Exposure

- Only the edge layer is publicly exposed for service traffic.
- Nginx serves the frontend static release and proxies API traffic to the private app service.
- DB, object storage, observability, backup, app, and ops services are private.
- Administrative access uses IAP rather than public SSH exposure.

## Secrets

- No secrets in Git, GitHub Actions logs, prompts, README files, frontend bundles, container images, or application logs.
- Frontend builds must contain only public runtime configuration; database/storage credentials and server secrets never become `VITE_*` or other browser-exposed build variables.
- Encrypted configuration uses SOPS + age.
- Decryption occurs in the controlled operations path.
- `ops-01` uses a scoped GCP service account instead of copied personal credentials.

## Logging

Never log passwords, session/CSRF secrets, storage credentials, binary attachments, or sensitive request bodies. Use synthetic identities and business data throughout the project.

Later observability may record route template, response status, duration, request correlation identifiers, and synthetic actor/role identifiers only when this can be done without exposing credentials or sensitive payloads.
