import assert from 'node:assert/strict';
import {createView,normalizeAudit,escapeHtml,historyPage,filterHistoryItems} from '../src/report/report.mjs';
import {createLens} from '../src/shared/lens.mjs';
const complete=data=>({status:'complete',data,errors:[]});
const audit=()=>({schemaVersion:1,kind:'syrin-audit',meta:{sessionId:'a'.repeat(32),machineId:'machine-a',systemDrive:'D:',generatedUtc:'2026-10-28T00:00:00Z',reportMode:'3d'},collectors:{system:complete([{model:'Fixture'}]),volumes:complete([{drive:'C:',volumeId:'data',sizeBytes:100,freeBytes:60},{drive:'D:',volumeId:'system',sizeBytes:100,freeBytes:1}]),startup:complete([]),events:complete([]),radar:complete([{id:'cache',label:'Cache',category:'cache',measuredBytes:2,cloudBytes:0,estimatedReclaimableBytes:null,status:'complete'},{id:'chat',label:'Telegram data',category:'app-data',measuredBytes:3,cloudBytes:0,estimatedReclaimableBytes:null,status:'complete'},{id:'vm',label:'Docker',category:'vm',measuredBytes:5,cloudBytes:0,estimatedReclaimableBytes:null,status:'complete'}])}});
let view=createView(audit());
assert.equal(view.systemVolume.drive,'D:');
assert.deepEqual(view.totals,{'cache':2,'app-data':3,'user-data':0,vm:5,system:0,unknown:0});
assert.equal(view.reclaimable,null);
assert.equal(view.startupCount,0);
assert.equal(view.eventCount,0);
let missing=audit();delete missing.collectors.startup;delete missing.collectors.events;
view=createView(missing);assert.equal(view.startupCount,null);assert.equal(view.eventCount,null);
let partial=audit();partial.collectors.events={status:'partial',data:[{count:7}],errors:['limited']};partial.collectors.startup=complete([{enabled:null}]);
view=createView(partial);assert.equal(view.eventCount,null);assert.equal(view.startupCount,null);assert.equal(view.unknownStartup,1);
let baseline=audit();baseline.collectors.volumes.data[1].freeBytes=9;
assert.equal(createView(audit(),baseline).comparison.delta,-8);
baseline.meta.machineId='another-machine';assert.throws(()=>createView(audit(),baseline),/mismatch/);
baseline=audit();baseline.collectors.volumes.data[1].volumeId='changed-volume';assert.equal(createView(audit(),baseline).comparison,null);
const legacy={meta:{GeneratedAt:'2020-01-01'},system:[{MakerModel:'Legacy'}],volumes:[{DriveLetter:'C',SizeGB:10,FreeGB:1}],radar:[{Item:'Telegram tdata',GB:10}]};
view=createView(legacy);assert.equal(view.systemVolume,null);assert.equal(view.radar[0].category,'unknown');assert.equal(view.audit.legacy,true);
assert.throws(()=>normalizeAudit({schemaVersion:99}),/Unsupported/);
assert.equal(escapeHtml('<script>"&\''),'&lt;script&gt;&quot;&amp;&#39;');
const historyItems=Array.from({length:128},(_,index)=>({id:'item-'+index}));
assert.deepEqual(historyPage(historyItems,2).items.map(item=>item.id),Array.from({length:28},(_,index)=>'item-'+(index+100)));
assert.equal(historyPage(historyItems,999).page,2);
assert.equal(historyPage(historyItems,-1).page,0);
assert.deepEqual(historyPage([],0).items,[]);
assert.equal(historyPage(historyItems,1).items[0].id,'item-50');
const searchable=[{id:'a',code:'Q1',original:'D:\\Đường\\A[1].cache',state:'quarantined'},{id:'b',code:'Q2',original:'D:\\other.cache',state:'purged'},{id:'c',code:'Q3',original:'D:\\conflict.cache',state:'conflict'}];
assert.deepEqual(filterHistoryItems(searchable,{query:'đường'.normalize('NFD')}).map(item=>item.id),['a']);
assert.deepEqual(filterHistoryItems(searchable,{query:'[1]'}).map(item=>item.id),['a']);
assert.deepEqual(filterHistoryItems(searchable,{state:'attention'}).map(item=>item.id),['c']);
assert.deepEqual(filterHistoryItems(searchable,{state:'purged',query:'Q1'}),[]);
console.log('Report model: volume identity, categories, unknown/partial data, baseline identity, legacy data and escaping passed');

