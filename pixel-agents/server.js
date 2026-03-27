#!/usr/bin/env node
/**
 * OrchyStraw Pixel Agents Server
 *
 * Forked from pixel-agents-standalone (MIT).
 * Replaces the Claude Code JSONL watcher with OrchyStraw's adapter
 * to visualize multi-agent orchestration cycles as pixel art characters.
 *
 * Usage:
 *   npm start                          # default: watches ~/.claude/projects/orchystraw
 *   PIXEL_SESSION_DIR=/tmp/test npm start   # custom session dir
 *   node server.js --dev               # dev mode with verbose logging
 *
 * Opens at http://localhost:3456
 */

const path = require('path');
const http = require('http');
const express = require('express');
const { WebSocketServer } = require('ws');
const { attachToServer } = require('../src/pixel/orchystraw-adapter');

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

const PORT = parseInt(process.env.PIXEL_PORT || '3456', 10);
const DEV_MODE = process.argv.includes('--dev');
const PROJECT_ROOT = path.resolve(__dirname, '..');

// ---------------------------------------------------------------------------
// Express app — serves the visualization client
// ---------------------------------------------------------------------------

const app = express();
app.use(express.static(path.join(__dirname, 'public')));

// Health check endpoint
app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', mode: 'orchystraw', version: '0.2.0' });
});

// ---------------------------------------------------------------------------
// HTTP + WebSocket server
// ---------------------------------------------------------------------------

const server = http.createServer(app);
const wss = new WebSocketServer({ server });

// ---------------------------------------------------------------------------
// Wire OrchyStraw adapter into the WebSocket server
// ---------------------------------------------------------------------------

const adapter = attachToServer(wss, {
  projectRoot: PROJECT_ROOT,
  sessionDir: process.env.PIXEL_SESSION_DIR || undefined,
  configPath: process.env.PIXEL_AGENTS_CONF || undefined,
});

adapter.on('adapter:started', ({ agents, sessionDir }) => {
  console.log(`[pixel-agents] Adapter started`);
  console.log(`[pixel-agents] Watching: ${sessionDir}`);
  console.log(`[pixel-agents] Agents: ${agents.join(', ')}`);
});

if (DEV_MODE) {
  adapter.on('agent:update', ({ agentId, state }) => {
    console.log(`[pixel-agents] ${agentId}: ${state.animation} (active=${state.active})`);
  });
}

wss.on('connection', (ws) => {
  console.log(`[pixel-agents] Client connected (total: ${wss.clients.size})`);
  ws.on('close', () => {
    console.log(`[pixel-agents] Client disconnected (total: ${wss.clients.size})`);
  });
});

// ---------------------------------------------------------------------------
// Start
// ---------------------------------------------------------------------------

server.listen(PORT, () => {
  console.log(`\n  OrchyStraw Pixel Agents`);
  console.log(`  http://localhost:${PORT}\n`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  adapter.stop();
  wss.close();
  server.close();
  process.exit(0);
});
