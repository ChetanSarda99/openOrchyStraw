#!/usr/bin/env node
/**
 * Test script for OrchyStraw Adapter
 *
 * Simulates a mini orchestration cycle by writing JSONL events to a temp
 * directory and verifying that the adapter correctly parses agents.conf,
 * tracks agent states, and emits the right events.
 *
 * Run: node src/pixel/test-adapter.js
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const {
  parseAgentsConf,
  AgentStateTracker,
  JSONLWatcher,
  OrchyStrawAdapter,
  TOOL_TO_ANIMATION,
  sanitizeText,
} = require('./orchystraw-adapter');

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

let passed = 0;
let failed = 0;

function assert(condition, msg) {
  if (condition) {
    passed++;
    console.log(`  ✓ ${msg}`);
  } else {
    failed++;
    console.log(`  ✗ ${msg}`);
  }
}

function section(name) {
  console.log(`\n── ${name} ──`);
}

// ---------------------------------------------------------------------------
// Test: parseAgentsConf
// ---------------------------------------------------------------------------

section('parseAgentsConf');

const projectRoot = path.resolve(__dirname, '..', '..');
const confPath = path.join(projectRoot, 'scripts', 'agents.conf');

const agents = parseAgentsConf(confPath);
const agentIds = Object.keys(agents);

assert(agentIds.length >= 9, `Parsed ${agentIds.length} agents from agents.conf (expected ≥9)`);
assert(agents['06-backend'] !== undefined, '06-backend exists');
assert(agents['03-pm'] !== undefined, '03-pm exists');
assert(agents['03-pm'].interval === 0, '03-pm interval is 0 (coordinator)');
assert(agents['06-backend'].interval === 1, '06-backend interval is 1 (every cycle)');
assert(agents['06-backend'].label === 'Backend Developer', '06-backend label correct');
assert(agents['08-pixel'].ownership.includes('src/pixel/'), '08-pixel owns src/pixel/');

// ---------------------------------------------------------------------------
// Test: character-map.json
// ---------------------------------------------------------------------------

section('character-map.json');

const mapPath = path.join(projectRoot, 'src', 'pixel', 'character-map.json');
assert(fs.existsSync(mapPath), 'character-map.json exists');

const charMap = JSON.parse(fs.readFileSync(mapPath, 'utf-8'));
assert(charMap.office && charMap.office.width === 800, 'Office dimensions set');
assert(Object.keys(charMap.desks).length >= 9, `${Object.keys(charMap.desks).length} desks defined`);
assert(Object.keys(charMap.agents).length >= 9, `${Object.keys(charMap.agents).length} agent chars defined`);

// Every agent in agents.conf should have a character mapping
for (const id of agentIds) {
  assert(charMap.agents[id] !== undefined, `${id} has character mapping`);
}

// PM should have a walkPath
assert(
  Array.isArray(charMap.agents['03-pm']?.walkPath),
  '03-pm has walkPath for desk-to-desk animation'
);

// ---------------------------------------------------------------------------
// Test: AgentStateTracker
// ---------------------------------------------------------------------------

section('AgentStateTracker');

const tracker = new AgentStateTracker(agents, charMap);
const initialStates = tracker.getAll();

assert(Object.keys(initialStates).length === agentIds.length, 'All agents initialized');
assert(initialStates['06-backend'].animation === 'idle', 'Agents start idle');
assert(initialStates['06-backend'].active === false, 'Agents start inactive');

// Simulate: backend starts typing
const typingEvent = {
  type: 'assistant',
  message: {
    role: 'assistant',
    content: [{ type: 'tool_use', name: 'write_file', input: { path: 'src/core/engine.sh' } }],
  },
};

const afterTyping = tracker.processEvent('06-backend', typingEvent);
assert(afterTyping.animation === 'typing', 'write_file → typing animation');
assert(afterTyping.active === true, 'Agent now active');
assert(afterTyping.lastFile === 'src/core/engine.sh', 'Tracks last file path');

// Simulate: backend reads shared context
const readEvent = {
  type: 'assistant',
  message: {
    role: 'assistant',
    content: [{ type: 'tool_use', name: 'read_file', input: { path: 'prompts/00-shared-context/context.md' } }],
  },
};

const afterReading = tracker.processEvent('06-backend', readEvent);
assert(afterReading.animation === 'reading', 'read_file → reading animation');

// Simulate: backend runs tests
const bashEvent = {
  type: 'assistant',
  message: {
    role: 'assistant',
    content: [{ type: 'tool_use', name: 'bash', input: { command: 'bash tests/run.sh' } }],
  },
};

const afterBash = tracker.processEvent('06-backend', bashEvent);
assert(afterBash.animation === 'running', 'bash → running animation');

// Simulate: PM says something (speech bubble)
const speechEvent = {
  type: 'assistant',
  message: {
    role: 'assistant',
    content: [{ type: 'text', text: 'Updating 06-backend...' }],
  },
};

const afterSpeech = tracker.processEvent('03-pm', speechEvent);
assert(afterSpeech.animation === 'talking', 'text content → talking animation');
assert(afterSpeech.lastSpeech === 'Updating 06-backend...', 'Speech text captured');

// Simulate: turn end
const endEvent = {
  type: 'result',
  subtype: 'success',
  result: 'done',
  session_id: 'orchystraw-06-backend',
};

const afterEnd = tracker.processEvent('06-backend', endEvent);
assert(afterEnd.animation === 'walking', 'result → walking animation (transitioning to idle)');
assert(afterEnd.active === false, 'Agent no longer active after turn end');

// ---------------------------------------------------------------------------
// Test: TOOL_TO_ANIMATION mapping
// ---------------------------------------------------------------------------

section('TOOL_TO_ANIMATION mapping');

assert(TOOL_TO_ANIMATION.write_file === 'typing', 'write_file → typing');
assert(TOOL_TO_ANIMATION.read_file === 'reading', 'read_file → reading');
assert(TOOL_TO_ANIMATION.grep === 'reading', 'grep → reading');
assert(TOOL_TO_ANIMATION.bash === 'running', 'bash → running');
assert(TOOL_TO_ANIMATION.list_files === 'reading', 'list_files → reading');

// ---------------------------------------------------------------------------
// Test: XSS sanitization (Phase 2.5)
// ---------------------------------------------------------------------------

section('XSS sanitization');

assert(sanitizeText('<script>alert(1)</script>') === '&lt;script&gt;alert(1)&lt;/script&gt;', 'sanitizeText escapes script tags');
assert(sanitizeText('"onload="alert(1)') === '&quot;onload=&quot;alert(1)', 'sanitizeText escapes double quotes');
assert(sanitizeText("it's a test") === "it&#x27;s a test", 'sanitizeText escapes single quotes');
assert(sanitizeText('a & b < c') === 'a &amp; b &lt; c', 'sanitizeText escapes ampersand + angle bracket');
assert(sanitizeText('') === '', 'sanitizeText handles empty string');
assert(sanitizeText(null) === '', 'sanitizeText handles null');
assert(sanitizeText(42) === '', 'sanitizeText handles non-string');

// XSS in file path — should be sanitized by state tracker
const xssFileEvent = {
  type: 'assistant',
  message: {
    role: 'assistant',
    content: [{ type: 'tool_use', name: 'write_file', input: { path: '<img src=x onerror=alert(1)>' } }],
  },
};
const afterXssFile = tracker.processEvent('06-backend', xssFileEvent);
assert(
  afterXssFile.lastFile === '&lt;img src=x onerror=alert(1)&gt;',
  'File paths are HTML-escaped in state tracker'
);

// XSS in speech text — should be sanitized by state tracker
const xssSpeechEvent = {
  type: 'assistant',
  message: {
    role: 'assistant',
    content: [{ type: 'text', text: '<b>bold</b> & "quoted"' }],
  },
};
const afterXssSpeech = tracker.processEvent('03-pm', xssSpeechEvent);
assert(
  afterXssSpeech.lastSpeech === '&lt;b&gt;bold&lt;/b&gt; &amp; &quot;quoted&quot;',
  'Speech text is HTML-escaped in state tracker'
);

// XSS in agent label — sanitized during initialization
assert(
  !initialStates['06-backend'].label.includes('<'),
  'Agent labels are sanitized on init'
);

// ---------------------------------------------------------------------------
// Test: JSONL watcher (write events to temp dir, verify detection)
// ---------------------------------------------------------------------------

section('JSONLWatcher (live file test)');

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'orchystraw-test-'));
const agentDir = path.join(tmpDir, '06-backend');
fs.mkdirSync(agentDir, { recursive: true });
const sessionFile = path.join(agentDir, 'session.jsonl');

// Write initial event
fs.writeFileSync(sessionFile, JSON.stringify(typingEvent) + '\n');

const watcher = new JSONLWatcher(tmpDir);
let receivedEvents = [];

watcher.on('event', (data) => {
  receivedEvents.push(data);
});

watcher.start();

// Give watcher time to pick up existing content and file changes
setTimeout(() => {
  // Write another event
  fs.appendFileSync(sessionFile, JSON.stringify(readEvent) + '\n');

  setTimeout(() => {
    watcher.stop();

    assert(receivedEvents.length >= 1, `Watcher received ${receivedEvents.length} events (expected ≥1)`);
    if (receivedEvents.length > 0) {
      assert(receivedEvents[0].agentId === '06-backend', 'Correct agent ID from watcher');
    }

    // Cleanup temp dir
    fs.rmSync(tmpDir, { recursive: true, force: true });

    // ── Summary ──
    console.log(`\n══ Results: ${passed} passed, ${failed} failed ══\n`);
    process.exit(failed > 0 ? 1 : 0);
  }, 500);
}, 300);
