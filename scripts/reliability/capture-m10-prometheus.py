#!/usr/bin/env python3
from __future__ import annotations

import json
import math
import sys
import urllib.parse
import urllib.request

if len(sys.argv) != 4:
    raise SystemExit("usage: capture-m10-prometheus.py PROMETHEUS_HOST START END")

host, start, end = sys.argv[1:4]

queries = {
    "application_probe": 'probe_success{node="obs-01",service="application-review-platform"}',
    "postgres_up": 'pg_up{node="db-01"}',
    "hikari_active": 'sum(hikaricp_connections_active{node="app-01"})',
    "hikari_pending": 'sum(hikaricp_connections_pending{node="app-01"})',
    "db_cpu_pct": '100 - (avg(rate(node_cpu_seconds_total{node="db-01",mode="idle"}[1m])) * 100)',
    "app_cpu_pct": '100 - (avg(rate(node_cpu_seconds_total{node="app-01",mode="idle"}[1m])) * 100)',
    "garage_up_by_node": 'up{service="garage"}',
}

base = f"http://{host}:9090/api/v1/query_range"
result = {
    "start": start,
    "end": end,
    "step": "15s",
    "queries": {},
}

for name, query in queries.items():
    params = urllib.parse.urlencode(
        {"query": query, "start": start, "end": end, "step": "15s"}
    )
    with urllib.request.urlopen(f"{base}?{params}", timeout=20) as response:
        payload = json.load(response)

    if payload.get("status") != "success":
        raise SystemExit(f"Prometheus query failed for {name}: {payload!r}")

    series_out = []
    flattened = []
    for series in payload.get("data", {}).get("result", []):
        values = []
        for timestamp, raw in series.get("values", []):
            try:
                value = float(raw)
            except (TypeError, ValueError):
                continue
            if not math.isfinite(value):
                continue
            values.append([float(timestamp), value])
            flattened.append(value)
        series_out.append(
            {
                "metric": series.get("metric", {}),
                "values": values,
            }
        )

    summary = None
    if flattened:
        summary = {
            "samples": len(flattened),
            "min": min(flattened),
            "max": max(flattened),
            "avg": sum(flattened) / len(flattened),
        }

    result["queries"][name] = {
        "promql": query,
        "summary": summary,
        "series": series_out,
    }

json.dump(result, sys.stdout, indent=2, sort_keys=True)
sys.stdout.write("\n")
