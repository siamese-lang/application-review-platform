#!/usr/bin/env python3
"""Convert `tofu output -json inventory` into the generated Ansible YAML inventory."""
import json
import sys

nodes = json.load(sys.stdin)
groups = {
    name: {"hosts": {}}
    for name in ("edge", "app", "db", "storage", "ops", "observability", "backup", "recovery_db")
}
for name, node in sorted(nodes.items()):
    groups[node["role"]]["hosts"][name] = {
        "ansible_host": node["private_ip"],
        "garage_zone": node["zone"],
    }

print("---\nall:\n  children:")
for group, body in groups.items():
    print(f"    {group}:\n      hosts:")
    for host, values in body["hosts"].items():
        print(
            f"        {host}:\n"
            f"          ansible_host: {values['ansible_host']}\n"
            f"          garage_zone: {values['garage_zone']}"
        )
