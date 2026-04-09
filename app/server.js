#!/usr/bin/env node
// orchystraw-app — Local server that reads real project data and serves the dashboard
//
// Usage:
//   node app/server.js                           # default: localhost:4321
//   ORCH_PORT=8080 node app/server.js            # custom port
//   ORCH_HOST=0.0.0.0 ORCH_PORT=9000 node app/server.js  # custom host+port
//   orchystraw app                               # via CLI (planned)

import { createServer } from "http";
import { readFileSync, existsSync, readdirSync, statSync } from "fs";
import { join, resolve, extname, basename } from "path";
import { homedir } from "os";
import { execSync } from "child_process";

const HOST = process.env.ORCH_HOST || "127.0.0.1";
const PORT = parseInt(process.env.ORCH_PORT || "4321", 10);
const ORCH_ROOT = process.env.ORCH_ROOT || resolve(import.meta.dirname, "..");
const REGISTRY_FILE = join(homedir(), ".orchystraw", "registry.jsonl");

// ── Helpers ──

function parseAgentsConf(confPath) {
  if (!existsSync(confPath)) return [];
  const lines = readFileSync(confPath, "utf-8").split("\n");
  const agents = [];
  for (const line of lines) {
    if (line.trim().startsWith("#") || !line.trim()) continue;
    const parts = line.split("|").map((p) => p.trim());
    if (parts.length < 5) continue;
    agents.push({
      id: parts[0],
      prompt_path: parts[1],
      ownership: parts[2],
      interval: parseInt(parts[3], 10),
      label: parts[4],
    });
  }
  return agents;
}

function readRegistry() {
  if (!existsSync(REGISTRY_FILE)) return [];
  return readFileSync(REGISTRY_FILE, "utf-8")
    .split("\n")
    .filter((l) => l.trim())
    .map((l) => {
      try {
        return JSON.parse(l);
      } catch {
        return null;
      }
    })
    .filter(Boolean);
}

function getProjectInfo(projectPath) {
  const conf =
    existsSync(join(projectPath, "agents.conf"))
      ? join(projectPath, "agents.conf")
      : existsSync(join(projectPath, "scripts", "agents.conf"))
        ? join(projectPath, "scripts", "agents.conf")
        : null;

  const agents = conf ? parseAgentsConf(conf) : [];
  let lastRun = null;
  let gitCommits = 0;

  try {
    gitCommits = parseInt(
      execSync(`git -C "${projectPath}" rev-list --count HEAD 2>/dev/null`, {
        encoding: "utf-8",
      }).trim(),
      10
    );
  } catch {}

  const auditFile = join(projectPath, ".orchystraw", "audit.jsonl");
  const auditLines = existsSync(auditFile)
    ? readFileSync(auditFile, "utf-8").split("\n").filter(Boolean).length
    : 0;

  return {
    name: basename(projectPath),
    path: projectPath,
    agents_count: agents.length,
    agents,
    commits: gitCommits,
    cycles: auditLines,
    last_run: lastRun,
  };
}

function getLogs(projectPath, limit = 50) {
  // Read orchestrator logs
  const logDirs = readdirSync(join(projectPath, "prompts"), {
    withFileTypes: true,
  }).filter((d) => d.isDirectory());

  const entries = [];
  for (const dir of logDirs) {
    const logPath = join(projectPath, "prompts", dir.name, "logs");
    if (!existsSync(logPath)) continue;
    try {
      const files = readdirSync(logPath)
        .filter((f) => f.endsWith(".log"))
        .sort()
        .reverse()
        .slice(0, 3);
      for (const f of files) {
        const content = readFileSync(join(logPath, f), "utf-8");
        const firstLine = content.split("\n")[0] || "";
        entries.push({
          timestamp: f.replace(/\.log$/, "").split("-").slice(-2).join(":"),
          agent_id: dir.name,
          level: "info",
          message: firstLine.slice(0, 200),
          file: f,
        });
      }
    } catch {}
  }
  return entries.slice(0, limit);
}

// ── API Routes ──

function expandHome(p) {
  if (p && p.startsWith("~")) return p.replace(/^~/, homedir());
  return p;
}

