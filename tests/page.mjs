import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {profileDefaults,profileLines,promptDocument} from '../src/web/page.mjs';

const page=readFileSync(new URL('../web/index.html',import.meta.url),'utf8');
const data=JSON.parse(page.match(/<script type="application\/json" id="syrin-page-data">(.*?)<\/script>/s)[1]);
for(const language of ['en','vi']){
  const edition=data.editions[language];
  const expected=readFileSync(new URL('../prompts/'+edition.promptFile,import.meta.url),'utf8');
  assert.equal(promptDocument(data,language,profileDefaults),expected);
  assert.equal(createHash('sha256').update(Buffer.from(edition.zipBase64,'base64')).digest('hex'),edition.zipSha256);
  const values={...profileDefaults,optBudget:'thorough',optMode:'audit',optReport:'none',optProtect:'D:\\Example\\Keep',optNote:'Literal <script> example'};
  const lines=profileLines(edition.profile,values);
  assert.equal(lines.length,8);
  assert.ok(lines.some(line=>line.includes('MaxSeconds=600')));
  assert.ok(lines.some(line=>line.includes('ReportMode=none')));
  assert.ok(lines.some(line=>line.includes('D:\\Example\\Keep')));
  assert.ok(lines.some(line=>line.includes('Literal <script> example')));
  assert.equal(values.optMode,'audit');
  const android=profileLines(edition.profile,{...values,optDevice:'android'}).join('\n');
  assert.ok(android.includes('Android') && android.includes('MaxSeconds=300'));
  assert.ok(!android.includes('D:\\Example\\Keep') && !android.includes('MaxSeconds=600'));
  assert.ok(android.includes('ReportMode=none'));
  const task=profileLines(edition.profile,{...values,optDevice:'android',optAndroidPackage:'com.example.app',optAndroidContext:'Scroll a fixture list'}).join('\n');
  assert.ok(task.includes('com.example.app') && task.includes('Scroll a fixture list'));
  const invalid=profileLines(edition.profile,{...values,optDevice:'android',optAndroidPackage:'com.example.app;reboot'}).join('\n');
  assert.ok(invalid.includes(edition.profile.androidInvalidPackage) && !invalid.includes(';reboot'));
}
assert.deepEqual(Object.keys(data.editions.en.ui).sort(),Object.keys(data.editions.vi.ui).sort());
console.log('Landing model: both default Markdown downloads match their artifacts; profile choices and embedded packages are exact.');