function verifyLensLifecycle() {
  const timers=new Map(), frames=new Map(), observers=[], storage=new Map();
  let nextId=0, paints=0, lens;
  class Element extends EventTarget {
    dataset={}; attributes=new Map(); clientWidth=480; clientHeight=320;
    setAttribute(name,value){this.attributes.set(name,String(value));}
    getAttribute(name){return this.attributes.get(name)??null;}
  }
  class Observer {
    constructor(callback){this.callback=callback;this.connected=false;observers.push(this);}
    observe(){this.connected=true;}
    disconnect(){this.connected=false;}
  }
  const doc=new EventTarget();doc.hidden=false;
  const media=new EventTarget();media.matches=false;
  const context={setTransform(){},clearRect(){paints++;},beginPath(){},ellipse(){},stroke(){},fillRect(){}};
  const canvas=new Element();canvas.getContext=()=>context;
  const button=new Element();
  const environment={document:doc,innerWidth:1280,devicePixelRatio:1,matchMedia:()=>media,getComputedStyle:()=>({getPropertyValue:()=> '#ffffff'}),IntersectionObserver:Observer,ResizeObserver:Observer,
    localStorage:{getItem:key=>storage.get(key)??null,setItem:(key,value)=>storage.set(key,value)},
    setTimeout:callback=>{const id=++nextId;timers.set(id,callback);return id;},clearTimeout:id=>timers.delete(id),
    requestAnimationFrame:callback=>{const id=++nextId;frames.set(id,callback);return id;},cancelAnimationFrame:id=>frames.delete(id)};
  const saved=new Map(Object.keys(environment).map(key=>[key,Object.getOwnPropertyDescriptor(globalThis,key)]));
  try {
    for(const [key,value] of Object.entries(environment)) Object.defineProperty(globalThis,key,{value,writable:true,configurable:true});
    lens=createLens(canvas,{preview:true,button,labels:()=>({pause:'Pause animation',resume:'Enable animation',reduced:'Reduced motion'})});
    observers[0].callback([{isIntersecting:true}]);
    assert.equal(canvas.dataset.motion,'running');
    assert.equal(button.textContent,'Pause animation');
    assert.equal(button.getAttribute('aria-pressed'),null,'An action with a changing label must not expose a pressed state');
    assert.equal(timers.size,1);
    const [timerId,tick]=timers.entries().next().value;timers.delete(timerId);tick();
    assert.equal(frames.size,1);
    button.dispatchEvent(new Event('click'));
    assert.equal(canvas.dataset.motion,'paused');assert.equal(button.textContent,'Enable animation');
    assert.equal(frames.size,0);assert.equal(timers.size,0);
    assert.equal(storage.get('syrin-motion'),'paused');
    button.dispatchEvent(new Event('click'));assert.equal(timers.size,1);
    media.matches=true;media.dispatchEvent(new Event('change'));
    assert.equal(canvas.dataset.motion,'reduced');assert.equal(button.disabled,true);assert.equal(button.textContent,'Reduced motion');
    assert.equal(timers.size,0);assert.equal(frames.size,0);
    media.matches=false;media.dispatchEvent(new Event('change'));
    assert.equal(button.disabled,false);assert.equal(timers.size,1);
    const beforeHidden=paints;doc.hidden=true;doc.dispatchEvent(new Event('visibilitychange'));
    assert.equal(canvas.dataset.motion,'hidden');assert.equal(paints,beforeHidden);assert.equal(timers.size,0);
    doc.hidden=false;doc.dispatchEvent(new Event('visibilitychange'));assert.equal(timers.size,1);
    observers[0].callback([{isIntersecting:false}]);const beforeOffscreen=paints;
    lens.setStage(2);lens.setCategory('cache');
    assert.equal(canvas.dataset.motion,'hidden');assert.equal(paints,beforeOffscreen);assert.equal(timers.size,0);assert.equal(frames.size,0);
    observers[0].callback([{isIntersecting:true}]);assert.equal(timers.size,1);
    lens.destroy();assert.equal(timers.size,0);assert.equal(frames.size,0);
    assert.ok(observers.every(observer=>!observer.connected));
    doc.dispatchEvent(new Event('visibilitychange'));media.dispatchEvent(new Event('change'));button.dispatchEvent(new Event('click'));
    assert.equal(timers.size,0);assert.equal(frames.size,0);
  } finally {
    lens?.destroy();
    for(const [key,descriptor] of saved){if(descriptor)Object.defineProperty(globalThis,key,descriptor);else delete globalThis[key];}
  }
}
verifyLensLifecycle();
console.log('Shared renderer: action semantics and pause/reduced-motion/hidden/offscreen/destroy cancellation passed (synthetic browser contract).');
