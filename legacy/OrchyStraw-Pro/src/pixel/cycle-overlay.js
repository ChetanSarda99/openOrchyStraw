/**
 * Cycle Counter Overlay for Pixel Agents Visualization
 *
 * Renders a HUD overlay on the pixel art canvas showing:
 * - Current cycle number
 * - Cycle phase (workers_running, pm_updating, committing, done)
 * - Active agent count
 * - Elapsed time
 *
 * Designed to be injected into pixel-agents-standalone's Canvas renderer.
 *
 * Usage:
 *   const overlay = new CycleOverlay(canvas);
 *   overlay.update({ cycle: 5, phase: 'workers_running', agents: {...} });
 */

const PHASE_LABELS = {
  workers_running: 'Workers Active',
  pm_updating: 'PM Updating',
  committing: 'Committing',
  done: 'Cycle Complete',
  idle: 'Idle',
  unknown: '—',
};

const PHASE_COLORS = {
  workers_running: '#4ade80', // green
  pm_updating: '#facc15', // yellow
  committing: '#60a5fa', // blue
  done: '#a78bfa', // purple
  idle: '#6b7280', // gray
  unknown: '#6b7280',
};

class CycleOverlay {
  /**
   * @param {HTMLCanvasElement} canvas — The pixel agents canvas to draw on
   * @param {object} [opts]
   * @param {string} [opts.font] — Font for overlay text
   * @param {number} [opts.padding] — Padding from canvas edges
   */
  constructor(canvas, opts = {}) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.font = opts.font || '10px "JetBrains Mono", monospace';
    this.padding = opts.padding || 8;
    this.state = {
      cycle: 0,
      phase: 'unknown',
      startedAt: null,
      activeCount: 0,
      totalCount: 0,
    };
  }

  /**
   * Update overlay state from adapter data.
   * @param {object} data
   * @param {object} data.cycle — { cycle, phase, startedAt }
   * @param {object} data.agents — Agent states keyed by ID
   */
  update(data) {
    if (data.cycle) {
      this.state.cycle = data.cycle.cycle || 0;
      this.state.phase = data.cycle.phase || 'unknown';
      this.state.startedAt = data.cycle.startedAt || null;
    }
    if (data.agents) {
      const agentList = Object.values(data.agents);
      this.state.totalCount = agentList.length;
      this.state.activeCount = agentList.filter(a => a.active).length;
    }
  }

  /** Draw the overlay onto the canvas. Call this in the render loop. */
  draw() {
    const { ctx, padding, state } = this;
    const w = this.canvas.width;

    ctx.save();

    // Background bar
    ctx.fillStyle = 'rgba(10, 10, 10, 0.85)';
    ctx.fillRect(0, 0, w, 28);

    // Separator line
    ctx.fillStyle = PHASE_COLORS[state.phase] || PHASE_COLORS.unknown;
    ctx.fillRect(0, 28, w, 2);

    ctx.font = this.font;
    ctx.textBaseline = 'middle';
    const y = 14;

    // Cycle number
    ctx.fillStyle = '#e5e5e5';
    ctx.fillText(`Cycle ${state.cycle}`, padding, y);

    // Phase indicator (centered)
    const phaseLabel = PHASE_LABELS[state.phase] || state.phase;
    const phaseColor = PHASE_COLORS[state.phase] || PHASE_COLORS.unknown;
    ctx.fillStyle = phaseColor;
    const phaseWidth = ctx.measureText(phaseLabel).width;
    ctx.fillText(phaseLabel, (w - phaseWidth) / 2, y);

    // Agent counter (right-aligned)
    const counterText = `${state.activeCount}/${state.totalCount} agents`;
    ctx.fillStyle = state.activeCount > 0 ? '#4ade80' : '#6b7280';
    const counterWidth = ctx.measureText(counterText).width;
    ctx.fillText(counterText, w - counterWidth - padding, y);

    // Elapsed time (below phase, if started)
    if (state.startedAt) {
      const elapsed = this._formatElapsed(state.startedAt);
      ctx.fillStyle = '#9ca3af';
      ctx.font = '8px "JetBrains Mono", monospace';
      const elapsedWidth = ctx.measureText(elapsed).width;
      ctx.fillText(elapsed, (w - elapsedWidth) / 2, y + 16);
    }

    ctx.restore();
  }

  _formatElapsed(startedAt) {
    const start = new Date(startedAt).getTime();
    if (isNaN(start)) return '';
    const diff = Math.floor((Date.now() - start) / 1000);
    if (diff < 0) return '';
    const m = Math.floor(diff / 60);
    const s = diff % 60;
    return `${m}m ${s.toString().padStart(2, '0')}s`;
  }
}

/**
 * Speech bubble renderer for agent communication visualization.
 * Draws temporary speech bubbles above agent positions.
 */
class SpeechBubbleRenderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.bubbles = []; // { agentId, label, text, x, y, expiresAt }
  }

  /**
   * Add a speech bubble above an agent.
   * @param {string} agentId
   * @param {string} label — Agent display name
   * @param {string} text — Speech text
   * @param {number} x — Canvas x position
   * @param {number} y — Canvas y position
   * @param {number} [durationMs=3000] — How long to show
   */
  add(agentId, label, text, x, y, durationMs = 3000) {
    // Remove existing bubble for this agent
    this.bubbles = this.bubbles.filter(b => b.agentId !== agentId);

    this.bubbles.push({
      agentId,
      label,
      text: text.length > 40 ? text.substring(0, 37) + '...' : text,
      x,
      y,
      expiresAt: Date.now() + durationMs,
    });
  }

  /** Draw all active bubbles. Call in render loop after drawing characters. */
  draw() {
    const now = Date.now();
    this.bubbles = this.bubbles.filter(b => b.expiresAt > now);

    const { ctx } = this;
    ctx.save();

    for (const bubble of this.bubbles) {
      const opacity = Math.min(1, (bubble.expiresAt - now) / 500); // fade out
      ctx.globalAlpha = opacity;

      ctx.font = '8px "JetBrains Mono", monospace';
      const textWidth = ctx.measureText(bubble.text).width;
      const labelWidth = ctx.measureText(bubble.label).width;
      const maxWidth = Math.max(textWidth, labelWidth);
      const bw = maxWidth + 12;
      const bh = 28;
      const bx = bubble.x - bw / 2;
      const by = bubble.y - bh - 16;

      // Bubble background
      ctx.fillStyle = 'rgba(10, 10, 10, 0.9)';
      this._roundRect(bx, by, bw, bh, 4);
      ctx.fill();

      // Bubble border
      ctx.strokeStyle = '#404040';
      ctx.lineWidth = 1;
      this._roundRect(bx, by, bw, bh, 4);
      ctx.stroke();

      // Tail (triangle pointing down)
      ctx.fillStyle = 'rgba(10, 10, 10, 0.9)';
      ctx.beginPath();
      ctx.moveTo(bubble.x - 4, by + bh);
      ctx.lineTo(bubble.x + 4, by + bh);
      ctx.lineTo(bubble.x, by + bh + 6);
      ctx.closePath();
      ctx.fill();

      // Label (agent name)
      ctx.fillStyle = '#a78bfa';
      ctx.fillText(bubble.label, bx + 6, by + 10);

      // Text
      ctx.fillStyle = '#e5e5e5';
      ctx.fillText(bubble.text, bx + 6, by + 22);
    }

    ctx.restore();
  }

  _roundRect(x, y, w, h, r) {
    const { ctx } = this;
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
}

// Node.js / browser compatibility
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { CycleOverlay, SpeechBubbleRenderer, PHASE_LABELS, PHASE_COLORS };
}
