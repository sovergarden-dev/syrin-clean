#!/usr/bin/env python3
"""Build and validate both standalone editions from canonical sources."""
import argparse
import base64
import hashlib
import io
import json
import re
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION = "3.6"
SLUG = "syrin-clean"
LANGUAGES = ("en", "vi")
SCRIPTS = ("audit.ps1", "history.ps1", "make-report.ps1", "new-restorepoint.ps1", "quarantine.ps1", "run-elevated.ps1")
MODULES = ("IO.psm1", "Audit.psm1", "Quarantine.psm1", "Report.psm1", "Windows.psm1")
SCHEMAS = ("audit.schema.json", "proposals.schema.json", "plan.schema.json")
PHASES = ("stage0-audit.md", "stage1-proposals.md", "stage2-execution.md")
SECRET = re.compile(rb"(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|AKIA[A-Z0-9]{16}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----)")


def read(path):
    return (ROOT / path).read_text(encoding="utf-8-sig")


def encoded(text, powershell=False):
    text = text.replace("\r\n", "\n")
    return (b"\xef\xbb\xbf" + text.replace("\n", "\r\n").encode("utf-8")) if powershell else text.encode("utf-8")


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def js(value):
    return json.dumps(value, ensure_ascii=False).replace("</", "<\\/")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def manifest(files, **metadata):
    return json_bytes({"schemaVersion": 1, **metadata, "files": [{"path": name, "sha256": digest(data), "bytes": len(data)} for name, data in sorted(files.items())]})


