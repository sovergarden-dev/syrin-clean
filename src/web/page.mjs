import {createLens} from '../shared/lens.mjs';

export const profileDefaults = {optRole:'auto',optScope:'full',optAggressiveness:'balanced',optBudget:'balanced',optMode:'approve',optReport:'r3d',optDrive:'',optProtect:'',optNote:''};

export function profileLines(profile, values) {
  const rules = [['roleSnippets','optRole','auto'],['scopeSnippets','optScope','full'],['aggrSnippets','optAggressiveness','balanced'],['budgetSnippets','optBudget','balanced'],['modeSnippets','optMode','approve'],['reportSnippets','optReport','r3d']];
  const lines = rules.map(([group, field, fallback]) => profile[group][values[field]] || profile[group][fallback]);
  for (const [key, field] of [['drive','optDrive'],['protect','optProtect'],['note','optNote']]) {
    const value = String(values[field] || '').trim();
    if (value) lines.push(profile.extraTpl[key].replace('{v}', value));
  }
  return lines;
}

export function composePrompt(edition, values) {
  return edition.policy.replace('__CUSTOM_CONTEXT__', edition.profile.blockHeader + profileLines(edition.profile, values).join('\n'));
}

export function promptDocument(data, language, values) {
  const edition = data.editions[language];
  const appendix = '## Bootstrap (APPENDIX-BOOTSTRAP)\n\n' + edition.ui.bootstrapIntro + '\n\n```powershell\n' + data.bootstrap + '\n```\n\n## Runtime bundle (APPENDIX-RUNTIME)\nSHA256: ' + edition.zipSha256 + '\n\n```base64\n' + edition.zipBase64 + '\n```\n';
  return edition.promptTitle + '\n\n## PROMPT\n\n' + composePrompt(edition, values) + '\n\n' + appendix;
}

