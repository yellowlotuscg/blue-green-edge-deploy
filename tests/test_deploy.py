import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run(*args, env=None):
    return subprocess.run(args, cwd=ROOT, text=True, capture_output=True, check=True, env=env)


def test_deploy_and_rollback_local(tmp_path):
    env = os.environ.copy()
    manifest_path = tmp_path / "manifest.json"
    env.update({"STATUS_DEPLOY_ROOT": str(tmp_path / "store"), "STATUS_STATE_ROOT": str(tmp_path / "state"), "DEPLOYMENTS_MANIFEST": str(manifest_path), "DRY_RUN": "1"})
    run("bash", "scripts/deploy.sh", "--local", env=env)
    manifest = json.loads(manifest_path.read_text())
    first = manifest["active"]["version"]
    assert manifest["active"]["color"] == "green"
    assert (tmp_path / "store/green/app/index.html").exists()
    run("bash", "scripts/deploy.sh", "--local", env=env)
    manifest = json.loads(manifest_path.read_text())
    second = manifest["active"]["version"]
    assert second != first
    run("bash", "scripts/rollback.sh", "--local", first, env=env)
    manifest = json.loads(manifest_path.read_text())
    assert manifest["active"]["version"] == first
    assert (tmp_path / "state/active_color").read_text().strip() == "green"


def test_smoke_test_rejects_missing_marker(tmp_path):
    root = tmp_path / "store/blue/data"
    root.mkdir(parents=True)
    (tmp_path / "store/blue/index.html").write_text("not a status page")
    result = subprocess.run([sys.executable, "scripts/smoke_test.py", "--root", str(tmp_path / "store"), "--color", "blue"], cwd=ROOT, text=True, capture_output=True)
    assert result.returncode != 0
