#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
schema="$root/config/secrets/runtime.schema.yaml"
db_tasks="$root/config/ansible/roles/db/tasks/main.yml"
alloy_tasks="$root/config/ansible/roles/alloy/tasks/main.yml"
alloy_unit="$root/config/ansible/roles/alloy/templates/alloy.service.j2"
postgres_alloy="$root/monitoring/alloy/postgres.alloy"
postgresql_conf="$root/config/ansible/roles/db/templates/postgresql.conf.j2"
pg_hba="$root/config/ansible/roles/db/templates/pg_hba.conf.j2"

grep -Fq 'db_monitor_password: REQUIRED_RUNTIME_SECRET' "$schema"
grep -Fq "listen_addresses = '{{ db_private_ip }},localhost'" "$postgresql_conf"
grep -Fq 'host all all 127.0.0.1/32 scram-sha-256' "$pg_hba"

grep -Fq 'CREATE ROLE arp_monitor' "$db_tasks"
grep -Fq 'NOSUPERUSER' "$db_tasks"
grep -Fq 'NOCREATEDB' "$db_tasks"
grep -Fq 'NOCREATEROLE' "$db_tasks"
grep -Fq 'NOREPLICATION' "$db_tasks"
grep -Fq 'NOBYPASSRLS' "$db_tasks"
grep -Fq 'CONNECTION LIMIT 5' "$db_tasks"
grep -Fq "GRANT pg_monitor TO arp_monitor" "$db_tasks"
grep -Fq "GRANT CONNECT ON DATABASE arp TO arp_monitor" "$db_tasks"
grep -Fq 'DB_MONITOR_PASSWORD: "{{ db_monitor_password }}"' "$db_tasks"
grep -Fq 'PGPASSWORD="$DB_MONITOR_PASSWORD" psql' "$db_tasks"
grep -Fq -- '--host=127.0.0.1' "$db_tasks"
grep -Fq -- '--username=arp_monitor' "$db_tasks"
grep -Fq 'ALTER ROLE arp_monitor PASSWORD' "$db_tasks"
grep -Fq 'no_log: true' "$db_tasks"

grep -Fq 'path: /etc/alloy/secrets' "$alloy_tasks"
grep -Fq 'dest: /etc/alloy/secrets/postgres-monitor-password' "$alloy_tasks"
grep -Fq 'content: "{{ db_monitor_password }}"' "$alloy_tasks"
grep -Fq "mode: '0640'" "$alloy_tasks"
grep -Fq 'src: "{{ playbook_dir }}/../../monitoring/alloy/postgres.alloy"' "$alloy_tasks"
grep -Fq 'dest: /etc/alloy/postgres.alloy' "$alloy_tasks"
grep -Fq "when: alloy_node_role == 'db'" "$alloy_tasks"
grep -Fq "when: alloy_node_role != 'db'" "$alloy_tasks"

grep -Fq '  /etc/alloy' "$alloy_unit"
if grep -Fq '  /etc/alloy/config.alloy' "$alloy_unit"; then
  echo 'Alloy must load the config directory so db-only config can be attached safely.' >&2
  exit 1
fi

grep -Fq 'local.file "postgres_monitor_password"' "$postgres_alloy"
grep -Fq 'filename  = "/etc/alloy/secrets/postgres-monitor-password"' "$postgres_alloy"
grep -Fq 'is_secret = true' "$postgres_alloy"
grep -Fq 'prometheus.exporter.postgres "database"' "$postgres_alloy"
grep -Fq 'local.file.postgres_monitor_password.content + "@127.0.0.1:5432/arp?sslmode=disable"' "$postgres_alloy"
if grep -Fq 'convert.nonsensitive' "$postgres_alloy"; then
  echo 'PostgreSQL monitoring credential must remain a secret in Alloy.' >&2
  exit 1
fi
grep -Fq 'prometheus.scrape "postgres"' "$postgres_alloy"
grep -Fq 'scrape_interval = "15s"' "$postgres_alloy"
grep -Fq 'forward_to      = [prometheus.remote_write.central.receiver]' "$postgres_alloy"
grep -Fq "{% if alloy_node_role in ['edge', 'db'] %}" "$alloy_unit"
grep -Fq 'SupplementaryGroups=adm' "$alloy_unit"
grep -Fq 'loki.source.file "postgres"' "$postgres_alloy"
grep -Fq '"__path__"    = "/var/log/postgresql/postgresql-*-main.log"' "$postgres_alloy"
grep -Fq '"service"     = "postgresql"' "$postgres_alloy"
grep -Fq '"stream"      = "database"' "$postgres_alloy"
grep -Fq 'forward_to = [loki.write.central.receiver]' "$postgres_alloy"
grep -Fq 'file_match {' "$postgres_alloy"

if grep -Eq 'db_app_password|arp_app|10\.40\.0\.30:5432' "$postgres_alloy"; then
  echo 'PostgreSQL metrics must use the dedicated local monitoring credential.' >&2
  exit 1
fi

echo 'M7 PostgreSQL metrics repository contract: PASS'
