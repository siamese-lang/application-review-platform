#!/usr/bin/env bash
set -euo pipefail
umask 077
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${AGE_RECIPIENT:?Set the real public age recipient generated in the controlled M6 operations path}"
: "${PLAINTEXT_FILE:?Set an outside-repository populated runtime schema path}"
: "${ENCRYPTED_FILE:?Set the destination *.enc.yaml path}"
[[ $AGE_RECIPIENT == age1* ]] || { echo 'AGE_RECIPIENT is not an age public recipient' >&2; exit 1; }
[[ -f $PLAINTEXT_FILE ]]
plaintext_path=$(realpath "$PLAINTEXT_FILE")
case "$plaintext_path" in "$root"|"$root"/*) echo 'PLAINTEXT_FILE must be outside the Git checkout.' >&2; exit 1;; esac
sops --encrypt --age "$AGE_RECIPIENT" --input-type yaml --output-type yaml "$PLAINTEXT_FILE" >"$ENCRYPTED_FILE"
echo "Encrypted secret material written. Remove the outside-repository plaintext according to the controlled environment's storage procedure." >&2
