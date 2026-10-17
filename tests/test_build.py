import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run(*args, env=None):
    return subprocess.run(args, cwd=ROOT, text=True, capture_output=True, check=True, env=env)


def test_seed_is_reproducible(tmp_path):
    first = tmp_path / "one.json"
    second = tmp_path / "two.json"
    run(sys.executable, "scripts/seed.py", "--output", str(first))
    run(sys.executable, "scripts/seed.py", "--output", str(second))
    assert first.read_text() == second.read_text()


def test_build_writes_versioned_immutable_artifact(tmp_path):
    data = ROOT / "data/status.json"
    run(sys.executable, "scripts/seed.py")
    result = run(sys.executable, "scripts/build.py", "--output", str(tmp_path / "dist"), "--timestamp", "20250115T120000Z")
    manifest = json.loads(result.stdout)
    artifact = tmp_path / "dist" / manifest["version"]
    assert (artifact / "app/index.html").exists()
    assert (artifact / "data/status.json").exists()
    assert json.loads((artifact / "build-manifest.json").read_text())["version"] == manifest["version"]
    assert (tmp_path / "dist/build-manifest.json").exists()
