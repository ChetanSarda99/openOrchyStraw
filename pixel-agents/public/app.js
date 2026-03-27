/**
 * OrchyStraw Pixel Agents — Client-Side Renderer
 *
 * Connects to the server via WebSocket, receives agent state updates,
 * and renders the pixel art office with animated characters.
 */

// ---------------------------------------------------------------------------
// Canvas setup
// ---------------------------------------------------------------------------

const canvas = document.getElementById('office');
const ctx = canvas.getContext('2d');
const W = canvas.width;
const H = canvas.height;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

let agents = {};
let characterMap = null;
let cycleState = { cycle: 0, phase: 'unknown', startedAt: null };
let speechBubbles = []; // { agentId, label, text, x, y, expiresAt }

// Animation frame counter
let frame = 0;

// Colors for agent sprites (keyed by sprite name)
const SPRITE_COLORS = {
  suit:      '#a78bfa', // CEO — purple
  glasses:   '#60a5fa', // CTO — blue
  clipboard: '#facc15', // PM/HR — yellow
  hoodie:    '#4ade80', // Backend — green
  artist:    '#f472b6', // Pixel — pink
  magnifier: '#fb923c', // QA — orange
  shield:    '#ef4444', // Security — red
  palette:   '#2dd4bf', // Web — teal
};

// Animation state indicators
const ANIM_ICONS = {
  typing:  '\u270D',  // writing hand
  reading: '\uD83D\uDCD6', // open book
  running: '\u26A1',  // lightning
  walking: '\uD83D\uDEB6', // walking
  talking: '\uD83D\uDCAC', // speech
  idle:    '\u00B7',  // dot
  error:   '\u26A0',  // warning
};

// ---------------------------------------------------------------------------
// Phase labels + colors (matches cycle-overlay.js)
// ---------------------------------------------------------------------------

const PHASE_LABELS = {
  workers_running: 'Workers Active',
  pm_updating:     'PM Updating',
  committing:      'Committing',
  done:            'Cycle Complete',
  idle:            'Idle',
  unknown:         '\u2014',
};

const PHASE_COLORS = {
  workers_running: '#4ade80',
  pm_updating:     '#facc15',
  committing:      '#60a5fa',
  done:            '#a78bfa',
  idle:            '#6b7280',
  unknown:         '#6b7280',
};

// ---------------------------------------------------------------------------
// WebSocket connection
// ---------------------------------------------------------------------------

const statusEl = document.getElementById('ws-status');
const agentListEl = document.getElementById('agent-list');

function connect() {
  const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
  const ws = new WebSocket(`${protocol}//${location.host}`);

  ws.onopen = () => {
    statusEl.textContent = 'Connected';
    statusEl.className = 'status connected';
  };

  ws.onclose = () => {
    statusEl.textContent = 'Disconnected — reconnecting...';
    statusEl.className = 'status';
    setTimeout(connect, 2000);
  };

  ws.onmessage = (evt) => {
    const msg = JSON.parse(evt.data);

    if (msg.type === 'orchystraw:init') {
      agents = msg.agents || {};
      characterMap = msg.characterMap || null;
      cycleState = msg.cycle || cycleState;
      updateAgentList();
    }

    if (msg.type === 'orchystraw:agent_update') {
      agents[msg.agentId] = msg.state;
      updateAgentList();
    }

    if (msg.type === 'orchystraw:speech') {
      const state = agents[msg.agentId];
      if (state) {
        addSpeechBubble(msg.agentId, msg.label, msg.text, state.position.x, state.position.y);
      }
    }
  };
}

connect();

// ---------------------------------------------------------------------------
// Agent list (HTML badges below canvas)
// ---------------------------------------------------------------------------

function updateAgentList() {
  agentListEl.innerHTML = '';
  for (const [id, state] of Object.entries(agents)) {
    const badge = document.createElement('div');
    badge.className = 'agent-badge' + (state.active ? ' active' : '');
    const icon = ANIM_ICONS[state.animation] || '';
    badge.textContent = state.label || id;
    const animSpan = document.createElement('span');
    animSpan.className = 'anim';
    animSpan.textContent = icon;
    badge.appendChild(animSpan);
    agentListEl.appendChild(badge);
  }
}

