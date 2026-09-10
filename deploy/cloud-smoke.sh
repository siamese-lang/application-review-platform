#!/usr/bin/env bash
set -euo pipefail
umask 077
: "${BASE_URL:?HTTPS base URL required}"
: "${APPLICANT_USERNAME:?required}"; : "${APPLICANT_PASSWORD:?required}"
: "${REVIEWER_USERNAME:?required}"; : "${REVIEWER_PASSWORD:?required}"
: "${ATTACHMENT_FIXTURE:?fixture path required}"
[[ $BASE_URL == https://* ]] || { echo 'BASE_URL must use HTTPS' >&2; exit 1; }
[[ -f $ATTACHMENT_FIXTURE ]]

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
current_stage='initialization'
trap 'rc=$?; echo "FAIL: cloud smoke stopped during: $current_stage (exit $rc)" >&2; exit $rc' ERR
stage() {
  current_stage=$1
  echo "STEP: $current_stage"
}

curl_cmd=(curl --fail --silent --show-error --connect-timeout 10 --max-time 30)
csrf() { sed -n 's/.*name="_csrf" value="\([^"]*\)".*/\1/p' "$1" | head -1; }
login() {
  local jar=$1 user=$2 password=$3 page="$tmp/login.html"
  "${curl_cmd[@]}" --cookie-jar "$jar" "$BASE_URL/login" -o "$page"
  local token; token=$(csrf "$page"); [[ -n $token ]]
  "${curl_cmd[@]}" --location --cookie "$jar" --cookie-jar "$jar" \
    --data-urlencode "_csrf=$token" --data-urlencode "username=$user" --data-urlencode "password=$password" \
    "$BASE_URL/login" -o "$tmp/home.html"
  ! grep -q 'Invalid username or password' "$tmp/home.html"
}

appjar="$tmp/app.cookies"; reviewjar="$tmp/review.cookies"
# The initial request proves TLS and public edge reachability. For a self-signed fallback,
# set CURL_CA_BUNDLE to the explicitly trusted certificate; this script never uses -k.
stage 'HTTPS reachability'
"${curl_cmd[@]}" "$BASE_URL/login" -o "$tmp/reachable.html"

stage 'applicant login'
login "$appjar" "$APPLICANT_USERNAME" "$APPLICANT_PASSWORD"

stage 'load program 1'
"${curl_cmd[@]}" --cookie "$appjar" "$BASE_URL/programs/1" -o "$tmp/program.html"
token=$(csrf "$tmp/program.html"); [[ -n $token ]]

stage 'create draft application'
headers="$tmp/create.headers"
"${curl_cmd[@]}" --cookie "$appjar" -D "$headers" -o /dev/null \
  --data-urlencode "_csrf=$token" --data-urlencode 'programId=1' \
  --data-urlencode 'title=M4 cloud smoke application' --data-urlencode 'content=Created by the repeatable M4 cloud smoke.' \
  "$BASE_URL/applications"
location=$(sed -n 's/^[Ll]ocation: *\([^[:space:]]*\).*/\1/p' "$headers" | tr -d '\r' | head -1)
case "$location" in
  /applications/*)
    application_path=$location
    ;;
  "$BASE_URL"/applications/*)
    application_path=${location#"$BASE_URL"}
    ;;
  *)
    echo "Unexpected application redirect Location: $location" >&2
    exit 1
    ;;
esac
[[ $application_path =~ ^/applications/([0-9]+)$ ]]; app_id=${BASH_REMATCH[1]}

stage "load draft application $app_id"
"${curl_cmd[@]}" --cookie "$appjar" "$BASE_URL$application_path" -o "$tmp/application.html"
token=$(csrf "$tmp/application.html"); [[ -n $token ]]

stage 'upload attachment'
"${curl_cmd[@]}" --location --cookie "$appjar" \
  -F "_csrf=$token" -F "file=@$ATTACHMENT_FIXTURE;type=application/octet-stream" \
  "$BASE_URL/applications/$app_id/attachments" -o "$tmp/uploaded.html"
attachment_path=$(sed -n "s/.*href=\"\(\/applications\/$app_id\/attachments\/[0-9][0-9]*\)\".*/\1/p" "$tmp/uploaded.html" | head -1)
[[ -n $attachment_path ]]

stage 'applicant attachment download integrity'
"${curl_cmd[@]}" --cookie "$appjar" "$BASE_URL$attachment_path" -o "$tmp/download.bin"
[[ $(sha256sum "$ATTACHMENT_FIXTURE" | cut -d' ' -f1) == $(sha256sum "$tmp/download.bin" | cut -d' ' -f1) ]]

token=$(csrf "$tmp/uploaded.html"); [[ -n $token ]]
stage 'edit draft application'
"${curl_cmd[@]}" --location --cookie "$appjar" --data-urlencode "_csrf=$token" \
  --data-urlencode 'title=M4 cloud smoke edited application' --data-urlencode 'content=Edited before submission.' \
  "$BASE_URL/applications/$app_id/edit" -o "$tmp/edited.html"

token=$(csrf "$tmp/edited.html"); [[ -n $token ]]
stage 'submit application'
"${curl_cmd[@]}" --location --cookie "$appjar" --data-urlencode "_csrf=$token" \
  "$BASE_URL/applications/$app_id/submit" -o "$tmp/submitted.html"
grep -q 'SUBMITTED' "$tmp/submitted.html"

stage 'reviewer login'
login "$reviewjar" "$REVIEWER_USERNAME" "$REVIEWER_PASSWORD"

stage 'load review page'
"${curl_cmd[@]}" --cookie "$reviewjar" "$BASE_URL/review/$app_id" -o "$tmp/review.html"
token=$(csrf "$tmp/review.html"); [[ -n $token ]]

stage 'start review'
"${curl_cmd[@]}" --location --cookie "$reviewjar" --data-urlencode "_csrf=$token" \
  "$BASE_URL/review/$app_id/start" -o "$tmp/in-review.html"

token=$(csrf "$tmp/in-review.html"); [[ -n $token ]]
stage 'approve application'
"${curl_cmd[@]}" --location --cookie "$reviewjar" --data-urlencode "_csrf=$token" \
  --data-urlencode 'decision=APPROVED' --data-urlencode 'reason=' \
  "$BASE_URL/review/$app_id/decision" -o "$tmp/approved.html"
grep -q 'APPROVED' "$tmp/approved.html"

review_attachment_path=$(sed -n "s/.*href=\"\(\/review\/$app_id\/attachments\/[0-9][0-9]*\)\".*/\1/p" "$tmp/approved.html" | head -1)
[[ -n $review_attachment_path ]]
stage 'reviewer attachment download integrity'
"${curl_cmd[@]}" --cookie "$reviewjar" "$BASE_URL$review_attachment_path" -o "$tmp/reviewer-download.bin"
[[ $(sha256sum "$ATTACHMENT_FIXTURE" | cut -d' ' -f1) == $(sha256sum "$tmp/reviewer-download.bin" | cut -d' ' -f1) ]]

echo "PASS: HTTPS, applicant create/edit/upload/download/submit, reviewer start/approve/download, and SHA-256 equality (application $app_id)."
