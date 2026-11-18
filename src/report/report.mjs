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
  const platform=audit.meta.platform || 'windows';
  if(!['windows','android'].includes(platform)) throw Error('Unsupported audit platform');
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
  const storage=first(collector('storage').data),battery=first(collector('battery').data),performance=first(collector('performance').data);
  let comparison=null,performanceComparison=null;
  if(baseline){
    const before=normalizeAudit(baseline);
    if(!audit.meta.machineId || before.meta.machineId!==audit.meta.machineId || before.legacy || audit.legacy) throw Error('Baseline machine or schema mismatch');
    if((before.meta.platform || 'windows')!==platform) throw Error('Baseline platform mismatch');
    const previous=list(before.collectors.volumes?.data).find(x=>systemVolume?.volumeId && x.volumeId===systemVolume.volumeId);
    if(previous && number(previous.freeBytes)!==null && number(systemVolume.freeBytes)!==null && collector('volumes').status==='complete' && before.collectors.volumes.status==='complete') comparison={before:previous.freeBytes,after:systemVolume.freeBytes,delta:systemVolume.freeBytes-previous.freeBytes};
    const old=first(before.collectors.performance?.data);
    if(collector('performance').status==='complete' && before.collectors.performance?.status==='complete' && performance.contextLabel && old.contextLabel===performance.contextLabel && old.method===performance.method && old.requestedSeconds===performance.requestedSeconds && old.intervalSeconds===performance.intervalSeconds && old.sampleCount>=2 && performance.sampleCount>=2 && number(old.meanCpuPercent)!==null && number(performance.meanCpuPercent)!==null && Date.parse(audit.meta.generatedUtc)>Date.parse(before.meta.generatedUtc)) performanceComparison={before:old.meanCpuPercent,after:performance.meanCpuPercent,delta:performance.meanCpuPercent-old.meanCpuPercent};
  }
  const memoryAvailable=number(first(collector('memory').data).availableBytes);
  const security=first(collector('security').data),defender=typeof security.realTimeProtection==='boolean'?security.realTimeProtection:null;
  return {audit,platform,storage,battery,performance,performanceComparison,collector,system:first(collector('system').data),systemVolume,radar,totals,startupCount,unknownStartup,eventCount,reclaimable,memoryAvailable,defender,comparison,incomplete:Object.entries(audit.collectors).filter(([,x])=>x.status!=='complete').map(([k])=>k)};
}

export function measurementAge(meta,now=Date.now()) {
  if(meta.shared) return null;
  const captured=Date.parse(meta.generatedUtc);
  return Number.isFinite(captured) && captured<=now ? Math.floor((now-captured)/60000) : null;
}

export function canRequestPurge(session, selectedIds) {
  const ids = list(selectedIds);
  if (!ids.length || !session || !session.ok || session.operation === 'import') return false;
  const byId = new Map(list(session.items).map(item => [item.id, item]));
  return ids.every(id => /^[a-f0-9]{32}$/.test(String(id)) && byId.get(id)?.state === 'quarantined');
}