def archive(files):
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as bundle:
        for name, data in sorted(files.items()):
            info = zipfile.ZipInfo(name, date_time=(2026, 10, 28, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            bundle.writestr(info, data)
    return output.getvalue()


def allowlist(directory, names):
    base = ROOT / directory
    pending = [base]
    while pending:
        path = pending.pop()
        if not path.exists():
            continue
        attributes = getattr(path.lstat(), "st_file_attributes", 0)
        if path.is_symlink() or attributes & 0x400:
            raise ValueError(f"Link/reparse point is not allowed in package sources: {path.relative_to(ROOT)}")
        if path.is_dir():
            pending.extend(path.iterdir())
        elif path.relative_to(base).as_posix() not in names:
            raise ValueError(f"Unexpected source/package file: {path.relative_to(ROOT)}")


def runtime_sources():
    paths = ["scripts/" + name for name in SCRIPTS] + ["modules/" + name for name in MODULES] + ["assets/" + name for name in SCHEMAS]
    allowlist("src/runtime", set(paths) | {"assets/report-template.html"})
    result = {name: encoded(read("src/runtime/" + name), name.endswith((".ps1", ".psm1"))) for name in paths}
    template = read("src/report/template.html").replace("/*__REPORT_CSS__*/", read("src/report/report.css")).replace("/*__REPORT_JS__*/", read("src/report/report.mjs"))
    result["assets/report-template.html"] = encoded(template)
    return result


def appendix(bundle, language):
    intro = "Extract the bootstrap code to a .ps1 file and run it with -PromptFile and a new empty -OutDir. It only extracts the verified runtime; it does not run cleanup. Do not paste the Base64 into the model context." if language == "en" else "Trích bootstrap thành file .ps1 rồi chạy với -PromptFile và -OutDir mới, trống. Nó chỉ giải nén runtime đã kiểm tra, không dọn máy. Không chép Base64 vào ngữ cảnh model."
    return "## Bootstrap (APPENDIX-BOOTSTRAP)\n\n" + intro + "\n\n```powershell\n" + read("src/extract-runtime.ps1").strip() + "\n```\n\n## Runtime bundle (APPENDIX-RUNTIME)\nSHA256: " + digest(bundle) + "\n\n```base64\n" + base64.b64encode(bundle).decode() + "\n```\n"


def build_outputs():
    runtime = runtime_sources()
    output = {"src/runtime/assets/report-template.html": runtime["assets/report-template.html"]}
    bundles = {}
    policies = {}
    for language in LANGUAGES:
        folder = "src/instructions/" + language
        allowlist(folder, {"SKILL.md", "INSTALL.txt"} | {"references/" + p for p in PHASES})
        entry = read(folder + "/SKILL.md").replace("__VERSION__", VERSION)
        full = entry.split("---", 2)[2].strip() + "\n\n" + "\n\n".join(read(folder + "/references/" + name).strip() for name in PHASES) + "\n"
        policies[language] = full
        profile_hint = "Use the profile in the user's opening message." if language == "en" else "Dùng hồ sơ trong lời mở đầu của người dùng."
        skill = dict(runtime)
        skill["SKILL.md"] = encoded(entry.replace("__CUSTOM_CONTEXT__", profile_hint))
        for name in PHASES:
            skill["references/" + name] = encoded(read(folder + "/references/" + name))
        skill["references/support.md"] = encoded(read("docs/feat/support.md"))
        skill["skill-manifest.json"] = manifest(skill, package=SLUG, version=VERSION, language=language)
        package = {SLUG + "/" + name: data for name, data in skill.items()}
        package["install.ps1"] = encoded(read("src/install.ps1"), True)
        package["INSTALL.txt" if language == "en" else "CAI-DAT.txt"] = encoded(read(folder + "/INSTALL.txt"))
        package["LICENSE"] = encoded(read("LICENSE"))
        package["bundle-manifest.json"] = manifest(package, package=SLUG, version=VERSION, language=language, channel="development")
        allowlist("skill/" + language, set(package))
        for name, data in package.items():
            if SECRET.search(data):
                raise ValueError(f"Credential-like content in package file: {name}")
            output[f"skill/{language}/{name}"] = data
        bundles[language] = archive(package)
        output[f"dist/{SLUG}-skill-v{VERSION}-{language}.zip"] = bundles[language]
        output[f"src/prompt-template.{language}.txt"] = encoded(full)
    for language in LANGUAGES:
        profile = json.loads(read(f"src/web/profile.{language}.json"))
        ui = json.loads(read(f"src/web/ui.{language}.json"))
        title = f"# Syrin clean · Windows prompt v{VERSION}" if language == "en" else f"# Syrin clean · Prompt Windows v{VERSION}"
        ui.update(promptTitle=title, promptFile=f"{SLUG}-prompt-{language}-v{VERSION}.md")
        lines = [profile[key][value] for key, value in (("roleSnippets", "auto"), ("scopeSnippets", "full"), ("aggrSnippets", "balanced"), ("budgetSnippets", "balanced"), ("modeSnippets", "approve"), ("reportSnippets", "r3d"))]
        prompt = policies[language].replace("__CUSTOM_CONTEXT__", profile["blockHeader"] + "\n".join(lines))
        extra = appendix(bundles[language], language)
        output[f"prompts/{SLUG}-prompt-{language}-v{VERSION}.md"] = encoded(title + "\n\n## PROMPT\n\n" + prompt + "\n\n" + extra)
        variables = {**profile, "PAGE": ui, "basePromptTemplate": policies[language], "skillZipB64": base64.b64encode(bundles["vi"]).decode() if language == "vi" else None, "skillZipEnB64": base64.b64encode(bundles["en"]).decode(), "runtimeAppendix": extra}
        script = "\n".join("var " + key + " = " + js(value) + ";" for key, value in variables.items()) + "\n" + read("src/web/page.js")
        page = read(f"src/web/page.{language}.html").replace("/*__PAGE_CSS__*/", read("src/web/page.css")).replace("/*__PAGE_JS__*/", script)
        command = f'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File ".\\syrin-clean\\scripts\\audit.ps1" -Scope full -ReportMode 3d -Lang {language} -Quiet'
        page = page.replace("__AUDIT_COMMAND__", command.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))
        output[f"web/{SLUG}-{language}-v{VERSION}.html"] = encoded(page)
    files = {name: data for name, data in output.items() if name.startswith(("dist/", "prompts/", "web/"))}
    output["dist/artifact-manifest.json"] = manifest(files, package=SLUG, version=VERSION, channel="development")
    output["dist/SHA256SUMS.txt"] = encoded("".join(digest(data) + "  " + name + "\n" for name, data in sorted(files.items())))
    return output


def validate(outputs):
    node = shutil.which("node")
    if not node:
        raise RuntimeError("Node.js is required to validate generated JavaScript.")
    with tempfile.TemporaryDirectory(prefix="syrin-build-") as temporary:
        folder = Path(temporary)
        for relative, data in outputs.items():
            if not relative.endswith(".html") or not relative.startswith(("web/", "src/runtime/assets/")):
                continue
            for index, (attrs, script) in enumerate(re.findall(r"<script\b([^>]*)>(.*?)</script>", data.decode("utf-8"), re.S)):
                if "application/json" in attrs:
                    continue
                path = folder / (str(index) + (".mjs" if "module" in attrs else ".js"))
                path.write_bytes(script.encode("utf-8"))
                result = subprocess.run([node, "--check", str(path)], capture_output=True, text=True)
                if result.returncode:
                    raise ValueError(f"JavaScript in {relative}: {result.stderr}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate without modifying files")
    args = parser.parse_args()
    outputs = build_outputs()
    validate(outputs)
    changed = [name for name, data in outputs.items() if not (ROOT / name).exists() or (ROOT / name).read_bytes() != data]
    if args.check:
        if changed:
            raise SystemExit("Generated files are stale:\n" + "\n".join(changed))
        print(f"Build check OK: {len(outputs)} files match canonical sources")
        return
    for name in changed:
        target = ROOT / name
        target.parent.mkdir(parents=True, exist_ok=True)
        temporary = target.with_name(target.name + ".build-tmp")
        try:
            temporary.write_bytes(outputs[name])
            temporary.replace(target)
        finally:
            temporary.unlink(missing_ok=True)
    print(f"Build OK: {len(outputs)} validated files; {len(changed)} updated")


if __name__ == "__main__":
    main()
