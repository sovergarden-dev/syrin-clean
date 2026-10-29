"""Stage only the public HTML artifacts for GitHub Pages."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PUBLIC_FILES = ("index.html", "report-demo.html")


def stage(destination):
    target = Path(destination).resolve()
    if target == ROOT or ROOT in target.parents:
        raise ValueError("Stage the site outside the source checkout")
    if target.exists() and any(target.iterdir()):
        raise ValueError("Choose an empty staging directory")
    target.mkdir(parents=True, exist_ok=True)
    entries = {}
    for name in PUBLIC_FILES:
        content = (ROOT / "web" / name).read_bytes()
        (target / name).write_bytes(content)
        entries[name] = hashlib.sha256(content).hexdigest()
    project = json.loads((ROOT / "project.json").read_text(encoding="utf-8"))
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    metadata = {"version": project["version"], "channel": project["channel"], "revision": revision, "files": entries}
    (target / "version.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    (target / ".nojekyll").write_bytes(b"")
    return metadata


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination")
    args = parser.parse_args()
    print(json.dumps(stage(args.destination), indent=2))
