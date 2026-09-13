# M6 Phase 6 — Korean Public-Service UI Usability Remediation

Status: COMPLETE SUBPLAN  
Parent milestone: M6 Operations & Delivery — Phase 6 closeout  
Base revision: `d96af2e3c8c0b540e220fd4f01c7cc1356b24c0e`

## Goal

Resolve the usability findings from the real M6 browser inspection without changing the
completed M5/M6 product, API, security, or delivery boundaries.

The deployed SPA should be immediately understandable as a Korean support-program
application/review service for applicant, reviewer, and administrator roles.

The work should borrow relevant Korea Design System (KRDS) public-service principles
such as readable typography, clear information hierarchy, explicit form labels/errors,
structured tables, and accessible responsive layout. This project does **not** claim
formal KRDS conformance.

## Observed findings

Manual inspection of the live HTTPS SPA found:

1. authentication and business functions worked, but a role switch could initially land
   on a protected route retained from the previous navigation and show an authorization
   error;
2. the service, navigation, state labels, form copy, tables, empty states, and operational
   pages are almost entirely English, making the support-program business context harder
   to understand for the intended Korean portfolio audience.

Finding 1 is fixed separately by PR #51. This subplan owns finding 2 and any directly
related readability adjustments only.

## Scope

### 1. Korean service identity and navigation

Use clear Korean public-service wording:

- service name: `지원사업 신청·심사 플랫폼`
- public programs: `지원사업`
- applicant workspace: `내 신청`
- reviewer workspace: `심사 업무`
- administrator workspace: `관리자`
- registration/login/logout and session labels in Korean
- update `frontend/index.html` to `lang="ko"`, Korean title, and Korean description

Do not rename URL paths, backend endpoints, enum values, or database values.

### 2. Shared business labels

Centralize user-facing labels rather than duplicating translations across pages.

Application status labels:

- `DRAFT` → `작성 중`
- `SUBMITTED` → `제출 완료`
- `IN_REVIEW` → `심사 중`
- `NEEDS_REVISION` → `보완 요청`
- `APPROVED` → `승인`
- `REJECTED` → `반려`

Program intake labels:

- `SCHEDULED` → `접수 예정`
- `OPEN` → `접수 중`
- `CLOSED` → `접수 마감`

Roles:

- `APPLICANT` → `신청자`
- `REVIEWER` → `심사자`
- `ADMIN` → `관리자`

Program publication labels:

- `DRAFT` → `작성 중`
- `PUBLISHED` → `게시 완료`

Audit event codes may remain internal values in the API, but the browser UI should render
human-readable Korean event names.

### 3. Korean date, number, and money presentation

User-facing timestamps and money should use Korean-readable formatting.

- dates/times: use `Intl.DateTimeFormat('ko-KR', ...)`
- amounts: use thousands separators and `원`
- do not change wire-format timestamps or numeric API contracts

Create shared formatting helpers if this reduces duplicated page logic.

### 4. Page copy and information hierarchy

Translate and refine visible text for:

- home/public program pages;
- registration/login;
- applicant list/form/detail/attachment/history;
- reviewer queue/detail/actions;
- administrator dashboard/program/application/user/audit pages;
- route guards, error notices, loading/empty states, pagination, buttons, confirmations.

Copy should explain the user's task, not merely translate English literally.

Examples:

- reviewer queue should clearly say that starting review assigns the application;
- applicant forms should distinguish temporary save/edit from final submission;
- administrator dashboard should describe operational counts and management entry points.

### 5. Limited visual/readability refinement

Keep the existing React/CSS structure. Make only changes that improve public-service
readability:

- replace the editorial/display-style `Georgia` heading dependency with a Korean-readable
  sans-serif stack;
- use a Korean-first system stack such as `"Pretendard GOV", Pretendard, "Noto Sans KR",
  "Apple SD Gothic Neo", system-ui, sans-serif` without adding a remote font dependency;
- reduce oversized hero/page headings where they compete with task content;
- keep clear content width, spacing, section headings, labels, table headers, and focus
  states;
- preserve existing responsive horizontal table scrolling and mobile layout;
- do not introduce a new component framework, icon library, animation system, or branding
  exercise.

### 6. Tests

Update tests only where assertions legitimately depend on changed user-facing copy.

Add or retain focused coverage for:

- Korean shared status labels;
- applicant/reviewer/admin navigation labels;
- Korean login/registration copy where relevant;
- browser E2E selectors that currently depend on English text;
- role-aware login redirect regression from PR #51.

Do not weaken behavior assertions merely to make localization pass.

## Expected files/components

Likely affected:

- `frontend/index.html`
- `frontend/src/components/AppShell.tsx`
- `frontend/src/components/StatusBadge.tsx`
- `frontend/src/components/ErrorNotice.tsx`
- role guards under `frontend/src/components/`
- pages under `frontend/src/pages/`
- `frontend/src/styles.css`
- a small shared UI-label/formatting helper if useful
- relevant Vitest files
- `frontend/e2e/application-review.spec.ts`

Do not change Spring controllers/services, Flyway migrations, database schema, Nginx
routing, authentication semantics, or M6 release mechanics for this slice.

## Constraints

- preserve M5 product workflows and M6 architecture;
- no new major dependency;
- no API/route/backend enum rename;
- no new functionality disguised as redesign;
- no public reviewer/admin registration;
- no secret or synthetic credential in source/tests;
- no claim of formal KRDS certification/compliance;
- keep the slice explainable as usability remediation discovered by real browser inspection.

## Verification

Required before merge:

1. frontend type-check;
2. frontend unit/component tests;
3. frontend production build;
4. real-stack Playwright E2E;
5. existing Nginx routing verification;
6. exact-head baseline CI;
7. inspect the actual diff for accidental backend/infrastructure changes.

After merge/publication/deployment:

8. explicit exact-release handoff and activation if the final UI is to be retained live;
9. public HTTPS smoke;
10. repeat a bounded manual browser inspection for public, applicant, reviewer, and admin
    pages;
11. record the usability result in M6 Phase 6 closeout evidence.

## Done condition

This subplan is complete when a Korean-speaking reviewer can open the deployed SPA and
understand what service it is, what each role can do, and what each application/program
state means without relying on source code or English domain terminology, while all
existing business and security behavior remains green.


## Completion result

- Korean public-service wording, shared domain labels, Korean formatting, and bounded readability changes were deployed.
- Role-aware login redirect behavior remained covered and correct.
- Manual validation found one additional pagination affordance issue: disabled buttons used a wait cursor.
- PR #55 changed the disabled cursor semantics and added a regression test proving admin application pagination requests page 1 and returns to page 0.
- Final reviewed/deployed release:
  `9d5fda9871e479e05dc4641fccf7dea3145d2ad6`.
- Final HTTPS/API/Garage smoke passed.
- This work remains KRDS-informed; no formal KRDS conformance claim is made.
