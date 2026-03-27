/**
 * OrchyStraw Pixel Agents — Embeddable Demo
 *
 * Self-contained, looping pixel art animation of agents working in an office.
 * No server, no dependencies — just attach to a canvas element.
 *
 * Usage (vanilla):
 *   <canvas id="pixel-demo" width="800" height="480"></canvas>
 *   <script src="demo-embed.js"></script>
 *   <script>PixelDemo.start(document.getElementById('pixel-demo'));</script>
 *
 * Usage (React / Next.js):
 *   import { startPixelDemo, stopPixelDemo } from './demo-embed';
 *   useEffect(() => {
 *     const cleanup = startPixelDemo(canvasRef.current);
 *     return cleanup;
 *   }, []);
 */

(function (root, factory) {
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = factory();
  } else {
    root.PixelDemo = factory();
  }
}(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  // -------------------------------------------------------------------------
  // Config
  // -------------------------------------------------------------------------

  const DESKS = {
    manager:  { x: 384, y: 48,  label: 'PM Desk' },
    strategy: { x: 96,  y: 48,  label: 'Strategy' },
    arch:     { x: 240, y: 48,  label: 'Architecture' },
    backend:  { x: 96,  y: 176, label: 'Backend' },
    web:      { x: 240, y: 176, label: 'Web' },
    pixel:    { x: 384, y: 176, label: 'Pixel' },
    qa:       { x: 528, y: 176, label: 'QA' },
    security: { x: 672, y: 176, label: 'Security' },
    hr:       { x: 528, y: 48,  label: 'HR' },
  };

  const AGENTS_DEF = [
    { id: '01-ceo',      label: 'CEO',      desk: 'strategy', sprite: 'suit',      idle: { x: 96,  y: 320 } },
    { id: '02-cto',      label: 'CTO',      desk: 'arch',     sprite: 'glasses',   idle: { x: 240, y: 320 } },
    { id: '03-pm',       label: 'PM',        desk: 'manager',  sprite: 'clipboard', idle: { x: 384, y: 320 } },
    { id: '06-backend',  label: 'Backend',  desk: 'backend',  sprite: 'hoodie',    idle: { x: 96,  y: 400 } },
    { id: '08-pixel',    label: 'Pixel',    desk: 'pixel',    sprite: 'artist',    idle: { x: 384, y: 400 } },
    { id: '09-qa',       label: 'QA',       desk: 'qa',       sprite: 'magnifier', idle: { x: 528, y: 400 } },
    { id: '10-security', label: 'Security', desk: 'security', sprite: 'shield',    idle: { x: 672, y: 400 } },
    { id: '11-web',      label: 'Web',      desk: 'web',      sprite: 'palette',   idle: { x: 240, y: 400 } },
    { id: '13-hr',       label: 'HR',       desk: 'hr',       sprite: 'clipboard', idle: { x: 528, y: 320 } },
  ];

  const SPRITE_COLORS = {
    suit: '#a78bfa', glasses: '#60a5fa', clipboard: '#facc15', hoodie: '#4ade80',
    artist: '#f472b6', magnifier: '#fb923c', shield: '#ef4444', palette: '#2dd4bf',
  };

  const STATUS_COLORS = {
    typing: '#4ade80', running: '#4ade80', reading: '#60a5fa',
    talking: '#60a5fa', walking: '#facc15', idle: '#6b7280', error: '#ef4444',
  };

  const PHASE_LABELS = {
    workers_running: 'Workers Active', pm_updating: 'PM Updating',
    committing: 'Committing', done: 'Cycle Complete', idle: 'Idle',
  };

  const PHASE_COLORS = {
    workers_running: '#4ade80', pm_updating: '#facc15',
    committing: '#60a5fa', done: '#a78bfa', idle: '#6b7280',
  };

  const CYCLE_DURATION = 18000;

  const SCRIPT = [
    { t: 0,     agent: '06-backend',  action: 'activate' },
    { t: 200,   agent: '11-web',      action: 'activate' },
    { t: 400,   agent: '08-pixel',    action: 'activate' },
    { t: 600,   agent: '02-cto',      action: 'activate' },
    { t: 2000,  agent: '06-backend',  action: 'read' },
    { t: 2200,  agent: '11-web',      action: 'read' },
    { t: 2500,  agent: '06-backend',  action: 'type', speech: 'Writing logger module...' },
    { t: 3000,  agent: '11-web',      action: 'type', speech: 'Building hero section' },
    { t: 3200,  agent: '08-pixel',    action: 'read' },
    { t: 3500,  agent: '02-cto',      action: 'read', speech: 'Reviewing architecture' },
    { t: 4000,  agent: '08-pixel',    action: 'type', speech: 'Rendering characters' },
    { t: 5000,  agent: '06-backend',  action: 'run',  speech: 'Running tests... 27/27 pass' },
    { t: 5500,  agent: '02-cto',      action: 'type', speech: 'Writing ADR-005' },
    { t: 6000,  agent: '11-web',      action: 'run',  speech: 'npm run build' },
    { t: 6500,  agent: '08-pixel',    action: 'run' },
    { t: 7500,  agent: '08-pixel',    action: 'error', speech: 'Build failed! Retrying...' },
    { t: 8000,  agent: '08-pixel',    action: 'type', speech: 'Fixed — rebuild OK' },
    { t: 8500,  agent: '09-qa',       action: 'activate' },
    { t: 8700,  agent: '10-security', action: 'activate' },
    { t: 9000,  agent: '09-qa',       action: 'read', speech: 'Reviewing backend changes' },
    { t: 9500,  agent: '10-security', action: 'read', speech: 'Scanning for vulnerabilities' },
    { t: 9500,  agent: '02-cto',      action: 'talk', speech: 'All modules PASS review' },
    { t: 10000, agent: '06-backend',  action: 'talk', speech: 'Shared context updated' },
    { t: 10200, agent: '02-cto',      action: 'deactivate' },
    { t: 10500, agent: '09-qa',       action: 'type', speech: 'QA report: PASS' },
    { t: 11000, agent: '10-security', action: 'type', speech: 'Audit: CONDITIONAL PASS' },
    { t: 12000, agent: '06-backend',  action: 'deactivate' },
    { t: 12200, agent: '11-web',      action: 'deactivate' },
    { t: 12400, agent: '08-pixel',    action: 'deactivate' },
    { t: 12600, agent: '09-qa',       action: 'deactivate' },
    { t: 12800, agent: '10-security', action: 'deactivate' },
    { t: 13000, agent: '03-pm',       action: 'activate' },
    { t: 13500, agent: '03-pm',       action: 'walk' },
    { t: 14000, agent: '03-pm',       action: 'type', speech: 'Updating all prompts...' },
    { t: 15000, agent: '03-pm',       action: 'talk', speech: 'Cycle complete!' },
    { t: 16000, agent: '03-pm',       action: 'deactivate' },
  ];

  // -------------------------------------------------------------------------
  // Engine
  // -------------------------------------------------------------------------

  // Easing function for smooth walk transitions
  function easeInOutCubic(t) {
    return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
  }

  function start(canvas) {
    const ctx = canvas.getContext('2d');
    const W = canvas.width;
    const H = canvas.height;
    let frame = 0;
    let cycleStart = performance.now();
    let cycleNum = 1;
    let phase = 'idle';
    let nextEventIdx = 0;
    let running = true;
    let inspectedAgent = null;
    let inspectExpiry = 0;

    const agents = {};
    for (const a of AGENTS_DEF) {
      agents[a.id] = {
        ...a, x: a.idle.x, y: a.idle.y, targetX: a.idle.x, targetY: a.idle.y,
        moveStartX: a.idle.x, moveStartY: a.idle.y, moveDist: 0, moveProgress: 1,
        animation: 'idle', active: false, lastSpeech: null, speechExpiry: 0,
      };
    }

    // Sprite cache — pre-render base sprites to offscreen canvases
    const spriteCache = {};
    for (const [type, color] of Object.entries(SPRITE_COLORS)) {
      const oc = document.createElement('canvas');
      oc.width = 12; oc.height = 24;
      const octx = oc.getContext('2d');
      octx.fillStyle = color;
      octx.fillRect(2, 6, 8, 10);
      octx.fillStyle = '#e5c9a0';
      octx.fillRect(3, 0, 6, 6);
      octx.fillStyle = '#1a1a1a';
      octx.fillRect(4, 2, 2, 2);
      octx.fillRect(7, 2, 2, 2);
      spriteCache[type] = oc;
      // Error variant (red body)
      const ec = document.createElement('canvas');
      ec.width = 12; ec.height = 24;
      const ectx = ec.getContext('2d');
      ectx.fillStyle = '#ef4444';
      ectx.fillRect(2, 6, 8, 10);
      ectx.fillStyle = '#e5c9a0';
      ectx.fillRect(3, 0, 6, 6);
      ectx.fillStyle = '#1a1a1a';
      ectx.fillRect(4, 2, 2, 2);
      ectx.fillRect(7, 2, 2, 2);
      spriteCache[type + '_error'] = ec;
    }

    // Background cache — pre-render static floor grid and desks
    const bgCache = document.createElement('canvas');
    bgCache.width = W; bgCache.height = H;
    (function () {
      const bg = bgCache.getContext('2d');
      bg.fillStyle = '#0a0a0a';
      bg.fillRect(0, 0, W, H);
      bg.strokeStyle = '#141414'; bg.lineWidth = 1;
      for (let gx = 0; gx < W; gx += 16) { bg.beginPath(); bg.moveTo(gx, 30); bg.lineTo(gx, H); bg.stroke(); }
      for (let gy = 30; gy < H; gy += 16) { bg.beginPath(); bg.moveTo(0, gy); bg.lineTo(W, gy); bg.stroke(); }
      for (const [name, desk] of Object.entries(DESKS)) {
        if (name === 'idle') continue;
        bg.fillStyle = '#1e1e1e';
        bg.fillRect(desk.x - 24, desk.y - 8, 48, 24);
        bg.strokeStyle = '#2a2a2a'; bg.lineWidth = 1;
        bg.strokeRect(desk.x - 24, desk.y - 8, 48, 24);
        bg.fillStyle = '#0a0a0a';
        bg.fillRect(desk.x - 8, desk.y - 14, 16, 8);
        bg.strokeStyle = '#333';
        bg.strokeRect(desk.x - 8, desk.y - 14, 16, 8);
        bg.fillStyle = '#333'; bg.font = '7px monospace'; bg.textAlign = 'center';
        bg.fillText(desk.label, desk.x, desk.y + 28);
        bg.textAlign = 'start';
      }
    })();

    // Click-to-inspect
    canvas.style.cursor = 'pointer';
    function onClick(e) {
      const rect = canvas.getBoundingClientRect();
      const scaleX = W / rect.width, scaleY = H / rect.height;
      const mx = (e.clientX - rect.left) * scaleX;
      const my = (e.clientY - rect.top) * scaleY;
      let closest = null, closestDist = Infinity;
      for (const s of Object.values(agents)) {
        const dx = s.x - mx, dy = (s.y - 6) - my;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < 24 && dist < closestDist) { closest = s.id; closestDist = dist; }
      }
      inspectedAgent = closest;
      inspectExpiry = closest ? performance.now() + 4000 : 0;
    }
    canvas.addEventListener('click', onClick);

    function resetCycle() {
      cycleStart = performance.now();
      nextEventIdx = 0;
      cycleNum++;
      phase = 'idle';
      for (const a of AGENTS_DEF) {
        const s = agents[a.id];
        s.targetX = a.idle.x; s.targetY = a.idle.y;
        s.moveStartX = a.idle.x; s.moveStartY = a.idle.y;
        s.moveDist = 0; s.moveProgress = 1;
        s.animation = 'idle'; s.active = false;
        s.lastSpeech = null; s.speechExpiry = 0;
      }
    }

    function processEvents(elapsed) {
      while (nextEventIdx < SCRIPT.length && SCRIPT[nextEventIdx].t <= elapsed) {
        const evt = SCRIPT[nextEventIdx++];
        const s = agents[evt.agent];
        switch (evt.action) {
          case 'activate': {
            s.active = true; s.animation = 'walking';
            const desk = DESKS[s.desk];
            s.moveStartX = s.x; s.moveStartY = s.y;
            s.targetX = desk.x; s.targetY = desk.y + 20;
            s.moveDist = Math.sqrt((s.targetX - s.x) ** 2 + (s.targetY - s.y) ** 2);
            s.moveProgress = 0;
            break;
          }
          case 'deactivate':
            s.active = false; s.animation = 'walking';
            s.moveStartX = s.x; s.moveStartY = s.y;
            s.targetX = s.idle.x; s.targetY = s.idle.y;
            s.moveDist = Math.sqrt((s.targetX - s.x) ** 2 + (s.targetY - s.y) ** 2);
            s.moveProgress = 0;
            break;
          case 'type':  s.animation = 'typing';  break;
          case 'read':  s.animation = 'reading'; break;
          case 'run':   s.animation = 'running'; break;
          case 'talk':  s.animation = 'talking'; break;
          case 'walk':  s.animation = 'walking'; break;
          case 'error': s.animation = 'error';   break;
        }
        if (evt.speech) {
          s.lastSpeech = evt.speech;
          s.speechExpiry = performance.now() + 2500;
        }
      }
      if (elapsed < 2000) phase = 'idle';
      else if (elapsed < 12000) phase = 'workers_running';
      else if (elapsed < 16000) phase = 'pm_updating';
      else phase = 'done';
    }

    function moveAgents() {
      for (const s of Object.values(agents)) {
        if (s.moveProgress < 1 && s.moveDist > 0) {
          s.moveProgress = Math.min(1, s.moveProgress + 2.5 / s.moveDist);
          const eased = easeInOutCubic(s.moveProgress);
          s.x = s.moveStartX + (s.targetX - s.moveStartX) * eased;
          s.y = s.moveStartY + (s.targetY - s.moveStartY) * eased;
          if (s.moveProgress >= 1) {
            s.x = s.targetX; s.y = s.targetY;
            if (s.animation === 'walking') s.animation = s.active ? 'typing' : 'idle';
          }
        }
      }
    }

    function roundRect(x, y, w, h, r) {
      ctx.beginPath();
      ctx.moveTo(x + r, y); ctx.lineTo(x + w - r, y);
      ctx.quadraticCurveTo(x + w, y, x + w, y + r);
      ctx.lineTo(x + w, y + h - r);
      ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
      ctx.lineTo(x + r, y + h);
      ctx.quadraticCurveTo(x, y + h, x, y + h - r);
      ctx.lineTo(x, y + r);
      ctx.quadraticCurveTo(x, y, x + r, y);
      ctx.closePath();
    }

    function draw() {
      // Cached background (floor grid + desks)
      ctx.drawImage(bgCache, 0, 0);

      // Agents
      for (const s of Object.values(agents)) {
        const color = SPRITE_COLORS[s.sprite] || '#6b7280';
        let bobY = 0;
        if (s.animation === 'typing') bobY = Math.sin(frame * 0.3) * 1;
        else if (s.animation === 'walking') bobY = Math.abs(Math.sin(frame * 0.2)) * 2;
        else if (s.animation === 'running') bobY = Math.abs(Math.sin(frame * 0.5)) * 3;
        else if (s.animation === 'talking') bobY = Math.sin(frame * 0.15) * 0.5;
        else if (s.animation === 'error') bobY = Math.sin(frame * 0.8) * 2;
        const x = Math.round(s.x), y = Math.round(s.y + bobY);

        // Draw cached sprite (body + head + eyes)
        const useError = s.animation === 'error' && frame % 10 < 5;
        const cacheKey = useError ? s.sprite + '_error' : s.sprite;
        if (useError) { ctx.shadowColor = '#ef4444'; ctx.shadowBlur = 8; }
        ctx.drawImage(spriteCache[cacheKey], x - 6, y - 18);
        ctx.shadowBlur = 0;

        // Close eyes during blink
        if (frame % 120 <= 5) {
          ctx.fillStyle = '#e5c9a0';
          ctx.fillRect(x - 2, y - 16, 2, 2);
          ctx.fillRect(x + 1, y - 16, 2, 2);
        }

        // Legs (dynamic — swing during walking)
        ctx.fillStyle = '#2a2a2a';
        if (s.animation === 'walking') {
          const legOff = Math.sin(frame * 0.3) * 2;
          ctx.fillRect(x - 3, y - 2, 3, 4 + legOff);
          ctx.fillRect(x + 1, y - 2, 3, 4 - legOff);
        } else {
          ctx.fillRect(x - 3, y - 2, 3, 4);
          ctx.fillRect(x + 1, y - 2, 3, 4);
        }

        // Active glow
        if (s.active) {
          ctx.shadowColor = color; ctx.shadowBlur = 10;
          ctx.fillStyle = color;
          ctx.fillRect(x - 1, y - 20, 2, 2);
          ctx.shadowBlur = 0;
        }

        // Name label
        ctx.fillStyle = s.active ? color : '#3a3a3a';
        ctx.font = '7px monospace'; ctx.textAlign = 'center';
        ctx.fillText(s.label, x, y + 10);
        ctx.textAlign = 'start';

        // Typing particles
        if (s.animation === 'typing' && frame % 8 < 4) {
          ctx.fillStyle = color + '66';
          ctx.fillRect(x + 6 + Math.random() * 8, y - 8 + Math.random() * 4, 2, 2);
        }

        // Status color indicator dot
        const sc = STATUS_COLORS[s.animation] || STATUS_COLORS.idle;
        ctx.fillStyle = sc;
        ctx.beginPath(); ctx.arc(x + 6, y - 18, 2.5, 0, Math.PI * 2); ctx.fill();
        if (s.active && frame % 40 < 20) {
          ctx.strokeStyle = sc + '66'; ctx.lineWidth = 1;
          ctx.beginPath(); ctx.arc(x + 6, y - 18, 4, 0, Math.PI * 2); ctx.stroke();
        }
      }

      // Speech bubbles with overlap resolution
      const now = performance.now();
      ctx.font = '7px monospace';
      const bubbles = [];
      for (const s of Object.values(agents)) {
        if (!s.lastSpeech || now > s.speechExpiry) continue;
        const text = s.lastSpeech.length > 32 ? s.lastSpeech.substring(0, 29) + '...' : s.lastSpeech;
        const tw = ctx.measureText(text).width;
        const lw = ctx.measureText(s.label).width;
        const bw = Math.max(tw, lw) + 12, bh = 22;
        const bx = Math.round(s.x) - bw / 2, by = Math.round(s.y) - 44;
        const remaining = s.speechExpiry - now;
        const opacity = remaining < 400 ? remaining / 400 : 1;
        bubbles.push({ s, text, bx, by, bw, bh, opacity, anchorX: Math.round(s.x) });
      }
      // Resolve overlapping bubbles — push lower ones downward
      bubbles.sort(function (a, b) { return a.by - b.by; });
      for (let i = 1; i < bubbles.length; i++) {
        for (let j = 0; j < i; j++) {
          const a = bubbles[j], b = bubbles[i];
          if (b.bx < a.bx + a.bw && b.bx + b.bw > a.bx) {
            const overlap = (a.by + a.bh + 5) - b.by;
            if (overlap > 0) b.by = a.by + a.bh + 7;
          }
        }
      }
      // Draw resolved bubbles
      for (const b of bubbles) {
        ctx.globalAlpha = b.opacity;
        ctx.fillStyle = 'rgba(10,10,10,0.92)';
        roundRect(b.bx, b.by, b.bw, b.bh, 3); ctx.fill();
        ctx.strokeStyle = '#333'; ctx.lineWidth = 1;
        roundRect(b.bx, b.by, b.bw, b.bh, 3); ctx.stroke();
        // Tail
        ctx.fillStyle = 'rgba(10,10,10,0.92)';
        ctx.beginPath();
        ctx.moveTo(b.anchorX - 3, b.by + b.bh);
        ctx.lineTo(b.anchorX + 3, b.by + b.bh);
        ctx.lineTo(b.anchorX, b.by + b.bh + 5);
        ctx.closePath(); ctx.fill();
        // Label
        ctx.fillStyle = SPRITE_COLORS[b.s.sprite] || '#a78bfa';
        ctx.fillText(b.s.label, b.bx + 6, b.by + 9);
        // Text
        ctx.fillStyle = '#ccc';
        ctx.fillText(b.text, b.bx + 6, b.by + 18);
        ctx.globalAlpha = 1;
      }

      // HUD overlay with elapsed time
      var elapsed = performance.now() - cycleStart;
      var elapsedSec = Math.floor(elapsed / 1000);
      var elapsedStr = Math.floor(elapsedSec / 60) + 'm ' + (elapsedSec % 60).toString().padStart(2, '0') + 's';

      ctx.fillStyle = 'rgba(10,10,10,0.9)';
      ctx.fillRect(0, 0, W, 26);
      const pc = PHASE_COLORS[phase] || '#6b7280';
      ctx.fillStyle = pc; ctx.fillRect(0, 26, W, 2);
      ctx.font = '10px monospace'; ctx.textBaseline = 'middle';
      ctx.fillStyle = '#e5e5e5'; ctx.textAlign = 'start';
      ctx.fillText('Cycle ' + cycleNum, 8, 13);
      ctx.fillStyle = '#9ca3af'; ctx.font = '8px monospace';
      ctx.fillText(elapsedStr, 70, 13);
      ctx.font = '10px monospace';
      ctx.fillStyle = pc; ctx.textAlign = 'center';
      ctx.fillText(PHASE_LABELS[phase] || phase, W / 2, 13);
      const ac = Object.values(agents).filter(a => a.active).length;
      ctx.fillStyle = ac > 0 ? '#4ade80' : '#6b7280';
      ctx.textAlign = 'end';
      ctx.fillText(ac + '/' + AGENTS_DEF.length + ' agents', W - 8, 13);
      ctx.textAlign = 'start'; ctx.textBaseline = 'alphabetic';

      // Inspect panel
      if (inspectedAgent && performance.now() < inspectExpiry) {
        var is = agents[inspectedAgent];
        if (is) {
          var isc = STATUS_COLORS[is.animation] || STATUS_COLORS.idle;
          var icolor = SPRITE_COLORS[is.sprite] || '#6b7280';
          var pw = 160, ph = 64;
          var px = Math.min(Math.max(Math.round(is.x) - pw / 2, 4), W - pw - 4);
          var py = Math.min(Math.round(is.y) + 18, H - ph - 4);
          ctx.fillStyle = 'rgba(10,10,10,0.95)';
          roundRect(px, py, pw, ph, 4); ctx.fill();
          ctx.strokeStyle = icolor + '66'; ctx.lineWidth = 1;
          roundRect(px, py, pw, ph, 4); ctx.stroke();
          ctx.fillStyle = isc;
          ctx.beginPath(); ctx.arc(px + 10, py + 11, 3, 0, Math.PI * 2); ctx.fill();
          ctx.fillStyle = icolor; ctx.font = '9px monospace';
          ctx.fillText(is.label + ' (' + is.id + ')', px + 18, py + 14);
          ctx.fillStyle = isc; ctx.font = '8px monospace';
          ctx.fillText('Status: ' + is.animation.charAt(0).toUpperCase() + is.animation.slice(1), px + 10, py + 28);
          ctx.fillStyle = is.active ? '#4ade80' : '#6b7280';
          ctx.fillText(is.active ? 'ACTIVE' : 'INACTIVE', px + 10, py + 40);
          if (is.lastSpeech && performance.now() < is.speechExpiry) {
            var itxt = is.lastSpeech.length > 22 ? is.lastSpeech.substring(0, 19) + '...' : is.lastSpeech;
            ctx.fillStyle = '#9ca3af'; ctx.fillText(itxt, px + 10, py + 52);
          } else {
            ctx.fillStyle = '#4a4a4a'; ctx.fillText('Desk: ' + (is.desk || 'none'), px + 10, py + 52);
          }
        }
      } else { inspectedAgent = null; }
    }

    function loop() {
      if (!running) return;
      frame++;
      const elapsed = performance.now() - cycleStart;
      if (elapsed >= CYCLE_DURATION) resetCycle();
      processEvents(elapsed);
      moveAgents();
      draw();
      requestAnimationFrame(loop);
    }

    requestAnimationFrame(loop);

    // Return cleanup function
    return function stop() {
      running = false;
      canvas.removeEventListener('click', onClick);
    };
  }

  return { start: start };
}));
