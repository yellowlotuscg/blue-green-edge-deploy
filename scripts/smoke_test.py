#!/usr/bin/env python3
"""Check the active local color or a deployed HTTP endpoint."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from urllib.request import urlopen


def read_target(args: argparse.Namespace) -> tuple[str, str]:
    if args.url:
        with urlopen(args.url, timeout=5) as response:
            return response.read().decode("utf-8"), "http"
    root = Path(args.root)
    prefix = root / args.color
    return (prefix / "app/index.html").read_text(encoding="utf-8"), str(prefix / "data/status.json")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".local_s3")
    parser.add_argument("--color", choices=["blue", "green"], default="blue")
    parser.add_argument("--url")
    parser.add_argument("--local", action="store_true", help="read the simulated local S3 directory")
    args = parser.parse_args()
    html, status_path = read_target(args)
    if "Northwind Widgets" not in html:
        raise SystemExit("smoke test failed: status page marker missing")
    if args.url:
        print("smoke test passed: http endpoint")
    else:
        data = json.loads(Path(status_path).read_text(encoding="utf-8"))
        if not data.get("services"):
            raise SystemExit("smoke test failed: no services")
        print(f"smoke test passed: {args.color} ({len(data['services'])} services)")


if __name__ == "__main__":
    main()
