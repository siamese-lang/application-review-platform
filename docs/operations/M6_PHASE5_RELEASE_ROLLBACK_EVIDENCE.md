# M6 Phase 5 — Immutable Release Deployment and Rollback Evidence

Status: VERIFIED

Execution date: 2026-09-12 UTC  
Final intended release: `a26193598d0fbcb5a2f6d468739b36b7aef3f0aa`

This record contains sanitized M6 Phase 5 deployment and rollback evidence. It intentionally omits plaintext passwords, BCrypt hashes, Garage secrets, the age private key, OS Login SSH material, session cookies, and decrypted SOPS content.

## Release identities

### Release A — retained rollback target

- source SHA: `53f5796235114481c62d9d178e395738f486ea3e`
- baseline CI run: `34684066677`
- OCI digest: `sha256:0f3ec84718f001439b1cab365cfe8dc5f18246395f0dd0d3b71bb8d1398a49f9`
- backend SHA-256: `94e15ef5ce57d9c40186f6dbcd9347bb03de4fbb500fad29e3c4c22c8b251f7b`
- frontend SHA-256: `c25587c981be6baf2392ef40082670f87374ae149b80fdc8d4cd847024ff965e`

### Release B — intended final release

- source SHA: `a26193598d0fbcb5a2f6d468739b36b7aef3f0aa`
- post-merge baseline CI / publication run: `34692775057`
- exact-release handoff run: `34695033956`
- OCI digest: `sha256:63716c0ff1b679ef2293fe1be47183828c87f323d13d2842bb8e8e84d280345c`
- backend SHA-256: `1dc0482e1d3aa4f608e77e68d6a74983994e68db2c9a2083582655482a346f4b`
- frontend SHA-256: `c25587c981be6baf2392ef40082670f87374ae149b80fdc8d4cd847024ff965e`

Both publication jobs retained a release manifest binding the backend/frontend payloads to one full source commit and verified the pulled OCI artifact by digest before the live deployment work.

## First activation and schema state

Release A was the first live immutable release activated through the M6 path. Its activation completed with `failed=0` for `app-01` and `edge-01`.

The first backend activation applied the final Flyway schema through V5. Live verification reported:

- Flyway V1–V5 present and successful;
- failed migration count: 0.

Synthetic controlled users were then bootstrapped without logging credentials. Identity-only verification returned:

```text
m6-admin:ADMIN
m6-applicant:APPLICANT
m6-reviewer:REVIEWER
```

## Public HTTPS business verification

The deployed smoke exercised the real HTTPS/Nginx/Spring/PostgreSQL/Garage path and passed:

- SPA root;
- SPA deep-link fallback;
- public programs API;
- applicant registration, login, session, and CSRF;
- structured application create/edit/submit;
- attachment upload and SHA-256-identical download through Garage;
- controlled reviewer login;
- review start and approval;
- reviewer attachment download integrity;
- final application state and status-history transitions.

No TLS-verification bypass was used.

## Release B activation

Release B was staged by the exact-release handoff workflow and activated through the versioned release path.

Before rollback, live release-state verification reported:

```text
backend current:  a26193598d0fbcb5a2f6d468739b36b7aef3f0aa
backend previous: 53f5796235114481c62d9d178e395738f486ea3e
frontend current:  a26193598d0fbcb5a2f6d468739b36b7aef3f0aa
frontend previous: 53f5796235114481c62d9d178e395738f486ea3e
```

The full HTTPS/API/Garage smoke passed on Release B before the rollback drill.

## Schema-compatible rollback drill

Repository comparison between Release A and Release B contained no application schema/Flyway migration change. The rollback was therefore explicitly acknowledged as schema compatible.

The real rollback operation switched Release B back to retained Release A and restarted/waited for backend readiness.

Observed rollback elapsed time:

- `38,346 ms` (`38.346 s`).

This is one observed operational measurement, not an SLA or availability guarantee.

Database migration rollback performed:

- **NO**.

After rollback, release-state verification reported:

```text
backend current:  53f5796235114481c62d9d178e395738f486ea3e
backend previous: a26193598d0fbcb5a2f6d468739b36b7aef3f0aa
frontend current:  53f5796235114481c62d9d178e395738f486ea3e
frontend previous: a26193598d0fbcb5a2f6d468739b36b7aef3f0aa
```

The complete HTTPS/API/Garage business smoke then passed on the rolled-back Release A, including application create/edit/submit, review approval, status history, and attachment SHA-256 integrity.

## Return to intended release

Release B was reactivated after the rollback drill.

Final release-state verification restored:

```text
backend current:  a26193598d0fbcb5a2f6d468739b36b7aef3f0aa
backend previous: 53f5796235114481c62d9d178e395738f486ea3e
frontend current:  a26193598d0fbcb5a2f6d468739b36b7aef3f0aa
frontend previous: 53f5796235114481c62d9d178e395738f486ea3e
```

The final full HTTPS/API/Garage smoke passed again after Release B restoration.

## Evidence boundary

Phase 5 proves that the project can:

1. identify a reviewed release by full source SHA and immutable OCI digest;
2. bind backend and frontend payloads to that release with retained checksums;
3. stage and activate the exact release through the controlled GitHub WIF → IAP/OS Login → `ops-01` path;
4. apply/verify the expected Flyway schema and bootstrap controlled synthetic identities;
5. verify the real HTTPS business and Garage attachment path;
6. roll back to the recorded previous schema-compatible release;
7. verify the same business path after rollback;
8. return to the intended final release.

Phase 5 does **not** claim automatic database rollback. A future application release that is incompatible with the current schema must block this rollback path or use a separately designed forward-repair strategy.

Manual browser inspection, final post-deploy infrastructure no-drift verification, and the retain/destroy lifecycle decision remain Phase 6 closeout work.
