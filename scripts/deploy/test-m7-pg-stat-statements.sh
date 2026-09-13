#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
postgresql_conf="$root/config/ansible/roles/db/templates/postgresql.conf.j2"
migration="$root/app/src/main/resources/db/migration/V6__m7_pg_stat_statements.sql"

grep -Fq "shared_preload_libraries = 'pg_stat_statements'" "$postgresql_conf"
grep -Fq 'compute_query_id = auto' "$postgresql_conf"

grep -Fq 'CREATE EXTENSION IF NOT EXISTS pg_stat_statements;' "$migration"

if grep -Eiq 'CREATE[[:space:]]+INDEX|ALTER[[:space:]]+TABLE|EXPLAIN|pg_stat_statements_reset' "$migration"; then
  echo 'M7 pg_stat_statements migration must only enable query statistics, not tune or reset them.' >&2
  exit 1
fi

if grep -R -Eiq 'CREATE[[:space:]]+EXTENSION([[:space:]]+IF[[:space:]]+NOT[[:space:]]+EXISTS)?[[:space:]]+pg_stat_statements'   "$root/config/ansible" "$root/deploy" "$root/scripts"; then
  echo 'pg_stat_statements schema activation must remain Flyway-owned.' >&2
  exit 1
fi

echo 'M7 pg_stat_statements repository contract: PASS'
