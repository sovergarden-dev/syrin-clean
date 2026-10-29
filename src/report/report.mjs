import {createLens} from '../shared/lens.mjs';

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

export function formatBytes(value,lang='en') {return number(value)===null ? copy[lang].unknown : (value/2**30).toLocaleString(lang==='vi'?'vi-VN':'en-US',{maximumFractionDigits:2})+' GiB';}

export function historyPage(items,page=0,pageSize=50) {
  const rows=list(items),size=Number.isInteger(pageSize)&&pageSize>0?pageSize:50;
  const pages=Math.max(1,Math.ceil(rows.length/size));
  const current=Math.max(0,Math.min(Number.isInteger(page)?page:0,pages-1));
  const start=current*size,end=Math.min(start+size,rows.length);
  return {items:rows.slice(start,end),page:current,pages,total:rows.length,start,end};
}

Object.assign(copy.en,{chooseSession:'Choose a session',previousPage:'Previous files',nextPage:'Next files',page:'Page',files:'files',selected:'Selected',sessionCount:'Sessions',reducedMotion:'Motion is disabled by your system preference.'});
Object.assign(copy.vi,{chooseSession:'Chọn phiên',previousPage:'File trước',nextPage:'File tiếp',page:'Trang',files:'file',selected:'Đã chọn',sessionCount:'Số phiên',reducedMotion:'Hiệu ứng chuyển động đang tắt theo tùy chọn hệ thống.'});

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


Object.assign(copy.en, {
  summary:'At a glance',print:'Print summary',language:'Language',skip:'Skip to report',tools:'Report tools',fontCredits:'Font licenses',
  share:'Prepare shared export',chooseSession:'Choose a session',search:'Find a file',searchPlaceholder:'Path, code or item ID',stateFilter:'State',
  allStates:'All states',storedState:'In quarantine',attentionState:'Needs attention',plannedState:'Planned',restoredState:'Restored',purgedState:'Permanently deleted',
  clearSelection:'Clear selection',noMatches:'No files match these filters. Try another term or state.',noHistory:'No file operations are included in this report.',
  noProposals:'No proposals were included. Ask your agent to review the audit before preparing a plan.',
  noMeasurements:'No folder measurements are available. Ask your agent which collectors were skipped or incomplete.',
  pageStatus:'Page {page}/{pages}. Files {start}–{end} of {total}.',coverage:'{filtered} of {total} files match the current filters.',selectedCount:'Selected in this session: {count} files.',
  demo:'Example data. This report does not describe your PC.',examplePC:'Example PC',demoRequest:'This is a synthetic example. Do not execute it.',
  requestNote:'This text asks your agent to prepare a plan. It does not authorize execution.',printNote:'Printed summary only. The full file history and original collector records remain in the HTML report.',
  pause:'Pause animation',resume:'Resume animation',reduced:'Reduced motion',scene:'A spatial view of measured groups. Exact values are in the table. Drag or use the arrow keys to rotate.',
  empty:'No data was included.',measurementNote:'Logical folder sizes can overlap and are not a promise of recoverable space. Application data, virtual disks and personal files are not junk. Partial measurements are lower bounds.',
  footer:'Generated locally by Syrin clean. No automatic upload. Original records retain their source language. Your agent/provider has its own data boundary. Review a fresh plan before any file operation.'
});
Object.assign(copy.vi, {
  summary:'Tổng quan',print:'In tóm tắt',language:'Ngôn ngữ',skip:'Đến báo cáo',tools:'Công cụ báo cáo',fontCredits:'Giấy phép font',
  share:'Chuẩn bị bản chia sẻ',chooseSession:'Chọn phiên',search:'Tìm file',searchPlaceholder:'Đường dẫn, mã hoặc ID file',stateFilter:'Trạng thái',
  allStates:'Mọi trạng thái',storedState:'Đang cách ly',attentionState:'Cần xem xét',plannedState:'Đã lập kế hoạch',restoredState:'Đã khôi phục',purgedState:'Đã xóa hẳn',
  clearSelection:'Bỏ chọn',noMatches:'Không có file khớp bộ lọc. Thử từ khóa hoặc trạng thái khác.',noHistory:'Báo cáo này chưa có lịch sử thao tác file.',
  noProposals:'Chưa có đề xuất đi kèm. Nhờ agent xem báo cáo trước khi lập kế hoạch.',
  noMeasurements:'Chưa có số đo thư mục. Nhờ agent làm rõ bộ thu thập nào bị bỏ qua hoặc chưa hoàn tất.',
  pageStatus:'Trang {page}/{pages}. File {start}–{end} trên {total}.',coverage:'{filtered} trên {total} file khớp bộ lọc hiện tại.',selectedCount:'Đã chọn trong phiên: {count} file.',
  demo:'Dữ liệu minh họa. Báo cáo này không mô tả máy của bạn.',examplePC:'Máy minh họa',demoRequest:'Đây là ví dụ giả lập. Không thực thi.',
  requestNote:'Nội dung này nhờ agent lập kế hoạch, chưa cấp quyền thực thi.',printNote:'Bản in chỉ gồm tóm tắt. Lịch sử file đầy đủ và bản ghi thu thập gốc vẫn nằm trong HTML.',
  pause:'Tạm dừng hiệu ứng',resume:'Bật hiệu ứng',reduced:'Đã giảm chuyển động',scene:'Góc nhìn không gian của các nhóm đã đo. Số chính xác nằm trong bảng. Kéo hoặc dùng phím mũi tên để xoay.',
  empty:'Chưa có dữ liệu đi kèm.',measurementNote:'Kích thước logic có thể chồng lặp và không phải cam kết dung lượng thu hồi. Dữ liệu ứng dụng, ổ máy ảo và file cá nhân không phải rác. Số đo chưa đầy đủ là mức tối thiểu đã thấy.',
  footer:'Syrin clean tạo báo cáo cục bộ, không tự tải lên. Bản ghi gốc giữ nguyên ngôn ngữ nguồn. Agent/nhà cung cấp có ranh giới dữ liệu riêng. Xem kế hoạch mới trước mỗi thao tác file.'
});

