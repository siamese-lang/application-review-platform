# ADR-002 — Define applicant registration and privileged-account provisioning

Status: ACCEPTED

Decision date: 2026-09-11

## Context

M1–M4 used repository/runtime bootstrap accounts to verify authorization, session persistence, applicant workflows, review workflows, and cloud deployment. That was sufficient for infrastructure and integrity milestones, but it does not define how a real browser user becomes an application user.

M5 changes the final browser boundary to a React SPA and REST API and expands the product surface into a recognizable support-program service. The account lifecycle must therefore be explicit before the API and UI are implemented.

The three roles do not have the same trust model:

- an `APPLICANT` is an external user who needs a self-service entry path;
- a `REVIEWER` receives privileged access to other users' submissions and must not be able to grant that role to itself;
- an `ADMIN` is an operational privileged identity and must not be created through public registration.

The project uses only synthetic people and organizations. It does not have a real email-delivery channel, mobile identity verification, enterprise IdP, or external reviewer-invitation system. Implementing a fake version of those systems would add complexity without proving a real trust boundary.

## Decision

### Applicant registration

M5 implements public self-registration for `APPLICANT` users.

The registration contract creates only an `APPLICANT`; the request does not accept an authoritative role field. A client can never register itself as `REVIEWER` or `ADMIN`.

Minimum registration information:

- unique username/login ID;
- password;
- display name;
- email address used as synthetic profile/contact metadata.

The server validates the request, hashes the password using the repository password encoder, stores no plaintext password, and returns a non-secret account representation. Duplicate username/email conflicts are explicit API errors.

Registration and login remain separate operations: successful registration does not silently create an authenticated session. The user signs in through the normal session-authentication endpoint afterward.

Email is not identity-proofing evidence in this project. M5 validates its format and uniqueness but does not claim that the address was externally verified.

### Public browsing before registration

Program list/detail information that is intended for applicants is readable without authentication. Creating, editing, uploading to, submitting, or viewing a private application requires an authenticated applicant session.

This makes the browser flow coherent: discover a program → register/sign in → create an application.

### Reviewer accounts

`REVIEWER` is a privileged role and has no public self-registration path.

For this synthetic project, reviewer identities are provisioned through the controlled operations/bootstrap path with secrets kept outside Git, as M4 already demonstrated. The browser/API must not expose an endpoint that allows an unauthenticated user or applicant to obtain the reviewer role.

A production organization could replace this provisioning source with enterprise SSO, an invitation workflow, or an internal identity-management process. Those trust systems are not simulated merely for appearance.

### Administrator accounts

`ADMIN` also has no public self-registration path. Administrative identities remain controlled bootstrap/operations identities.

M5 does not build a general IAM administration console. Admin business screens remain primarily operational/read-oriented.

### User record

M5 expands the existing `users` record only enough to support the browser identity boundary:

- existing `id`;
- existing unique `username`;
- existing `password_hash`;
- `display_name`;
- `email` with uniqueness enforced for registered identities;
- existing `role`;
- `created_at`;
- `updated_at`.

Existing synthetic bootstrap users are backfilled with synthetic profile values by Flyway. No real personal data is introduced.

No account-status state machine, invitation-token table, external identity table, or organization-membership hierarchy is added until a concrete later requirement needs one.

### Session and authorization

ADR-001 remains authoritative for browser authentication:

- Spring Security session authentication;
- Spring Session JDBC;
- Secure/HttpOnly session cookie in production;
- CSRF protection for unsafe methods;
- JSON 401/403 semantics for API requests;
- same-origin production routing through Nginx.

Registration does not weaken those controls. Ownership and role checks remain server-side.

### Audit boundary

Successful account registration creates a non-secret audit event such as `USER_REGISTERED`. ADR-003 generalizes the existing application-only audit target model so this user-subject event is referentially represented without pretending it belongs to an application. Password values and session/CSRF secrets are never audited or logged.

Login success/failure event collection is not required in M5; authentication telemetry belongs to later observability/security work if it becomes useful.

## Explicitly deferred

M5 does not implement or claim:

- real-name or government identity verification;
- email verification;
- password-reset email delivery;
- SMS/OTP/MFA;
- OAuth/OIDC/SSO/Keycloak;
- reviewer invitation email;
- public reviewer/admin signup;
- enterprise organization membership/role administration;
- account deletion/compliance workflows.

These are legitimate production concerns, but without the relevant external identity or messaging systems they would be synthetic complexity rather than evidence of a working trust integration.

## Consequences

Positive:

- the applicant journey has a credible unauthenticated-to-authenticated boundary;
- the project demonstrates password hashing, uniqueness/validation, session creation, authorization, and public/private API separation;
- privileged roles have an explicit trust boundary instead of being selectable during signup;
- the design remains testable without introducing a fake identity provider or messaging service.

Trade-offs:

- reviewer/admin provisioning is operational rather than self-service;
- email ownership is not verified;
- lost-password recovery is intentionally absent from the synthetic product.

These limitations must be stated rather than presented as production-complete identity management.

## Verification requirements

M5 must verify at least:

1. an unauthenticated user can read public program list/detail endpoints;
2. a valid registration creates exactly an `APPLICANT` account;
3. registration cannot assign `REVIEWER` or `ADMIN` authority;
4. duplicate username/email and invalid input return structured API errors;
5. stored passwords are hashes and plaintext passwords are never returned/logged;
6. a newly registered applicant can subsequently log in and establish the existing JDBC-backed session;
7. unauthenticated users still cannot access private application/reviewer/admin APIs;
8. an applicant cannot access reviewer/admin APIs;
9. bootstrap reviewer/admin accounts continue to authenticate through the same session infrastructure;
10. the applicant browser E2E begins with public program discovery and includes registration/login before creating a private application.
