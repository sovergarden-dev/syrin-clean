
      function val(id) { var el = document.getElementById(id); return el ? el.value.trim() : ''; }
      function buildPrompt() {
        var lines = profileLines();
        var finalPrompt = basePromptTemplate.replace('__CUSTOM_CONTEXT__', blockHeader + lines.join('\n'));
        document.getElementById('superPrompt').textContent = finalPrompt;
        var words = finalPrompt.split(/\s+/).filter(Boolean).length;
        document.getElementById('wordCount').textContent = '(' + words.toLocaleString(PAGE.locale) + ' ' + PAGE.words + ')';
      }
      ['optRole','optScope','optAggressiveness','optBudget','optMode','optReport'].forEach(function (id) { document.getElementById(id).addEventListener('change', buildPrompt); });
      ['optDrive','optProtect','optNote'].forEach(function (id) { document.getElementById(id).addEventListener('input', buildPrompt); });
      document.getElementById('resetCustom').addEventListener('click', function () {
        document.getElementById('optRole').value = 'auto'; document.getElementById('optScope').value = 'full';
        document.getElementById('optAggressiveness').value = 'balanced'; document.getElementById('optMode').value = 'approve'; document.getElementById('optBudget').value = 'balanced'; document.getElementById('optReport').value = 'r3d';
        ['optDrive','optProtect','optNote'].forEach(function (id) { document.getElementById(id).value = ''; });
        buildPrompt();
      });
      buildPrompt();
      function flash(btn, text) { var old = btn.textContent; btn.textContent = text; btn.classList.add('copied'); setTimeout(function () { btn.textContent = old; btn.classList.remove('copied'); }, 2200); }
      function wireCopy(buttonId, sourceId, doneText) {
        var btn = document.getElementById(buttonId), src = document.getElementById(sourceId);
        if (!btn || !src) return;
        btn.addEventListener('click', function () {
          var text = src.textContent;
          function fallback() {
            var range = document.createRange(); range.selectNodeContents(src);
            var sel = window.getSelection(); sel.removeAllRanges(); sel.addRange(range);
            try { if (document.execCommand('copy')) { flash(btn, doneText); sel.removeAllRanges(); } else { showToast(PAGE.copyFailure); } } catch (e) { showToast(PAGE.copyFailure); }
          }
          if (navigator.clipboard && navigator.clipboard.writeText) { navigator.clipboard.writeText(text).then(function () { flash(btn, doneText); }, fallback); } else { fallback(); }
        });
      }
      function wireDownload(buttonId, sourceId, fileName, bom, doneText) {
        var btn = document.getElementById(buttonId), src = document.getElementById(sourceId);
        if (!btn || !src) return;
        btn.addEventListener('click', function () {
          var text = src.textContent.replace(/\r?\n/g, '\r\n');
          var blob = new Blob([(bom ? '\ufeff' : '') + text], { type: 'text/plain;charset=utf-8' });
          var a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = fileName;
          document.body.appendChild(a); a.click(); setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 500);
          flash(btn, doneText);
        });
      }
      wireCopy('copyPrompt', 'superPrompt', PAGE.copied);
      wireCopy('copyCmds', 'auditCmds', PAGE.copied);
      (function () {
        var btn = document.getElementById('downloadPrompt');
        if (!btn) return;
        btn.addEventListener('click', function () {
          var text = PAGE.promptTitle + '\n\n## PROMPT\n\n' + document.getElementById('superPrompt').textContent + '\n\n' + runtimeAppendix;
          var blob = new Blob([text.replace(/\r?\n/g, '\r\n')], { type: 'text/markdown;charset=utf-8' });
          var a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = PAGE.promptFile;
          document.body.appendChild(a); a.click(); setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 500);
          flash(btn, PAGE.downloaded);
        });
      })();
      document.getElementById('downloadCmds').addEventListener('click', function () { downloadZip(PAGE.language === 'en'); });

      function showToast(msg) { var t = document.getElementById('toast'); if (!t) return; t.textContent = msg; t.classList.add('show'); clearTimeout(t._h); t._h = setTimeout(function () { t.classList.remove('show'); }, 2400); }
      function profileLines() {
        var lines = [roleSnippets[val('optRole')] || roleSnippets.auto, scopeSnippets[val('optScope')] || scopeSnippets.full,
          aggrSnippets[val('optAggressiveness')] || aggrSnippets.balanced, budgetSnippets[val('optBudget')] || budgetSnippets.balanced, modeSnippets[val('optMode')] || modeSnippets.approve, reportSnippets[val('optReport')] || reportSnippets.r3d];
        if (val('optDrive')) lines.push(extraTpl.drive.replace('{v}', val('optDrive')));
        if (val('optProtect')) lines.push(extraTpl.protect.replace('{v}', val('optProtect')));
        if (val('optNote')) lines.push(extraTpl.note.replace('{v}', val('optNote')));
        return lines;
      }
      function buildStarter() {
        document.getElementById('starterMsg').textContent = PAGE.starter + blockHeader + profileLines().join('\n');
      }
      ['optRole','optScope','optAggressiveness','optBudget','optMode','optReport'].forEach(function (id) { document.getElementById(id).addEventListener('change', buildStarter); });
      ['optDrive','optProtect','optNote'].forEach(function (id) { document.getElementById(id).addEventListener('input', buildStarter); });
      document.getElementById('resetCustom').addEventListener('click', buildStarter);
      buildStarter();
      wireCopy('copyStarter', 'starterMsg', PAGE.copied);
      wireCopy('copyInstall', 'installMsg', PAGE.copied);
      var tabs = Array.prototype.slice.call(document.querySelectorAll('.tab'));
      tabs.forEach(function (tab, index) {
        tab.addEventListener('click', function () {
          tabs.forEach(function (item) { var active = item === tab; item.classList.toggle('active', active); item.setAttribute('aria-selected', String(active)); item.tabIndex = active ? 0 : -1; });
          Array.prototype.forEach.call(document.querySelectorAll('.panel'), function (panel) { panel.classList.toggle('active', panel.id === tab.getAttribute('data-tab')); });
        });
        tab.addEventListener('keydown', function (event) {
          var next = event.key === 'ArrowRight' ? (index + 1) % tabs.length : event.key === 'ArrowLeft' ? (index + tabs.length - 1) % tabs.length : event.key === 'Home' ? 0 : event.key === 'End' ? tabs.length - 1 : -1;
          if (next >= 0) { event.preventDefault(); tabs[next].focus(); tabs[next].click(); }
        });
      });
      function downloadZip(en) {
        var bin = atob(en || !skillZipB64 ? skillZipEnB64 : skillZipB64), arr = new Uint8Array(bin.length);
        for (var i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
        var blob = new Blob([arr], { type: 'application/zip' });
        var a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = en ? 'syrin-clean-skill-v3.6-en.zip' : 'syrin-clean-skill-v3.6-vi.zip';
        document.body.appendChild(a); a.click(); setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 800);
        showToast(PAGE.skillDownloaded);
      }
      Array.prototype.forEach.call(document.querySelectorAll('[data-dl]'), function (btn) {
        btn.addEventListener('click', function () {
          if (btn.getAttribute('data-dl') === 'zip') { downloadZip(false); } else if (btn.getAttribute('data-dl') === 'zip-en') { downloadZip(true); }
          else { document.getElementById('downloadPrompt').click(); showToast(PAGE.promptDownloaded); }
        });
      });
      (function () {
        var els = document.querySelectorAll('.reveal');
        if (!('IntersectionObserver' in window)) { Array.prototype.forEach.call(els, function (e) { e.classList.add('in'); }); return; }
        var io = new IntersectionObserver(function (entries) { entries.forEach(function (en) { if (en.isIntersecting) { en.target.classList.add('in'); io.unobserve(en.target); } }); }, { threshold: 0.08 });
        Array.prototype.forEach.call(els, function (e) { io.observe(e); });
      })();

      (function () {
        var $ = function (id) { return document.getElementById(id); };
        var mq = window.matchMedia ? window.matchMedia('(prefers-reduced-motion: reduce)') : null;
        var reduce = !!(mq && mq.matches);
        var clamp = function (v, a, b) { return v < a ? a : v > b ? b : v; };
        var smooth = function (t) { t = clamp(t, 0, 1); return t * t * (3 - 2 * t); };
        var seg = function (p, a, b) { return smooth((p - a) / (b - a)); };
        var lin = function (p, a, b) { return clamp((p - a) / (b - a), 0, 1); };
        var out3 = function (t) { return 1 - Math.pow(1 - t, 3); };
        var each = function (list, fn) { Array.prototype.forEach.call(list, fn); };

        /* section entrances (headings unfold in 3D via CSS) */
        var rise = document.querySelectorAll('[data-rise]');
        if ('IntersectionObserver' in window && !reduce) {
          var io = new IntersectionObserver(function (entries) {
            var k = 0;
            entries.forEach(function (en) { if (en.isIntersecting) { en.target.style.setProperty('--d', (k++ * 80) + 'ms'); en.target.classList.add('in'); io.unobserve(en.target); } });
          }, { threshold: 0.12, rootMargin: '0px 0px -6% 0px' });
          each(rise, function (el) { if (!el.closest('#hero')) io.observe(el); });
        } else { each(rise, function (el) { el.classList.add('in'); }); }

        /* hero intro */
        var hero = $('hero');
        if (hero) {
          var hp = hero.querySelectorAll('[data-rise]');
          each(hp, function (el, n) { el.style.setProperty('--d', (280 + n * 110) + 'ms'); });
          setTimeout(function () { hero.classList.add('go'); each(hp, function (el) { el.classList.add('in'); }); }, 60);
        }

        /* never list: rows flip up in 3D, then get struck through */
        var nl = $('neverList');
        if (nl) {
          if ('IntersectionObserver' in window && !reduce) { var no = new IntersectionObserver(function (e) { if (e[0].isIntersecting) { nl.classList.add('in'); no.disconnect(); } }, { threshold: 0.25 }); no.observe(nl); }
          else nl.classList.add('in');
        }

        /* 3D tilt on panels and on the footer wordmark */
        var fine = window.matchMedia ? window.matchMedia('(pointer: fine)').matches : true;
        function tilt(el, area, mx, my) {
          if (!el || reduce || !fine) return;
          area.addEventListener('pointermove', function (e) {
            var r = el.getBoundingClientRect();
            var x = clamp((e.clientX - r.left) / r.width, 0, 1) - 0.5, y = clamp((e.clientY - r.top) / r.height, 0, 1) - 0.5;
            el.classList.add('live');
            el.style.transform = 'perspective(1000px) rotateX(' + (-y * mx).toFixed(2) + 'deg) rotateY(' + (x * my).toFixed(2) + 'deg)';
          });
          area.addEventListener('pointerleave', function () { el.classList.remove('live'); el.style.transform = ''; });
        }
        each(document.querySelectorAll('.way-alt[data-tilt]'), function (el) { tilt(el, el, 7, 9); });
        var fn = $('footName'); if (fn) tilt(fn, fn.closest('footer') || fn, 16, 22);

        /* ===== the 3D scene: your drive as a cloud of files =====
           Xem: a scan plane passes, junk turns red. Duyet: junk gathers into quarantine.
           Lam: quarantine spirals away, everything else settles into tidy layers.
           WebGL draws the files (up to 9000); a 2D canvas on top draws the rings.
           Without WebGL the same story is drawn in 2D with fewer files. */
        var stage = $('stage'), box = $('stageCanvas'), glc = $('scene3d'), ov = $('sceneOverlay');
        var blocks = document.querySelectorAll('.sb');
        var statusEl = $('stageStatus'), hint = $('stageHint');
        var P = 0, lastStatus = '';
        function progress() {
          if (!blocks.length) return 0;
          var vh = window.innerHeight || 800, vc = vh / 2, f = blocks[0].getBoundingClientRect(), s = f.top - vh * 0.6, d = [];
          each(blocks, function (bl) { var r = bl.getBoundingClientRect(); d.push(r.top + r.height / 2 - vc); });
          var K = [0.2, 0.52, 1];
          if (s >= 0) return 0;
          if (d[0] > 0) return K[0] * (-s) / (d[0] - s);
          for (var i = 1; i < d.length; i++) { if (d[i] > 0) return K[i - 1] + (K[i] - K[i - 1]) * (-d[i - 1]) / (d[i] - d[i - 1]); }
          return 1;
        }
        function activeBlock() { var best = P < 0.02 ? -1 : P < 0.36 ? 0 : P < 0.6 ? 1 : 2; each(blocks, function (bl, i) { bl.classList.toggle('on', i === best); }); }
        function setStatus(p) {
          var t = p < 0.02 ? PAGE.scene[0] : p < 0.36 ? PAGE.scene[1] : p < 0.6 ? PAGE.scene[2] : p < 0.96 ? PAGE.scene[3] : PAGE.scene[4];
          if (t !== lastStatus && statusEl) { lastStatus = t; statusEl.textContent = t; }
        }
        var octx = ov && ov.getContext ? ov.getContext('2d') : null;
        if (!octx) {
          var onS = function () { P = progress(); setStatus(P); activeBlock(); };
          window.addEventListener('scroll', onS, { passive: true }); onS();
        } else {
          var VS = [
            'attribute vec3 aC; attribute vec3 aT; attribute vec4 aI;',
            'uniform float uP, uTime, uRy, uRx, uD, uSc, uScanY, uScanOn, uTidyAll, uSp2, uTop, uDpr, uWob;',
            'uniform vec2 uRes, uO; uniform vec3 uQ; varying vec3 vCol;',
            'float lin(float x, float a, float b) { return clamp((x - a) / (b - a), 0.0, 1.0); }',
            'void main() {',
            '  float s = aI.x; float size = aI.y; float junk = aI.z; float layer = aI.w;',
            '  vec3 col = vec3(0.886, 0.918, 0.898); vec3 p; float fade = 1.0;',
            '  float wob = uWob * sin(uTime * 0.7 + s * 40.0) * 0.012;',
            '  if (junk > 0.5) {',
            '    float gt = smoothstep(0.38 + s * 0.08, 0.5 + s * 0.06, uP);',
            '    float vt = smoothstep(0.0, 1.0, lin(uP, 0.56 + s * 0.06, 0.72 + s * 0.04));',
            '    p = mix(aC, aT, gt); p.y += wob;',
            '    if (vt > 0.0) {',
            '      vec3 d = p - uQ; float ang = vt * vt * 9.0 + s * 3.0; float ca = cos(ang); float sa = sin(ang); float k1 = 1.0 - vt;',
            '      p = vec3(uQ.x + (d.x * ca - d.z * sa) * k1, uQ.y + d.y * k1 - vt * 0.18, uQ.z + (d.x * sa + d.z * ca) * k1);',
            '      fade = 1.0 - vt; size *= 1.0 - vt * 0.6;',
            '    }',
            '    float rev = smoothstep(0.0, 1.0, (aC.y - uScanY) * 6.0 + 0.5);',
            '    col = mix(col, vec3(1.0, 0.376, 0.376), rev); size *= 1.0 + rev * 0.25;',
            '  } else {',
            '    float st0 = 0.57 + layer * 0.045 + s * 0.04;',
            '    float t = lin(uP, st0, st0 + 0.2); float tt = 1.0 - pow(1.0 - t, 3.0);',
            '    float lift = sin(3.14159 * tt) * 0.35 * (s - 0.5) * 2.0;',
            '    p = mix(aC, aT, tt); p.y += lift + wob * (1.0 - tt);',
            '    float dy = aC.y - uScanY; float fl = uScanOn * exp(-dy * dy * 90.0);',
            '    col = mix(col, vec3(1.0), fl);',
            '    size = size * (1.0 + fl * 0.5) + (uSp2 * 0.8 - size) * pow(tt, 4.0);',
            '    float ac = uTidyAll * (layer > uTop - 0.5 ? 0.9 : 0.06);',
            '    col = mix(col, vec3(0.204, 0.827, 0.6), ac);',
            '  }',
            '  float cy = cos(uRy); float sy = sin(uRy); float cx = cos(uRx); float sx = sin(uRx);',
            '  float x1 = p.x * cy - p.z * sy; float z1 = p.x * sy + p.z * cy;',
            '  float y1 = p.y * cx - z1 * sx; float z2 = p.y * sx + z1 * cx;',
            '  float k = uD / (uD + z2);',
            '  vec2 sp = uO + vec2(x1, -y1) * uSc * k;',
            '  float depth = clamp(0.18 + 0.82 * (1.0 - (z2 + 1.3) / 2.6), 0.1, 1.0) * fade;',
            '  vCol = mix(vec3(0.043, 0.059, 0.055), col, depth);',
            '  gl_PointSize = max(1.0, size * uSc * k * uDpr);',
            '  gl_Position = vec4(sp.x / uRes.x * 2.0 - 1.0, 1.0 - sp.y / uRes.y * 2.0, clamp(z2 / 4.0, -0.99, 0.99), 1.0);',
            '  if (fade < 0.02) gl_Position = vec4(2.0, 2.0, 2.0, 1.0);',
            '}'].join('\n');
          var FS = 'precision mediump float; varying vec3 vCol; void main() { gl_FragColor = vec4(vCol, 1.0); }';
          var gl = null, prog = null, loc = {}, bufs = [];
          function sh(type, src) { var o = gl.createShader(type); gl.shaderSource(o, src); gl.compileShader(o); if (!gl.getShaderParameter(o, gl.COMPILE_STATUS)) { if (window.console) console.warn(gl.getShaderInfoLog(o)); return null; } return o; }
          function setupGL() {
            try { gl = glc.getContext('webgl', { antialias: true, alpha: true, premultipliedAlpha: true }) || glc.getContext('experimental-webgl'); } catch (x) { gl = null; }
            if (!gl) return false;
            var v = sh(gl.VERTEX_SHADER, VS), f = sh(gl.FRAGMENT_SHADER, FS); if (!v || !f) { gl = null; return false; }
            prog = gl.createProgram(); gl.attachShader(prog, v); gl.attachShader(prog, f); gl.linkProgram(prog);
            if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) { gl = null; return false; }
            gl.useProgram(prog);
            ['aC', 'aT', 'aI'].forEach(function (n) { loc[n] = gl.getAttribLocation(prog, n); });
            ['uP', 'uTime', 'uRy', 'uRx', 'uD', 'uSc', 'uScanY', 'uScanOn', 'uTidyAll', 'uSp2', 'uTop', 'uDpr', 'uWob', 'uRes', 'uO', 'uQ'].forEach(function (n) { loc[n] = gl.getUniformLocation(prog, n); });
            gl.enable(gl.DEPTH_TEST); gl.depthFunc(gl.LEQUAL); gl.clearColor(0, 0, 0, 0);
            return true;
          }
          var useGL = !reduce || true;
          useGL = setupGL();
          if (!useGL) glc.style.display = 'none';
          var small = (window.innerWidth || 1200) < 760;
          var memGB = navigator.deviceMemory || 8;
          var N = 0, NY = 5, sp2 = 0.1, C3, T3, I4, drawCount = 0;
          var Q = [1.02, -0.6, 0.32];
          var seed;
          function rnd() { seed |= 0; seed = seed + 0x6D2B79F5 | 0; var t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }
          function gauss() { var u = rnd() || 1e-6, v = rnd(); return Math.sqrt(-2 * Math.log(u)) * Math.cos(6.2831853 * v); }
          function inSphere(r) { var x, y, z; do { x = rnd() * 2 - 1; y = rnd() * 2 - 1; z = rnd() * 2 - 1; } while (x * x + y * y + z * z > 1); return [x * r, y * r, z * r]; }
          function build(count) {
            seed = 20261027; N = count; drawCount = count;
            C3 = new Float32Array(N * 3); T3 = new Float32Array(N * 3); I4 = new Float32Array(N * 4);
            var Cs = [], i, k; for (k = 0; k < 8; k++) Cs.push(inSphere(0.72));
            var sizeK = Math.sqrt(1500 / N), clean = [];
            for (i = 0; i < N; i++) {
              var ci = i % 8, p;
              if (rnd() < 0.12) { p = inSphere(1.18); ci = -1; }
              else { var c = Cs[ci], spr = 0.2 + 0.1 * (ci % 3); p = [c[0] + gauss() * spr, c[1] + gauss() * spr, c[2] + gauss() * spr]; }
              C3[i * 3] = p[0]; C3[i * 3 + 1] = p[1]; C3[i * 3 + 2] = p[2];
              var jk = rnd() < (ci >= 0 && ci < 3 ? 0.62 : 0.12) ? 1 : 0;
              I4[i * 4] = rnd(); I4[i * 4 + 1] = (0.010 + rnd() * 0.017) * sizeK; I4[i * 4 + 2] = jk;
              if (jk) { var q = inSphere(0.2); T3[i * 3] = Q[0] + q[0]; T3[i * 3 + 1] = Q[1] + q[1]; T3[i * 3 + 2] = Q[2] + q[2]; } else clean.push(i);
            }
            for (i = clean.length - 1; i > 0; i--) { var j = Math.floor(rnd() * (i + 1)), tmp = clean[i]; clean[i] = clean[j]; clean[j] = tmp; }
            var M = clean.length, per = Math.ceil(M / NY), n = Math.ceil(Math.sqrt(per)); sp2 = 1.36 / n;
            clean.forEach(function (idx, k2) { var L = Math.floor(k2 / per), jj = k2 % per; T3[idx * 3] = ((jj % n) - (n - 1) / 2) * sp2; T3[idx * 3 + 2] = (Math.floor(jj / n) - (n - 1) / 2) * sp2; T3[idx * 3 + 1] = (L - (NY - 1) / 2) * 0.27; I4[idx * 4 + 3] = L; });
            if (useGL) {
              bufs.forEach(function (bf) { gl.deleteBuffer(bf); }); bufs = [];
              [['aC', C3, 3], ['aT', T3, 3], ['aI', I4, 4]].forEach(function (a) { var bf = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, bf); gl.bufferData(gl.ARRAY_BUFFER, a[1], gl.STATIC_DRAW); gl.enableVertexAttribArray(loc[a[0]]); gl.vertexAttribPointer(loc[a[0]], a[2], gl.FLOAT, false, 0, 0); bufs.push(bf); });
            }
          }
          build(useGL ? (small ? 3600 : (memGB <= 4 ? 5200 : 9000)) : (small ? 650 : 1500));
          var X, Y, Z, A, S, R, G, B, order;
          function alloc2D() { X = new Float32Array(N); Y = new Float32Array(N); Z = new Float32Array(N); A = new Float32Array(N); S = new Float32Array(N); R = new Uint8Array(N); G = new Uint8Array(N); B = new Uint8Array(N); order = []; for (var i = 0; i < N; i++) order.push(i); }
          if (!useGL) alloc2D();
          glc.addEventListener('webglcontextlost', function (e) { e.preventDefault(); useGL = false; glc.style.display = 'none'; build(small ? 650 : 1500); alloc2D(); kick(); });
          var W = 0, H = 0, dpr = 1;
          function resize() {
            dpr = Math.min(window.devicePixelRatio || 1, 2); W = box.clientWidth || 600; H = box.clientHeight || 400;
            [glc, ov].forEach(function (c) { c.width = Math.max(1, Math.round(W * dpr)); c.height = Math.max(1, Math.round(H * dpr)); });
            if (useGL) gl.viewport(0, 0, glc.width, glc.height);
          }
          resize();
          if (window.ResizeObserver) new ResizeObserver(function () { resize(); draw(); }).observe(box); else window.addEventListener('resize', function () { resize(); draw(); });
          var rotY = 0.6, vel = 0, mx = 0, my = 0, tmx = 0, tmy = 0, time = 0, last = 0, dragging = false, lx = 0, visible = true, raf = 0, frames = 0, ftime = 0, tuned = 0;
          stage.addEventListener('pointermove', function (e) {
            var r = stage.getBoundingClientRect(); tmx = clamp((e.clientX - r.left) / r.width - 0.5, -0.5, 0.5); tmy = clamp((e.clientY - r.top) / r.height - 0.5, -0.5, 0.5);
            if (dragging) { vel += (e.clientX - lx) * 0.0016; lx = e.clientX; }
            kick();
          });
          stage.addEventListener('pointerleave', function () { tmx = 0; tmy = 0; kick(); });
          ov.addEventListener('pointerdown', function (e) { dragging = true; lx = e.clientX; ov.classList.add('drag'); if (hint) hint.classList.add('gone'); try { ov.setPointerCapture(e.pointerId); } catch (x) {} kick(); });
          function endDrag() { dragging = false; ov.classList.remove('drag'); }
          ov.addEventListener('pointerup', endDrag); ov.addEventListener('pointercancel', endDrag);
          function project(x, y, z, c) {
            var x1 = x * c.cyA - z * c.syA, z1 = x * c.syA + z * c.cyA, y1 = y * c.cxA - z1 * c.sxA, z2 = y * c.sxA + z1 * c.cxA, k = c.D / (c.D + z2);
            return [c.ox + x1 * c.Sc * k, c.oy - y1 * c.Sc * k, z2, k];
          }
          function particles2D(c, p, scanY, scanOn, tidyAll) {
            for (var i = 0; i < N; i++) {
              var s = I4[i * 4], size = I4[i * 4 + 1], jk = I4[i * 4 + 2], layer = I4[i * 4 + 3], x, y, z, a = 1, r = 226, g = 234, b = 229;
              var cx0 = C3[i * 3], cy0 = C3[i * 3 + 1], cz0 = C3[i * 3 + 2], tx = T3[i * 3], ty = T3[i * 3 + 1], tz = T3[i * 3 + 2];
              var wob = reduce ? 0 : Math.sin(time * 0.7 + s * 40) * 0.012;
              if (jk > 0.5) {
                var gt = seg(p, 0.38 + s * 0.08, 0.5 + s * 0.06), vt = smooth(lin(p, 0.56 + s * 0.06, 0.72 + s * 0.04));
                x = cx0 + (tx - cx0) * gt; y = cy0 + (ty - cy0) * gt + wob; z = cz0 + (tz - cz0) * gt;
                if (vt > 0) { var dx = x - Q[0], dz = z - Q[2], dy = y - Q[1], ang = vt * vt * 9 + s * 3, ca = Math.cos(ang), sa = Math.sin(ang), k1 = 1 - vt;
                  x = Q[0] + (dx * ca - dz * sa) * k1; z = Q[2] + (dx * sa + dz * ca) * k1; y = Q[1] + dy * k1 - vt * 0.18; a = 1 - vt; size *= 1 - vt * 0.6; }
                var rev = smooth((cy0 - scanY) * 6 + 0.5);
                r = 226 + 29 * rev; g = 234 - 138 * rev; b = 229 - 133 * rev; size *= 1 + rev * 0.25;
              } else {
                var st0 = 0.57 + layer * 0.045 + s * 0.04, tt = out3(lin(p, st0, st0 + 0.2)), lift = Math.sin(Math.PI * tt) * 0.35 * (s - 0.5) * 2;
                x = cx0 + (tx - cx0) * tt; y = cy0 + (ty - cy0) * tt + lift + wob * (1 - tt); z = cz0 + (tz - cz0) * tt;
                var fl = scanOn ? Math.exp(-(cy0 - scanY) * (cy0 - scanY) * 90) : 0;
                r += (255 - r) * fl; g += (255 - g) * fl; b += (255 - b) * fl;
                size = size * (1 + fl * 0.5) + (sp2 * 0.8 - size) * Math.pow(tt, 4);
                var ac = tidyAll * (layer > NY - 1.5 ? 0.9 : 0.06);
                r += (52 - r) * ac; g += (211 - g) * ac; b += (153 - b) * ac;
              }
              var q = project(x, y, z, c);
              X[i] = q[0]; Y[i] = q[1]; Z[i] = q[2];
              A[i] = a * clamp(0.18 + 0.82 * (1 - (q[2] + 1.3) / 2.6), 0.1, 1);
              S[i] = Math.max(1.1, size * c.Sc * q[3]); R[i] = r; G[i] = g; B[i] = b;
            }
            order.sort(function (u, v) { return Z[v] - Z[u]; });
            for (var o = 0; o < N; o++) {
              var j = order[o]; if (A[j] < 0.02) continue;
              octx.fillStyle = 'rgba(' + (R[j] | 0) + ',' + (G[j] | 0) + ',' + (B[j] | 0) + ',' + A[j].toFixed(3) + ')';
              var w = S[j]; octx.fillRect(X[j] - w / 2, Y[j] - w / 2, w, w);
            }
          }
          function draw() {
            if (!W || !H) return;
            var p = P, scanT = seg(p, 0.03, 0.34), scanY = 1.25 - 2.5 * scanT, scanOn = p > 0.03 && p < 0.36, tidyAll = seg(p, 0.9, 1);
            mx += (tmx - mx) * 0.08; my += (tmy - my) * 0.08;
            var ry = rotY + mx * 0.9, rx = 0.38 + my * 0.3 + tidyAll * 0.16;
            var c = { cyA: Math.cos(ry), syA: Math.sin(ry), cxA: Math.cos(rx), sxA: Math.sin(rx), D: 2.7, Sc: Math.min(W, H) * (W < 520 ? 0.36 : 0.33), ox: W * 0.5, oy: H * 0.5 };
            octx.setTransform(dpr, 0, 0, dpr, 0, 0); octx.clearRect(0, 0, W, H);
            if (useGL) {
              gl.useProgram(prog);
              gl.uniform1f(loc.uP, p); gl.uniform1f(loc.uTime, time); gl.uniform1f(loc.uRy, ry); gl.uniform1f(loc.uRx, rx); gl.uniform1f(loc.uD, c.D); gl.uniform1f(loc.uSc, c.Sc);
              gl.uniform1f(loc.uScanY, scanY); gl.uniform1f(loc.uScanOn, scanOn ? 1 : 0); gl.uniform1f(loc.uTidyAll, tidyAll); gl.uniform1f(loc.uSp2, sp2); gl.uniform1f(loc.uTop, NY - 1);
              gl.uniform1f(loc.uDpr, dpr); gl.uniform1f(loc.uWob, reduce ? 0 : 1); gl.uniform2f(loc.uRes, W, H); gl.uniform2f(loc.uO, c.ox, c.oy); gl.uniform3f(loc.uQ, Q[0], Q[1], Q[2]);
              gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT); gl.drawArrays(gl.POINTS, 0, drawCount);
            } else particles2D(c, p, scanY, scanOn, tidyAll);
            if (scanOn) {
              var fade = Math.min(1, (p - 0.03) / 0.03, (0.36 - p) / 0.03);
              octx.beginPath();
              for (var t = 0; t <= 64; t++) { var an = t / 64 * 6.2831853, pr = project(Math.cos(an) * 1.02, scanY, Math.sin(an) * 1.02, c); if (t) octx.lineTo(pr[0], pr[1]); else octx.moveTo(pr[0], pr[1]); }
              octx.closePath(); octx.fillStyle = 'rgba(52,211,153,' + (0.07 * fade).toFixed(3) + ')'; octx.fill();
              octx.strokeStyle = 'rgba(52,211,153,' + (0.6 * fade).toFixed(3) + ')'; octx.lineWidth = 1.6; octx.stroke();
            }
            var qa = seg(p, 0.42, 0.54) * (1 - seg(p, 0.58, 0.72));
            if (qa > 0.01) {
              octx.setLineDash([6, 7]); octx.lineDashOffset = -time * 14; octx.lineWidth = 2.2;
              for (var rn = 0; rn < 2; rn++) {
                octx.beginPath();
                for (var t2 = 0; t2 <= 48; t2++) {
                  var a2 = t2 / 48 * 6.2831853 + time * 0.4, c2 = Math.cos(a2) * 0.33, s2 = Math.sin(a2) * 0.33;
                  var pq = rn ? project(Q[0] + c2, Q[1] + s2, Q[2], c) : project(Q[0] + c2, Q[1], Q[2] + s2, c);
                  if (t2) octx.lineTo(pq[0], pq[1]); else octx.moveTo(pq[0], pq[1]);
                }
                octx.strokeStyle = 'rgba(245,184,61,' + ((rn ? 0.6 : 0.9) * qa).toFixed(3) + ')'; octx.stroke();
              }
              octx.setLineDash([]);
            }
          }
          function tick(ts) {
            raf = 0;
            var dt = last ? Math.min(0.05, (ts - last) / 1000) : 0.016; last = ts;
            if (!reduce) { time += dt; rotY += dt * 0.14 * (1 - 0.6 * seg(P, 0.9, 1)); }
            rotY += vel; vel *= 0.92;
            var t0 = (window.performance && performance.now) ? performance.now() : Date.now();
            draw();
            if (tuned < 2 && !reduce) {
              frames++; ftime += dt;
              if (frames >= 90) { var avg = ftime / frames * 1000; if (avg > 26 && drawCount > 1800) { drawCount = Math.floor(drawCount * 0.6); if (!useGL) { N = drawCount; order = order.filter(function (i) { return i < N; }); } tuned++; } else tuned = 2; frames = 0; ftime = 0; }
            }
            if (visible && !document.hidden && (!reduce || Math.abs(vel) > 0.0005 || dragging || Math.abs(tmx - mx) > 0.002 || Math.abs(tmy - my) > 0.002)) raf = requestAnimationFrame(tick);
            else last = 0;
          }
          function kick() { if (!raf) raf = requestAnimationFrame(tick); }
          function onScroll() { P = progress(); setStatus(P); activeBlock(); if (reduce) draw(); kick(); }
          window.addEventListener('scroll', onScroll, { passive: true });
          window.addEventListener('resize', onScroll);
          document.addEventListener('visibilitychange', kick);
          if ('IntersectionObserver' in window) new IntersectionObserver(function (e) { visible = e[0].isIntersecting; kick(); }).observe(stage);
          onScroll();
        }

        /* display lines never overflow: shrink until they fit their column */
        var fitEls = document.querySelectorAll('[data-fit]');
        function fitAll() {
          each(fitEls, function (el) {
            el.style.fontSize = '';
            var inline = getComputedStyle(el).display.indexOf('inline') === 0, host = el.parentElement, i = 0;
            function room() { return inline ? host.clientWidth - 14 : el.clientWidth; }
            while (el.scrollWidth > room() + 1 && i++ < 40) el.style.fontSize = (parseFloat(getComputedStyle(el).fontSize) * 0.95) + 'px';
          });
        }
        fitAll();
        if (document.fonts && document.fonts.ready) document.fonts.ready.then(fitAll);
        var fitT = 0; window.addEventListener('resize', function () { clearTimeout(fitT); fitT = setTimeout(fitAll, 120); });

        /* first run: switch the starter message to audit-only */
        var ta = $('tryAudit');
        if (ta) ta.addEventListener('click', function () {
          var m = $('optMode'); m.value = 'audit';
          var ev; try { ev = new Event('change'); } catch (x) { ev = document.createEvent('Event'); ev.initEvent('change', true, true); }
          m.dispatchEvent(ev);
          var t0 = document.querySelector(".tab[data-tab='p-starter']"); if (t0) t0.click();
          var cu = $('customize'); if (cu && cu.scrollIntoView) cu.scrollIntoView({ behavior: reduce ? 'auto' : 'smooth', block: 'start' });
          if (typeof showToast === 'function') showToast(PAGE.auditOnly);
        });

        /* layout self-check: open the page with ?check to list overflow and overlaps at the current size */
        window.layoutCheck = function () {
          var sel = 'h1,h2,h3,p,li,label,summary,.btn,.copy-btn,.tab,.chips span,.hero-facts span,.stage-foot,select,input';
          var list = Array.prototype.filter.call(document.querySelectorAll(sel), function (e) {
            if (e.closest('#stage') || e.closest('.lc-panel')) return false;
            var d = e.closest('details'); if (d && !d.open && !e.closest('summary')) return false;
            var r = e.getBoundingClientRect(); return r.width > 0 && r.height > 0 && getComputedStyle(e).visibility !== 'hidden';
          });
          var issues = [], de = document.documentElement;
          if (de.scrollWidth > de.clientWidth + 1) issues.push([PAGE.pageOverflow + de.scrollWidth + 'px > ' + de.clientWidth + 'px']);
          var rects = list.map(function (e) { var r = e.getBoundingClientRect(); return { e: e, l: r.left, t: r.top + window.pageYOffset, r: r.right, b: r.bottom + window.pageYOffset }; });
          rects.forEach(function (o) { var e = o.e; if (e.scrollWidth > e.clientWidth + 2 && !/^(SELECT|INPUT)$/.test(e.tagName) && getComputedStyle(e).overflowX === 'visible' && getComputedStyle(e).display !== 'inline') issues.push([PAGE.textOverflow, e]); if (o.r > de.clientWidth + 1 || o.l < -1) issues.push([PAGE.outside, e]); });
          for (var i = 0; i < rects.length; i++) for (var j = i + 1; j < rects.length; j++) {
            var a = rects[i], b = rects[j]; if (a.e.contains(b.e) || b.e.contains(a.e)) continue;
            var w = Math.min(a.r, b.r) - Math.max(a.l, b.l), hh = Math.min(a.b, b.b) - Math.max(a.t, b.t);
            if (w > 2 && hh > 2) issues.push([PAGE.overlap, a.e, b.e]);
          }
          var st = $('stage'), sto = $('story');
          if (st && sto && getComputedStyle(sto).gridTemplateColumns.split(' ').length > 1) {
            var sr = st.getBoundingClientRect();
            rects.forEach(function (o) { if (!o.e.closest('.story-text')) return; var t = o.t - window.pageYOffset, bb = o.b - window.pageYOffset; if (Math.min(o.r, sr.right) - Math.max(o.l, sr.left) > 2 && Math.min(bb, sr.bottom) - Math.max(t, sr.top) > 2) issues.push([PAGE.sceneOverlap, o.e]); });
          }
          return issues;
        };
        if (/[?&]check\b/.test(location.search)) {
          var panel = document.createElement('div'); panel.className = 'lc-panel'; document.body.appendChild(panel);
          var desc = function (e) { return e.tagName.toLowerCase() + (e.className && typeof e.className === 'string' ? '.' + e.className.split(' ').join('.') : '') + ' “' + (e.textContent || '').trim().slice(0, 30) + '”'; };
          var run = function () {
            Array.prototype.forEach.call(document.querySelectorAll('.lc-bad'), function (e) { e.classList.remove('lc-bad'); });
            var is = window.layoutCheck();
            is.forEach(function (x) { if (x[1]) x[1].classList.add('lc-bad'); if (x[2]) x[2].classList.add('lc-bad'); });
            panel.innerHTML = '<b>' + PAGE.layout + ' · ' + window.innerWidth + '×' + window.innerHeight + ' · ' + (is.length ? is.length + ' ' + PAGE.issues : PAGE.noIssues) + '</b>' + is.slice(0, 25).map(function (x) { return '<div>' + x[0] + (x[1] ? ': ' + desc(x[1]).replace(/</g, '&lt;') : '') + (x[2] ? ' + ' + desc(x[2]).replace(/</g, '&lt;') : '') + '</div>'; }).join('');
          };
          each(document.querySelectorAll('[data-rise]'), function (el) { el.classList.add('in'); });
          setTimeout(run, 900); var ct = 0; window.addEventListener('resize', function () { clearTimeout(ct); ct = setTimeout(run, 300); }); window.addEventListener('scroll', function () { clearTimeout(ct); ct = setTimeout(run, 300); }, { passive: true });
        }
        window.__ready = true;
      })();
