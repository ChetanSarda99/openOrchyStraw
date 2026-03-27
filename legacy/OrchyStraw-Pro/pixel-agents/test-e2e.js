#!/usr/bin/env node
/**
 * End-to-End Test for OrchyStraw Pixel Agents Server
 *
 * 1. Starts the server on a random port
 * 2. Connects via WebSocket
 * 3. Writes synthetic JSONL events to a temp session dir
 * 4. Verifies the adapter detects events and broadcasts via WebSocket
 * 5. Verifies HTTP health endpoint
 *
 * Run: node pixel-agents/test-e2e.js
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const http = require('http');
const express = require('express');
const { WebSocketServer, WebSocket } = require('ws');
const { attachToServer } = require('../src/pixel/orchystraw-adapter');

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

let passed = 0;
let failed = 0;

function assert(condition, msg) {
  if (condition) {
    passed++;
    console.log(`  \u2713 ${msg}`);
  } else {
    failed++;
    console.log(`  \u2717 ${msg}`);
  }
}

function section(name) {
  console.log(`\n\u2500\u2500 ${name} \u2500\u2500`);
}

// ---------------------------------------------------------------------------
// Setup: temp session dir + server
// ---------------------------------------------------------------------------

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'orchystraw-e2e-'));
const projectRoot = path.resolve(__dirname, '..');

// Pre-create an agent dir with a session file
const agentDir = path.join(tmpDir, '06-backend');
fs.mkdirSync(agentDir, { recursive: true });
const sessionFile = path.join(agentDir, 'session.jsonl');
fs.writeFileSync(sessionFile, '');

// Create Express + WS server
const app = express();
app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', mode: 'orchystraw', version: '0.2.0' });
});

const server = http.createServer(app);
const wss = new WebSocketServer({ server });

// Attach adapter with temp session dir
const adapter = attachToServer(wss, {
  projectRoot,
  sessionDir: tmpDir,
});

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

server.listen(0, () => {
  const port = server.address().port;
  console.log(`Test server on port ${port}`);

  // Test 1: HTTP health endpoint
  section('HTTP health endpoint');

  http.get(`http://localhost:${port}/api/health`, (res) => {
    let body = '';
    res.on('data', (chunk) => { body += chunk; });
    res.on('end', () => {
      const data = JSON.parse(body);
      assert(data.status === 'ok', 'Health returns ok');
      assert(data.mode === 'orchystraw', 'Mode is orchystraw');

      // Test 2: WebSocket connection + init message
      section('WebSocket init handshake');

      const ws = new WebSocket(`ws://localhost:${port}`);
      let initReceived = false;
      const wsMessages = [];

      ws.on('message', (raw) => {
        const msg = JSON.parse(raw.toString());
        wsMessages.push(msg);

        if (msg.type === 'orchystraw:init' && !initReceived) {
          initReceived = true;
          assert(true, 'Received orchystraw:init message');
          assert(msg.agents !== undefined, 'Init includes agents state');
          assert(msg.characterMap !== undefined || msg.characterMap === null, 'Init includes characterMap');
          assert(msg.cycle !== undefined, 'Init includes cycle state');

          // Test 3: Write JSONL events and verify adapter broadcasts
          section('JSONL event detection + broadcast');

          const typingEvent = {
            type: 'assistant',
            message: {
              role: 'assistant',
              content: [{
                type: 'tool_use',
                name: 'write_file',
                input: { path: 'src/core/engine.sh' },
              }],
            },
          };

          const readEvent = {
            type: 'assistant',
            message: {
              role: 'assistant',
              content: [{
                type: 'tool_use',
                name: 'read_file',
                input: { path: 'prompts/00-shared-context/context.md' },
              }],
            },
          };

          const speechEvent = {
            type: 'assistant',
            message: {
              role: 'assistant',
              content: [{ type: 'text', text: 'Building engine module...' }],
            },
          };

          const endEvent = {
            type: 'result',
            subtype: 'success',
            result: 'done',
            session_id: 'orchystraw-06-backend',
          };

          // Write events to session file
          fs.appendFileSync(sessionFile, JSON.stringify(typingEvent) + '\n');

          setTimeout(() => {
            fs.appendFileSync(sessionFile, JSON.stringify(readEvent) + '\n');
          }, 200);

          setTimeout(() => {
            fs.appendFileSync(sessionFile, JSON.stringify(speechEvent) + '\n');
          }, 400);

          setTimeout(() => {
            fs.appendFileSync(sessionFile, JSON.stringify(endEvent) + '\n');
          }, 600);

          // Wait for all events to propagate
          setTimeout(() => {
            const updates = wsMessages.filter(m => m.type === 'orchystraw:agent_update');
            const speeches = wsMessages.filter(m => m.type === 'orchystraw:speech');

            assert(updates.length >= 1, `Received ${updates.length} agent_update messages (expected >=1)`);

            // Check that at least one update has the right agent
            const backendUpdates = updates.filter(m => m.agentId === '06-backend');
            assert(backendUpdates.length >= 1, `Backend agent updates received: ${backendUpdates.length}`);

            if (backendUpdates.length > 0) {
              // Check animation states were tracked
              const animations = backendUpdates.map(m => m.state?.animation);
              assert(
                animations.includes('typing') || animations.includes('reading') || animations.includes('running'),
                `Animations detected: ${animations.join(', ')}`
              );
            }

            assert(speeches.length >= 1, `Speech bubble events received: ${speeches.length}`);
            if (speeches.length > 0) {
              assert(speeches[0].text === 'Building engine module...', 'Speech text correct');
            }

            // Test 4: Second client gets init with updated state
            section('Second client init with current state');

            const ws2 = new WebSocket(`ws://localhost:${port}`);
            ws2.on('message', (raw2) => {
              const msg2 = JSON.parse(raw2.toString());
              if (msg2.type === 'orchystraw:init') {
                assert(true, 'Second client received init');
                assert(
                  msg2.agents && msg2.agents['06-backend'],
                  'Second client init includes backend agent state'
                );

                // Cleanup
                ws2.close();
                ws.close();
                adapter.stop();
                wss.close();
                server.close();
                fs.rmSync(tmpDir, { recursive: true, force: true });

                // Summary
                console.log(`\n\u2550\u2550 Results: ${passed} passed, ${failed} failed \u2550\u2550\n`);
                process.exit(failed > 0 ? 1 : 0);
              }
            });
          }, 1500);
        }
      });

      ws.on('error', (err) => {
        console.error('WebSocket error:', err.message);
        cleanup();
      });
    });
  });
});

function cleanup() {
  try {
    adapter.stop();
    wss.close();
    server.close();
    fs.rmSync(tmpDir, { recursive: true, force: true });
  } catch (_) {}
  console.log(`\n\u2550\u2550 Results: ${passed} passed, ${failed} failed \u2550\u2550\n`);
  process.exit(failed > 0 ? 1 : 0);
}

// Timeout safety net
setTimeout(() => {
  console.log('\nTest timed out after 15s');
  cleanup();
}, 15000);
