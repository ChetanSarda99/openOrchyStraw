/**
 * OrchyStraw Adapter for Pixel Agents Standalone
 *
 * Replaces the default Claude Code JSONL watcher with an OrchyStraw-aware
 * adapter that reads our synthetic JSONL events and agents.conf, then emits
 * WebSocket events for the Pixel Agents visualization.
 *
 * Usage:
 *   const adapter = require('./orchystraw-adapter');
 *   adapter.start({ server, configPath, sessionDir });
 *
 * This is Phase 2 of the Pixel Agents integration.
 * Phase 1 (emit-jsonl.sh) writes the JSONL files.
 * This adapter reads them and drives the visualization.
 */

const fs = require('fs');
const path = require('path');
const { EventEmitter } = require('events');

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const DEFAULT_SESSION_DIR = path.join(
  process.env.HOME || process.env.USERPROFILE || '~',
  '.claude', 'projects', 'orchystraw'
);

const TOOL_TO_ANIMATION = {
  write_file: 'typing',
  read_file: 'reading',
  grep: 'reading',
  list_files: 'reading',
  bash: 'running',
};

// ---------------------------------------------------------------------------
// XSS sanitization
// ---------------------------------------------------------------------------

function sanitizeText(str) {
  if (typeof str !== 'string') return '';
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;');
}

// ---------------------------------------------------------------------------
// agents.conf parser
// ---------------------------------------------------------------------------

/**
 * Parse agents.conf into a map of agent configurations.
 * Format: id | prompt_path | ownership | interval | label
 */
function parseAgentsConf(confPath) {
  const agents = {};
  if (!fs.existsSync(confPath)) return agents;

  const lines = fs.readFileSync(confPath, 'utf-8').split('\n');
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;

    const parts = trimmed.split('|').map(s => s.trim());
    if (parts.length < 5) continue;

    const [id, promptPath, ownership, interval, label] = parts;
    agents[id] = {
      id,
      promptPath,
      ownership: ownership.split(/\s+/),
      interval: parseInt(interval, 10),
      label,
    };
  }
  return agents;
}

// ---------------------------------------------------------------------------
// JSONL file watcher
// ---------------------------------------------------------------------------

class JSONLWatcher extends EventEmitter {
  constructor(sessionDir) {
    super();
    this.sessionDir = sessionDir;
    this.watchers = new Map();
    this.offsets = new Map(); // track read position per file
  }

  start() {
    if (!fs.existsSync(this.sessionDir)) {
      fs.mkdirSync(this.sessionDir, { recursive: true });
    }

    // Watch for new agent directories
    this._dirWatcher = fs.watch(this.sessionDir, (eventType, filename) => {
      if (!filename) return;
      const agentDir = path.join(this.sessionDir, filename);
      if (fs.existsSync(agentDir) && fs.statSync(agentDir).isDirectory()) {
        this._watchAgent(filename);
      }
    });

    // Watch existing agent directories
    try {
      const entries = fs.readdirSync(this.sessionDir, { withFileTypes: true });
      for (const entry of entries) {
        if (entry.isDirectory()) {
          this._watchAgent(entry.name);
        }
      }
    } catch (_) {
      // sessionDir may be empty
    }
  }

  _watchAgent(agentId) {
    if (this.watchers.has(agentId)) return;

    const sessionFile = path.join(this.sessionDir, agentId, 'session.jsonl');
    if (!fs.existsSync(sessionFile)) {
      // Wait for file to appear
      const dirPath = path.join(this.sessionDir, agentId);
      const dirWatcher = fs.watch(dirPath, (_, fname) => {
        if (fname === 'session.jsonl' && fs.existsSync(sessionFile)) {
          dirWatcher.close();
          this._watchSessionFile(agentId, sessionFile);
        }
      });
      this.watchers.set(agentId + ':dir', dirWatcher);
      return;
    }

    this._watchSessionFile(agentId, sessionFile);
  }

