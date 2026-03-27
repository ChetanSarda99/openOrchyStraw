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
    { t: 8000,  agent: '09-qa',       action: 'activate' },
    { t: 8200,  agent: '10-security', action: 'activate' },
    { t: 8500,  agent: '09-qa',       action: 'read', speech: 'Reviewing backend changes' },
    { t: 9000,  agent: '10-security', action: 'read', speech: 'Scanning for vulnerabilities' },
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

    const agents = {};
    for (const a of AGENTS_DEF) {
      agents[a.id] = {
        ...a, x: a.idle.x, y: a.idle.y, targetX: a.idle.x, targetY: a.idle.y,
        animation: 'idle', active: false, lastSpeech: null, speechExpiry: 0,
      };
    }

    function resetCycle() {
      cycleStart = performance.now();
      nextEventIdx = 0;
      cycleNum++;
      phase = 'idle';
      for (const a of AGENTS_DEF) {
        const s = agents[a.id];
        s.targetX = a.idle.x; s.targetY = a.idle.y;
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
            s.targetX = desk.x; s.targetY = desk.y + 20;
            break;
          }
          case 'deactivate':
            s.active = false; s.animation = 'walking';
            s.targetX = s.idle.x; s.targetY = s.idle.y;
            break;
          case 'type':  s.animation = 'typing';  break;
          case 'read':  s.animation = 'reading'; break;
          case 'run':   s.animation = 'running'; break;
          case 'talk':  s.animation = 'talking'; break;
          case 'walk':  s.animation = 'walking'; break;
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
        const dx = s.targetX - s.x, dy = s.targetY - s.y;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (dist > 1) {
          const spd = 2.5;
          s.x += (dx / dist) * Math.min(spd, dist);
          s.y += (dy / dist) * Math.min(spd, dist);
        } else {
          s.x = s.targetX; s.y = s.targetY;
          if (s.animation === 'walking') s.animation = s.active ? 'typing' : 'idle';
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
      // Floor
      ctx.fillStyle = '#0a0a0a';
      ctx.fillRect(0, 0, W, H);
      ctx.strokeStyle = '#141414'; ctx.lineWidth = 1;
      for (let x = 0; x < W; x += 16) { ctx.beginPath(); ctx.moveTo(x, 30); ctx.lineTo(x, H); ctx.stroke(); }
      for (let y = 30; y < H; y += 16) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(W, y); ctx.stroke(); }

      // Desks
      for (const [name, desk] of Object.entries(DESKS)) {
        if (name === 'idle') continue;
        ctx.fillStyle = '#1e1e1e';
        ctx.fillRect(desk.x - 24, desk.y - 8, 48, 24);
        ctx.strokeStyle = '#2a2a2a'; ctx.lineWidth = 1;
        ctx.strokeRect(desk.x - 24, desk.y - 8, 48, 24);
        ctx.fillStyle = '#0a0a0a';
        ctx.fillRect(desk.x - 8, desk.y - 14, 16, 8);
        ctx.strokeStyle = '#333';
        ctx.strokeRect(desk.x - 8, desk.y - 14, 16, 8);
        ctx.fillStyle = '#333'; ctx.font = '7px monospace';
        ctx.textAlign = 'center';
        ctx.fillText(desk.label, desk.x, desk.y + 28);
        ctx.textAlign = 'start';
      }

      // Agents
      for (const s of Object.values(agents)) {
        const color = SPRITE_COLORS[s.sprite] || '#6b7280';
        let bobY = 0;
        if (s.animation === 'typing') bobY = Math.sin(frame * 0.3);
        else if (s.animation === 'walking') bobY = Math.abs(Math.sin(frame * 0.2)) * 2;
        else if (s.animation === 'running') bobY = Math.abs(Math.sin(frame * 0.5)) * 3;
        const x = Math.round(s.x), y = Math.round(s.y + bobY);

        ctx.fillStyle = color;
        ctx.fillRect(x - 4, y - 12, 8, 10);
        ctx.fillStyle = '#e5c9a0';
        ctx.fillRect(x - 3, y - 18, 6, 6);
        if (frame % 120 > 5) {
          ctx.fillStyle = '#1a1a1a';
          ctx.fillRect(x - 2, y - 16, 2, 2);
          ctx.fillRect(x + 1, y - 16, 2, 2);
        }
        ctx.fillStyle = '#2a2a2a';
        ctx.fillRect(x - 3, y - 2, 3, 4);
        ctx.fillRect(x + 1, y - 2, 3, 4);

        if (s.active) {
          ctx.shadowColor = color; ctx.shadowBlur = 10;
          ctx.fillStyle = color;
          ctx.fillRect(x - 1, y - 20, 2, 2);
          ctx.shadowBlur = 0;
        }

        ctx.fillStyle = s.active ? color : '#3a3a3a';
        ctx.font = '7px monospace'; ctx.textAlign = 'center';
        ctx.fillText(s.label, x, y + 10);
        ctx.textAlign = 'start';

        if (s.animation === 'typing' && frame % 8 < 4) {
          ctx.fillStyle = color + '66';
          ctx.fillRect(x + 6 + Math.random() * 8, y - 8 + Math.random() * 4, 2, 2);
        }
      }

      // Speech bubbles
      const now = performance.now();
      for (const s of Object.values(agents)) {
        if (!s.lastSpeech || now > s.speechExpiry) continue;
        const remaining = s.speechExpiry - now;
        ctx.globalAlpha = remaining < 400 ? remaining / 400 : 1;
        const text = s.lastSpeech.length > 32 ? s.lastSpeech.substring(0, 29) + '...' : s.lastSpeech;
        ctx.font = '7px monospace';
        const tw = ctx.measureText(text).width;
        const lw = ctx.measureText(s.label).width;
        const bw = Math.max(tw, lw) + 12, bh = 22;
        const bx = Math.round(s.x) - bw / 2, by = Math.round(s.y) - 44;
        ctx.fillStyle = 'rgba(10,10,10,0.92)';
        roundRect(bx, by, bw, bh, 3); ctx.fill();
        ctx.strokeStyle = '#333'; ctx.lineWidth = 1;
        roundRect(bx, by, bw, bh, 3); ctx.stroke();
        ctx.fillStyle = 'rgba(10,10,10,0.92)';
        ctx.beginPath();
        ctx.moveTo(Math.round(s.x) - 3, by + bh);
        ctx.lineTo(Math.round(s.x) + 3, by + bh);
        ctx.lineTo(Math.round(s.x), by + bh + 5);
        ctx.closePath(); ctx.fill();
        ctx.fillStyle = SPRITE_COLORS[s.sprite] || '#a78bfa';
        ctx.fillText(s.label, bx + 6, by + 9);
        ctx.fillStyle = '#ccc';
        ctx.fillText(text, bx + 6, by + 18);
        ctx.globalAlpha = 1;
      }

      // HUD overlay
      ctx.fillStyle = 'rgba(10,10,10,0.9)';
      ctx.fillRect(0, 0, W, 26);
      const pc = PHASE_COLORS[phase] || '#6b7280';
      ctx.fillStyle = pc; ctx.fillRect(0, 26, W, 2);
      ctx.font = '10px monospace'; ctx.textBaseline = 'middle';
      ctx.fillStyle = '#e5e5e5'; ctx.textAlign = 'start';
      ctx.fillText('Cycle ' + cycleNum, 8, 13);
      ctx.fillStyle = pc; ctx.textAlign = 'center';
      ctx.fillText(PHASE_LABELS[phase] || phase, W / 2, 13);
      const ac = Object.values(agents).filter(a => a.active).length;
      ctx.fillStyle = ac > 0 ? '#4ade80' : '#6b7280';
      ctx.textAlign = 'end';
      ctx.fillText(ac + '/' + AGENTS_DEF.length + ' agents', W - 8, 13);
      ctx.textAlign = 'start'; ctx.textBaseline = 'alphabetic';
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
    return function stop() { running = false; };
  }

  return { start: start };
}));
