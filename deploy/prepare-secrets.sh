#!/usr/bin/env bash
set -euo pipefail
umask 077
: "${AGE_RECIPIENT:?Set the real public age recipient generated in the controlled Phase 2 path}"
: "${PLAINTEXT_FILE:?Set an outside-repository populated runtime schema path}"
: "${ENCRYPTED_FILE:?Set the destination *.enc.yaml path}"
[[ $AGE_RECIPIENT == age1* ]] || { echo 'AGE_RECIPIENT is not an age public recipient' >&2; exit 1; }
[[ -f $PLAINTEXT_FILE ]]
sops --encrypt --age "$AGE_RECIPIENT" --input-type yaml --output-type yaml "$PLAINTEXT_FILE" >"$ENCRYPTED_FILE"
echo "Encrypted secret material written; delete the outside-repository plaintext securely." >&2