// ---------------------------------------------------------------------------
// Speech bubbles
// ---------------------------------------------------------------------------

function addSpeechBubble(agentId, label, text, x, y) {
  speechBubbles = speechBubbles.filter(b => b.agentId !== agentId);
  speechBubbles.push({
    agentId,
    label,
    text: text.length > 35 ? text.substring(0, 32) + '...' : text,
    x, y,
    expiresAt: Date.now() + 4000,
  });
}

// ---------------------------------------------------------------------------
// Render loop
// ---------------------------------------------------------------------------

function render() {
  frame++;
  ctx.clearRect(0, 0, W, H);

  drawFloor();
  drawDesks();
  drawAgents();
  drawSpeechBubbles();
  drawOverlay();

  requestAnimationFrame(render);
}

// ---------------------------------------------------------------------------
// Drawing: floor grid
// ---------------------------------------------------------------------------

function drawFloor() {
  ctx.fillStyle = '#111111';
  ctx.fillRect(0, 0, W, H);

  // Subtle grid
  ctx.strokeStyle = '#1a1a1a';
  ctx.lineWidth = 1;
  for (let x = 0; x < W; x += 16) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, H);
    ctx.stroke();
  }
  for (let y = 0; y < H; y += 16) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(W, y);
    ctx.stroke();
  }
}

// ---------------------------------------------------------------------------
// Drawing: desks
// ---------------------------------------------------------------------------

function drawDesks() {
  if (!characterMap) return;

  for (const [name, desk] of Object.entries(characterMap.desks)) {
    if (name === 'idle') continue; // break area, no visible desk

    // Desk surface
    ctx.fillStyle = '#2a2a2a';
    ctx.fillRect(desk.x - 24, desk.y - 8, 48, 24);

    // Desk border
    ctx.strokeStyle = '#3a3a3a';
    ctx.lineWidth = 1;
    ctx.strokeRect(desk.x - 24, desk.y - 8, 48, 24);

    // Monitor (small rectangle on desk)
    ctx.fillStyle = '#0f0f0f';
    ctx.fillRect(desk.x - 8, desk.y - 14, 16, 8);
    ctx.strokeStyle = '#404040';
    ctx.strokeRect(desk.x - 8, desk.y - 14, 16, 8);

    // Label
    ctx.fillStyle = '#404040';
    ctx.font = '7px monospace';
    ctx.textAlign = 'center';
    ctx.fillText(desk.label || name, desk.x, desk.y + 28);
    ctx.textAlign = 'start';
  }
}

// ---------------------------------------------------------------------------
// Drawing: agents (pixel art characters)
// ---------------------------------------------------------------------------

function drawAgents() {
  for (const [id, state] of Object.entries(agents)) {
    const charInfo = characterMap?.agents?.[id];
    const color = SPRITE_COLORS[charInfo?.sprite] || '#6b7280';
    const pos = state.position || { x: 400, y: 400 };

    // Animation offsets
    let bobY = 0;
    if (state.animation === 'typing') {
      bobY = Math.sin(frame * 0.3) * 1;
    } else if (state.animation === 'walking') {
      bobY = Math.abs(Math.sin(frame * 0.2)) * 2;
    } else if (state.animation === 'running') {
      bobY = Math.abs(Math.sin(frame * 0.5)) * 3;
    }

    const x = pos.x;
    const y = pos.y + bobY;

    // Body (pixel art style — blocky)
    ctx.fillStyle = color;
    ctx.fillRect(x - 4, y - 12, 8, 10); // torso

    // Head
    ctx.fillStyle = '#e5c9a0'; // skin tone
    ctx.fillRect(x - 3, y - 18, 6, 6);

    // Eyes (blink every ~120 frames)
    if (frame % 120 > 5) {
      ctx.fillStyle = '#1a1a1a';
      ctx.fillRect(x - 2, y - 16, 2, 2);
      ctx.fillRect(x + 1, y - 16, 2, 2);
    }

    // Legs
    ctx.fillStyle = '#333333';
    ctx.fillRect(x - 3, y - 2, 3, 4);
    ctx.fillRect(x + 1, y - 2, 3, 4);

    // Activity indicator (glow when active)
    if (state.active) {
      ctx.shadowColor = color;
      ctx.shadowBlur = 8;
      ctx.fillStyle = color;
      ctx.fillRect(x - 1, y - 20, 2, 2);
      ctx.shadowBlur = 0;
    }

    // Agent label
    ctx.fillStyle = state.active ? color : '#4a4a4a';
    ctx.font = '7px monospace';
    ctx.textAlign = 'center';
    ctx.fillText(state.label || id, x, y + 10);
    ctx.textAlign = 'start';
  }
}

