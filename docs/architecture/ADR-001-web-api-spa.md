# ADR-001 — Adopt a REST API and React SPA browser boundary

Status: ACCEPTED

Decision date: 2026-09-11

## Context

The M0 baseline selected Spring MVC + Thymeleaf as the browser presentation stack and explicitly listed a React SPA as a non-goal. M1–M4 successfully proved business-state integrity, attachment handling, and deployment on the split-role GCP IaaS topology.

Real M4 browser verification exposed a different problem: the supported UI is still close to raw server-rendered forms and does not communicate the application/review workflow well enough for the finished system. The current domain representation is also deliberately minimal (`Program` is primarily title/description and `Application` is primarily title/content/status), so a cosmetic CSS pass alone would improve appearance without creating a strong web-system boundary for later delivery, observability, workload, and performance work.

The project is intended to demonstrate a coherent production-like system that can be explained in an interview. The browser boundary therefore needs to demonstrate intentional API design, browser security, frontend build/deployment, reverse-proxy routing, and realistic role-based workflow screens without adding complexity that has no operational reason.

This decision is made immediately after M4 because M5+ delivery automation, observability, and load testing should target the final browser/API boundary rather than be rebuilt later.

## Decision

Replace Thymeleaf as the primary browser presentation with a React + TypeScript single-page application backed by a versioned Spring Boot REST API.

The backend remains one Spring Boot modular monolith. Existing domain/service logic, PostgreSQL, Garage, Spring Session JDBC, Flyway, Nginx, and the M4 IaaS role separation remain valid unless a later ADR changes them.

Target production topology:

```text
Browser
  │ HTTPS
  ▼
edge-01: Nginx
  ├─ /, /assets/**     → React/Vite static release
  └─ /api/v1/**        → app-01: Spring Boot REST API
                              ├─ JDBC → db-01: PostgreSQL
                              └─ S3 API → Garage
```

### Frontend runtime choice

Use React with TypeScript and Vite to produce static assets. The production frontend has no dedicated Node process and no separate frontend VM. Nginx serves the compiled static release directly.

A full-stack React framework or SSR server is not justified because the application is an authenticated workflow system, SEO is not a goal, and the existing Spring backend already owns business and data access. A static SPA keeps the runtime boundary simple while still creating a real frontend build and deployment artifact.

### API boundary

Use `/api/v1` for browser APIs. REST controllers use explicit DTOs and delegate business rules to existing services/domain objects. JPA entities are never the public JSON contract.

Use resource-oriented endpoints for reads and edits, and explicit command endpoints where a domain transition is clearer than pretending the operation is generic CRUD. Examples include submit, start-review, request-revision, approve, and reject.

List endpoints that can grow use explicit pagination/filter contracts. HTTP 409 represents stale-version/transition conflicts. Validation, authentication, authorization, not-found, and conflict responses use a consistent JSON problem shape.

### Authentication and browser security

Keep Spring Security session authentication and Spring Session JDBC rather than introducing JWT solely because the client is a SPA.

Rationale:

- the only supported first-party client is a browser application;
- frontend and API share one production origin;
- server-side session invalidation is straightforward;
- the project already externalizes session state from the application process through JDBC;
- a JWT refresh/token-storage subsystem would add a second authentication lifecycle without a demonstrated requirement.

The session identifier remains in a Secure, HttpOnly cookie. Unsafe methods remain CSRF-protected. The SPA obtains a CSRF token through an explicit bootstrap mechanism and sends it on modifying requests. API authentication/authorization failures return JSON 401/403 responses instead of HTML login redirects.

### CORS policy

Production deliberately uses one origin through Nginx, so the normal browser path does not require permissive CORS.

Local frontend development uses the Vite development proxy for `/api`. Do not add wildcard CORS merely to make local development convenient.

If a real cross-origin client is introduced later, configure only the required origins/methods/headers and process CORS before Spring Security. That future requirement must be demonstrated rather than assumed.

### Product-surface enrichment

Add a small set of structured fields required to make the system recognizable as a support-program application/review workflow. The approved direction is additive, not an enterprise feature expansion:

- Program: stable program code and application window in addition to title/description.
- Application: organization name, project title, short summary, requested amount, detailed plan/content, plus existing workflow fields.

Existing status history remains the authoritative transition record. Do not create dynamic form builders, organization hierarchies, notification subsystems, or separate comment services without a concrete requirement.

### Deployment contract

The frontend and backend are separate artifacts from the same repository revision:

- frontend: versioned Vite `dist` release served by Nginx;
- backend: versioned Spring Boot JAR served by `app-01`.

Nginx routes `/api/` before SPA fallback. Fingerprinted assets may use long-lived caching while `index.html` must remain update-safe. The later Operations milestone owns artifact promotion, migration order, rollback, and deployment automation.

## Alternatives considered

### Keep Thymeleaf and only improve CSS

Rejected as the final architecture. It would be the smallest change, but it would leave API design, frontend artifact delivery, SPA session/CSRF behavior, and frontend/backend routing outside the system being measured later. It would also make the final project look disproportionately like an early Spring MVC exercise despite the operational scope built around it.

### React SPA with JWT authentication

Rejected. JWT is useful for specific distributed/mobile/external-client requirements, but none currently exists. Adding access/refresh token issuance and browser token lifecycle only to appear modern would make the authentication architecture less defensible, not more.

### Separate frontend VM or Node production server

Rejected. Static frontend assets do not require an additional compute failure domain. Nginx already exists at the public edge and can serve the release efficiently.

### Next.js/SSR

Rejected for the current requirements. Server-side rendering and an additional application runtime do not materially improve an authenticated support-program workflow and would add deployment and observability scope unrelated to project goals.

### Microservice split during the frontend rewrite

Rejected. Browser/API separation does not justify breaking the business application into distributed services. The modular monolith preserves transaction boundaries and keeps failure analysis focused.

## Consequences

Positive:

- the project gains an explicit HTTP API contract and typed frontend boundary;
- frontend build/deployment, Nginx routing, session/CSRF handling, API errors, and browser E2E become verifiable system concerns;
- later CI/CD, observability, k6, and performance work target the final interface;
- the UI can represent applicant/reviewer/admin workflows at a credible business-system level;
- the architecture remains operationally small: no additional production VM or managed service.

Costs:

- M5 requires DTO/API work, additive Flyway migrations, frontend implementation, and browser tests;
- existing Thymeleaf controllers/templates become migration code and must eventually be removed;
- later milestones are renumbered to insert this work before Operations.

Risks and controls:

- duplicated authorization in UI: UI visibility is convenience only; server service/domain checks remain authoritative;
- API/entity coupling: explicit DTOs and contract tests prevent JPA leakage;
- SPA stale writes: client-observed application version is required and conflicts return 409;
- CSRF mistakes: keep Spring Security CSRF enabled and cover modifying flows with integration/E2E tests;
- frontend dependency growth: keep the dependency set minimal and do not add state frameworks without evidence.

## Superseded baseline statements

This ADR supersedes only these M0 statements:

- `Spring MVC + Thymeleaf` as the final primary browser presentation boundary;
- `React SPA` as a blanket non-goal.

It does not supersede the domain state machine, PostgreSQL/Garage responsibilities, Spring Session JDBC decision, GCP IaaS boundary, Nginx public-edge role, failure-domain separation, secret handling, or measurement-first policy.

## Verification

The decision is considered successfully implemented only when the active M5 plan is completed with API integration tests, frontend build/tests, real browser E2E against the backend test stack, same-origin routing verification, session/CSRF verification, and a recognizable applicant/reviewer/admin workflow surface.