function startPage(data) {
  const $ = id => document.getElementById(id);
  let language = 'en', stage = 0, toastTimer = 0, lens;
  try { if (localStorage.getItem('syrin-language') === 'vi') language = 'vi'; } catch {}
  const requested = new URLSearchParams(location.search).get('lang');
  if (requested === 'en' || requested === 'vi') language = requested;
  const current = () => data.editions[language];
  const values = () => Object.fromEntries(Object.keys(profileDefaults).map(id => [id, $(id).value.trim()]));
  function status(message) {
    clearTimeout(toastTimer); $('toast').textContent = message; $('toast').hidden = false;
    toastTimer = setTimeout(() => { $('toast').hidden = true; }, 4200);
  }
  function buildMessages() {
    const edition = current(), selected = values();
    const prompt = composePrompt(edition, selected);
    $('superPrompt').textContent = prompt;
    $('starterMsg').textContent = edition.ui.starter + edition.profile.blockHeader + profileLines(edition.profile, selected).join('\n');
    $('wordCount').textContent = prompt.split(/\s+/).filter(Boolean).length.toLocaleString(edition.ui.locale) + ' ' + edition.ui.words;
    $('installMsg').textContent = edition.ui.installMessage;
    $('auditCmds').textContent = 'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File ".\\syrin-clean\\scripts\\audit.ps1" -Scope full -ReportMode 3d -Lang ' + language + ' -Quiet';
  }
  let offlineDemoUrl;
  if (location.protocol === 'file:' || location.protocol === 'blob:') {
    const bytes = Uint8Array.from(atob(data.demoBase64), character => character.charCodeAt(0));
    offlineDemoUrl = URL.createObjectURL(new Blob([bytes], {type:'text/html;charset=utf-8'}));
  }
  function translate() {
    const ui = current().ui;
    document.documentElement.lang = language; $('language').value = language;
    document.title = ui.title; document.querySelector('meta[name="description"]').content = ui.description;
    for (const element of document.querySelectorAll('[data-i18n]')) element.textContent = ui[element.dataset.i18n];
    for (const element of document.querySelectorAll('[data-i18n-aria]')) element.setAttribute('aria-label', ui[element.dataset.i18nAria]);
    for (const element of document.querySelectorAll('[data-i18n-placeholder]')) element.setAttribute('placeholder', ui[element.dataset.i18nPlaceholder]);
    $('stageStatus').textContent = ui['stage' + stage];
    $('openDemo').href = offlineDemoUrl ? offlineDemoUrl + '#lang=' + language : 'report-demo.html?lang=' + language;
    $('downloadHtml').hidden = Boolean(offlineDemoUrl);
    clearTimeout(toastTimer); $('toast').hidden = true;
    buildMessages(); lens?.refresh();
  }
  $('language').addEventListener('change', () => {
    language = $('language').value === 'vi' ? 'vi' : 'en';
    try { localStorage.setItem('syrin-language', language); } catch {}
    translate();
  });
  for (const id of Object.keys(profileDefaults)) $(id).addEventListener($(id).tagName === 'SELECT' ? 'change' : 'input', buildMessages);
  $('resetCustom').addEventListener('click', () => { for (const [id, value] of Object.entries(profileDefaults)) $(id).value = value; buildMessages(); status(current().ui.resetDone); });
  $('tryAudit').addEventListener('click', () => { $('optMode').value = 'audit'; buildMessages(); status(current().ui.auditOnly); });
  const tabs = [...document.querySelectorAll('[role="tab"]')];
  function selectTab(tab) {
    for (const item of tabs) { const active = item === tab; item.setAttribute('aria-selected', String(active)); item.tabIndex = active ? 0 : -1; $(item.getAttribute('aria-controls')).hidden = !active; }
  }
  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => selectTab(tab));
    tab.addEventListener('keydown', event => {
      const next = event.key === 'ArrowRight' ? (index + 1) % tabs.length : event.key === 'ArrowLeft' ? (index + tabs.length - 1) % tabs.length : event.key === 'Home' ? 0 : event.key === 'End' ? tabs.length - 1 : -1;
      if (next < 0) return; event.preventDefault(); selectTab(tabs[next]); tabs[next].focus();
    });
  });
  function selectText(element) { const range = document.createRange(); range.selectNodeContents(element); const selection = getSelection(); selection.removeAllRanges(); selection.addRange(range); element.focus(); }
  for (const [buttonId, sourceId] of [['copyStarter','starterMsg'],['copyPrompt','superPrompt'],['copyInstall','installMsg'],['copyCmds','auditCmds']]) {
    $(buttonId).addEventListener('click', async () => {
      try { await navigator.clipboard.writeText($(sourceId).textContent); status(current().ui.copied); }
      catch { selectText($(sourceId)); status(current().ui.copyFailure); }
    });
  }
  function download(contents, type, name, message) {
    const url = URL.createObjectURL(new Blob([contents], {type}));
    const link = document.createElement('a'); link.href = url; link.download = name; document.body.append(link); link.click(); link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 30000); status(message);
  }
  function downloadSkill() {
    try { const edition = current(); const bytes = Uint8Array.from(atob(edition.zipBase64), character => character.charCodeAt(0)); download(bytes, 'application/zip', edition.zipFile, edition.ui.skillDownloaded); }
    catch { status(current().ui.downloadFailure); }
  }
  function downloadPrompt() {
    try { const edition = current(); download(promptDocument(data, language, values()), 'text/markdown;charset=utf-8', edition.promptFile, edition.ui.promptDownloaded); }
    catch { status(current().ui.downloadFailure); }
  }
  for (const button of document.querySelectorAll('[data-dl]')) button.addEventListener('click', button.dataset.dl === 'md' ? downloadPrompt : downloadSkill);
  $('downloadCmds').addEventListener('click', downloadSkill);
  $('downloadPrompt').addEventListener('click', downloadPrompt);
  for (const button of document.querySelectorAll('[data-stage]')) button.addEventListener('click', () => {
    stage = Number(button.dataset.stage);
    for (const item of document.querySelectorAll('[data-stage]')) item.setAttribute('aria-pressed', String(item === button));
    $('stageStatus').textContent = current().ui['stage' + stage]; lens.setStage(stage);
  });
  translate();
  lens = createLens($('reviewLens'), {preview:true, button:$('motion'), labels:() => current().ui});
  document.documentElement.dataset.ready = 'true';
}

if (typeof document !== 'undefined') {
  try { startPage(JSON.parse(document.getElementById('syrin-page-data').textContent)); }
  catch (error) { const toast = document.getElementById('toast'); toast.hidden = false; toast.textContent = 'Interactive controls could not start. Download a package from the GitHub Releases link.'; console.error(error); }
}
