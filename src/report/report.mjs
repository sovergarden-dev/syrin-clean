const list = value => Array.isArray(value) ? value : [];
const first = value => list(value)[0] || {};
const number = value => typeof value === 'number' && Number.isFinite(value) && value >= 0 ? value : null;
export const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const categories = ['cache','app-data','user-data','vm','system','unknown'];

export function normalizeAudit(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw Error('Invalid audit object');
  if (input.schemaVersion === 1 && input.kind === 'syrin-audit' && input.meta && input.collectors) return input;
  if (input.schemaVersion !== undefined || !input.meta || !Array.isArray(input.system) || !Array.isArray(input.volumes)) throw Error('Unsupported audit format');
  const legacy = (data) => ({status:'partial',data:list(data),errors:['Legacy measurements have no collector provenance.']});
  return {schemaVersion:1,kind:'syrin-audit',legacy:true,meta:{sessionId:'',machineId:null,systemDrive:null,generatedUtc:input.meta.GeneratedAt,reportMode:'simple',warnings:[]},collectors:{
    system:legacy(input.system.map(x=>({model:x.MakerModel,windows:x.Windows,architecture:x.Arch,ramBytes:number(x.RAM_GB) === null ? null : x.RAM_GB*2**30}))),
    volumes:legacy(input.volumes.map(x=>({drive:String(x.DriveLetter)+':',sizeBytes:number(x.SizeGB) === null ? null : x.SizeGB*2**30,freeBytes:number(x.FreeGB) === null ? null : x.FreeGB*2**30}))),
    radar:legacy(list(input.radar).map((x,i)=>({id:'legacy-'+i,label:x.Item,path:x.Path,category:'unknown',measuredBytes:number(x.GB) === null ? null : x.GB*2**30,cloudBytes:number(x.CloudOnlyGB) === null ? null : x.CloudOnlyGB*2**30,status:'partial',estimatedReclaimableBytes:null}))),
    startup:legacy(input.startup_run),events:legacy(input.events)
  }};
}

export function createView(input, baseline=null) {
  const audit=normalizeAudit(input);
  const collector=name=>audit.collectors[name] || {status:'unavailable',data:[],errors:[]};
  const volumes=list(collector('volumes').data);
  const systemVolume=volumes.find(v=>String(v.drive).toUpperCase() === String(audit.meta.systemDrive || '').toUpperCase()) || null;
  const radar=list(collector('radar').data).filter(x=>x && number(x.measuredBytes)!==null).map(x=>({...x,category:categories.includes(x.category)?x.category:'unknown'}));
  const totals=Object.fromEntries(categories.map(c=>[c,radar.filter(x=>x.category===c).reduce((s,x)=>s+x.measuredBytes,0)]));
  const startup=collector('startup');
  const unknownStartup=list(startup.data).filter(x=>typeof x.enabled!=='boolean').length;
  const startupCount=startup.status==='complete' && !unknownStartup ? list(startup.data).filter(x=>x.enabled).length : null;
  const events=collector('events');
  const eventCount=events.status==='complete' && list(events.data).every(x=>number(x.count)!==null) ? list(events.data).reduce((s,x)=>s+x.count,0) : null;
  const estimates=radar.map(x=>number(x.estimatedReclaimableBytes));
  const reclaimable=estimates.length && estimates.every(x=>x!==null) ? estimates.reduce((a,b)=>a+b,0) : null;
  let comparison=null;
  if(baseline){
    const before=normalizeAudit(baseline);
    if(!audit.meta.machineId || before.meta.machineId!==audit.meta.machineId || before.legacy || audit.legacy) throw Error('Baseline machine or schema mismatch');
    const previous=list(before.collectors.volumes?.data).find(x=>systemVolume?.volumeId && x.volumeId===systemVolume.volumeId);
    if(previous && number(previous.freeBytes)!==null && number(systemVolume.freeBytes)!==null && collector('volumes').status==='complete' && before.collectors.volumes.status==='complete') comparison={before:previous.freeBytes,after:systemVolume.freeBytes,delta:systemVolume.freeBytes-previous.freeBytes};
  }
  const memoryAvailable=number(first(collector('memory').data).availableBytes);
  const security=first(collector('security').data),defender=typeof security.realTimeProtection==='boolean'?security.realTimeProtection:null;
  return {audit,collector,system:first(collector('system').data),systemVolume,radar,totals,startupCount,unknownStartup,eventCount,reclaimable,memoryAvailable,defender,comparison,incomplete:Object.entries(audit.collectors).filter(([,x])=>x.status!=='complete').map(([k])=>k)};
}

