import base64
import hashlib
import importlib.util
import io
import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("syrin_build", ROOT / "tools/build.py")
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


class PackagingTests(unittest.TestCase):
    def test_archive_metadata_does_not_depend_on_host_defaults(self):
        original = zipfile.ZipInfo.__init__
        def unix_default(info, *args, **kwargs):
            original(info, *args, **kwargs)
            info.create_system = 3
        with patch.object(zipfile.ZipInfo, "__init__", unix_default):
            data = build.archive({"fixture.txt": b"portable fixture"})
        with zipfile.ZipFile(io.BytesIO(data)) as bundle:
            self.assertEqual(bundle.getinfo("fixture.txt").create_system, 0)
            self.assertEqual(bundle.read("fixture.txt"), b"portable fixture")

    def test_pages_staging_contains_only_public_artifacts(self):
        module_spec = importlib.util.spec_from_file_location("syrin_publish", ROOT / "tools/publish_site.py")
        publish = importlib.util.module_from_spec(module_spec)
        module_spec.loader.exec_module(publish)
        with tempfile.TemporaryDirectory(prefix="syrin-pages-test-") as temporary:
            target = Path(temporary)
            metadata = publish.stage(target)
            self.assertEqual({path.name for path in target.iterdir()}, {"index.html", "report-demo.html", "version.json", ".nojekyll"})
            self.assertEqual(metadata["version"], build.VERSION)
            for name in ("index.html", "report-demo.html"):
                self.assertEqual((target / name).read_bytes(), (ROOT / "web" / name).read_bytes())
            with self.assertRaisesRegex(ValueError, "empty"):
                publish.stage(target)
        with self.assertRaisesRegex(ValueError, "outside"):
            publish.stage(ROOT / "web")

    def test_page_contracts_have_accessible_tabs_and_unique_ids(self):
        class Elements(HTMLParser):
            def __init__(self):
                super().__init__()
                self.elements = []
            def handle_starttag(self, tag, attributes):
                self.elements.append((tag, dict(attributes)))
        for name in ("index.html", "report-demo.html"):
            parser = Elements()
            parser.feed((ROOT / "web" / name).read_text(encoding="utf-8"))
            ids = [a["id"] for _, a in parser.elements if "id" in a]
            self.assertEqual(len(ids), len(set(ids)))
            self.assertEqual(next(a["lang"] for tag, a in parser.elements if tag == "html"), "en")
            self.assertFalse([a for tag, a in parser.elements if tag == "script" and "src" in a])
            self.assertFalse([a for tag, a in parser.elements if tag == "link" and a.get("rel") == "stylesheet"])
            if name == "report-demo.html":
                self.assertIn("report-language", ids)
                continue
            tabs = [a for _, a in parser.elements if a.get("role") == "tab"]
            self.assertEqual(len(tabs), 2)
            self.assertEqual(sum(a.get("aria-selected") == "true" for a in tabs), 1)
            for tab in tabs:
                self.assertIn(tab["aria-controls"], ids)
                self.assertEqual(tab["tabindex"], "0" if tab["aria-selected"] == "true" else "-1")
            panels = [a for _, a in parser.elements if a.get("role") == "tabpanel"]
            self.assertEqual(len(panels), 2)
            for panel in panels:
                self.assertIn(panel["aria-labelledby"], [a["id"] for a in tabs])

    def test_generated_outputs_match_and_embedded_bundles_are_exact(self):
        outputs = build.build_outputs()
        for name, data in outputs.items():
            self.assertEqual((ROOT / name).read_bytes(), data, name)
        for language in build.LANGUAGES:
            data = (ROOT / f"dist/syrin-clean-skill-v{build.VERSION}-{language}.zip").read_bytes()
            with zipfile.ZipFile(io.BytesIO(data)) as bundle:
                self.assertIsNone(bundle.testzip())
                manifest = json.loads(bundle.read("bundle-manifest.json"))
                self.assertEqual(set(bundle.namelist()), {x["path"] for x in manifest["files"]} | {"bundle-manifest.json"})
                for entry in manifest["files"]:
                    self.assertEqual(hashlib.sha256(bundle.read(entry["path"])).hexdigest(), entry["sha256"])
                    if entry["path"].endswith((".ps1", ".psm1")):
                        self.assertTrue(bundle.read(entry["path"]).startswith(b"\xef\xbb\xbf"), entry["path"])
            prompt = (ROOT / f"prompts/syrin-clean-prompt-{language}-v{build.VERSION}.md").read_text(encoding="utf-8")
            match = re.search(r"## Runtime bundle \(APPENDIX-RUNTIME\)\nSHA256: ([a-f0-9]{64})\n\n```base64\n(.*?)\n```", prompt, re.S)
            self.assertIsNotNone(match)
            self.assertEqual(base64.b64decode(match[2]), data)
            self.assertEqual(match[1], hashlib.sha256(data).hexdigest())
            page = (ROOT / "web/index.html").read_text(encoding="utf-8")
            payload = json.loads(re.search(r'<script type="application/json" id="syrin-page-data">(.*?)</script>', page, re.S).group(1))
            self.assertEqual(base64.b64decode(payload["editions"][language]["zipBase64"]), data)
            self.assertEqual(payload["editions"][language]["zipSha256"], hashlib.sha256(data).hexdigest())
            self.assertEqual(base64.b64decode(payload["demoBase64"]), (ROOT / "web/report-demo.html").read_bytes())
        self.assertEqual((ROOT / "web/index.html").read_bytes(), (ROOT / "dist/syrin-clean.html").read_bytes())
        self.assertEqual((ROOT / "web/report-demo.html").read_bytes(), (ROOT / "dist/syrin-clean-report-demo.html").read_bytes())
        release_manifest = json.loads((ROOT / "dist/artifact-manifest.json").read_text(encoding="utf-8"))
        names = {entry["path"] for entry in release_manifest["files"]}
        self.assertEqual(len(names), 6)
        self.assertTrue(all(Path(name).name == name for name in names))
        checksums = dict(line.split("  ", 1)[::-1] for line in (ROOT / "dist/SHA256SUMS.txt").read_text(encoding="utf-8").splitlines())
        self.assertEqual(set(checksums), names | {"artifact-manifest.json"})
        self.assertEqual(checksums["artifact-manifest.json"], hashlib.sha256((ROOT / "dist/artifact-manifest.json").read_bytes()).hexdigest())

    def test_allowlist_rejects_unknown_files_without_packaging_them(self):
        with tempfile.TemporaryDirectory(prefix="syrin-build-test-") as temporary:
            directory = Path(temporary)
            original = build.ROOT
            try:
                build.ROOT = directory
                (directory / "skill/en").mkdir(parents=True)
                (directory / "skill/en/.env").write_text("SYNTHETIC_FIXTURE=not-secret", encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "Unexpected"):
                    build.allowlist("skill/en", {"install.ps1"})
            finally:
                build.ROOT = original


