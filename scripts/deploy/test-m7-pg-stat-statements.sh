#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
postgresql_conf="$root/config/ansible/roles/db/templates/postgresql.conf.j2"
pg_hba="$root/config/ansible/roles/db/templates/pg_hba.conf.j2"
app_unit="$root/config/ansible/roles/app/templates/arp.service.j2"
release_playbook="$root/config/ansible/release.yml"
deploy_release="$root/deploy/deploy-release.sh"
runtime_schema="$root/config/secrets/runtime.schema.yaml"
migration="$root/app/src/main/resources/db/migration/V6__m7_pg_stat_statements.sql"

grep -Fq "shared_preload_libraries = 'pg_stat_statements'" "$postgresql_conf"
grep -Fq 'compute_query_id = auto' "$postgresql_conf"

grep -Fq 'CREATE EXTENSION IF NOT EXISTS pg_stat_statements;' "$migration"

grep -Fq 'db_migration_password: REQUIRED_RUNTIME_SECRET' "$runtime_schema"
grep -Fq 'host arp arp_flyway {{ app_private_ip }}/32 scram-sha-256' "$pg_hba"
grep -Fq 'EnvironmentFile=-/etc/arp/arp-flyway.env' "$app_unit"
grep -Fq 'ARP_RUNTIME_SECRETS_FILE' "$deploy_release"
grep -Fq 'CREATE ROLE arp_flyway LOGIN SUPERUSER' "$release_playbook"
grep -Fq 'REASSIGN OWNED BY {{ flyway_role }} TO postgres;' "$release_playbook"
grep -Fq 'DROP ROLE {{ flyway_role }};' "$release_playbook"
grep -Fq 'SPRING_FLYWAY_USER={{ flyway_role }}' "$release_playbook"
grep -Fq 'SPRING_FLYWAY_PASSWORD={{ db_migration_password }}' "$release_playbook"
grep -Fq 'Remove temporary Flyway environment' "$release_playbook"
grep -Fq 'Restart application with normal runtime database credentials' "$release_playbook"

if grep -Eq 'ALTER ROLE arp_app .*SUPERUSER|CREATE ROLE arp_app .*SUPERUSER' "$release_playbook"; then
  echo 'The runtime arp_app role must never be elevated for migrations.' >&2
  exit 1
fi

if grep -Eiq 'CREATE[[:space:]]+INDEX|ALTER[[:space:]]+TABLE|EXPLAIN|pg_stat_statements_reset' "$migration"; then
  echo 'M7 pg_stat_statements migration must only enable query statistics, not tune or reset them.' >&2
  exit 1
fi

if grep -R -Eiq \
  --exclude='test-m7-pg-stat-statements.sh' \
  'CREATE[[:space:]]+EXTENSION([[:space:]]+IF[[:space:]]+NOT[[:space:]]+EXISTS)?[[:space:]]+pg_stat_statements' \
  "$root/config/ansible" "$root/deploy" "$root/scripts"; then
  echo 'pg_stat_statements schema activation must remain Flyway-owned.' >&2
  exit 1
fi

echo 'M7 pg_stat_statements repository contract: PASS'
