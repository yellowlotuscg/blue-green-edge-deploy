#!/usr/bin/env python3
"""Build immutable static artifacts with a content-addressed version."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def source_files() -> list[tuple[str, Path]]:
    return [(f"app/{path.name}", path) for path in sorted((ROOT / "app").iterdir()) if path.is_file()] + [("data/status.json", ROOT / "data/status.json")]


def build(output_dir: Path | None = None, timestamp: str | None = None) -> dict:
    output_dir = output_dir or ROOT / "dist"
    files = source_files()
    digest = hashlib.sha256()
    for relative, path in files:
        digest.update(relative.encode())
        digest.update(path.read_bytes())
    content_hash = digest.hexdigest()[:12]
    timestamp = timestamp or os.environ.get("SOURCE_DATE_TIMESTAMP") or datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    version = f"{timestamp}-{content_hash}"
    destination = output_dir / version
    if destination.exists():
        raise FileExistsError(f"immutable artifact already exists: {destination}")
    destination.mkdir(parents=True)
    for relative, source in files:
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    manifest = {"version": version, "content_hash": content_hash, "built_at": timestamp, "files": [relative for relative, _ in files]}
    (destination / "build-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (output_dir / "build-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / "dist")
    parser.add_argument("--timestamp")
    args = parser.parse_args()
    manifest = build(args.output, args.timestamp)
    print(json.dumps(manifest))


if __name__ == "__main__":
    main()
