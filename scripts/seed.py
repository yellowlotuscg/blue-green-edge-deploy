#!/usr/bin/env python3
"""Create deterministic synthetic status data for the sample status page."""
from __future__ import annotations

import argparse
import json
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path

SERVICES = [
    ("api", "Public API", "Requests, authentication, and webhooks"),
    ("web", "Web application", "Customer dashboard and account pages"),
    ("payments", "Payments", "Checkout, invoices, and refunds"),
    ("search", "Search", "Catalog and account search"),
]


def build_data(seed: int = 20250115) -> dict:
    rng = random.Random(seed)
    now = datetime(2025, 1, 15, 12, 0, tzinfo=timezone.utc)
    statuses = ["operational", "operational", "operational", "degraded"]
    services = []
    for key, name, description in SERVICES:
        services.append({"id": key, "name": name, "description": description, "status": rng.choice(statuses)})
    if all(service["status"] == "operational" for service in services):
        services[-1]["status"] = "degraded"
    incidents = []
    for index, service in enumerate(services):
        if service["status"] != "operational":
            incidents.append({
                "id": f"inc-{index + 1:03d}",
                "service": service["id"],
                "title": f"{service['name']} latency elevated",
                "status": "monitoring",
                "message": "Synthetic incident data: engineers are monitoring elevated latency.",
                "created_at": (now - timedelta(minutes=rng.randint(20, 180))).isoformat().replace("+00:00", "Z"),
            })
    return {"generated_at": now.isoformat().replace("+00:00", "Z"), "seed": seed, "services": services, "incidents": incidents}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="data/status.json")
    parser.add_argument("--seed", type=int, default=20250115)
    args = parser.parse_args()
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(build_data(args.seed), indent=2) + "\n", encoding="utf-8")
    print(f"wrote {output}")


if __name__ == "__main__":
    main()
