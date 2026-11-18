import base64
import contextlib
import hashlib
import importlib.util
import io
import json
import os
import re
import shutil
import subprocess
import tempfile
import textwrap
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
    def test_packaged_support_links_target_the_release_documentation(self):
        outputs = build.build_outputs()
        prefix = build.PROJECT['repository'] + '/blob/' + build.VERSION + '/docs/'
        for language in build.LANGUAGES:
            text = outputs[f'skill/{language}/syrin-clean/references/support.md'].decode('utf-8')
            self.assertIn('](' + prefix + 'feat/devices.md)', text)
            self.assertIn('](' + prefix + 'research/android-live-validation.md)', text)
            self.assertNotIn('](devices.md)', text)

    def test_manual_redeploy_skips_provenance_but_still_checks_published_html(self):
        workflow = (ROOT / '.github/workflows/pages.yml').read_text(encoding='utf-8')
        verifier = textwrap.dedent(workflow.split("python - <<'PY'\n", 1)[1].split('          PY', 1)[0])
        with tempfile.TemporaryDirectory(prefix='syrin-release-verify-test-') as temporary:
            directory = Path(temporary)
            site = directory / 'site'
            site.mkdir()
            payloads = {'syrin-clean.html': b'fixture page', 'syrin-clean-report-demo.html': b'fixture report',
                        'en.zip': b'fixture en', 'vi.zip': b'fixture vi', 'en.md': b'fixture prompt en',
                        'vi.md': b'fixture prompt vi', 'artifact-manifest.json': b'fixture manifest', 'SHA256SUMS.txt': b'fixture checksums'}
            digest = lambda data: hashlib.sha256(data).hexdigest()
            metadata = {'version': 'fixture-tag', 'files': {}}
            for name, asset in [('index.html', 'syrin-clean.html'), ('report-demo.html', 'syrin-clean-report-demo.html')]:
                (site / name).write_bytes(payloads[asset])
                metadata['files'][name] = digest(payloads[asset])
            (site / 'version.json').write_text(json.dumps(metadata), encoding='utf-8')
            (site / '.nojekyll').write_bytes(b'')
            release = {'draft': False, 'tag_name': 'fixture-tag', 'assets': [{'name': name, 'digest': 'sha256:' + digest(data)} for name, data in payloads.items()]}
            subjects = directory / 'subjects'
            environment = {'SITE_DIR': str(site), 'RELEASE_DIR': str(subjects), 'PAGES_TAG': 'fixture-tag',
                           'PAGES_REPOSITORY': 'example/fixture', 'GH_TOKEN': 'fixture-only'}

            def verify(event):
                with patch.dict(os.environ, {**environment, 'PAGES_EVENT': event}), patch('urllib.request.urlopen', side_effect=lambda *args, **kwargs: io.BytesIO(json.dumps(release).encode())), contextlib.redirect_stdout(io.StringIO()):
                    exec(verifier, {'__name__': '__main__'})

            verify('workflow_dispatch')
            with self.assertRaises(AssertionError):
                verify('release')
            for extra, content in [('og-preview.png', b'\x89PNG\r\n\x1a\nfixture'), ('robots.txt', b'User-agent: *\n'), ('sitemap.xml', b'<urlset/>')]:
                (site / extra).write_bytes(content)
                metadata['files'][extra] = digest(content)
            (site / 'version.json').write_text(json.dumps(metadata), encoding='utf-8')
            with self.assertRaises(FileNotFoundError):
                verify('release')
            (site / 'index.html').write_bytes(b'tampered')
            with self.assertRaisesRegex(AssertionError, 'Site metadata differs|Site differs'):
                verify('workflow_dispatch')
            (site / 'index.html').write_bytes(payloads['syrin-clean.html'])
            subjects.mkdir()
            for name, data in payloads.items():
                (subjects / name).write_bytes(data)
            verify('release')
            (subjects / 'en.zip').write_bytes(b'tampered')
            with self.assertRaisesRegex(AssertionError, 'Release asset differs'):
                verify('release')

    def test_release_staging_has_only_current_verified_artifacts(self):
        module_spec = importlib.util.spec_from_file_location("syrin_stage_release", ROOT / "tools/stage_release.py")
        release = importlib.util.module_from_spec(module_spec)
        module_spec.loader.exec_module(release)
        with tempfile.TemporaryDirectory(prefix="syrin-release-test-") as temporary:
            target = Path(temporary)
            names = release.stage(target)
            self.assertEqual(len(names), 8)
            manifest = json.loads((target / "artifact-manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(set(names), {row["path"] for row in manifest["files"]} | {"artifact-manifest.json", "SHA256SUMS.txt"})
            for row in manifest["files"]:
                self.assertEqual(hashlib.sha256((target / row["path"]).read_bytes()).hexdigest(), row["sha256"])
            with self.assertRaisesRegex(ValueError, "empty"):
                release.stage(target)
        with self.assertRaisesRegex(ValueError, "outside"):
            release.stage(ROOT / "dist")

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
            self.assertEqual(
                {path.name for path in target.iterdir()},
                {"index.html", "report-demo.html", "og-preview.png", "robots.txt", "sitemap.xml", "version.json", ".nojekyll"},
            )
            self.assertEqual(metadata["version"], build.VERSION)
            for name in ("index.html", "report-demo.html"):
                self.assertEqual((target / name).read_bytes(), (ROOT / "web" / name).read_bytes())
            self.assertTrue((target / "og-preview.png").read_bytes().startswith(b"\x89PNG\r\n\x1a\n"))
            self.assertIn("Sitemap: " + build.PROJECT["homepage"] + "sitemap.xml", (target / "robots.txt").read_text(encoding="utf-8"))
            self.assertIn("<loc>" + build.PROJECT["homepage"] + "</loc>", (target / "sitemap.xml").read_text(encoding="utf-8"))
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
            motion_tag, motion = next((tag, a) for tag, a in parser.elements if a.get("id") == "motion")
            self.assertEqual(motion_tag, "button")
            self.assertEqual(motion.get("type"), "button")
            self.assertNotIn("aria-pressed", motion, name)
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
                (directory / "dist").mkdir(parents=True)
                (directory / "dist/syrin-clean-skill-v0.0.1-en.zip").write_bytes(b"stale")
                with self.assertRaisesRegex(ValueError, "Unexpected"):
                    build.check_output_trees({"dist/syrin-clean.html": b"current"})
            finally:
                build.ROOT = original

    def test_json_schemas_validate_demo_plan_and_proposals(self):
        def assert_schema(schema, value, path="$"):
            if "const" in schema:
                self.assertEqual(value, schema["const"], path)
            if "enum" in schema:
                self.assertIn(value, schema["enum"], path)
            if "type" in schema:
                allowed = schema["type"] if isinstance(schema["type"], list) else [schema["type"]]
                checks = {
                    "object": lambda v: isinstance(v, dict),
                    "array": lambda v: isinstance(v, list),
                    "string": lambda v: isinstance(v, str),
                    "boolean": lambda v: isinstance(v, bool),
                    "integer": lambda v: type(v) is int,
                    "number": lambda v: type(v) in (int, float),
                    "null": lambda v: v is None,
                }
                self.assertTrue(any(checks[kind](value) for kind in allowed), f"{path}: {value!r} not in {allowed}")
            if isinstance(value, str) and "pattern" in schema:
                self.assertRegex(value, schema["pattern"], path)
            if type(value) in (int, float) and "minimum" in schema:
                self.assertGreaterEqual(value, schema["minimum"], path)
            if isinstance(value, list):
                if "minItems" in schema:
                    self.assertGreaterEqual(len(value), schema["minItems"], path)
                if "items" in schema:
                    for idx, item in enumerate(value):
                        assert_schema(schema["items"], item, f"{path}[{idx}]")
            if isinstance(value, dict):
                for req in schema.get("required", []):
                    self.assertIn(req, value, f"{path}.{req}")
                props = schema.get("properties", {})
                extra = schema.get("additionalProperties", True)
                for key, child in value.items():
                    if key in props:
                        assert_schema(props[key], child, f"{path}.{key}")
                    elif extra is False:
                        self.fail(f"Unexpected property {path}.{key}")
                    elif isinstance(extra, dict):
                        assert_schema(extra, child, f"{path}.{key}")

        audit_schema = json.loads((ROOT / "src/runtime/assets/audit.schema.json").read_text(encoding="utf-8"))
        plan_schema = json.loads((ROOT / "src/runtime/assets/plan.schema.json").read_text(encoding="utf-8"))
        proposals_schema = json.loads((ROOT / "src/runtime/assets/proposals.schema.json").read_text(encoding="utf-8"))
        demo = json.loads((ROOT / "src/report/demo.json").read_text(encoding="utf-8"))
        assert_schema(audit_schema, demo["audit"])
        assert_schema(audit_schema, demo["baseline"])
        sample_proposals = {
            "schemaVersion": 1,
            "kind": "syrin-proposals",
            "sessionId": "a" * 32,
            "items": [{"id": "C1", "title": "Review cache", "evidence": "2 GB", "benefit": "2 GB", "loss": "Cold start", "risk": "low", "undo": "reversible"}],
        }
        assert_schema(proposals_schema, sample_proposals)
        with self.assertRaises(AssertionError):
            assert_schema(proposals_schema, {**sample_proposals, "unexpected": True})
        sample_plan = {
            "schemaVersion": 1,
            "kind": "syrin-file-plan",
            "planId": "a" * 32,
            "sessionId": "b" * 32,
            "operation": "quarantine",
            "ownerSid": "S-1-5-21-1",
            "root": "D:\\Quarantine",
            "rootId": None,
            "legacyRoot": "",
            "createdUtc": "2026-11-18T00:00:00Z",
            "conflict": "skip",
            "measuredBytes": 12,
            "estimatedReclaimableBytes": 0,
            "warnings": [" Metadata only "],
            "protection": {"mode": "approve", "protectedPaths": [], "files": [{"path": "D:\\policy.json", "digest": "c" * 64}]},
            "groups": [{"groupId": "G1", "directory": "D:\\Cache", "itemCount": 1, "measuredBytes": 12, "firstCode": "Q1", "lastCode": "Q1", "sampleFiles": ["a.bin"]}],
            "items": [{
                "id": "d" * 32,
                "code": "Q1",
                "groupId": "G1",
                "original": "D:\\Cache\\a.bin",
                "stored": "D:\\Quarantine\\a.bin",
                "fingerprint": {"FileId": "1:2", "Length": 12, "LastWriteUtc": "2026-11-18T00:00:00Z", "Links": 1},
                "destination": "D:\\Quarantine\\a.bin",
                "expectedState": "planned",
            }],
        }
        assert_schema(plan_schema, sample_plan)
        with self.assertRaises(AssertionError):
            assert_schema(plan_schema, {**sample_plan, "rogueField": 1})


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

    def test_install_supports_detected_and_explicit_agent_targets(self):
        (self.profile / ".codex").mkdir()
        (self.profile / ".gemini/antigravity").mkdir(parents=True)
        detected = self.powershell(self.package / "install.ps1", "-ProfileRoot", self.profile, "-IncludeDetectedAgents")
        self.assertEqual(detected.returncode, 0, detected.stdout + detected.stderr)
        for target in (".claude", ".agents", ".codex", ".gemini/antigravity"):
            self.assertTrue((self.profile / target / "skills/syrin-clean/SKILL.md").is_file(), target)
        self.assertFalse((self.profile / ".cursor/skills/syrin-clean/SKILL.md").exists())
        rejected = self.powershell(self.package / "install.ps1", "-ProfileRoot", self.profile, "-AgentTargets", ".unknown-agent")
        self.assertNotEqual(rejected.returncode, 0)


if __name__ == "__main__":
    unittest.main()
