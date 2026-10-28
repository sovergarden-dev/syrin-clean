#!/usr/bin/env python3
"""Rebuild dist/, web/ and prompts/ from skill/ and src/.

Usage:  python tools/build.py

1. Zips skill/vi and skill/en into dist/.
2. Re-embeds the zips, prompt templates, audit script, report template and
   make-report script into web/*.html (only the embedded content changes).
3. Regenerates prompts/*.md with the default profile and appendices A/B/C.
4. Runs `node --check` on the page scripts when Node.js is available.
"""
import base64, html, io, json, re, shutil, subprocess, sys, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VER = '3.6'
SKILL = 'syrin-clean'
PAGES = {lang: ROOT / 'web' / f'{SKILL}-{lang}-v{VER}.html' for lang in ('vi', 'en')}
ZIPS = {lang: ROOT / 'dist' / f'{SKILL}-skill-v{VER}-{lang}.zip' for lang in ('vi', 'en')}
MDS = {lang: ROOT / 'prompts' / f'{SKILL}-prompt-{lang}-v{VER}.md' for lang in ('vi', 'en')}
MD = {
    'vi': {'title': f'# Syrin clean · Prompt Windows v{VER}',
           'a': '## Ph\u1ee5 l\u1ee5c A (APPENDIX-A-AUDIT-SCRIPT): script ki\u1ec3m to\u00e1n ch\u1ec9-\u0111\u1ecdc cho agent d\u00f9ng l\u1ea1i',
           'b': '## Ph\u1ee5 l\u1ee5c B (APPENDIX-B-REPORT-TEMPLATE): m\u1eabu b\u00e1o c\u00e1o 3D',
           'c': '## Ph\u1ee5 l\u1ee5c C (APPENDIX-C-MAKE-REPORT): script t\u1ea1o b\u00e1o c\u00e1o'},
    'en': {'title': f'# Syrin clean prompt (Universal v{VER})',
           'a': '## Appendix A (APPENDIX-A-AUDIT-SCRIPT): read-only audit script for the agent',
           'b': '## Appendix B (APPENDIX-B-REPORT-TEMPLATE): 3D report template',
           'c': '## Appendix C (APPENDIX-C-MAKE-REPORT): report builder script'}}


def js(value):
    return json.dumps(value, ensure_ascii=False).replace('</', '<\\/')


def var_span(page, name):
    m = re.search(r'var ' + re.escape(name) + r' = ', page)
    if not m:
        sys.exit(f'JS variable {name} not found')
    return m.end(), page.index(';\n', m.end())


def get_var(page, name):
    a, b = var_span(page, name)
    return json.loads(page[a:b].replace('<\\/', '</'))


def set_var(page, name, value_js):
    a, b = var_span(page, name)
    return page[:a] + value_js + page[b:]


def make_zip(lang):
    src = ROOT / 'skill' / lang
    files = sorted((p for p in src.rglob('*') if p.is_file()), key=lambda p: (len(p.relative_to(src).parts), p.as_posix()))
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as z:
        for p in files:
            info = zipfile.ZipInfo(p.relative_to(src).as_posix(), date_time=(2026, 10, 28, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            z.writestr(info, p.read_bytes())
    ZIPS[lang].parent.mkdir(exist_ok=True)
    ZIPS[lang].write_bytes(buf.getvalue())
    return buf.getvalue()


def main():
    zips = {lang: base64.b64encode(make_zip(lang)).decode() for lang in ('vi', 'en')}
    for lang, page_path in PAGES.items():
        sk = ROOT / 'skill' / lang / SKILL
        page = page_path.read_text(encoding='utf-8')
        tpl = (ROOT / 'src' / f'prompt-template.{lang}.txt').read_text(encoding='utf-8')
        audit = (sk / 'scripts' / 'audit.ps1').read_text(encoding='utf-8-sig').strip('\r\n').replace('\r\n', '\n')
        report_tpl = (sk / 'assets' / 'report-template.html').read_text(encoding='utf-8')
        make_report = (sk / 'scripts' / 'make-report.ps1').read_text(encoding='utf-8-sig')
        page = set_var(page, 'basePromptTemplate', js(tpl))
        page = set_var(page, 'skillZipB64', "'" + zips['vi'] + "'" if lang == 'vi' else 'null')
        page = set_var(page, 'skillZipEnB64', "'" + zips['en'] + "'")
        page = set_var(page, 'reportTpl', js(report_tpl))
        page = set_var(page, 'makeReportPs', js(make_report))
        page = re.sub(r"(<pre class='code' id='auditCmds'>).*?(</pre>)", lambda m: m.group(1) + html.escape(audit, quote=False) + m.group(2), page, count=1, flags=re.S)
        page_path.write_text(page, encoding='utf-8', newline='')
        lines = [get_var(page, 'roleSnippets')['auto'], get_var(page, 'scopeSnippets')['full'], get_var(page, 'aggrSnippets')['balanced'],
                 get_var(page, 'budgetSnippets')['balanced'], get_var(page, 'modeSnippets')['approve'], get_var(page, 'reportSnippets')['r3d']]
        prompt = tpl.replace('__CUSTOM_CONTEXT__\n', get_var(page, 'blockHeader') + '\n'.join(lines) + '\n\n')
        t = MD[lang]
        md = (t['title'] + '\n\n## PROMPT\n\n' + prompt +
              '\n\n---\n\n' + t['a'] + '\n\n```powershell\n' + audit + '\n```\n' +
              '\n---\n\n' + t['b'] + '\n\n```html\n' + report_tpl + '\n```\n' +
              '\n' + t['c'] + '\n\n```powershell\n' + make_report + '\n```\n')
        MDS[lang].parent.mkdir(exist_ok=True)
        MDS[lang].write_text(md.replace('\r\n', '\n'), encoding='utf-8', newline='\n')
        if shutil.which('node'):
            script = page[page.rindex('    <script>') + 12:page.rindex('</script>')]
            tmp = ROOT / 'tools' / f'.check-{lang}.js'
            tmp.write_text(script, encoding='utf-8')
            r = subprocess.run(['node', '--check', str(tmp)], capture_output=True, text=True)
            tmp.unlink()
            if r.returncode:
                sys.exit(f'JavaScript error in {page_path.name}:\n{r.stderr}')
        print(f'[{lang}] {page_path.name}, {MDS[lang].name}, {ZIPS[lang].name}')
    print('Build OK')


if __name__ == '__main__':
    main()
