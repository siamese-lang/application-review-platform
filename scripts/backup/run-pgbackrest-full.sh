#!/usr/bin/env bash
set -euo pipefail

command -v pgbackrest >/dev/null
id pgbackrest >/dev/null

sudo -u pgbackrest pgbackrest --stanza=arp --type=full backup
sudo -u pgbackrest pgbackrest --stanza=arp info --output=json
