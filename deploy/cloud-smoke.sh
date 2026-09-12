#!/usr/bin/env bash
set -euo pipefail
umask 077

: "${BASE_URL:?HTTPS base URL required}"
: "${REVIEWER_USERNAME:?Synthetic reviewer username required}"
: "${REVIEWER_PASSWORD:?Synthetic reviewer password required}"
: "${ATTACHMENT_FIXTURE:?Synthetic attachment fixture path required}"

[[ $BASE_URL == https://* ]] || { echo 'BASE_URL must use HTTPS' >&2; exit 1; }
[[ -f $ATTACHMENT_FIXTURE ]] || { echo 'ATTACHMENT_FIXTURE does not exist' >&2; exit 1; }
for command in curl python3 sha256sum; do
  command -v "$command" >/dev/null || { echo "Missing prerequisite: $command" >&2; exit 1; }
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
current_stage='initialization'
trap 'rc=$?; echo "FAIL: cloud smoke stopped during: $current_stage (exit $rc)" >&2; exit $rc' ERR

stage() {
  current_stage=$1
  echo "STEP: $current_stage"
}

curl_cmd=(curl --fail --silent --show-error --connect-timeout 10 --max-time 30)

json_value() {
  local file=$1 expression=$2
  python3 - "$file" "$expression" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
value = eval(sys.argv[2], {"__builtins__": {}}, {"d": data})
if isinstance(value, bool):
    print("true" if value else "false")
elif value is None:
    print("")
else:
    print(value)
PY
}

csrf_values() {
  local jar=$1 out=$2
  "${curl_cmd[@]}" --cookie "$jar" --cookie-jar "$jar"     "$BASE_URL/api/v1/auth/csrf" -o "$out"
  python3 - "$out" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
header = data.get("headerName")
token = data.get("token")
if not header or not token:
    raise SystemExit("CSRF response is missing headerName/token")
print(header, token)
PY
}

request_json() {
  local jar=$1 method=$2 path=$3 body=$4 out=$5
  local csrf_file="$tmp/csrf.json" header token
  read -r header token < <(csrf_values "$jar" "$csrf_file")
  "${curl_cmd[@]}"     --request "$method"     --cookie "$jar" --cookie-jar "$jar"     --header "$header: $token"     --header 'Content-Type: application/json'     --data "$body"     "$BASE_URL$path"     -o "$out"
}

login() {
  local jar=$1 username=$2 password=$3 out=$4 body
  body=$(python3 - "$username" "$password" <<'PY'
import json
import sys
print(json.dumps({"username": sys.argv[1], "password": sys.argv[2]}))
PY
)
  request_json "$jar" POST /api/v1/auth/login "$body" "$out"
}

appjar="$tmp/applicant.cookies"
reviewjar="$tmp/reviewer.cookies"
: >"$appjar"
: >"$reviewjar"

# TLS is verified normally. This script intentionally never uses curl -k/--insecure.
stage 'HTTPS SPA root'
"${curl_cmd[@]}" "$BASE_URL/" -o "$tmp/root.html"
grep -q 'id="root"' "$tmp/root.html"

stage 'HTTPS SPA deep-link fallback'
"${curl_cmd[@]}" "$BASE_URL/programs" -o "$tmp/deep-link.html"
grep -q 'id="root"' "$tmp/deep-link.html"

stage 'public programs API through Nginx'
"${curl_cmd[@]}" "$BASE_URL/api/v1/programs?size=1" -o "$tmp/programs.json"
program_id=$(json_value "$tmp/programs.json" 'd["items"][0]["id"]')
[[ $program_id =~ ^[0-9]+$ ]]

applicant_username="m6-smoke-$(date +%s)-$$"
applicant_password=$(python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(24))
PY
)
applicant_email="${applicant_username}@example.test"

stage 'public applicant registration with CSRF'
register_body=$(python3 - "$applicant_username" "$applicant_password" "$applicant_email" <<'PY'
import json
import sys
print(json.dumps({
    "username": sys.argv[1],
    "password": sys.argv[2],
    "displayName": "M6 Cloud Smoke Applicant",
    "email": sys.argv[3],
}))
PY
)
request_json "$appjar" POST /api/v1/auth/register "$register_body" "$tmp/register.json"
[[ $(json_value "$tmp/register.json" 'd["role"]') == APPLICANT ]]

stage 'applicant login/session'
login "$appjar" "$applicant_username" "$applicant_password" "$tmp/applicant-login.json"
"${curl_cmd[@]}" --cookie "$appjar" "$BASE_URL/api/v1/auth/me" -o "$tmp/applicant-me.json"
[[ $(json_value "$tmp/applicant-me.json" 'd["role"]') == APPLICANT ]]

stage 'create structured draft application'
create_body=$(python3 - "$program_id" <<'PY'
import json
import sys
print(json.dumps({
    "programId": int(sys.argv[1]),
    "applicantOrganizationName": "M6 Synthetic Organization",
    "projectTitle": "M6 cloud smoke project",
    "shortSummary": "Initial Phase 5 cloud smoke summary.",
    "requestedAmount": 1250000,
    "detailedPlan": "Initial Phase 5 cloud smoke plan.",
}))
PY
)
request_json "$appjar" POST /api/v1/applications "$create_body" "$tmp/application-created.json"
app_id=$(json_value "$tmp/application-created.json" 'd["id"]')
app_version=$(json_value "$tmp/application-created.json" 'd["version"]')
[[ $app_id =~ ^[0-9]+$ ]]
[[ $(json_value "$tmp/application-created.json" 'd["status"]') == DRAFT ]]

stage 'upload attachment through deployed Garage path'
read -r csrf_header csrf_token < <(csrf_values "$appjar" "$tmp/upload-csrf.json")
"${curl_cmd[@]}"   --request POST   --cookie "$appjar" --cookie-jar "$appjar"   --header "$csrf_header: $csrf_token"   --form "file=@$ATTACHMENT_FIXTURE;type=application/octet-stream"   "$BASE_URL/api/v1/applications/$app_id/attachments"   -o "$tmp/attachment.json"
attachment_id=$(json_value "$tmp/attachment.json" 'd["id"]')
[[ $attachment_id =~ ^[0-9]+$ ]]
[[ $(json_value "$tmp/attachment.json" 'd["status"]') == AVAILABLE ]]

stage 'applicant attachment download integrity'
"${curl_cmd[@]}" --cookie "$appjar"   "$BASE_URL/api/v1/applications/$app_id/attachments/$attachment_id"   -o "$tmp/applicant-download.bin"
[[ $(sha256sum "$ATTACHMENT_FIXTURE" | cut -d' ' -f1) == $(sha256sum "$tmp/applicant-download.bin" | cut -d' ' -f1) ]]

stage 'edit draft application'
edit_body=$(python3 - "$app_version" <<'PY'
import json
import sys
print(json.dumps({
    "version": int(sys.argv[1]),
    "applicantOrganizationName": "M6 Synthetic Organization",
    "projectTitle": "M6 cloud smoke project",
    "shortSummary": "Edited Phase 5 cloud smoke summary.",
    "requestedAmount": 1250000,
    "detailedPlan": "Edited Phase 5 cloud smoke plan before submission.",
}))
PY
)
request_json "$appjar" PUT "/api/v1/applications/$app_id" "$edit_body" "$tmp/application-edited.json"
app_version=$(json_value "$tmp/application-edited.json" 'd["version"]')
[[ $(json_value "$tmp/application-edited.json" 'd["status"]') == DRAFT ]]

stage 'submit application'
submit_body=$(python3 - "$app_version" <<'PY'
import json
import sys
print(json.dumps({"version": int(sys.argv[1])}))
PY
)
request_json "$appjar" POST "/api/v1/applications/$app_id/submit" "$submit_body" "$tmp/application-submitted.json"
app_version=$(json_value "$tmp/application-submitted.json" 'd["version"]')
[[ $(json_value "$tmp/application-submitted.json" 'd["status"]') == SUBMITTED ]]

stage 'synthetic reviewer login/session'
login "$reviewjar" "$REVIEWER_USERNAME" "$REVIEWER_PASSWORD" "$tmp/reviewer-login.json"
"${curl_cmd[@]}" --cookie "$reviewjar" "$BASE_URL/api/v1/auth/me" -o "$tmp/reviewer-me.json"
[[ $(json_value "$tmp/reviewer-me.json" 'd["role"]') == REVIEWER ]]

stage 'start review'
start_body=$(python3 - "$app_version" <<'PY'
import json
import sys
print(json.dumps({"version": int(sys.argv[1])}))
PY
)
request_json "$reviewjar" POST "/api/v1/review/applications/$app_id/start" "$start_body" "$tmp/in-review.json"
app_version=$(json_value "$tmp/in-review.json" 'd["version"]')
[[ $(json_value "$tmp/in-review.json" 'd["status"]') == IN_REVIEW ]]

stage 'reviewer attachment download integrity'
"${curl_cmd[@]}" --cookie "$reviewjar"   "$BASE_URL/api/v1/review/applications/$app_id/attachments/$attachment_id"   -o "$tmp/reviewer-download.bin"
[[ $(sha256sum "$ATTACHMENT_FIXTURE" | cut -d' ' -f1) == $(sha256sum "$tmp/reviewer-download.bin" | cut -d' ' -f1) ]]

stage 'approve application'
approve_body=$(python3 - "$app_version" <<'PY'
import json
import sys
print(json.dumps({"version": int(sys.argv[1])}))
PY
)
request_json "$reviewjar" POST "/api/v1/review/applications/$app_id/approve" "$approve_body" "$tmp/approved.json"
[[ $(json_value "$tmp/approved.json" 'd["status"]') == APPROVED ]]

stage 'final applicant state and status history'
"${curl_cmd[@]}" --cookie "$appjar" "$BASE_URL/api/v1/applications/$app_id" -o "$tmp/final.json"
[[ $(json_value "$tmp/final.json" 'd["status"]') == APPROVED ]]
"${curl_cmd[@]}" --cookie "$appjar" "$BASE_URL/api/v1/applications/$app_id/history" -o "$tmp/history.json"
python3 - "$tmp/history.json" <<'PY'
import json
import sys

history = json.load(open(sys.argv[1], encoding="utf-8"))
pairs = [(row["fromStatus"], row["toStatus"]) for row in history]
required = [
    ("DRAFT", "SUBMITTED"),
    ("SUBMITTED", "IN_REVIEW"),
    ("IN_REVIEW", "APPROVED"),
]
for pair in required:
    if pair not in pairs:
        raise SystemExit(f"missing status transition: {pair}")
PY

unset applicant_password
echo "PASS: HTTPS SPA/API, registration/session/CSRF, application edit/submit, Garage attachment SHA-256 integrity, reviewer start/approve, and final history (application $app_id)."