@unittest.skipUnless(os.name == "nt", "Windows PowerShell and native directory handles are required")
class WindowsPackageTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="syrin-package-test-")
        self.root = Path(self.directory.name)
        self.package = self.root / "package"
        with zipfile.ZipFile(ROOT / f"dist/syrin-clean-skill-v{build.VERSION}-en.zip") as bundle:
            bundle.extractall(self.package)
        self.profile = self.root / "profile"
        self.profile.mkdir()
        self.environment = dict(os.environ)
        self.environment["PSModulePath"] = str(Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/Modules")
        for key, suffix in (("USERPROFILE", ""), ("LOCALAPPDATA", "local"), ("APPDATA", "roaming"), ("TEMP", "temp"), ("TMP", "temp")):
            target = self.profile / suffix
            target.mkdir(exist_ok=True)
            self.environment[key] = str(target)

    def tearDown(self):
        self.directory.cleanup()

    def powershell(self, script, *arguments):
        return subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", str(script), *map(str, arguments)], env=self.environment, cwd=self.root, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)

    def test_install_verifies_both_locations_and_preserves_old_versions(self):
        first = self.powershell(self.package / "install.ps1", "-ProfileRoot", self.profile)
        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        for agent in (".claude", ".agents"):
            target = self.profile / agent / "skills/syrin-clean"
            manifest = json.loads((target / "skill-manifest.json").read_text(encoding="utf-8"))
            for entry in manifest["files"]:
                self.assertEqual(hashlib.sha256((target / entry["path"]).read_bytes()).hexdigest(), entry["sha256"])
            (target / "user-customization.txt").write_text("keep previous work", encoding="utf-8")
        second = self.powershell(self.package / "install.ps1", "-ProfileRoot", self.profile)
        self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
        for agent in (".claude", ".agents"):
            backups = list((self.profile / ".syrin-clean-installer").glob("*/" + agent.lstrip(".") + "/previous"))
            self.assertEqual(len(backups), 1)
            self.assertEqual((backups[0] / "user-customization.txt").read_text(encoding="utf-8"), "keep previous work")
            self.assertEqual([p.name for p in (self.profile / agent / "skills").iterdir()], ["syrin-clean"])

    def test_tampered_package_does_not_replace_existing_skill(self):
        first = self.powershell(self.package / "install.ps1", "-ProfileRoot", self.profile)
        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        marker = self.profile / ".claude/skills/syrin-clean/user-customization.txt"
        marker.write_text("keep", encoding="utf-8")
        (self.package / "syrin-clean/scripts/audit.ps1").write_text("corrupted", encoding="utf-8")
        failed = self.powershell(self.package / "install.ps1", "-ProfileRoot", self.profile)
        self.assertNotEqual(failed.returncode, 0)
        self.assertEqual(marker.read_text(encoding="utf-8"), "keep")

    def test_failed_second_commit_rolls_back_first_target(self):
        import ctypes
        from ctypes import wintypes
        first = self.powershell(self.package / "install.ps1", "-ProfileRoot", self.profile)
        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        targets = [self.profile / agent / "skills/syrin-clean" for agent in (".claude", ".agents")]
        for target in targets:
            (target / "original.txt").write_text("original", encoding="utf-8")
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
        kernel.CreateFileW.restype = wintypes.HANDLE
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        handle = kernel.CreateFileW(str(targets[1]), 0x80000000, 3, None, 3, 0x02000000, None)
        self.assertNotEqual(handle, wintypes.HANDLE(-1).value)
        try:
            failed = self.powershell(self.package / "install.ps1", "-ProfileRoot", self.profile)
            self.assertNotEqual(failed.returncode, 0, failed.stdout)
            for target in targets:
                self.assertEqual((target / "original.txt").read_text(encoding="utf-8"), "original")
        finally:
            kernel.CloseHandle(handle)

    def test_prompt_extractor_matches_package_and_rejects_traversal(self):
        destination = self.root / "extracted"
        result = self.powershell(ROOT / "src/extract-runtime.ps1", "-PromptFile", ROOT / f"prompts/syrin-clean-prompt-en-v{build.VERSION}.md", "-OutDir", destination)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((destination / "bundle-manifest.json").read_bytes(), (self.package / "bundle-manifest.json").read_bytes())
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w") as bundle:
            bundle.writestr("../escape.txt", "fixture")
        data = buffer.getvalue()
        malicious = self.root / "invalid-prompt.md"
        malicious.write_text("## Runtime bundle (APPENDIX-RUNTIME)\nSHA256: " + hashlib.sha256(data).hexdigest() + "\n\n```base64\n" + base64.b64encode(data).decode() + "\n```\n", encoding="utf-8")
        result = self.powershell(ROOT / "src/extract-runtime.ps1", "-PromptFile", malicious, "-OutDir", self.root / "rejected")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "escape.txt").exists())


if __name__ == "__main__":
    unittest.main()