// ---------------------------------------------------------------------------
// Drawing: speech bubbles
// ---------------------------------------------------------------------------

function drawSpeechBubbles() {
  const now = Date.now();
  speechBubbles = speechBubbles.filter(b => b.expiresAt > now);

  for (const bubble of speechBubbles) {
    const fadeMs = 500;
    const remaining = bubble.expiresAt - now;
    const opacity = remaining < fadeMs ? remaining / fadeMs : 1;
    ctx.globalAlpha = opacity;

    ctx.font = '7px monospace';
    const textWidth = ctx.measureText(bubble.text).width;
    const labelWidth = ctx.measureText(bubble.label).width;
    const bw = Math.max(textWidth, labelWidth) + 10;
    const bh = 22;
    const bx = bubble.x - bw / 2;
    const by = bubble.y - 42;

    // Background
    ctx.fillStyle = 'rgba(10, 10, 10, 0.92)';
    roundRect(bx, by, bw, bh, 3);
    ctx.fill();

    // Border
    ctx.strokeStyle = '#404040';
    ctx.lineWidth = 1;
    roundRect(bx, by, bw, bh, 3);
    ctx.stroke();

    // Tail
    ctx.fillStyle = 'rgba(10, 10, 10, 0.92)';
    ctx.beginPath();
    ctx.moveTo(bubble.x - 3, by + bh);
    ctx.lineTo(bubble.x + 3, by + bh);
    ctx.lineTo(bubble.x, by + bh + 5);
    ctx.closePath();
    ctx.fill();

    // Label
    ctx.fillStyle = '#a78bfa';
    ctx.fillText(bubble.label, bx + 5, by + 9);

    // Text
    ctx.fillStyle = '#e5e5e5';
    ctx.fillText(bubble.text, bx + 5, by + 18);

    ctx.globalAlpha = 1;
  }
}

function roundRect(x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r);
  ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x + r, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
}

// ---------------------------------------------------------------------------
// Drawing: HUD overlay (cycle counter, phase, agents)
// ---------------------------------------------------------------------------

function drawOverlay() {
  // Background bar
  ctx.fillStyle = 'rgba(10, 10, 10, 0.85)';
  ctx.fillRect(0, 0, W, 26);

  // Phase color separator
  const phaseColor = PHASE_COLORS[cycleState.phase] || PHASE_COLORS.unknown;
  ctx.fillStyle = phaseColor;
  ctx.fillRect(0, 26, W, 2);

  ctx.font = '10px monospace';
  ctx.textBaseline = 'middle';
  const y = 13;

  // Cycle number (left)
  ctx.fillStyle = '#e5e5e5';
  ctx.textAlign = 'start';
  ctx.fillText('Cycle ' + cycleState.cycle, 8, y);

  // Phase label (center)
  const phaseLabel = PHASE_LABELS[cycleState.phase] || cycleState.phase;
  ctx.fillStyle = phaseColor;
  ctx.textAlign = 'center';
  ctx.fillText(phaseLabel, W / 2, y);

  // Agent counter (right)
  const agentList = Object.values(agents);
  const activeCount = agentList.filter(a => a.active).length;
  const totalCount = agentList.length;
  ctx.fillStyle = activeCount > 0 ? '#4ade80' : '#6b7280';
  ctx.textAlign = 'end';
  ctx.fillText(activeCount + '/' + totalCount + ' agents', W - 8, y);

  ctx.textAlign = 'start';
  ctx.textBaseline = 'alphabetic';
}

// ---------------------------------------------------------------------------
// Start render loop
// ---------------------------------------------------------------------------

requestAnimationFrame(render);
