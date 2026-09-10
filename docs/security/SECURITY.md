# SECURITY — M0 Frozen Baseline

Status: FROZEN

## Identity and authorization

- Spring Security uses session-based authentication.
- Spring Session JDBC stores session state in PostgreSQL so login state is not tied to one WAS.
- Passwords are hashed; no real personal data is used.
- Server-side identity comes from the authenticated session. Browser-supplied `user_id` or role values are never trusted as authority.
- Ownership and role authorization are enforced in service/domain logic.
- CSRF protection remains enabled for the session-based web application.

## Exposure

- Only the edge layer is publicly exposed for service traffic.
- DB, object storage, observability, backup, app, and ops services are private.
- Administrative access uses IAP rather than public SSH exposure.

## Secrets

- No secrets in Git, GitHub Actions logs, prompts, README files, container images, or application logs.
- Encrypted configuration uses SOPS + age.
- Decryption occurs in the controlled operations path, initially on `ops-01`.
- `ops-01` uses a scoped GCP service account instead of copied personal credentials.

## Logging

Never log passwords, session/token secrets, storage credentials, binary attachments, or sensitive request bodies. Use synthetic identities and business data throughout the project.