const copy={
  en:{
    report:'Read-only report',pc:'This PC',summary:'At a glance',unknown:'Not measured',partial:'Partial or unverified',complete:'Measured',
    startup:'Enabled startup items',events:'Critical errors in 7 days',space:'System volume free space',estimate:'Estimated reclaimable space',
    measured:'Measured folder groups',
    measurementNote:'Logical folder sizes can overlap and are not a promise of recoverable space. Application data, virtual disks and personal files are not junk. Partial measurements are lower bounds.',
    all:'All categories',category:'Show category',cache:'Caches','app-data':'Application data','user-data':'Personal data',vm:'Virtual machines',system:'System data','unknown-category':'Unclassified',
    comparison:'Before and after',comparisonNote:'Observed free-space change can include activity outside Syrin clean.',before:'Before',after:'After',delta:'Observed change',
    proposals:'Proposals',proposalNote:'A report does not authorize changes. Review the files, consequences and plan reference; the agent executes only the items you confirm.',
    empty:'No data was included.',history:'File operation history',
    historyNote:'Select stored items to ask your agent for a restore plan, or choose intact quarantined items to request a separate irreversible purge plan. This page never executes commands.',
    restore:'Prepare restore request',purge:'Prepare permanent delete request',details:'Collector details',
    pause:'Pause animation',resume:'Resume animation',reduced:'Reduced motion',
    scene:'A spatial view of measured groups. Exact values are in the table. Drag or use the arrow keys to rotate.',
    share:'Prepare shared export',request:'Request for your agent',copy:'Copy request',copied:'Copied.',
    manual:'Copy the text manually; clipboard access was unavailable.',
    footer:'Generated locally by Syrin clean. No automatic upload. Original records retain their source language. Your agent/provider has its own data boundary. Review a fresh plan before any file operation.',
    incomplete:'Collectors not fully measured: ',
    legacy:'Legacy data is unverified. New audits use explicit categories and collector status.',
    shared:'Aggregate-only export: raw paths, commands, names and history were omitted. Review before sharing.',
    limited:'Only the first items are shown. Ask the agent for the complete session list.',
    beforeApproval:'Create a plan only; do not execute it until I confirm the exact plan and item IDs.',
    purgeApproval:'Irreversible permanent deletion: create a separate purge plan only; do not execute it until I confirm the exact P-codes and plan digest.',
    chooseSession:'Choose a session',previousPage:'Previous files',nextPage:'Next files',page:'Page',files:'files',selected:'Selected',sessionCount:'Sessions',
    reducedMotion:'Motion is disabled by your system preference.',
    memory:'Available memory',defender:'Defender real-time protection',on:'Active',off:'Not active',securityNote:'Defender status only; other security software may be active.',
    print:'Print summary',language:'Language',skip:'Skip to report',tools:'Report tools',fontCredits:'Font licenses',
    search:'Find a file',searchPlaceholder:'Path, code or item ID',stateFilter:'State',
    allStates:'All states',storedState:'In quarantine',attentionState:'Needs attention',plannedState:'Planned',restoredState:'Restored',purgedState:'Permanently deleted',
    clearSelection:'Clear selection',noMatches:'No files match these filters. Try another term or state.',noHistory:'No file operations are included in this report.',
    noProposals:'No proposals were included. Ask your agent to review the audit before preparing a plan.',
    noMeasurements:'No folder measurements are available. Ask your agent which collectors were skipped or incomplete.',
    pageStatus:'Page {page}/{pages}. Files {start}-{end} of {total}.',coverage:'{filtered} of {total} files match the current filters.',selectedCount:'Selected in this session: {count} files.',
    demo:'Example data. This report does not describe your PC.',examplePC:'Example PC',demoRequest:'This is a synthetic example. Do not execute it.',
    requestNote:'This text asks your agent to prepare a plan. It does not authorize execution.',printNote:'Printed summary only. The full file history and original collector records remain in the HTML report.',
    phone:'Android phone',phoneSpace:'Phone storage free',charge:'Battery charge',temperature:'Battery temperature',
    androidNotice:'Android preview: USB diagnostics only. No app, setting or file changes. Package grades are not authorization; RAM or swap alone does not prove a cause of lag.',
    snapshot:'This is a saved snapshot. Rebuilding HTML does not collect new measurements.',age:'Minutes since capture',
    performance:'Performance over time',
    performanceNote:'CPU is normalized across logical processors. Process rows omit command lines and paths. Changes in workload, reboot, charging or temperature can explain differences; these measurements do not establish a speed-up.',
    cpuMean:'Average CPU',cpuPeak:'Peak CPU',sampleTime:'Sample time',cpu:'CPU',topProcess:'Highest sampled process',cpuDelta:'CPU change (percentage points)',
    recovery:'Recovery integrity is checked again when you request a plan.',
    appTitle:'App rendering observations',
    appNote:'Cumulative counters since the app counter started, plus optional two-point window deltas when sampled. Missing process or counter origin stays partial.',
    appTotal:'Recorded frames',appJanky:'Janky frames',appWindowFrames:'Window frames',appWindowJanky:'Window janky frames',appTask:'Described task',
    collectorNames:{system:'System',volumes:'Volumes',memory:'Memory',startup:'Startup',events:'Event log',security:'Defender',cpu:'Processor',gpu:'Graphics',ram:'RAM modules',disks:'Physical disks',diskHealth:'Disk health',power:'Power plan',battery:'Battery',restorePoints:'Restore points',processes:'Processes',tasks:'Startup tasks',services:'Services',apps:'Applications',radar:'Storage groups',hotspots:'Unclassified large folders',devArtifacts:'Stale build environments',largeFiles:'Large files',storage:'Phone storage',packages:'App inventory',appSizes:'App storage usage',thermal:'Thermal status',frames:'App frames',performance:'Performance samples'},
    states:{planned:'Planned',moving:'Transfer needs reconciliation',quarantined:'In quarantine',restoring:'Restore needs reconciliation',restored:'Restored',conflict:'Name conflict',failed:'Needs attention',purging:'Purge needs reconciliation',purged:'Permanently deleted'},
    qualities:{complete:'Measured',partial:'Partial',unavailable:'Unavailable',failed:'Failed'},
    proposalColumns:{id:'Code',title:'Action',evidence:'Evidence',benefit:'Expected benefit',loss:'What you lose',risk:'Review level',undo:'Recovery'},
    risks:{low:'Low',review:'Review carefully',high:'High'},
    undoLabels:{reversible:'While recovery data remains intact',partial:'Partial',irreversible:'Cannot be undone','not-applicable':'Not applicable'}
  },
  vi:{
    report:'Báo cáo chỉ đọc',pc:'Máy tính này',summary:'Tổng quan',unknown:'Chưa đo được',partial:'Chưa đầy đủ hoặc chưa xác minh',complete:'Đã đo',
    startup:'Mục khởi động đang bật',events:'Lỗi nghiêm trọng trong 7 ngày',space:'Ổ hệ thống còn trống',estimate:'Dung lượng thu hồi ước tính',
    measured:'Các nhóm thư mục đã đo',
    measurementNote:'Kích thước logic có thể chồng lặp và không phải cam kết dung lượng thu hồi. Dữ liệu ứng dụng, ổ máy ảo và file cá nhân không phải rác. Số đo chưa đầy đủ là mức tối thiểu đã thấy.',
    all:'Tất cả nhóm',category:'Hiển thị nhóm',cache:'Bộ đệm','app-data':'Dữ liệu ứng dụng','user-data':'Dữ liệu cá nhân',vm:'Máy ảo',system:'Dữ liệu hệ thống','unknown-category':'Chưa phân loại',
    comparison:'Trước và sau',comparisonNote:'Thay đổi dung lượng trống có thể gồm hoạt động ngoài Syrin clean.',before:'Trước',after:'Sau',delta:'Thay đổi quan sát được',
    proposals:'Đề xuất',proposalNote:'Báo cáo không cấp quyền thay đổi. Xem file, hậu quả và mã kế hoạch; agent chỉ thực thi đúng các mục bạn xác nhận.',
    empty:'Chưa có dữ liệu đi kèm.',history:'Lịch sử thao tác file',
    historyNote:'Chọn mục đang lưu để nhờ agent lập kế hoạch khôi phục, hoặc chọn các mục đang cách ly nguyên vẹn để yêu cầu kế hoạch xóa hẳn riêng (không hoàn tác được). Trang này không thực thi lệnh.',
    restore:'Tạo yêu cầu khôi phục',purge:'Tạo yêu cầu xóa hẳn',details:'Chi tiết bộ thu thập',
    pause:'Tạm dừng hiệu ứng',resume:'Bật hiệu ứng',reduced:'Đã giảm chuyển động',
    scene:'Góc nhìn không gian của các nhóm đã đo. Số chính xác nằm trong bảng. Kéo hoặc dùng phím mũi tên để xoay.',
    share:'Chuẩn bị bản chia sẻ',request:'Yêu cầu gửi agent',copy:'Sao chép yêu cầu',copied:'Đã sao chép.',
    manual:'Hãy sao chép phần chữ; trình duyệt chưa cho truy cập clipboard.',
    footer:'Syrin clean tạo báo cáo cục bộ, không tự tải lên. Bản ghi gốc giữ nguyên ngôn ngữ nguồn. Agent/nhà cung cấp có ranh giới dữ liệu riêng. Xem kế hoạch mới trước mỗi thao tác file.',
    incomplete:'Các bộ thu thập chưa đo đầy đủ: ',
    legacy:'Dữ liệu cũ chưa được xác minh. Lần kiểm tra mới có phân loại và trạng thái đo rõ ràng.',
    shared:'Bản chỉ gồm số tổng hợp: đã bỏ đường dẫn, lệnh, tên riêng và lịch sử thô. Xem lại trước khi chia sẻ.',
    limited:'Chỉ hiện các mục đầu tiên. Nhờ agent liệt kê đầy đủ phiên để chọn tiếp.',
    beforeApproval:'Chỉ lập kế hoạch; chưa thực thi cho đến khi tôi xác nhận đúng kế hoạch và ID.',
    purgeApproval:'Xóa vĩnh viễn không hoàn tác được: chỉ lập kế hoạch xóa hẳn riêng; chưa thực thi cho đến khi tôi xác nhận đúng mã P và mã băm kế hoạch.',
    chooseSession:'Chọn phiên',previousPage:'File trước',nextPage:'File tiếp',page:'Trang',files:'file',selected:'Đã chọn',sessionCount:'Số phiên',
    reducedMotion:'Hiệu ứng chuyển động đang tắt theo tùy chọn hệ thống.',
    memory:'Bộ nhớ còn dùng được',defender:'Bảo vệ thời gian thực của Defender',on:'Đang bật',off:'Chưa bật',securityNote:'Đây là trạng thái Defender; có thể đang dùng phần mềm bảo mật khác.',
    print:'In tóm tắt',language:'Ngôn ngữ',skip:'Đến báo cáo',tools:'Công cụ báo cáo',fontCredits:'Giấy phép font',
    search:'Tìm file',searchPlaceholder:'Đường dẫn, mã hoặc ID file',stateFilter:'Trạng thái',
    allStates:'Mọi trạng thái',storedState:'Đang cách ly',attentionState:'Cần xem xét',plannedState:'Đã lập kế hoạch',restoredState:'Đã khôi phục',purgedState:'Đã xóa hẳn',
    clearSelection:'Bỏ chọn',noMatches:'Không có file khớp bộ lọc. Thử từ khóa hoặc trạng thái khác.',noHistory:'Báo cáo này chưa có lịch sử thao tác file.',
    noProposals:'Chưa có đề xuất đi kèm. Nhờ agent xem báo cáo trước khi lập kế hoạch.',
    noMeasurements:'Chưa có số đo thư mục. Nhờ agent làm rõ bộ thu thập nào bị bỏ qua hoặc chưa hoàn tất.',
    pageStatus:'Trang {page}/{pages}. File {start}-{end} trên {total}.',coverage:'{filtered} trên {total} file khớp bộ lọc hiện tại.',selectedCount:'Đã chọn trong phiên: {count} file.',
    demo:'Dữ liệu minh họa. Báo cáo này không mô tả máy của bạn.',examplePC:'Máy minh họa',demoRequest:'Đây là ví dụ giả lập. Không thực thi.',
    requestNote:'Nội dung này nhờ agent lập kế hoạch, chưa cấp quyền thực thi.',printNote:'Bản in chỉ gồm tóm tắt. Lịch sử file đầy đủ và bản ghi thu thập gốc vẫn nằm trong HTML.',
    phone:'Điện thoại Android',phoneSpace:'Bộ nhớ điện thoại còn trống',charge:'Mức pin',temperature:'Nhiệt độ pin',
    androidNotice:'Android thử nghiệm: chỉ kiểm tra qua USB. Không đổi app, cài đặt hay file. Xếp hạng package không cấp quyền thao tác; riêng RAM hoặc swap chưa chứng minh nguyên nhân giật.',
    snapshot:'Đây là bản chụp đã lưu. Tạo lại HTML không thu thập số liệu mới.',age:'Số phút từ lúc thu thập',
    performance:'Hiệu năng theo thời gian',
    performanceNote:'CPU được chuẩn hóa trên các bộ xử lý logic. Không thu dòng lệnh hay đường dẫn tiến trình. Tác vụ, reboot, sạc và nhiệt độ có thể làm số đo thay đổi; đây chưa phải bằng chứng tăng tốc.',
    cpuMean:'CPU trung bình',cpuPeak:'CPU cao nhất',sampleTime:'Thời điểm đo',cpu:'CPU',topProcess:'Tiến trình cao nhất trong mẫu',cpuDelta:'Thay đổi CPU (điểm phần trăm)',
    recovery:'Tính toàn vẹn dữ liệu khôi phục sẽ được kiểm tra lại khi bạn yêu cầu lập kế hoạch.',
    appTitle:'Quan sát khung hình ứng dụng',
    appNote:'Bộ đếm tích lũy từ lúc app bắt đầu đếm, kèm chênh lệch hai mốc khi lấy mẫu theo cửa sổ. Thiếu tiến trình hoặc mốc đếm vẫn là chưa đầy đủ.',
    appTotal:'Khung hình đã ghi',appJanky:'Khung hình bị giật',appWindowFrames:'Khung hình trong cửa sổ đo',appWindowJanky:'Khung hình giật trong cửa sổ đo',appTask:'Tác vụ mô tả',
    collectorNames:{system:'Hệ thống',volumes:'Các ổ đĩa',memory:'Bộ nhớ',startup:'Khởi động',events:'Nhật ký lỗi',security:'Defender',cpu:'Bộ xử lý',gpu:'Đồ họa',ram:'Thanh RAM',disks:'Ổ vật lý',diskHealth:'Sức khỏe ổ',power:'Chế độ nguồn',battery:'Pin',restorePoints:'Điểm khôi phục',processes:'Tiến trình',tasks:'Tác vụ khởi động',services:'Dịch vụ',apps:'Ứng dụng',radar:'Nhóm dung lượng',hotspots:'Thư mục lớn chưa phân loại',devArtifacts:'Thư mục build lập trình cũ',largeFiles:'File lớn',storage:'Bộ nhớ điện thoại',packages:'Danh sách app',appSizes:'Dung lượng theo ứng dụng',thermal:'Trạng thái nhiệt',frames:'Khung hình app',performance:'Mẫu hiệu năng'},
    states:{planned:'Đã lập kế hoạch',moving:'Đang chuyển, cần đối chiếu',quarantined:'Đang cách ly',restoring:'Đang khôi phục, cần đối chiếu',restored:'Đã khôi phục',conflict:'Trùng tên',failed:'Cần xử lý lỗi',purging:'Đang xóa hẳn, cần đối chiếu',purged:'Đã xóa hẳn'},
    qualities:{complete:'Đã đo',partial:'Chưa đầy đủ',unavailable:'Chưa khả dụng',failed:'Có lỗi'},
    proposalColumns:{id:'Mã',title:'Việc làm',evidence:'Bằng chứng',benefit:'Bạn được gì',loss:'Bạn mất gì',risk:'Mức cần xem xét',undo:'Khôi phục'},
    risks:{low:'Thấp',review:'Cần xem kỹ',high:'Cao'},
    undoLabels:{reversible:'Khi file và journal còn nguyên',partial:'Một phần',irreversible:'Không hoàn tác được','not-applicable':'Không áp dụng'}
  }
};

