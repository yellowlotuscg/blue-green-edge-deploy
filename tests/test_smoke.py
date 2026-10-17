import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_smoke_test_accepts_built_page(tmp_path):
    subprocess.run([sys.executable, "scripts/seed.py"], cwd=ROOT, check=True)
    subprocess.run([sys.executable, "scripts/build.py", "--output", str(tmp_path / "dist"), "--timestamp", "20250115T120001Z"], cwd=ROOT, check=True)
    version = json.loads((tmp_path / "dist/build-manifest.json").read_text())["version"]
    target = tmp_path / "store/blue"
    target.mkdir(parents=True)
    source = tmp_path / "dist" / version
    import shutil
    shutil.copytree(source, target, dirs_exist_ok=True)
    result = subprocess.run([sys.executable, "scripts/smoke_test.py", "--root", str(tmp_path / "store"), "--color", "blue"], cwd=ROOT, text=True, capture_output=True)
    assert result.returncode == 0, result.stderr
    assert "smoke test passed" in result.stdout
