#!/usr/bin/env node
/**
 * Full Pipeline Integration Test — Bash Emitter → Node Adapter → WebSocket
 *
 * Proves that JSONL events written by emit-jsonl.sh are correctly detected,
 * parsed, and broadcast by the OrchyStraw adapter + server.
 *
 * Flow:
 *   1. Start pixel-agents server on random port with temp session dir
 *   2. Connect WebSocket client
 *   3. Shell out to bash to source emit-jsonl.sh and emit a full agent lifecycle
 *   4. Verify WebSocket receives correct agent_update and speech messages
 *   5. Test multi-agent scenario (backend + PM visit)
 *
 * Run: node src/pixel/test-pipeline.js
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const http = require('http');
const { execSync } = require('child_process');

// Resolve dependencies from pixel-agents/node_modules
const PROJECT_ROOT_EARLY = path.resolve(__dirname, '../..');
const PIXEL_AGENTS_DIR = path.join(PROJECT_ROOT_EARLY, 'pixel-agents');
const express = require(path.join(PIXEL_AGENTS_DIR, 'node_modules', 'express'));
const { WebSocketServer, WebSocket } = require(path.join(PIXEL_AGENTS_DIR, 'node_modules', 'ws'));
const { attachToServer, sanitizeText } = require('./orchystraw-adapter');

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
// Helper: run bash emitter commands via shell
// ---------------------------------------------------------------------------

const PROJECT_ROOT = path.resolve(__dirname, '../..');
const EMITTER_PATH = path.join(PROJECT_ROOT, 'src/pixel/emit-jsonl.sh');

function emitViaBash(sessionDir, commands) {
  const script = `
    export PIXEL_SESSION_DIR="${sessionDir}"
    export PIXEL_ENABLED=1
    source "${EMITTER_PATH}"
    ${commands}
  `;
  execSync(`bash -c '${script.replace(/'/g, "'\\''")}'`, {
    cwd: PROJECT_ROOT,
    stdio: 'pipe',
  });
}

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'orchystraw-pipeline-'));

const app = express();
app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', mode: 'orchystraw-pipeline-test' });
});

const server = http.createServer(app);
const wss = new WebSocketServer({ server });

const adapter = attachToServer(wss, {
  projectRoot: PROJECT_ROOT,
  sessionDir: tmpDir,
});

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

server.listen(0, () => {
  const port = server.address().port;
  console.log(`Pipeline test server on port ${port}`);
  console.log(`Session dir: ${tmpDir}`);

  // Connect WebSocket
  const ws = new WebSocket(`ws://localhost:${port}`);
  const messages = [];

  ws.on('message', (raw) => {
    messages.push(JSON.parse(raw.toString()));
  });

  ws.on('open', () => {
    // Wait for init message, then start tests
    setTimeout(() => runTests(ws, messages, port), 300);
  });

  ws.on('error', (err) => {
    console.error('WebSocket error:', err.message);
    cleanup();
  });
});

function runTests(ws, messages, port) {
  // ── Test 1: Init message received ──
  section('WebSocket init');
  const inits = messages.filter(m => m.type === 'orchystraw:init');
  assert(inits.length === 1, 'Received orchystraw:init message');
  if (inits.length > 0) {
    assert(inits[0].cycle !== undefined, 'Init includes cycle state');
  }

  // Clear messages for next phase
  messages.length = 0;

  // ── Test 2: Bash emitter → agent lifecycle ──
  section('Bash emitter: backend agent full lifecycle');

  emitViaBash(tmpDir, `
    pixel_init
    pixel_agent_start "06-backend" "prompts/06-backend/06-backend.txt"
    pixel_agent_read_context "06-backend"
    pixel_agent_coding "06-backend" "src/core/engine.sh"
    pixel_agent_running "06-backend" "bash tests/core/run-tests.sh"
    pixel_agent_done "06-backend" "Completed integration — 32/32 tests pass"
  `);

  // Verify JSONL files were created by bash
  const backendSession = path.join(tmpDir, '06-backend', 'session.jsonl');
  assert(fs.existsSync(backendSession), 'Bash emitter created 06-backend/session.jsonl');

  const lines = fs.readFileSync(backendSession, 'utf-8').split('\n').filter(l => l.trim());
  assert(lines.length >= 6, `JSONL has ${lines.length} events (expected ≥6)`);

  // Verify each line is valid JSON
  let allValid = true;
  for (const line of lines) {
    try {
      JSON.parse(line);
    } catch (_) {
      allValid = false;
    }
  }
  assert(allValid, 'All JSONL lines are valid JSON');

  // Verify event types
  const events = lines.map(l => JSON.parse(l));
  const toolNames = events
    .filter(e => e.type === 'assistant' && e.message?.content)
    .flatMap(e => e.message.content)
    .filter(b => b.type === 'tool_use')
    .map(b => b.name);

  assert(toolNames.includes('read_file'), 'Events include read_file (prompt read + context read)');
  assert(toolNames.includes('write_file'), 'Events include write_file (coding + context update)');
  assert(toolNames.includes('bash'), 'Events include bash (running tests)');

  const speechBlocks = events
    .filter(e => e.type === 'assistant' && e.message?.content)
    .flatMap(e => e.message.content)
    .filter(b => b.type === 'text');
  assert(speechBlocks.length >= 1, `Speech events: ${speechBlocks.length} (expected ≥1)`);

  const resultEvents = events.filter(e => e.type === 'result');
  assert(resultEvents.length === 1, 'Exactly 1 result/end event');

  // Wait for adapter to detect and broadcast
  setTimeout(() => {
    section('Adapter broadcast verification');

    const updates = messages.filter(m => m.type === 'orchystraw:agent_update');
    const speeches = messages.filter(m => m.type === 'orchystraw:speech');

    assert(updates.length >= 1, `Received ${updates.length} agent_update broadcasts`);

    const backendUpdates = updates.filter(m => m.agentId === '06-backend');
    assert(backendUpdates.length >= 1, `Backend agent updates: ${backendUpdates.length}`);

    if (backendUpdates.length > 0) {
      const animations = backendUpdates.map(m => m.state?.animation);
      assert(animations.includes('typing'), 'Adapter detected typing animation');
      assert(animations.includes('reading'), 'Adapter detected reading animation');
      assert(animations.includes('running'), 'Adapter detected running animation');

      // Check that state tracks active flag
      const activeStates = backendUpdates.filter(m => m.state?.active === true);
      assert(activeStates.length >= 1, 'Agent marked active during work');
    }

    assert(speeches.length >= 1, `Speech broadcasts: ${speeches.length}`);
    if (speeches.length > 0) {
      assert(speeches[0].agentId === '06-backend', 'Speech from correct agent');
    }

    // ── Test 3: Multi-agent — PM visits backend ──
    messages.length = 0;
    section('Multi-agent: PM visits backend desk');

    emitViaBash(tmpDir, `
      pixel_agent_start "03-pm" "prompts/03-pm/03-pm.txt"
      pixel_pm_visit "06-backend" "prompts/06-backend/06-backend.txt"
      pixel_agent_done "03-pm" "Updated all agent prompts"
    `);

    setTimeout(() => {
      const pmUpdates = messages.filter(
        m => m.type === 'orchystraw:agent_update' && m.agentId === '03-pm'
      );
      const pmSpeeches = messages.filter(
        m => m.type === 'orchystraw:speech' && m.agentId === '03-pm'
      );

      assert(pmUpdates.length >= 1, `PM agent updates: ${pmUpdates.length}`);
      assert(pmSpeeches.length >= 1, `PM speech broadcasts: ${pmSpeeches.length}`);

      if (pmSpeeches.length > 0) {
        // PM says "Updating 06-backend..." from pixel_pm_visit
        const visitSpeech = pmSpeeches.find(m => m.text && m.text.includes('06-backend'));
        assert(visitSpeech !== undefined, 'PM speech mentions target agent');
      }

      // ── Test 4: PIXEL_ENABLED=0 disables emission ──
      section('PIXEL_ENABLED=0 disables emission');

      const disabledDir = path.join(tmpDir, 'disabled-test');
      const disabledScript = `
        export PIXEL_SESSION_DIR="${disabledDir}"
        export PIXEL_ENABLED=0
        source "${EMITTER_PATH}"
        pixel_init
        pixel_agent_start "09-qa" "prompts/09-qa/09-qa.txt"
        pixel_agent_done "09-qa" "QA complete"
      `;
      execSync(`bash -c '${disabledScript.replace(/'/g, "'\\''")}'`, {
        cwd: PROJECT_ROOT,
        stdio: 'pipe',
      });

      const qaSession = path.join(disabledDir, '09-qa', 'session.jsonl');
      assert(!fs.existsSync(qaSession), 'No JSONL written when PIXEL_ENABLED=0');

      // ── Test 5: XSS in speech is sanitized by adapter ──
      section('XSS sanitization in adapter');

      const xssText = '<script>alert("xss")</script>';
      const sanitized = sanitizeText(xssText);
      assert(!sanitized.includes('<script>'), 'sanitizeText strips script tags');
      assert(sanitized.includes('&lt;script&gt;'), 'sanitizeText escapes angle brackets');

      // ── Test 6: Verify second client gets current state ──
      section('Second client gets current state');

      const ws2 = new WebSocket(`ws://localhost:${port}`);
      ws2.on('message', (raw) => {
        const msg = JSON.parse(raw.toString());
        if (msg.type === 'orchystraw:init') {
          assert(true, 'Second client received init');
          assert(
            msg.agents && msg.agents['06-backend'],
            'Second client sees backend agent state'
          );
          assert(
            msg.agents && msg.agents['03-pm'],
            'Second client sees PM agent state'
          );

          ws2.close();
          cleanup();
        }
      });

      ws2.on('error', () => cleanup());
    }, 1500);
  }, 1500);
}

// ---------------------------------------------------------------------------
// Cleanup
// ---------------------------------------------------------------------------

function cleanup() {
  try {
    adapter.stop();
    wss.close();
    server.close();
    fs.rmSync(tmpDir, { recursive: true, force: true });
  } catch (_) {}

  console.log(`\n══ Pipeline Test Results: ${passed} passed, ${failed} failed ══\n`);
  process.exit(failed > 0 ? 1 : 0);
}

// Timeout safety net
setTimeout(() => {
  console.log('\nPipeline test timed out after 20s');
  cleanup();
}, 20000);
