#!/usr/bin/env bash
set -euo pipefail

mode=${1:-}
marker_code=${2:-}

if [[ $mode != create && $mode != cleanup ]]; then
  echo "usage: $0 {create|cleanup} M11-PITR-<marker>" >&2
  exit 2
fi
if [[ ! $marker_code =~ ^M11-PITR-[A-Za-z0-9._-]+$ || ${#marker_code} -gt 50 ]]; then
  echo "invalid marker code" >&2
  exit 2
fi

psql_arp=(sudo -u postgres psql --no-psqlrc --set ON_ERROR_STOP=1 --dbname=arp)
utc_sql="to_char(clock_timestamp(), 'YYYY-MM-DD\"T\"HH24:MI:SS.USOF')"

psql_marker() {
  local sql=$1
  printf '%s\n' "$sql" | "${psql_arp[@]}" -Atq --set "marker_code=$marker_code"
}

if [[ $mode == cleanup ]]; then
  refs=$(psql_marker "SELECT count(*) FROM applications a JOIN programs p ON p.id=a.program_id WHERE p.code=:'marker_code'")
  [[ $refs == 0 ]] || {
    echo "refusing to remove marker program referenced by applications: $refs" >&2
    exit 1
  }

  deleted=$(psql_marker "DELETE FROM programs WHERE code=:'marker_code' RETURNING code")
  if [[ -n $deleted && $deleted != "$marker_code" ]]; then
    echo "unexpected cleanup result: $deleted" >&2
    exit 1
  fi
  echo "M11_PITR_MARKER_CLEANUP=PASS code=$marker_code"
  exit 0
fi

existing=$(psql_marker "SELECT count(*) FROM programs WHERE code=:'marker_code'")
[[ $existing == 0 ]] || {
  echo "marker already exists: $marker_code" >&2
  exit 1
}

"${psql_arp[@]}" --set "marker_code=$marker_code" >/dev/null <<'SQL'
INSERT INTO programs (
  code,
  title,
  description,
  publication_status,
  application_open_at,
  application_close_at,
  version,
  created_at,
  updated_at
)
VALUES (
  :'marker_code',
  'M11 PITR synthetic marker',
  'M11_PITR_PRE',
  'DRAFT',
  TIMESTAMPTZ '2026-01-01 00:00:00+00',
  TIMESTAMPTZ '2099-01-01 00:00:00+00',
  0,
  clock_timestamp(),
  clock_timestamp()
);
SQL

pre_visible_at=$("${psql_arp[@]}" -Atc "SELECT $utc_sql")
sleep 1
target_time=$("${psql_arp[@]}" -Atc "SELECT $utc_sql")
sleep 1

post_state=$(psql_marker "
UPDATE programs
SET description='M11_PITR_POST',
    updated_at=clock_timestamp(),
    version=version+1
WHERE code=:'marker_code'
  AND description='M11_PITR_PRE'
RETURNING description")
[[ $post_state == M11_PITR_POST ]] || {
  echo "failed to create POST marker state" >&2
  exit 1
}

post_visible_at=$("${psql_arp[@]}" -Atc "SELECT $utc_sql")
wal_switch=$("${psql_arp[@]}" -Atc "SELECT pg_switch_wal()")
sudo -u postgres pgbackrest --stanza=arp check >/dev/null
live_state=$(psql_marker "SELECT description FROM programs WHERE code=:'marker_code'")
[[ $live_state == M11_PITR_POST ]] || {
  echo "unexpected live marker state: $live_state" >&2
  exit 1
}

printf 'M11_PITR_MARKER_CODE=%s\n' "$marker_code"
printf 'M11_PITR_PRE_VISIBLE_AT=%s\n' "$pre_visible_at"
printf 'M11_PITR_TARGET_TIME=%s\n' "$target_time"
printf 'M11_PITR_POST_VISIBLE_AT=%s\n' "$post_visible_at"
printf 'M11_PITR_WAL_SWITCH=%s\n' "$wal_switch"
printf 'M11_PITR_LIVE_STATE=%s\n' "$live_state"
echo 'M11_PITR_MARKERS=PASS'
