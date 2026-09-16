#!/usr/bin/env bash
set -euo pipefail

mode=${1:-}
guard_file=/etc/nginx/snippets/arp-mutation-guard.conf
nginx_pid_file=/run/nginx.pid

if [[ $EUID -ne 0 ]]; then
  echo "M11 mutation gate must run as root" >&2
  exit 1
fi

if [[ $mode != enable && $mode != disable && $mode != status ]]; then
  echo "usage: $0 {enable|disable|status}" >&2
  exit 2
fi

[[ -f $guard_file ]] || {
  echo "missing managed mutation guard: $guard_file" >&2
  exit 1
}

is_enabled() {
  grep -Fq 'return 503;' "$guard_file"
}

worker_pids() {
  [[ -r $nginx_pid_file ]] || return 0
  local master
  master=$(cat "$nginx_pid_file")
  pgrep -P "$master" 2>/dev/null || true
}

reload_and_drain() {
  local old_workers deadline pid
  old_workers=$(worker_pids)
  nginx -t >/dev/null
  systemctl reload nginx
  deadline=$((SECONDS + 30))

  for pid in $old_workers; do
    while kill -0 "$pid" 2>/dev/null; do
      if (( SECONDS >= deadline )); then
        echo "timed out waiting for pre-block Nginx worker $pid to drain" >&2
        return 1
      fi
      sleep 1
    done
  done

  printf '%s' "$old_workers" | awk 'NF {count++} END {print count+0}'
}

write_guard() {
  local desired=$1 tmp backup
  tmp=$(mktemp)
  backup=$(mktemp)
  cp "$guard_file" "$backup"

  if [[ $desired == enabled ]]; then
    cat >"$tmp" <<'NGINX'
# M11 checkpoint mutation guard enabled.
if ($request_method ~ ^(POST|PUT|PATCH|DELETE)$) {
  return 503;
}
NGINX
  else
    printf '%s\n' '# M11 checkpoint mutation guard is disabled by default.' >"$tmp"
  fi

  install -o root -g root -m 0644 "$tmp" "$guard_file"
  if ! nginx -t >/dev/null 2>&1; then
    install -o root -g root -m 0644 "$backup" "$guard_file"
    nginx -t >/dev/null
    rm -f "$tmp" "$backup"
    echo "candidate mutation guard failed nginx -t; previous guard restored" >&2
    return 1
  fi

  rm -f "$tmp" "$backup"
}

case "$mode" in
  status)
    if is_enabled; then
      echo "M11_MUTATION_GATE=ENABLED"
    else
      echo "M11_MUTATION_GATE=DISABLED"
    fi
    ;;
  enable)
    if is_enabled; then
      echo "M11_MUTATION_GATE=ALREADY_ENABLED"
      exit 0
    fi
    write_guard enabled
    drained=$(reload_and_drain)
    is_enabled || { echo "mutation guard did not remain enabled" >&2; exit 1; }
    printf 'M11_MUTATION_GATE=ENABLED drained_workers=%s activated_at=%s\n' \
      "$drained" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    ;;
  disable)
    if ! is_enabled; then
      echo "M11_MUTATION_GATE=ALREADY_DISABLED"
      exit 0
    fi
    write_guard disabled
    drained=$(reload_and_drain)
    if is_enabled; then
      echo "mutation guard remained enabled after disable" >&2
      exit 1
    fi
    printf 'M11_MUTATION_GATE=DISABLED drained_workers=%s deactivated_at=%s\n' \
      "$drained" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    ;;
esac