  _watchSessionFile(agentId, filePath) {
    if (this.watchers.has(agentId)) return;

    this.offsets.set(filePath, 0);

    // Read any existing content
    this._readNewLines(agentId, filePath);

    const watcher = fs.watch(filePath, () => {
      this._readNewLines(agentId, filePath);
    });
    this.watchers.set(agentId, watcher);
  }

  _readNewLines(agentId, filePath) {
    try {
      const stat = fs.statSync(filePath);
      const offset = this.offsets.get(filePath) || 0;

      if (stat.size <= offset) {
        // File was truncated (new cycle) — reset offset
        if (stat.size < offset) {
          this.offsets.set(filePath, 0);
        }
        return;
      }

      const fd = fs.openSync(filePath, 'r');
      const buf = Buffer.alloc(stat.size - offset);
      fs.readSync(fd, buf, 0, buf.length, offset);
      fs.closeSync(fd);

      this.offsets.set(filePath, stat.size);

      const newData = buf.toString('utf-8');
      const lines = newData.split('\n').filter(l => l.trim());

      for (const line of lines) {
        try {
          const event = JSON.parse(line);
          this.emit('event', { agentId, event });
        } catch (_) {
          // skip malformed lines
        }
      }
    } catch (_) {
      // file may have been deleted between cycles
    }
  }

  stop() {
    for (const [, watcher] of this.watchers) {
      watcher.close();
    }
    this.watchers.clear();
    if (this._dirWatcher) {
      this._dirWatcher.close();
      this._dirWatcher = null;
    }
  }
}

// ---------------------------------------------------------------------------
// Agent state tracker
// ---------------------------------------------------------------------------

class AgentStateTracker {
  constructor(agentsConf, characterMap) {
    this.agents = agentsConf;
    this.characterMap = characterMap;
    this.states = {};

    // Initialize all agents as idle
    for (const id of Object.keys(agentsConf)) {
      this.states[id] = {
        id,
        label: sanitizeText(agentsConf[id].label),
        animation: 'idle',
        position: this._getIdleSpot(id),
        desk: this._getDesk(id),
        lastFile: null,
        lastSpeech: null,
        active: false,
      };
    }
  }

  _getDesk(agentId) {
    const charInfo = this.characterMap?.agents?.[agentId];
    if (!charInfo) return null;
    const deskName = charInfo.desk;
    return this.characterMap?.desks?.[deskName] || null;
  }

  _getIdleSpot(agentId) {
    return this.characterMap?.agents?.[agentId]?.idleSpot || { x: 400, y: 400 };
  }

  processEvent(agentId, event) {
    if (!this.states[agentId]) {
      this.states[agentId] = {
        id: agentId,
        label: agentId,
        animation: 'idle',
        position: { x: 400, y: 400 },
        desk: null,
        lastFile: null,
        lastSpeech: null,
        active: false,
      };
    }

    const state = this.states[agentId];

    if (event.type === 'assistant' && event.message?.content) {
      state.active = true;
      state.position = state.desk || state.position;

      for (const block of event.message.content) {
        if (block.type === 'tool_use') {
          state.animation = TOOL_TO_ANIMATION[block.name] || 'running';
          const rawFile = block.input?.path || block.input?.command || null;
          state.lastFile = rawFile ? sanitizeText(rawFile) : null;
        } else if (block.type === 'text') {
          state.animation = 'talking';
          state.lastSpeech = sanitizeText(block.text);
        }
      }
    } else if (event.type === 'result') {
      state.animation = 'walking';
      state.active = false;
      // After a brief walking animation, agent returns to idle spot
      setTimeout(() => {
        state.animation = 'idle';
        state.position = this._getIdleSpot(agentId);
      }, 2000);
    }

    return { ...state };
  }

  getAll() {
    return { ...this.states };
  }
}

// ---------------------------------------------------------------------------
// Cycle state reader
// ---------------------------------------------------------------------------

/**
 * Read cycle state from the orchestrator's state file.
 * Returns { cycle, phase, startedAt } or defaults.
 */
