#!/usr/bin/env bash
set -euo pipefail
umask 077
: "${DATABASE_URL:?libpq database URL required}"
: "${SYNTHETIC_APPLICANT_PASSWORD:?required}"
: "${SYNTHETIC_REVIEWER_PASSWORD:?required}"
: "${SYNTHETIC_ADMIN_PASSWORD:?required}"
command -v htpasswd >/dev/null || { echo 'apache2-utils/htpasswd is required' >&2; exit 1; }
for role in APPLICANT REVIEWER ADMIN; do
  var="SYNTHETIC_${role}_PASSWORD"; password=${!var}; username="m4-${role,,}"
  hash=$(htpasswd -bnBC 12 '' "$password" | tr -d ':\n')
  PGOPTIONS='--client-min-messages=warning' psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -v username="$username" -v hash="$hash" -v role="$role" <<'SQL' >/dev/null
INSERT INTO users (username, password_hash, role)
SELECT :'username', :'hash', :'role'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = :'username');
SQL
done
echo 'Synthetic users are present; existing accounts were not rotated.'
