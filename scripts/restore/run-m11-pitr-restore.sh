#!/usr/bin/env bash
set -euo pipefail

target_time=${1:-}
marker_code=${2:-}

if [[ -z $target_time || -z $marker_code ]]; then
  echo "usage: $0 <target-time> <marker-code>" >&2
  exit 2
fi
if [[ ! $target_time =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+[+-][0-9]{2}(:?[0-9]{2})?$ ]]; then
  echo "invalid PITR target timestamp: $target_time" >&2
  exit 2
fi
if [[ ! $marker_code =~ ^M11-PITR-[A-Za-z0-9._-]+$ || ${#marker_code} -gt 50 ]]; then
  echo "invalid marker code" >&2
  exit 2
fi

pg_major=$(pg_config --version | awk '{print $2}' | cut -d. -f1)
unit="postgresql@${pg_major}-main.service"
data_dir=/srv/postgresql/data

if systemctl is-active --quiet "$unit"; then
  echo "recovery PostgreSQL must be stopped before PITR" >&2
  exit 1
fi
if find "$data_dir" -mindepth 1 -print -quit | grep -q .; then
  echo "recovery data directory is not empty; refusing non-fresh restore" >&2
  exit 1
fi

start_ms=$(date +%s%3N)
start_iso=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)

sudo -u postgres pgbackrest \
  --stanza=arp \
  --type=time \
  "--target=$target_time" \
  --target-action=promote \
  restore

restore_done_ms=$(date +%s%3N)

systemctl start "$unit"
ready=false
for _ in $(seq 1 120); do
  if pg_isready --host=127.0.0.1 --port=5432 --quiet; then
    ready=true
    break
  fi
  sleep 1
done
[[ $ready == true ]] || {
  journalctl -u "$unit" --since "$start_iso" --no-pager | tail -n 120 >&2 || true
  echo "recovery PostgreSQL did not become ready" >&2
  exit 1
}

ready_ms=$(date +%s%3N)
psql_arp=(sudo -u postgres psql --no-psqlrc --set ON_ERROR_STOP=1 --dbname=arp)
psql_marker() {
  local sql=$1
  printf '%s\n' "$sql" | "${psql_arp[@]}" -Atq --set "marker_code=$marker_code"
}

marker_count=$(psql_marker "SELECT count(*) FROM programs WHERE code=:'marker_code'")
marker_state=$(psql_marker "SELECT description FROM programs WHERE code=:'marker_code'")

[[ $marker_count == 1 ]] || {
  echo "expected exactly one restored marker row, found: $marker_count" >&2
  exit 1
}
[[ $marker_state == M11_PITR_PRE ]] || {
  echo "unexpected restored marker state: $marker_state" >&2
  exit 1
}

orphan_applications=$("${psql_arp[@]}" -Atc "
SELECT count(*)
FROM applications a
LEFT JOIN programs p ON p.id=a.program_id
LEFT JOIN users applicant ON applicant.id=a.applicant_id
LEFT JOIN users reviewer ON reviewer.id=a.reviewer_id
WHERE p.id IS NULL
   OR applicant.id IS NULL
   OR (a.reviewer_id IS NOT NULL AND reviewer.id IS NULL)")
[[ $orphan_applications == 0 ]] || {
  echo "restored database has orphan applications: $orphan_applications" >&2
  exit 1
}

history_mismatch=$("${psql_arp[@]}" -Atc "
WITH latest AS (
  SELECT DISTINCT ON (application_id)
         application_id,
         to_status
  FROM application_status_history
  ORDER BY application_id, changed_at DESC, id DESC
)
SELECT count(*)
FROM applications a
JOIN latest l ON l.application_id=a.id
WHERE a.status <> l.to_status")
[[ $history_mismatch == 0 ]] || {
  echo "restored database has application/history mismatch: $history_mismatch" >&2
  exit 1
}

terminal_history_missing=$("${psql_arp[@]}" -Atc "
SELECT count(*)
FROM applications a
WHERE a.status IN ('APPROVED','REJECTED')
  AND NOT EXISTS (
    SELECT 1
    FROM application_status_history h
    WHERE h.application_id=a.id
      AND h.to_status=a.status
  )")
[[ $terminal_history_missing == 0 ]] || {
  echo "restored terminal application lacks terminal history: $terminal_history_missing" >&2
  exit 1
}

verified_ms=$(date +%s%3N)

printf 'M11_PITR_TARGET_TIME=%s\n' "$target_time"
printf 'M11_PITR_MARKER_CODE=%s\n' "$marker_code"
printf 'M11_PITR_RECOVERED_MARKER_STATE=%s\n' "$marker_state"
echo 'M11_PITR_PRE_INCLUDED=PASS'
echo 'M11_PITR_POST_EXCLUDED=PASS'
printf 'M11_PITR_ORPHAN_APPLICATIONS=%s\n' "$orphan_applications"
printf 'M11_PITR_HISTORY_STATUS_MISMATCH=%s\n' "$history_mismatch"
printf 'M11_PITR_TERMINAL_HISTORY_MISSING=%s\n' "$terminal_history_missing"
printf 'M11_PITR_RESTORE_MS=%s\n' "$((restore_done_ms - start_ms))"
printf 'M11_PITR_DB_READY_MS=%s\n' "$((ready_ms - start_ms))"
printf 'M11_PITR_VERIFIED_MS=%s\n' "$((verified_ms - start_ms))"
echo 'M11_PITR_RESTORE=PASS'

echo 'M11_PITR_POSTGRES_LOG_BEGIN'
journalctl -u "$unit" --since "$start_iso" --no-pager \
  | grep -E 'recovery stopping|redo done|database system is ready' \
  | tail -n 20 || true
echo 'M11_PITR_POSTGRES_LOG_END'
