#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
venv=/opt/arp-ansible

sudo apt-get update
sudo apt-get install -y python3 python3-venv
if [[ ! -x "$venv/bin/ansible-playbook" ]]; then
  sudo python3 -m venv "$venv"
fi
sudo "$venv/bin/pip" install --disable-pip-version-check 'ansible-core>=2.17,<2.20'
sudo ln -sfn "$venv/bin/ansible" /usr/local/bin/ansible
sudo ln -sfn "$venv/bin/ansible-inventory" /usr/local/bin/ansible-inventory
sudo ln -sfn "$venv/bin/ansible-playbook" /usr/local/bin/ansible-playbook
sudo ln -sfn "$venv/bin/ansible-galaxy" /usr/local/bin/ansible-galaxy

cd "$root/config/ansible"
ansible-galaxy collection install -r requirements.yml
ansible-playbook --inventory 'localhost,' bootstrap-ops.yml
