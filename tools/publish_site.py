"""Stage only the public HTML and SEO discovery artifacts for GitHub Pages."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PUBLIC_HTML = ("index.html", "report-demo.html")
OG_IMAGE = "og-preview.png"


def stage(destination):
    target = Path(destination).resolve()
    if target == ROOT or ROOT in target.parents:
        raise ValueError("Stage the site outside the source checkout")
    if target.exists() and any(target.iterdir()):
        raise ValueError("Choose an empty staging directory")
    target.mkdir(parents=True, exist_ok=True)
    project = json.loads((ROOT / "project.json").read_text(encoding="utf-8"))
    home = project["homepage"] if project["homepage"].endswith("/") else project["homepage"] + "/"
    og_bytes = (ROOT / "docs/images" / OG_IMAGE).read_bytes()
    if not og_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("Expected a valid PNG social preview image")
    robots = f"User-agent: *\nAllow: /\n\nSitemap: {home}sitemap.xml\n".encode("utf-8")
    sitemap = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        f"  <url><loc>{home}</loc></url>\n"
        f"  <url><loc>{home}report-demo.html</loc></url>\n"
        "</urlset>\n"
    ).encode("utf-8")
    staged = {name: (ROOT / "web" / name).read_bytes() for name in PUBLIC_HTML}
    staged[OG_IMAGE] = og_bytes
    staged["robots.txt"] = robots
    staged["sitemap.xml"] = sitemap
    entries = {}
    for name, content in staged.items():
        (target / name).write_bytes(content)
        entries[name] = hashlib.sha256(content).hexdigest()
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