function readCycleState(projectRoot) {
  const candidates = [
    path.join(projectRoot, '.orchystraw', 'cycle-state.json'),
    path.join(projectRoot, 'scripts', 'cycle-state.json'),
  ];

  for (const file of candidates) {
    if (fs.existsSync(file)) {
      try {
        return JSON.parse(fs.readFileSync(file, 'utf-8'));
      } catch (_) {
        continue;
      }
    }
  }

  return { cycle: 0, phase: 'unknown', startedAt: null };
}

// ---------------------------------------------------------------------------
// Main adapter
// ---------------------------------------------------------------------------

class OrchyStrawAdapter extends EventEmitter {
  /**
   * @param {object} opts
   * @param {string} opts.projectRoot   — Path to OrchyStraw project root
   * @param {string} [opts.sessionDir]  — Override JSONL session dir
   * @param {string} [opts.configPath]  — Override agents.conf path
   */
  constructor(opts = {}) {
    super();
    this.projectRoot = opts.projectRoot || process.cwd();
    this.sessionDir = opts.sessionDir || DEFAULT_SESSION_DIR;
    this.configPath = opts.configPath || path.join(this.projectRoot, 'scripts', 'agents.conf');

    // Load character map
    const mapPath = path.join(this.projectRoot, 'src', 'pixel', 'character-map.json');
    this.characterMap = fs.existsSync(mapPath)
      ? JSON.parse(fs.readFileSync(mapPath, 'utf-8'))
      : null;

    // Parse agents.conf
    this.agentsConf = parseAgentsConf(this.configPath);

    // State tracker
    this.stateTracker = new AgentStateTracker(this.agentsConf, this.characterMap);

    // JSONL watcher
    this.watcher = new JSONLWatcher(this.sessionDir);
  }

  start() {
    this.watcher.on('event', ({ agentId, event }) => {
      const newState = this.stateTracker.processEvent(agentId, event);
      this.emit('agent:update', { agentId, state: newState, event });
    });

    this.watcher.start();
    this.emit('adapter:started', {
      agents: Object.keys(this.agentsConf),
      sessionDir: this.sessionDir,
    });
  }

  stop() {
    this.watcher.stop();
    this.emit('adapter:stopped');
  }

  /** Get current state of all agents for initial WebSocket handshake. */
  getState() {
    return {
      cycle: readCycleState(this.projectRoot),
      agents: this.stateTracker.getAll(),
      characterMap: this.characterMap,
    };
  }
}

// ---------------------------------------------------------------------------
// WebSocket bridge — plugs into pixel-agents-standalone's Express server
// ---------------------------------------------------------------------------

/**
 * Attach OrchyStraw adapter to an existing WebSocket server.
 *
 * @param {WebSocket.Server} wss — The WebSocket server from pixel-agents-standalone
 * @param {object} opts — Same options as OrchyStrawAdapter constructor
 */
function attachToServer(wss, opts = {}) {
  const adapter = new OrchyStrawAdapter(opts);

  // Broadcast helper
  function broadcast(type, data) {
    const msg = JSON.stringify({ type, ...data });
    for (const client of wss.clients) {
      if (client.readyState === 1) { // WebSocket.OPEN
        client.send(msg);
      }
    }
  }

  // On new client connection, send full state
  wss.on('connection', (ws) => {
    const state = adapter.getState();
    ws.send(JSON.stringify({ type: 'orchystraw:init', ...state }));
  });

  // Broadcast agent updates
  adapter.on('agent:update', ({ agentId, state, event }) => {
    broadcast('orchystraw:agent_update', { agentId, state });

    // Speech bubbles get their own event for overlay rendering
    if (state.animation === 'talking' && state.lastSpeech) {
      broadcast('orchystraw:speech', {
        agentId,
        label: state.label,
        text: sanitizeText(state.lastSpeech),
      });
    }
  });

  adapter.start();
  return adapter;
}

// ---------------------------------------------------------------------------
// Exports
// ---------------------------------------------------------------------------

module.exports = {
  OrchyStrawAdapter,
  JSONLWatcher,
  AgentStateTracker,
  parseAgentsConf,
  readCycleState,
  attachToServer,
  sanitizeText,
  TOOL_TO_ANIMATION,
  DEFAULT_SESSION_DIR,
};