const copy={
  en:{report:'Read-only report',pc:'This PC',summary:'Measurements and confidence',unknown:'Not measured',partial:'Partial or unverified',complete:'Measured',startup:'Enabled startup items',events:'Critical errors in 7 days',space:'System volume free space',estimate:'Estimated reclaimable space',measured:'Measured folder groups',measurementNote:'Logical folder sizes are not promises of recoverable disk space. Application data, virtual disks and personal files are not junk. Partial scans are lower bounds.',all:'All categories',category:'Show category',cache:'Caches', 'app-data':'Application data','user-data':'Personal data',vm:'Virtual machines',system:'System data', 'unknown-category':'Unclassified',comparison:'Before and after',comparisonNote:'Observed free-space change can include activity outside Syrin clean.',before:'Before',after:'After',delta:'Observed change',proposals:'Proposals',proposalNote:'A report does not authorize changes. Review the files, consequences and plan reference; the agent executes only the items you confirm.',empty:'No data available.',history:'File operation history',historyNote:'Select stored items to ask your agent for a new restore plan. This page never executes commands.',restore:'Prepare restore request',details:'Collector details',pause:'Pause 3D',resume:'Enable 3D',scene:'Measured groups; use the table for exact values. Arrow keys or drag rotate the scene.',share:'Prepare a private-data-reduced export',request:'Request for your agent',copy:'Copy request',copied:'Copied.',manual:'Copy the text manually; clipboard access was unavailable.',footer:'Generated locally by Syrin clean. No automatic upload. Your agent/provider may process command output externally. Restore and purge have different consequences; review each plan.',incomplete:'Collectors not fully measured: ',legacy:'Legacy data is unverified. New audits use explicit categories and collector status.',shared:'Aggregate-only export: raw paths, commands, names and history were omitted. Review before sharing.',limited:'Only the first items are shown. Ask the agent for the complete session list.',beforeApproval:'Create a plan only; do not execute it until I confirm the exact plan and item IDs.'},
  vi:{report:'Báo cáo chỉ đọc',pc:'Máy tính này',summary:'Số liệu và mức độ tin cậy',unknown:'Chưa đo được',partial:'Chưa đầy đủ hoặc chưa xác minh',complete:'Đã đo',startup:'Mục khởi động đang bật',events:'Lỗi nghiêm trọng trong 7 ngày',space:'Ổ hệ thống còn trống',estimate:'Dung lượng thu hồi ước tính',measured:'Các nhóm thư mục đã đo',measurementNote:'Kích thước logic của thư mục không phải cam kết dung lượng sẽ giải phóng. Dữ liệu ứng dụng, ổ máy ảo và file cá nhân không phải rác. Số đo chưa đầy đủ chỉ là mức tối thiểu đã thấy.',all:'Tất cả nhóm',category:'Hiển thị nhóm',cache:'Bộ đệm','app-data':'Dữ liệu ứng dụng','user-data':'Dữ liệu cá nhân',vm:'Máy ảo',system:'Dữ liệu hệ thống','unknown-category':'Chưa phân loại',comparison:'Trước và sau',comparisonNote:'Thay đổi dung lượng trống có thể gồm hoạt động ngoài Syrin clean.',before:'Trước',after:'Sau',delta:'Thay đổi quan sát được',proposals:'Đề xuất',proposalNote:'Báo cáo không cấp quyền thay đổi. Xem file, hậu quả và mã kế hoạch; agent chỉ thực thi đúng các mục bạn xác nhận.',empty:'Chưa có dữ liệu.',history:'Lịch sử thao tác file',historyNote:'Chọn mục đang lưu để nhờ agent lập kế hoạch khôi phục mới. Trang này không thực thi lệnh.',restore:'Tạo yêu cầu khôi phục',details:'Chi tiết bộ thu thập',pause:'Tạm dừng 3D',resume:'Bật 3D',scene:'Các nhóm đã đo; xem bảng để biết số chính xác. Dùng phím mũi tên hoặc kéo để xoay.',share:'Tạo yêu cầu xuất bản đã lược thông tin riêng',request:'Yêu cầu gửi agent',copy:'Sao chép yêu cầu',copied:'Đã sao chép.',manual:'Hãy sao chép phần chữ; trình duyệt chưa cho truy cập clipboard.',footer:'Syrin clean tạo báo cáo cục bộ, không tự upload. Agent/nhà cung cấp có thể xử lý đầu ra lệnh ngoài máy. Khôi phục và xóa hẳn có hậu quả khác nhau; hãy xem từng kế hoạch.',incomplete:'Các bộ thu thập chưa đo đầy đủ: ',legacy:'Dữ liệu cũ chưa được xác minh. Lần kiểm tra mới có phân loại và trạng thái đo rõ ràng.',shared:'Bản chỉ gồm số tổng hợp: đã bỏ đường dẫn, lệnh, tên riêng và lịch sử thô. Xem lại trước khi chia sẻ.',limited:'Chỉ hiện các mục đầu tiên. Nhờ agent liệt kê đầy đủ phiên để chọn tiếp.',beforeApproval:'Chỉ lập kế hoạch; chưa thực thi cho đến khi tôi xác nhận đúng kế hoạch và ID.'}
};