export function filterHistoryItems(items, {query = '', state = 'all'} = {}) {
  const needle = String(query).trim().normalize('NFC').toLowerCase();
  const attention = ['moving','restoring','purging','conflict','failed'];
  return list(items).filter(item => {
    const matchesState = state === 'all' || (state === 'attention' ? attention.includes(item.state) : item.state === state);
    const text = [item.original,item.code,item.id].filter(Boolean).join(' ').normalize('NFC').toLowerCase();
    return matchesState && (!needle || text.includes(needle));
  });
}

const interpolate = (text, values) => text.replace(/\{(\w+)\}/g, (_, key) => String(values[key] ?? ''));

function renderReport(payload) {
  const $ = id => document.getElementById(id), esc = escapeHtml;
  const view = createView(payload.audit, payload.baseline);
  const sessions = list(payload.history);
  let language = payload.language === 'vi' ? 'vi' : 'en', T = copy[language], lens;
  const requested = new URLSearchParams(location.search || location.hash.slice(1)).get('lang');
  if (requested === 'en' || requested === 'vi') language = requested;
  const state = {session:0,page:0,query:'',filter:'all',category:'all',selections:new Map(),request:null};
  const gb = value => formatBytes(value, language);
  const empty = text => '<p class="empty-state">' + esc(text) + '</p>';
  function fact(title, value, quality, detail = '') {
    return '<div class="fact" data-quality="' + esc(quality) + '"><b>' + esc(title) + '</b><strong>' + esc(value) + '</strong><small>' + esc(detail || (quality === 'complete' ? T.complete : T.partial)) + '</small></div>';
  }
  function table(rows) {
    if (!rows.length) return empty(T.empty);
    const keys = Object.keys(rows[0]);
    return '<div class="table-wrap"><table><thead><tr>' + keys.map(key => '<th scope="col">' + esc(key) + '</th>').join('') + '</tr></thead><tbody>' + rows.slice(0,200).map(row => '<tr>' + keys.map(key => '<td>' + esc(typeof row[key] === 'object' ? JSON.stringify(row[key]) : row[key] ?? T.unknown) + '</td>').join('') + '</tr>').join('') + '</tbody></table></div>' + (rows.length > 200 ? '<p class="section-note">' + esc(T.limited) + '</p>' : '');
  }
  function renderRadar() {
    const rows = view.radar.filter(row => state.category === 'all' || row.category === state.category);
    const max = Math.max(1, ...view.radar.map(row => row.measuredBytes));
    $('radar').innerHTML = rows.length ? rows.map(row => {
      const label = payload.demo ? T[row.category === 'unknown' ? 'unknown-category' : row.category] : row.label;
      return '<div class="radar-row"><div><b>' + esc(label) + '</b><small>' + esc(T[row.category === 'unknown' ? 'unknown-category' : row.category]) + ', ' + esc(row.status === 'complete' ? T.complete : T.partial) + '</small></div><span class="radar-value">' + esc((row.status === 'complete' ? '' : '≥ ') + gb(row.measuredBytes)) + '</span><div class="measure-track" aria-hidden="true"><span style="--ratio:' + Math.min(1,row.measuredBytes/max) + '"></span></div></div>';
    }).join('') : empty(T.noMeasurements);
    lens?.setCategory(state.category);
  }
  function renderRequest(action, focus = true) {
    state.request = action;
    $('request').value = (payload.demo ? T.demoRequest : T.beforeApproval) + '\n' + JSON.stringify(action, null, 2);
    $('request-section').hidden = false; $('request-status').textContent = '';
    if (focus) $('request').focus();
  }
  function renderHistory() {
    const host = $('sessions'); host.textContent = '';
    $('history-tools').hidden = !sessions.length;
    if (!sessions.length) { host.innerHTML = empty(T.noHistory); return; }
    const session = sessions[state.session], box = document.createElement('div'); box.className = 'session';
    const header = document.createElement('div'); header.className = 'session-header';
    const identity = document.createElement('div'), code = document.createElement('code'); code.textContent = session.sessionId; identity.append(code); header.append(identity); box.append(header); host.append(box);
    if (!session.ok) { const error = document.createElement('p'); error.className = 'errors'; error.textContent = session.error; box.append(error); return; }
    if (!state.selections.has(session.sessionId)) state.selections.set(session.sessionId, new Set());
    const selected = state.selections.get(session.sessionId), source = list(session.items);
    const filtered = filterHistoryItems(source, {query:state.query,state:state.filter}), page = historyPage(filtered,state.page); state.page = page.page;
    const pageText = document.createElement('p'); pageText.className = 'history-page'; pageText.setAttribute('role','status'); pageText.setAttribute('aria-live','polite');
    pageText.textContent = interpolate(T.pageStatus,{page:page.page+1,pages:page.pages,start:page.total?page.start+1:0,end:page.end,total:page.total}); identity.append(pageText);
    const coverage = document.createElement('p'); coverage.className = 'history-page'; coverage.textContent = interpolate(T.coverage,{filtered:filtered.length,total:source.length}); identity.append(coverage);
    const selectedText = document.createElement('p'); selectedText.className = 'selection-summary'; selectedText.setAttribute('role','status'); selectedText.setAttribute('aria-live','polite'); header.append(selectedText);
    const restore = document.createElement('button'); restore.className = 'button button-primary'; restore.type = 'button'; restore.id = 'restore-request'; restore.textContent = T.restore;
    const clear = document.createElement('button'); clear.type = 'button'; clear.className = 'button button-quiet'; clear.textContent = T.clearSelection;
    function updateSelection() { selectedText.textContent = interpolate(T.selectedCount,{count:selected.size}); restore.disabled = selected.size === 0; clear.disabled = selected.size === 0; }
    for (const item of page.items) {
      const row = document.createElement('label'); row.className = 'selection';
      const checkbox = document.createElement('input'); checkbox.type = 'checkbox'; checkbox.dataset.itemId = item.id;
      checkbox.disabled = !['quarantined','conflict','failed'].includes(item.state) || !/^[a-f0-9]{32}$/.test(item.id || '');
      checkbox.checked = selected.has(item.id);
      checkbox.addEventListener('change', () => { if (checkbox.checked) selected.add(item.id); else selected.delete(item.id); updateSelection(); });
      const text = document.createElement('span'), itemCode = document.createElement('b'), original = document.createTextNode(item.original || item.id), itemState = document.createElement('small');
      itemCode.textContent = item.code || ''; itemState.textContent = T.states[item.state] || item.state; text.append(itemCode, original, itemState); row.append(checkbox, text); box.append(row);
    }
    if (!page.items.length) { const message = document.createElement('p'); message.className = 'empty-state'; message.textContent = T.noMatches; box.append(message); }
    const navigation = document.createElement('div'); navigation.className = 'history-navigation';
    const pageButtons = document.createElement('div'); pageButtons.className = 'toolbar';
    for (const [delta,id,label,disabled] of [[-1,'history-prev',T.previousPage,page.page === 0],[1,'history-next',T.nextPage,page.page+1 >= page.pages]]) {
      const button = document.createElement('button'); button.type = 'button'; button.id = id; button.className = 'button button-secondary'; button.textContent = label; button.disabled = disabled;
      button.addEventListener('click', () => { state.page += delta; renderHistory(); const target = $(id); if (target.disabled) $('history-session').focus(); else target.focus(); }); pageButtons.append(button);
    }
    const selectionButtons = document.createElement('div'); selectionButtons.className = 'toolbar';
    clear.addEventListener('click', () => { selected.clear(); renderHistory(); $('history-search').focus(); });
    restore.addEventListener('click', () => { if (selected.size) renderRequest({operation:'restore',root:payload.historyRoot,sessionId:session.sessionId,itemIds:[...selected]}); });
    selectionButtons.append(clear,restore); navigation.append(pageButtons,selectionButtons); box.append(navigation);
    if (session.totalItems > source.length) { const warning = document.createElement('p'); warning.className = 'notice'; warning.textContent = T.limited; box.append(warning); }
    updateSelection();
  }
  function renderAll() {
    T = copy[language]; document.documentElement.lang = language; $('report-language').value = language;
    document.title = 'Syrin clean | ' + (payload.demo ? T.examplePC : view.system.model || T.pc);
    const labels = {'skip-report':'skip','language-label':'language','subtitle':'report','summary-title':'summary','measurements-title':'measured','measurement-note':'measurementNote','category-label':'category','comparison-title':'comparison','comparison-note':'comparisonNote','proposals-title':'proposals','proposal-note':'proposalNote','history-title':'history','history-note':'historyNote','details-title':'details','scene-note':'scene','share':'share','request-title':'request','request-note':'requestNote','copy-request':'copy','history-link':'history','print-report':'print','print-note':'printNote','font-credits-title':'fontCredits','session-label':'chooseSession','search-label':'search','state-label':'stateFilter','footer':'footer'};
    for (const [id,key] of Object.entries(labels)) $(id).textContent = T[key];
    $('session-label').textContent = T.chooseSession + ' (' + sessions.length + ')';
    $('report-tools').setAttribute('aria-label',T.tools); $('request').setAttribute('aria-label',T.request); $('cloud').setAttribute('aria-label',T.scene); $('history-search').placeholder = T.searchPlaceholder;
    $('top').textContent = payload.demo ? T.examplePC : view.system.model || T.pc;
    $('identity').textContent = [view.system.windows,view.system.edition,view.system.architecture,localDate(view.audit.meta.generatedUtc,language)].filter(Boolean).join(', ');
    $('demo-banner').hidden = !payload.demo; $('demo-banner').textContent = T.demo;
    const warningText = language === 'vi' ? {'agent-privacy':'Agent hoặc nhà cung cấp có thể xử lý đầu ra lệnh ngoài máy.','support-unverified':'Cấu hình, filesystem và provider chưa thử vẫn chưa được xác minh.'} : {'agent-privacy':'Your agent/provider may process command output outside this device.','support-unverified':'Untested configurations, filesystems and providers remain unverified.'};
    const warnings = [...list(view.audit.meta.warnings), ...list(view.audit.meta.warningCodes).map(code => warningText[code]).filter(Boolean)];
    if (view.audit.legacy) warnings.unshift(T.legacy);
    if (payload.shared) warnings.unshift(T.shared);
    if (view.incomplete.length) warnings.push(T.incomplete + view.incomplete.map(name => T.collectorNames[name] || name).join(', '));
    $('notice').textContent = warnings.join('\n');
    $('facts').innerHTML = fact(T.space,view.systemVolume ? view.systemVolume.drive + ' ' + gb(view.systemVolume.freeBytes) : T.unknown,view.systemVolume ? view.collector('volumes').status : 'unavailable') +
      fact(T.memory,gb(view.memoryAvailable),view.memoryAvailable === null ? 'unavailable' : view.collector('memory').status) +
      fact(T.estimate,gb(view.reclaimable),view.reclaimable === null ? 'unavailable' : 'complete') +
      fact(T.startup,view.startupCount ?? T.unknown,view.startupCount === null ? 'unavailable' : 'complete',view.unknownStartup ? view.unknownStartup + ' ' + T.unknown : '') +
      fact(T.events,view.eventCount ?? T.unknown,view.eventCount === null ? 'unavailable' : view.collector('events').status) +
      fact(T.defender,view.defender === null ? T.unknown : view.defender ? T.on : T.off,view.defender === null ? 'unavailable' : view.collector('security').status,T.securityNote);
    $('category').innerHTML = '<option value="all">' + esc(T.all) + '</option>' + categories.map(category => '<option value="' + category + '">' + esc(T[category === 'unknown' ? 'unknown-category' : category]) + '</option>').join('');
    $('category').value = state.category; renderRadar();
    $('scene').hidden = payload.mode !== '3d' || !view.radar.some(row => row.measuredBytes > 0);
    $('comparison-section').hidden = !view.comparison;
    if (view.comparison) { const comparison = view.comparison; $('comparison').innerHTML = fact(T.before,gb(comparison.before),'complete') + fact(T.after,gb(comparison.after),'complete') + fact(T.delta,(comparison.delta >= 0 ? '+' : '−') + gb(Math.abs(comparison.delta)),'complete'); }
    const proposals = list(payload.proposals?.items).map(item => {
      if (payload.proposals.schemaVersion !== 1) return item;
      return Object.fromEntries(Object.entries(T.proposalColumns).map(([key,label]) => [label,key === 'risk' ? T.risks[item[key]] || item[key] : key === 'undo' ? T.undoLabels[item[key]] || item[key] : item[key]]));
    });
    $('proposals').innerHTML = proposals.length ? table(proposals) : empty(T.noProposals);
    $('details').innerHTML = Object.entries(view.audit.collectors).map(([name,collector]) => '<details><summary>' + esc(T.collectorNames[name] || name) + ': ' + esc(T.qualities[collector.status] || collector.status) + '</summary><p class="errors">' + esc(list(collector.errors).join('\n')) + '</p>' + table(list(collector.data)) + '</details>').join('');
    $('history-session').textContent = '';
    sessions.forEach((session,index) => { const option = document.createElement('option'); option.value = String(index); option.textContent = (index+1) + '. ' + localDate(session.createdUtc,language) + ' / ' + String(session.sessionId).slice(0,12); $('history-session').append(option); });
    $('history-session').value = String(state.session);
    $('history-state').innerHTML = [['all','allStates'],['quarantined','storedState'],['attention','attentionState'],['planned','plannedState'],['restored','restoredState'],['purged','purgedState']].map(([value,label]) => '<option value="' + value + '">' + esc(T[label]) + '</option>').join('');
    $('history-state').value = state.filter;
    $('share').hidden = Boolean(payload.shared); $('history').hidden = Boolean(payload.shared); $('history-link').hidden = Boolean(payload.shared);
    renderHistory(); if (state.request) renderRequest(state.request,false); lens?.refresh();
  }
  $('report-language').addEventListener('change', () => { language = $('report-language').value === 'vi' ? 'vi' : 'en'; renderAll(); });
  $('category').addEventListener('change', () => { state.category = $('category').value; renderRadar(); });
  $('history-session').addEventListener('change', () => { state.session = Number($('history-session').value); state.page = 0; renderHistory(); });
  $('history-search').addEventListener('input', () => { state.query = $('history-search').value; state.page = 0; renderHistory(); });
  $('history-state').addEventListener('change', () => { state.filter = $('history-state').value; state.page = 0; renderHistory(); });
  $('share').addEventListener('click', () => renderRequest({operation:'share-report',auditSessionId:view.audit.meta.sessionId,upload:false}));
  $('print-report').addEventListener('click', () => window.print());
  $('copy-request').addEventListener('click', async () => { try { await navigator.clipboard.writeText($('request').value); $('request-status').textContent = T.copied; } catch { $('request').select(); $('request-status').textContent = T.manual; } });
  renderAll();
  if (!$('scene').hidden) lens = createLens($('cloud'),{rows:view.radar,button:$('motion'),labels:() => T});
}

if (typeof document !== 'undefined') {
  try { renderReport(JSON.parse(document.getElementById('syrin-data').textContent)); }
  catch (error) { document.getElementById('notice').textContent = 'Report could not be rendered. Ask your agent to regenerate it. ' + error.message; document.getElementById('top').textContent = 'Syrin clean'; console.error(error); }
}