function handleApi(url, res) {
  const [path, query] = url.split("?");
  const params = new URLSearchParams(query || "");
  // Expand ~ in path params
  const origGet = params.get.bind(params);
  params.get = (key) => { const v = origGet(key); return v ? expandHome(v) : v; };

  try {
    switch (path) {
      case "/api/projects": {
        const projects = readRegistry().map((r) => ({
          ...r,
          ...getProjectInfo(r.path),
        }));
        return json(res, projects);
      }

      case "/api/project": {
        const p = params.get("path") || ORCH_ROOT;
        return json(res, getProjectInfo(p));
      }

      case "/api/agents": {
        const p = params.get("path") || ORCH_ROOT;
        const conf = existsSync(join(p, "agents.conf"))
          ? join(p, "agents.conf")
          : join(p, "scripts", "agents.conf");
        return json(res, parseAgentsConf(conf));
      }

      case "/api/logs": {
        const p = params.get("path") || ORCH_ROOT;
        const limit = parseInt(params.get("limit") || "50", 10);
        return json(res, getLogs(p, limit));
      }

      case "/api/config": {
        const p = params.get("path") || ORCH_ROOT;
        const conf = existsSync(join(p, "agents.conf"))
          ? join(p, "agents.conf")
          : join(p, "scripts", "agents.conf");
        if (existsSync(conf)) {
          return json(res, {
            raw: readFileSync(conf, "utf-8"),
            agents: parseAgentsConf(conf),
            path: conf,
          });
        }
        return json(res, { error: "No agents.conf found" }, 404);
      }

      case "/api/status": {
        return json(res, {
          orch_root: ORCH_ROOT,
          version: "0.5.0",
          modules: 35,
          registered_projects: readRegistry().length,
          host: HOST,
          port: PORT,
        });
      }

      default:
        return json(res, { error: "Not found" }, 404);
    }
  } catch (err) {
    return json(res, { error: err.message }, 500);
  }
}

function json(res, data, status = 200) {
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
  });
  res.end(JSON.stringify(data));
}

// ── Static file serving ──

const MIME = {
  ".html": "text/html",
  ".js": "application/javascript",
  ".css": "text/css",
  ".json": "application/json",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".ico": "image/x-icon",
};

function serveStatic(url, res) {
  const distDir = join(import.meta.dirname, "dist");

  // If dist doesn't exist, serve a "build first" message
  if (!existsSync(distDir)) {
    res.writeHead(200, { "Content-Type": "text/html" });
    res.end(`<!DOCTYPE html>
<html><head><title>OrchyStraw</title></head>
<body style="background:#0a0a0a;color:#fafafa;font-family:system-ui;display:flex;justify-content:center;align-items:center;height:100vh;margin:0">
<div style="text-align:center">
<h1>OrchyStraw</h1>
<p>Build the frontend first:</p>
<pre style="background:#111;padding:16px;border-radius:8px;text-align:left">cd app && npm install && npm run build</pre>
<p style="color:#666">Then restart: node app/server.js</p>
<hr style="border-color:#222;margin:24px 0">
<p style="color:#666">API is live — try <a href="/api/status" style="color:#10b981">/api/status</a></p>
</div></body></html>`);
    return;
  }

  let filePath = join(distDir, url === "/" ? "index.html" : url);

  // SPA fallback — serve index.html for non-file routes
  if (!existsSync(filePath) && !extname(filePath)) {
    filePath = join(distDir, "index.html");
  }

  if (!existsSync(filePath)) {
    res.writeHead(404);
    res.end("Not found");
    return;
  }

  const mime = MIME[extname(filePath)] || "application/octet-stream";
  res.writeHead(200, { "Content-Type": mime });
  res.end(readFileSync(filePath));
}

// ── Server ──

const server = createServer((req, res) => {
  if (req.url.startsWith("/api/")) {
    handleApi(req.url, res);
  } else {
    serveStatic(req.url, res);
  }
});

server.listen(PORT, HOST, () => {
  const url = `http://${HOST}:${PORT}`;
  console.log(`╔══════════════════════════════════════════════════╗`);
  console.log(`║  orchystraw app                                  ║`);
  console.log(`║  ${url.padEnd(46)} ║`);
  console.log(`╚══════════════════════════════════════════════════╝`);
  console.log(`  ORCH_ROOT: ${ORCH_ROOT}`);
  console.log(`  Projects:  ${readRegistry().length} registered`);
  console.log(``);
  console.log(`  Customize: ORCH_HOST=0.0.0.0 ORCH_PORT=8080 node app/server.js`);

  // Auto-open browser on macOS
  if (process.platform === "darwin") {
    import("child_process").then(({ exec }) => {
      exec(`open ${url}`);
    });
  }
});