export function formatBytes(value,lang='en') {return number(value)===null ? copy[lang].unknown : (value/2**30).toLocaleString(lang==='vi'?'vi-VN':'en-US',{maximumFractionDigits:2})+' GB';}

Object.assign(copy.en,{memory:'Available memory',defender:'Defender real-time protection',on:'Active',off:'Not active',securityNote:'Defender status only; other security software may be active.'});
Object.assign(copy.vi,{memory:'Bộ nhớ còn dùng được',defender:'Bảo vệ thời gian thực của Defender',on:'Đang bật',off:'Chưa bật',securityNote:'Đây là trạng thái Defender; có thể đang dùng phần mềm bảo mật khác.'});

Object.assign(copy.en,{
  collectorNames:{system:'System',volumes:'Volumes',memory:'Memory',startup:'Startup',events:'Event log',security:'Defender',cpu:'Processor',gpu:'Graphics',ram:'RAM modules',disks:'Physical disks',diskHealth:'Disk health',power:'Power plan',battery:'Battery',restorePoints:'Restore points',processes:'Processes',tasks:'Startup tasks',services:'Services',apps:'Applications',radar:'Storage groups',largeFiles:'Large files'},
  states:{planned:'Planned',moving:'Transfer needs reconciliation',quarantined:'In quarantine',restoring:'Restore needs reconciliation',restored:'Restored',conflict:'Name conflict',failed:'Needs attention',purging:'Purge needs reconciliation',purged:'Permanently deleted'},
  qualities:{complete:'Measured',partial:'Partial',unavailable:'Unavailable',failed:'Failed'},
  proposalColumns:{id:'Code',title:'Action',evidence:'Evidence',benefit:'Expected benefit',loss:'What you lose',risk:'Review level',undo:'Recovery'},
  risks:{low:'Low',review:'Review carefully',high:'High'},
  undoLabels:{reversible:'While recovery data remains intact',partial:'Partial',irreversible:'Cannot be undone','not-applicable':'Not applicable'}
});
Object.assign(copy.vi,{
  collectorNames:{system:'Hệ thống',volumes:'Các ổ đĩa',memory:'Bộ nhớ',startup:'Khởi động',events:'Nhật ký lỗi',security:'Defender',cpu:'Bộ xử lý',gpu:'Đồ họa',ram:'Thanh RAM',disks:'Ổ vật lý',diskHealth:'Sức khỏe ổ',power:'Chế độ nguồn',battery:'Pin',restorePoints:'Điểm khôi phục',processes:'Tiến trình',tasks:'Tác vụ khởi động',services:'Dịch vụ',apps:'Ứng dụng',radar:'Nhóm dung lượng',largeFiles:'File lớn'},
  states:{planned:'Đã lập kế hoạch',moving:'Đang chuyển, cần đối chiếu',quarantined:'Đang cách ly',restoring:'Đang khôi phục, cần đối chiếu',restored:'Đã khôi phục',conflict:'Trùng tên',failed:'Cần xử lý lỗi',purging:'Đang xóa hẳn, cần đối chiếu',purged:'Đã xóa hẳn'},
  qualities:{complete:'Đã đo',partial:'Chưa đầy đủ',unavailable:'Chưa khả dụng',failed:'Có lỗi'},
  proposalColumns:{id:'Mã',title:'Việc làm',evidence:'Bằng chứng',benefit:'Bạn được gì',loss:'Bạn mất gì',risk:'Mức cần xem xét',undo:'Khôi phục'},
  risks:{low:'Thấp',review:'Cần xem kỹ',high:'Cao'},
  undoLabels:{reversible:'Khi file và journal còn nguyên',partial:'Một phần',irreversible:'Không hoàn tác được','not-applicable':'Không áp dụng'}
});
function localDate(value,lang){const date=new Date(value);return Number.isNaN(date.getTime())?String(value||''):date.toLocaleString(lang==='vi'?'vi-VN':'en-US');}

