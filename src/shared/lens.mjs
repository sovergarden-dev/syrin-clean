export function createLens(canvas, {rows = [], preview = false, button, labels}) {
  const context = canvas.getContext('2d');
  if (!context) { if (button) button.disabled = true; return {setStage() {}, setCategory() {}, refresh() {}, destroy() {}}; }
  const media = matchMedia('(prefers-reduced-motion: reduce)');
  const css = getComputedStyle(canvas);
  const palette = Object.fromEntries(['cache','app-data','user-data','vm','system','unknown'].map(key => [key, css.getPropertyValue('--category-' + key).trim()]));
  const rule = css.getPropertyValue('--lens-rule').trim();
  const signal = css.getPropertyValue('--signal').trim();
  const abort = new AbortController(), events = {signal: abort.signal};
  let enabled = true;
  try { enabled = localStorage.getItem('syrin-motion') !== 'paused'; } catch {}
  let visible = false, frame = 0, timer = 0, width = 0, height = 0, rotation = -.3, lastTime = 0;
  let stage = 0, displayedStage = 0, category = 'all', dragging = false, lastX = 0;
  const budget = innerWidth < 700 ? 160 : 280;
  const groups = preview ? ['cache','app-data','user-data','vm'].map(category => ({category, measuredBytes: 1})) : rows.filter(row => row.measuredBytes > 0);
  const sum = groups.reduce((total, row) => total + row.measuredBytes, 0);
  let seed = 13;
  const random = () => { seed = seed * 16807 % 2147483647; return (seed - 1) / 2147483646; };
  const points = [];
  groups.forEach((group, groupIndex) => {
    const count = Math.min(budget - points.length, Math.max(3, Math.round(budget * group.measuredBytes / sum)));
    for (let index = 0; index < count; index++) {
      const angle = random() * Math.PI * 2, radius = .45 + random() * .5;
      points.push({angle, radius, height: random() - .5, group: groupIndex, category: group.category, x: 0, y: 0, z: 0, k: 1, color: palette[group.category] || palette.unknown});
    }
  });
  const projected = points.map(point => ({point, x: 0, y: 0, z: 0, k: 1}));
  canvas.dataset.pointCount = String(points.length);
  function active() { return visible && !document.hidden && enabled && !media.matches && !dragging; }
  function cancel() { if (frame) cancelAnimationFrame(frame); if (timer) clearTimeout(timer); frame = 0; timer = 0; }
  function draw() {
    const dpr = Math.min(devicePixelRatio || 1, 1.5);
    context.setTransform(dpr, 0, 0, dpr, 0, 0); context.clearRect(0, 0, width, height);
    const scale = Math.min(width, height) * .33, centerX = width * .5, centerY = height * .5;
    const cosine = Math.cos(rotation), sine = Math.sin(rotation);
    context.strokeStyle = rule; context.lineWidth = 1;
    for (let ring = 0; ring < 5; ring++) {
      context.globalAlpha = .26 + ring * .035;
      context.beginPath(); context.ellipse(centerX, centerY + (ring - 2) * scale * .16, scale * (1.1 - Math.abs(ring - 2) * .09), scale * .27, -.12, 0, Math.PI * 2); context.stroke();
    }
    context.globalAlpha = .75; context.strokeStyle = signal;
    context.beginPath(); context.ellipse(centerX, centerY, scale * 1.16, scale * .29, -.62 + rotation * .06, Math.PI * .1, Math.PI * 1.7); context.stroke();
    for (let index = 0; index < points.length; index++) {
      const point = points[index], split = preview ? Math.min(1, displayedStage) : 1;
      let x = Math.cos(point.angle) * point.radius;
      let y = point.height * .8 * (1 - split) + ((point.group / Math.max(groups.length - 1, 1)) - .5) * 1.35 * split;
      let z = Math.sin(point.angle) * point.radius;
      if (preview && displayedStage > 1) {
        const isolate = Math.min(displayedStage - 1, 1) * (displayedStage < 2 ? 1 : 3 - displayedStage);
        if (point.category === 'cache') { x = x * (1 - isolate * .7) - isolate * .75; y *= 1 - isolate * .5; z *= 1 - isolate * .7; }
        else x += isolate * .2;
      }
      const xx = x * cosine - z * sine, zz = x * sine + z * cosine;
      const k = 3.5 / (3.5 + zz), item = projected[index];
      item.point = point; item.x = centerX + xx * scale * k; item.y = centerY + (y + zz * .13) * scale * k; item.z = zz; item.k = k;
    }
    projected.sort((a, b) => b.z - a.z);
    for (const item of projected) {
      const chosen = category === 'all' || item.point.category === category;
      context.globalAlpha = chosen ? .38 + .56 * (1 - (item.z + 1) / 2) : .08;
      context.fillStyle = preview ? signal : item.point.color;
      const size = (preview ? 2.8 : 3.1) * item.k;
      context.fillRect(item.x, item.y, size, size);
    }
    context.globalAlpha = 1;
  }
  function schedule() { if (active()) timer = setTimeout(() => { timer = 0; frame = requestAnimationFrame(tick); }, 1000 / 24); }
  function tick(now) {
    frame = 0; if (!active()) return;
    if (lastTime) rotation += Math.min((now - lastTime) / 1000, .1) * .1;
    lastTime = now; displayedStage += (stage - displayedStage) * .16; draw(); schedule();
  }
  function refresh() {
    cancel(); lastTime = 0;
    canvas.dataset.motion = media.matches ? 'reduced' : !enabled ? 'paused' : !visible || document.hidden ? 'hidden' : 'running';
    if (button) {
      const copy = labels(); button.disabled = media.matches; button.textContent = media.matches ? copy.reduced : enabled ? copy.pause : copy.resume;
      button.setAttribute('aria-pressed', String(enabled && !media.matches));
    }
    if (!active()) displayedStage = stage;
    if (visible && !document.hidden) { draw(); schedule(); }
  }
  function resize() {
    width = canvas.clientWidth; height = canvas.clientHeight;
    const dpr = Math.min(devicePixelRatio || 1, 1.5); canvas.width = Math.round(width * dpr); canvas.height = Math.round(height * dpr); refresh();
  }
  const observer = new IntersectionObserver(entries => { visible = entries[0].isIntersecting; refresh(); }); observer.observe(canvas);
  const resizeObserver = new ResizeObserver(resize); resizeObserver.observe(canvas);
  button?.addEventListener('click', () => { enabled = !enabled; try { localStorage.setItem('syrin-motion', enabled ? 'enabled' : 'paused'); } catch {} refresh(); }, events);
  document.addEventListener('visibilitychange', refresh, events);
  media.addEventListener('change', refresh, events);
  canvas.addEventListener('pointerdown', event => { dragging = true; lastX = event.clientX; cancel(); canvas.setPointerCapture(event.pointerId); }, events);
  canvas.addEventListener('pointermove', event => { if (!dragging) return; rotation += (event.clientX - lastX) * .007; lastX = event.clientX; if (!frame) frame = requestAnimationFrame(() => { frame = 0; draw(); }); }, events);
  canvas.addEventListener('pointerup', () => { dragging = false; refresh(); }, events);
  canvas.addEventListener('pointercancel', () => { dragging = false; refresh(); }, events);
  canvas.addEventListener('keydown', event => { if (!['ArrowLeft','ArrowRight'].includes(event.key)) return; event.preventDefault(); rotation += event.key === 'ArrowLeft' ? -.12 : .12; draw(); }, events);
  resize();
  return {
    setStage(value) { stage = Math.max(0, Math.min(3, value)); if (!active()) displayedStage = stage; refresh(); },
    setCategory(value) { category = value; if (visible) draw(); },
    refresh,
    destroy() { cancel(); observer.disconnect(); resizeObserver.disconnect(); abort.abort(); }
  };
}