export function formatBytes(value,lang='en') {return number(value)===null ? copy[lang].unknown : (value/2**30).toLocaleString(lang==='vi'?'vi-VN':'en-US',{maximumFractionDigits:2})+' GiB';}

export function historyPage(items,page=0,pageSize=50) {
  const rows=list(items),size=Number.isInteger(pageSize)&&pageSize>0?pageSize:50;
  const pages=Math.max(1,Math.ceil(rows.length/size));
  const current=Math.max(0,Math.min(Number.isInteger(page)?page:0,pages-1));
  const start=current*size,end=Math.min(start+size,rows.length);
  return {items:rows.slice(start,end),page:current,pages,total:rows.length,start,end};
}

function localDate(value,lang){const date=new Date(value);return Number.isNaN(date.getTime())?String(value||''):date.toLocaleString(lang==='vi'?'vi-VN':'en-US');}

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
    const headerNote = payload.demo ? T.demoRequest : (action.operation === 'purge' ? T.purgeApproval : T.beforeApproval);
    $('request').value = headerNote + '\n' + JSON.stringify(action, null, 2);
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
    const purge = document.createElement('button'); purge.className = 'button button-danger'; purge.type = 'button'; purge.id = 'purge-request'; purge.textContent = T.purge;
    const clear = document.createElement('button'); clear.type = 'button'; clear.className = 'button button-quiet'; clear.textContent = T.clearSelection;
    function updateSelection() {
      const ids = [...selected];
      selectedText.textContent = interpolate(T.selectedCount,{count:ids.length});
      restore.disabled = ids.length === 0;
      purge.disabled = !canRequestPurge(session, ids);
      clear.disabled = ids.length === 0;
    }
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
    purge.addEventListener('click', () => { const ids=[...selected]; if (canRequestPurge(session,ids)) renderRequest({operation:'purge',root:payload.historyRoot,sessionId:session.sessionId,itemIds:ids}); });
    selectionButtons.append(clear,restore,purge); navigation.append(pageButtons,selectionButtons); box.append(navigation);
    if (session.totalItems > source.length) { const warning = document.createElement('p'); warning.className = 'notice'; warning.textContent = T.limited; box.append(warning); }
    updateSelection();
  }
  function renderAll() {
    T = copy[language]; document.documentElement.lang = language; $('report-language').value = language;
    const example=view.platform==='android'?T.phone:T.examplePC;
    document.title = 'Syrin clean | ' + (payload.demo ? example : view.system.model || (view.platform==='android'?T.phone:T.pc));
    const labels = {'skip-report':'skip','language-label':'language','subtitle':'report','summary-title':'summary','measurements-title':'measured','measurement-note':'measurementNote','category-label':'category','comparison-title':'comparison','comparison-note':'comparisonNote','proposals-title':'proposals','proposal-note':'proposalNote','history-title':'history','history-note':'historyNote','details-title':'details','scene-note':'scene','share':'share','request-title':'request','request-note':'requestNote','copy-request':'copy','history-link':'history','print-report':'print','print-note':'printNote','font-credits-title':'fontCredits','session-label':'chooseSession','search-label':'search','state-label':'stateFilter','footer':'footer'};
    for (const [id,key] of Object.entries(labels)) $(id).textContent = T[key];
    $('session-label').textContent = T.chooseSession + ' (' + sessions.length + ')';
    $('report-tools').setAttribute('aria-label',T.tools); $('request').setAttribute('aria-label',T.request); $('cloud').setAttribute('aria-label',T.scene); $('history-search').placeholder = T.searchPlaceholder;
    $('top').textContent = payload.demo ? example : view.system.model || (view.platform==='android'?T.phone:T.pc);
    $('identity').textContent = [view.platform==='android'?'Android '+(view.system.android || ''):view.system.windows,view.system.edition,view.system.architecture,localDate(view.audit.meta.generatedUtc,language)].filter(Boolean).join(', ');
    const age=measurementAge(view.audit.meta);
    $('freshness').textContent = T.snapshot + ' ' + T.age + ': ' + (age===null?T.unknown:age.toLocaleString(language==='vi'?'vi-VN':'en-US'));
    $('demo-banner').hidden = !payload.demo; $('demo-banner').textContent = T.demo;
    const warningText = language === 'vi' ? {'agent-privacy':'Agent hoặc nhà cung cấp có thể xử lý đầu ra lệnh ngoài máy.','support-unverified':'Cấu hình, filesystem và provider chưa thử vẫn chưa được xác minh.'} : {'agent-privacy':'Your agent/provider may process command output outside this device.','support-unverified':'Untested configurations, filesystems and providers remain unverified.'};
    const warnings = [...list(view.audit.meta.warnings), ...list(view.audit.meta.warningCodes).map(code => warningText[code]).filter(Boolean)];
    if(view.platform==='android') warnings.unshift(T.androidNotice);
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
    if(view.platform==='android'){
      const percent=value=>number(value)===null?T.unknown:value.toLocaleString(language==='vi'?'vi-VN':'en-US')+'%';
      const quality=(name,value)=>value===null?'unavailable':view.collector(name).status;
      const temperature=typeof view.battery.temperatureC==='number' && Number.isFinite(view.battery.temperatureC)?view.battery.temperatureC:null;
      $('facts').innerHTML=fact(T.phoneSpace,gb(view.storage.freeBytes),quality('storage',number(view.storage.freeBytes)))+fact(T.memory,gb(view.memoryAvailable),quality('memory',view.memoryAvailable))+fact(T.charge,percent(view.battery.chargePercent),quality('battery',number(view.battery.chargePercent)))+fact(T.temperature,temperature===null?T.unknown:temperature+' °C',quality('battery',temperature));
    }
    $('measurements').hidden=view.platform==='android';
    $('app-section').hidden=view.platform!=='android' || !view.audit.collectors.frames;
    if(view.audit.collectors.frames){
      const frames=view.collector('frames'),data=first(frames.data);
      $('app-title').textContent=T.appTitle;$('app-note').textContent=T.appNote;
      $('app-context').textContent=[data.package,data.contextLabel?T.appTask+': '+data.contextLabel:''].filter(Boolean).join(' · ');
      let frameFacts=fact(T.appTotal,number(data.totalFrames)===null?T.unknown:data.totalFrames,frames.status)+fact(T.appJanky,number(data.jankyFrames)===null?T.unknown:data.jankyFrames,frames.status);
      if(data.windowOriginVerified){
        frameFacts+=fact(T.appWindowFrames,number(data.windowTotalFrames)===null?T.unknown:data.windowTotalFrames,frames.status)+fact(T.appWindowJanky,number(data.windowJankyFrames)===null?T.unknown:data.windowJankyFrames,frames.status);
      }
      $('app-facts').innerHTML=frameFacts;
    }
    $('performance-section').hidden=!view.performance.sampleCount;
    $('performance-title').textContent=T.performance;$('performance-note').textContent=T.performanceNote;
    if(view.performance.sampleCount){
      const perf=view.performance, pct=value=>number(value)===null?T.unknown:value+'%';
      $('performance-facts').innerHTML=fact(T.cpuMean,pct(perf.meanCpuPercent),view.collector('performance').status)+fact(T.cpuPeak,pct(perf.peakCpuPercent),view.collector('performance').status);
      $('performance-samples').innerHTML=table(list(perf.samples).map(sample=>({[T.sampleTime]:localDate(sample.sampledUtc,language),[T.cpu]:pct(sample.cpuPercent),[T.memory]:gb(sample.availableBytes),[T.topProcess]:first(sample.processes).name || T.unknown})));
      if(view.performanceComparison){const c=view.performanceComparison;$('performance-facts').innerHTML+=fact(T.before,pct(c.before),'complete')+fact(T.after,pct(c.after),'complete')+fact(T.cpuDelta,(c.delta>=0?'+':'')+c.delta.toFixed(2),'complete');}
    }
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
    $('details').innerHTML = Object.entries(view.audit.collectors).map(([name,collector]) => '<details><summary>' + esc(T.collectorNames[name] || name) + ': ' + esc(T.qualities[collector.status] || collector.status) + '</summary><p class="errors">' + esc(list(collector.errors).join('\n')) + '</p>' + table(name==='performance'?list(view.performance.samples).flatMap(sample=>list(sample.processes).map(process=>({sampledUtc:sample.sampledUtc,...process}))):list(collector.data)) + '</details>').join('');
    $('history-session').textContent = '';
    sessions.forEach((session,index) => { const option = document.createElement('option'); option.value = String(index); option.textContent = (index+1) + '. ' + localDate(session.createdUtc,language) + ' / ' + String(session.sessionId).slice(0,12); $('history-session').append(option); });
    $('history-session').value = String(state.session);
    $('history-state').innerHTML = [['all','allStates'],['quarantined','storedState'],['attention','attentionState'],['planned','plannedState'],['restored','restoredState'],['purged','purgedState']].map(([value,label]) => '<option value="' + value + '">' + esc(T[label]) + '</option>').join('');
    $('history-state').value = state.filter;
    $('share').hidden = Boolean(payload.shared); $('history').hidden = Boolean(payload.shared) || view.platform==='android'; $('history-link').hidden = Boolean(payload.shared) || view.platform==='android';
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