function renderScene(canvas,rows,button,T){
  const context=canvas.getContext('2d'); if(!context){button.disabled=true;return}
  const media=matchMedia('(prefers-reduced-motion: reduce)');let enabled=!media.matches,visible=false,frame=0,rotation=.4,drag=false,lastX=0,width=0,height=0;
  const palette={cache:'#5ce0ac','app-data':'#94bfff','user-data':'#ffd17b',vm:'#c8a4ff',system:'#a8b9af',unknown:'#ff9e9e'};
  const budget=innerWidth<700?500:1000;const sum=rows.reduce((n,x)=>n+x.measuredBytes,0)||1;
  const points=[];let seed=7;const random=()=>{seed=seed*16807%2147483647;return(seed-1)/2147483646};
  rows.forEach((row,i)=>{const angle=i*2.399963,y=1-2*(i+.5)/Math.max(1,rows.length),radius=Math.sqrt(1-y*y),count=Math.max(8,Math.round(budget*row.measuredBytes/sum));for(let j=0;j<count && points.length<budget;j++){const a=random()*Math.PI*2,r=Math.cbrt(random())*.18;points.push([Math.cos(angle)*radius+r*Math.cos(a),y+r*(random()-.5),Math.sin(angle)*radius+r*Math.sin(a),palette[row.category]])}});
  function draw(){const dpr=Math.min(devicePixelRatio||1,2);context.setTransform(dpr,0,0,dpr,0,0);context.clearRect(0,0,width,height);const c=Math.cos(rotation),s=Math.sin(rotation);const projected=points.map(([x,y,z,color])=>{const xx=x*c-z*s,zz=x*s+z*c,k=2.8/(2.8+zz);return{x:width/2+xx*Math.min(width,height)*.32*k,y:height/2+y*Math.min(width,height)*.32*k,z:zz,k,color}}).sort((a,b)=>b.z-a.z);for(const p of projected){context.globalAlpha=.35+.6*(1-(p.z+1.3)/2.6);context.fillStyle=p.color;context.fillRect(p.x,p.y,Math.max(1.5,2*p.k),Math.max(1.5,2*p.k))}context.globalAlpha=1}
  function tick(){frame=0;if(!visible||document.hidden)return;if(enabled&&!drag)rotation+=.003;draw();if(enabled&&!media.matches)frame=requestAnimationFrame(tick)}
  function update(){button.textContent=enabled?T.pause:T.resume;button.setAttribute('aria-pressed',String(enabled));if(frame){cancelAnimationFrame(frame);frame=0}if(visible&&!document.hidden){draw();if(enabled&&!media.matches)frame=requestAnimationFrame(tick)}}
  function resize(){width=canvas.clientWidth;height=canvas.clientHeight;const dpr=Math.min(devicePixelRatio||1,2);canvas.width=width*dpr;canvas.height=height*dpr;update()}
  new IntersectionObserver(entries=>{visible=entries[0].isIntersecting;update()}).observe(canvas);
  button.addEventListener('click',()=>{enabled=!enabled;update()});document.addEventListener('visibilitychange',update);media.addEventListener('change',()=>{enabled=!media.matches;update()});window.addEventListener('resize',resize);
  canvas.addEventListener('pointerdown',e=>{drag=true;lastX=e.clientX;canvas.setPointerCapture(e.pointerId)});canvas.addEventListener('pointermove',e=>{if(drag){rotation+=(e.clientX-lastX)*.008;lastX=e.clientX;draw()}});canvas.addEventListener('pointerup',()=>{drag=false});canvas.addEventListener('pointercancel',()=>{drag=false});canvas.addEventListener('keydown',e=>{if(['ArrowLeft','ArrowRight'].includes(e.key)){e.preventDefault();rotation+=(e.key==='ArrowLeft'?-.12:.12);draw()}});resize();
}

function renderReport(payload){
  const lang=payload.language==='vi'?'vi':'en',T=copy[lang],$=id=>document.getElementById(id),esc=escapeHtml;
  document.documentElement.lang=lang;
  const view=createView(payload.audit,payload.baseline);const gb=n=>formatBytes(n,lang);
  const labels={'subtitle':'report','summary-title':'summary','measurements-title':'measured','measurement-note':'measurementNote','category-label':'category','comparison-title':'comparison','comparison-note':'comparisonNote','proposals-title':'proposals','proposal-note':'proposalNote','history-title':'history','history-note':'historyNote','details-title':'details','scene-note':'scene','share':'share','request-title':'request','copy-request':'copy','history-link':'history','footer':'footer'};
  for(const[id,key]of Object.entries(labels))$(id).textContent=T[key];
  $('top').textContent=view.system.model||T.pc;
  $('identity').textContent=[view.system.windows,view.system.edition,view.system.architecture,localDate(view.audit.meta.generatedUtc,lang)].filter(Boolean).join(' · ');
  const messages=lang==='vi'?{'agent-privacy':'Agent hoặc nhà cung cấp có thể xử lý đầu ra lệnh ngoài máy.','support-unverified':'Các cấu hình, filesystem và provider chưa thử vẫn chưa được xác minh.'}:{'agent-privacy':'Your agent/provider may process command output outside this device.','support-unverified':'Untested configurations, filesystems and providers remain unverified.'};
  const warnings=[...list(view.audit.meta.warnings),...list(view.audit.meta.warningCodes).map(code=>messages[code]).filter(Boolean)];if(view.audit.legacy)warnings.unshift(T.legacy);if(payload.shared)warnings.unshift(T.shared);if(view.incomplete.length)warnings.push(T.incomplete+view.incomplete.map(name=>T.collectorNames[name]||name).join(', '));$('notice').textContent=warnings.join('\n');
  const fact=(title,value,quality,detail='')=>'<div class="fact" data-quality="'+esc(quality)+'"><b>'+esc(title)+'</b><strong>'+esc(value)+'</strong><small>'+esc(detail|| (quality==='complete'?T.complete:T.partial))+'</small></div>';
  $('facts').innerHTML=fact(T.space,view.systemVolume?view.systemVolume.drive+' '+gb(view.systemVolume.freeBytes):T.unknown,view.systemVolume?view.collector('volumes').status:'unavailable')+fact(T.startup,view.startupCount??T.unknown,view.startupCount===null?'unavailable':'complete',view.unknownStartup?view.unknownStartup+' '+T.unknown:'')+fact(T.events,view.eventCount??T.unknown,view.eventCount===null?'unavailable':view.collector('events').status)+fact(T.estimate,gb(view.reclaimable),view.reclaimable===null?'unavailable':'complete');
  $('facts').innerHTML+=fact(T.memory,gb(view.memoryAvailable),view.memoryAvailable===null?'unavailable':view.collector('memory').status)+fact(T.defender,view.defender===null?T.unknown:view.defender?T.on:T.off,view.defender===null?'unavailable':view.collector('security').status,T.securityNote);
  $('category').innerHTML='<option value="all">'+T.all+'</option>'+categories.map(c=>'<option value="'+c+'">'+esc(T[c==='unknown'?'unknown-category':c])+'</option>').join('');
  function showRadar(){const chosen=$('category').value;const rows=view.radar.filter(x=>chosen==='all'||x.category===chosen);$('radar').innerHTML=rows.length?rows.map(x=>'<div class="radar-row"><div><b>'+esc(x.label)+'</b><small>'+esc(T[x.category==='unknown'?'unknown-category':x.category])+' · '+esc(x.status==='complete'?T.complete:T.partial)+'</small></div><span>'+esc(gb(x.measuredBytes))+'</span></div>').join(''):'<p>'+T.empty+'</p>'}
  $('category').addEventListener('change',showRadar);showRadar();
  if(payload.mode==='3d'&&view.radar.length){$('cloud').setAttribute('aria-label',T.scene);renderScene($('cloud'),view.radar,$('motion'),T)}else{$('scene').hidden=true;$('motion').hidden=true}
  if(view.comparison){$('comparison-section').hidden=false;const c=view.comparison;$('comparison').innerHTML=fact(T.before,gb(c.before),'complete')+fact(T.after,gb(c.after),'complete')+fact(T.delta,(c.delta>=0?'+':'−')+gb(Math.abs(c.delta)),'complete')}
  function table(rows,columns){if(!rows.length)return '<p>'+T.empty+'</p>';const keys=columns||Object.keys(rows[0]);return '<div class="table-wrap"><table><thead><tr>'+keys.map(k=>'<th scope="col">'+esc(k)+'</th>').join('')+'</tr></thead><tbody>'+rows.slice(0,200).map(row=>'<tr>'+keys.map(k=>'<td>'+esc(typeof row[k]==='object'?JSON.stringify(row[k]):row[k]??T.unknown)+'</td>').join('')+'</tr>').join('')+'</tbody></table></div>'+(rows.length>200?'<p>'+T.limited+'</p>':'')}
  const proposalRows=list(payload.proposals?.items).map(item=>{if(payload.proposals.schemaVersion!==1)return item;const row={};for(const[key,label]of Object.entries(T.proposalColumns))row[label]=key==='risk'?(T.risks[item[key]]||item[key]):key==='undo'?(T.undoLabels[item[key]]||item[key]):item[key];return row});
  $('proposals').innerHTML=table(proposalRows);
  $('details').innerHTML=Object.entries(view.audit.collectors).map(([name,c])=>'<details><summary>'+esc(T.collectorNames[name]||name)+' · '+esc(T.qualities[c.status]||c.status)+'</summary><p class="errors">'+esc(list(c.errors).join('\n'))+'</p>'+table(list(c.data))+'</details>').join('');
  function request(action){$('request').value=T.beforeApproval+'\n'+JSON.stringify(action,null,2);$('request-section').hidden=false;$('request').focus();$('request-status').textContent=''}
  $('sessions').textContent='';
  for(const session of list(payload.history)){
    const box=document.createElement('div');box.className='session';const heading=document.createElement('h3');heading.textContent=localDate(session.createdUtc,lang)||session.sessionId;box.appendChild(heading);
    const identity=document.createElement('code');identity.textContent=session.sessionId.slice(0,12);identity.title=session.sessionId;box.appendChild(identity);
    if(!session.ok){const error=document.createElement('p');error.textContent=session.error;box.appendChild(error);$('sessions').appendChild(box);continue}
    const selected=[];
    for(const item of list(session.items)){
      const label=document.createElement('label');label.className='selection';const checkbox=document.createElement('input');checkbox.type='checkbox';checkbox.disabled=!['quarantined','conflict','failed'].includes(item.state);checkbox.addEventListener('change',()=>{const n=selected.indexOf(item.id);if(checkbox.checked&&n<0)selected.push(item.id);else if(n>=0)selected.splice(n,1)});const text=document.createElement('span');text.textContent=(item.code?item.code+' · ':'')+(item.original||item.id)+' · '+(T.states[item.state]||item.state);label.append(checkbox,text);box.appendChild(label);
    }
    if(session.totalItems>list(session.items).length){const warning=document.createElement('p');warning.textContent=T.limited;box.appendChild(warning)}
    const button=document.createElement('button');button.type='button';button.textContent=T.restore;button.addEventListener('click',()=>{if(selected.length)request({operation:'restore',root:payload.historyRoot,sessionId:session.sessionId,itemIds:selected})});box.appendChild(button);$('sessions').appendChild(box);
  }
  if(!list(payload.history).length)$('sessions').textContent=T.empty;
  $('share').hidden=Boolean(payload.shared);$('share').addEventListener('click',()=>request({operation:'share-report',auditSessionId:view.audit.meta.sessionId,upload:false}));
  $('copy-request').addEventListener('click',async()=>{try{await navigator.clipboard.writeText($('request').value);$('request-status').textContent=T.copied}catch{$('request').select();$('request-status').textContent=T.manual}});
}

if(typeof document!=='undefined'){
  try{renderReport(JSON.parse(document.getElementById('syrin-data').textContent))}
  catch(error){document.getElementById('notice').textContent='Report could not be rendered: '+error.message;document.getElementById('top').textContent='Syrin clean';}
}
