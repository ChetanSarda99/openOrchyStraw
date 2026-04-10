#!/usr/bin/env node
// orchystraw-app — Local server that reads real project data and serves the dashboard
//
// Usage:
//   node app/server.js                           # default: localhost:4321
//   ORCH_PORT=8080 node app/server.js            # custom port
//   ORCH_HOST=0.0.0.0 ORCH_PORT=9000 node app/server.js  # custom host+port
//   orchystraw app                               # via CLI (planned)

import { createServer } from "http";
import { readFileSync, existsSync, readdirSync, statSync, mkdirSync, writeFileSync } from "fs";
import { join, resolve, extname, basename } from "path";
import { homedir } from "os";
import { execSync, spawn } from "child_process";

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
  const entries = [];
  const projectName = basename(projectPath);

  // 1. Pull from live running cycle output (most recent activity)
  const runningInfo = runningCycles.get(projectName);
  if (runningInfo && runningInfo.output) {
    const lines = runningInfo.output.split("\n").filter((l) => l.trim());
    for (const line of lines.slice(-200)) {
      // Parse: [2026-04-10 01:42:16] [agent-id] message
      const match = line.match(/^\[([\d-]+\s[\d:]+)\](?:\s\[(\w+)\s*\]\s*(?:\[(\S+)\])?)?\s*(.*)$/);
      if (match) {
        const [, ts, level, ctx, msg] = match;
        const isoTs = ts.replace(" ", "T") + "Z";
        // Try to extract agent_id from message like "[agent-id] ..."
        const agentMatch = msg.match(/^\[(\d{2}[a-z]?-[\w-]+)\]\s*(.*)$/);
        entries.push({
          timestamp: isoTs,
          agent_id: agentMatch ? agentMatch[1] : ctx || "orchestrator",
          level: (level || "INFO").toLowerCase(),
          message: (agentMatch ? agentMatch[2] : msg).slice(0, 300),
          source: "live",
        });
      } else if (line.trim()) {
        entries.push({
          timestamp: new Date().toISOString(),
          agent_id: "orchestrator",
          level: "info",
          message: line.slice(0, 300),
          source: "live",
        });
      }
    }
  }

  // 2. Pull from finished cycles (recent completions)
  const finishedInfo = finishedCycles.get(projectName);
  if (finishedInfo && finishedInfo.output && entries.length < limit) {
    const lines = finishedInfo.output.split("\n").filter((l) => l.trim());
    for (const line of lines.slice(-100)) {
      const match = line.match(/^\[([\d-]+\s[\d:]+)\](?:\s\[(\w+)\s*\]\s*(?:\[(\S+)\])?)?\s*(.*)$/);
      if (match) {
        const [, ts, level, ctx, msg] = match;
        const agentMatch = msg.match(/^\[(\d{2}[a-z]?-[\w-]+)\]\s*(.*)$/);
        entries.push({
          timestamp: ts.replace(" ", "T") + "Z",
          agent_id: agentMatch ? agentMatch[1] : ctx || "orchestrator",
          level: (level || "INFO").toLowerCase(),
          message: (agentMatch ? agentMatch[2] : msg).slice(0, 300),
          source: "finished",
        });
      }
    }
  }

  // 3. Fall back to agent log files for historical context
  if (entries.length < limit) {
    try {
      const promptsDir = join(projectPath, "prompts");
      if (existsSync(promptsDir)) {
        const logDirs = readdirSync(promptsDir, { withFileTypes: true })
          .filter((d) => d.isDirectory());
        for (const dir of logDirs) {
          const logPath = join(projectPath, "prompts", dir.name, "logs");
          if (!existsSync(logPath)) continue;
          try {
            const files = readdirSync(logPath)
              .filter((f) => f.endsWith(".log"))
              .map((f) => ({
                name: f,
                mtime: statSync(join(logPath, f)).mtimeMs,
              }))
              .sort((a, b) => b.mtime - a.mtime)
              .slice(0, 3);
            for (const f of files) {
              const filePath = join(logPath, f.name);
              const content = readFileSync(filePath, "utf-8");
              const firstLine = content.split("\n")[0] || "";
              entries.push({
                timestamp: new Date(f.mtime).toISOString(),
                agent_id: dir.name,
                level: "info",
                message: firstLine.slice(0, 300),
                source: "file",
                file: f.name,
              });
            }
          } catch {}
        }
      }
    } catch {}
  }

  // Sort by timestamp descending (most recent first)
  entries.sort((a, b) => {
    const ta = new Date(a.timestamp).getTime() || 0;
    const tb = new Date(b.timestamp).getTime() || 0;
    return tb - ta;
  });

  return entries.slice(0, limit);
}

// ── Pixel events (JSONL reader) ──

function readPixelEvents(projectPath, sinceMs = 0) {
  // Pixel JSONL lives at ~/.claude/projects/orchystraw-<project>/<agent_id>/session.jsonl
  const projectName = basename(projectPath);
  let pixelDir = join(homedir(), ".claude", "projects", `orchystraw-${projectName}`);

  // Fallback to legacy non-namespaced dir for backward compat
  if (!existsSync(pixelDir)) {
    const legacyDir = join(homedir(), ".claude", "projects", "orchystraw");
    if (existsSync(legacyDir)) {
      pixelDir = legacyDir;
    } else {
      return [];
    }
  }

  const now = Date.now();
  const agents = [];
  let entries;
  try {
    entries = readdirSync(pixelDir, { withFileTypes: true }).filter((d) => d.isDirectory());
  } catch {
    return [];
  }

  for (const dir of entries) {
    const sessionFile = join(pixelDir, dir.name, "session.jsonl");
    if (!existsSync(sessionFile)) continue;

    let lastEvent = null;
    let lastTool = null;
    let lastMessage = null;
    let lastTs = 0;
    let alive = false;

    try {
      const lines = readFileSync(sessionFile, "utf-8").split("\n").filter(Boolean);
      for (const line of lines) {
        try {
          const obj = JSON.parse(line);
          const ts = obj.timestamp ? new Date(obj.timestamp).getTime() : 0;
          if (ts > lastTs) lastTs = ts;
          if (obj.type === "assistant" && obj.message?.content?.[0]) {
            const block = obj.message.content[0];
            if (block.type === "tool_use") {
              lastTool = block.name;
              lastEvent = block;
            } else if (block.type === "text") {
              lastMessage = block.text;
            }
          } else if (obj.type === "result") {
            lastTool = "idle";
          }
        } catch {
          // skip malformed line
        }
      }
    } catch {
      continue;
    }

    // "alive" = had an event in the last 15 seconds
    alive = now - lastTs < 15_000;
    if (lastTs <= sinceMs && sinceMs > 0) continue;

    agents.push({
      agent_id: dir.name,
      last_tool: lastTool || "idle",
      last_message: lastMessage,
      last_timestamp: lastTs ? new Date(lastTs).toISOString() : null,
      alive,
      state: lastTool === "idle" || !alive ? "idle" : "working",
    });
  }

  // Also include agents from agents.conf as idle (even if no JSONL exists)
  try {
    const confPath = existsSync(join(projectPath, "agents.conf"))
      ? join(projectPath, "agents.conf")
      : join(projectPath, "scripts", "agents.conf");
    const confAgents = parseAgentsConf(confPath);
    const existingIds = new Set(agents.map((a) => a.agent_id));
    for (const a of confAgents) {
      if (!existingIds.has(a.id)) {
        agents.push({
          agent_id: a.id,
          label: a.label,
          last_tool: "idle",
          last_message: null,
          last_timestamp: null,
          alive: false,
          state: "idle",
        });
      }
    }
    // Attach labels to all
    const labelMap = new Map(confAgents.map((a) => [a.id, a.label]));
    for (const a of agents) {
      if (!a.label) a.label = labelMap.get(a.agent_id) || a.agent_id;
    }
  } catch {}

  agents.sort((a, b) => a.agent_id.localeCompare(b.agent_id));
  return agents;
}

// ── Codebase detection (for onboarding wizard) ──

function detectCodebase(projectPath) {
  const markers = [
    { file: "package.json", type: "node", template: "saas" },
    { file: "next.config.js", type: "nextjs", template: "saas" },
    { file: "next.config.ts", type: "nextjs", template: "saas" },
    { file: "Cargo.toml", type: "rust", template: "api" },
    { file: "go.mod", type: "go", template: "api" },
    { file: "requirements.txt", type: "python", template: "api" },
    { file: "pyproject.toml", type: "python", template: "api" },
    { file: "Gemfile", type: "ruby", template: "api" },
    { file: "pom.xml", type: "java", template: "api" },
    { file: "build.gradle", type: "gradle", template: "api" },
    { file: "composer.json", type: "php", template: "api" },
    { file: "mix.exs", type: "elixir", template: "api" },
  ];

  const found = [];
  for (const m of markers) {
    if (existsSync(join(projectPath, m.file))) {
      found.push(m);
    }
  }

  // Content detection
  let suggestedTemplate = "content";
  let detectedType = "unknown";
  if (found.length > 0) {
    const primary = found[0];
    detectedType = primary.type;
    suggestedTemplate = primary.template;
  }

  // Look for hints of content-heavy projects
  if (
    existsSync(join(projectPath, "content")) ||
    existsSync(join(projectPath, "posts")) ||
    existsSync(join(projectPath, "_posts"))
  ) {
    suggestedTemplate = "content";
  }

  // yc-startup heuristic: has both frontend + docs + marketing
  if (
    existsSync(join(projectPath, "site")) &&
    existsSync(join(projectPath, "docs")) &&
    found.some((f) => f.type === "node")
  ) {
    suggestedTemplate = "yc-startup";
  }

  return {
    path: projectPath,
    exists: existsSync(projectPath),
    detected_type: detectedType,
    markers_found: found.map((f) => f.file),
    suggested_template: suggestedTemplate,
  };
}

function readTemplateAgentsConf(template) {
  const templateDir = join(ORCH_ROOT, "template", template);
  const confPath = join(templateDir, "agents.conf");
  if (existsSync(confPath)) {
    try {
      return readFileSync(confPath, "utf-8");
    } catch {
      return "";
    }
  }
  // Fallback: use the orchystraw root agents.conf
  const rootConf = join(ORCH_ROOT, "agents.conf");
  if (existsSync(rootConf)) {
    try {
      return readFileSync(rootConf, "utf-8");
    } catch {
      return "";
    }
  }
  return "";
}

// ── POST body reader ──

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      try {
        const raw = Buffer.concat(chunks).toString("utf-8");
        resolve(raw ? JSON.parse(raw) : {});
      } catch (err) {
        reject(err);
      }
    });
    req.on("error", reject);
  });
}

// ── Running cycle state (multi-project) ──

const runningCycles = new Map(); // projectName -> { process, path, pid, startedAt, cycles, output, listeners }
const finishedCycles = new Map(); // projectName -> { ...info, finishedAt, exitCode } — kept 30 min

const FINISHED_RETENTION_MS = 30 * 60 * 1000;

function cleanupFinished() {
  const now = Date.now();
  for (const [name, info] of finishedCycles) {
    if (now - new Date(info.finishedAt).getTime() > FINISHED_RETENTION_MS) {
      finishedCycles.delete(name);
    }
  }
}
setInterval(cleanupFinished, 60_000);

function getRunningState() {
  const entries = [];
  for (const [name, info] of runningCycles) {
    // Check if process is still alive
    try { process.kill(info.pid, 0); } catch {
      runningCycles.delete(name);
      continue;
    }
    entries.push({
      project: name,
      path: info.path,
      pid: info.pid,
      cycles: info.cycles,
      started_at: info.startedAt,
      output_lines: info.output.split("\n").length,
    });
  }
  return entries;
}

// ── API Routes ──

function expandHome(p) {
  if (p && p.startsWith("~")) return p.replace(/^~/, homedir());
  return p;
}

async function handleApi(url, req, res) {
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
          const raw = readFileSync(conf, "utf-8")
            .replace(/[\x00-\x08\x0b\x0c\x0e-\x1f]/g, " ");  // strip control chars for JSON safety
          return json(res, {
            raw,
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

      case "/api/start": {
        const p = params.get("path") || ORCH_ROOT;
        const cycles = parseInt(params.get("cycles") || "5", 10);
        const projectName = basename(p);
        const orchBin = join(ORCH_ROOT, "bin", "orchystraw");

        if (runningCycles.has(projectName)) {
          return json(res, { error: `${projectName} is already running`, running: getRunningState() }, 409);
        }

        try {
          // Force agents by default in app mode — users expect cycles to actually run
          const child = spawn(orchBin, ["run", p, "--cycles", String(cycles), "--force"], {
            env: { ...process.env, ORCH_ROOT },
            stdio: ["ignore", "pipe", "pipe"],
            detached: true,  // survives tab switches
          });
          child.unref();  // don't block server exit

          const info = {
            process: child,
            path: p,
            pid: child.pid,
            cycles,
            startedAt: new Date().toISOString(),
            output: "",
            listeners: new Set(), // SSE response objects
          };

          const broadcast = (chunk) => {
            info.output += chunk;
            for (const listener of info.listeners) {
              try {
                listener.write(`data: ${JSON.stringify({ chunk })}\n\n`);
              } catch {
                info.listeners.delete(listener);
              }
            }
          };

          child.stdout.on("data", (d) => broadcast(d.toString()));
          child.stderr.on("data", (d) => broadcast(d.toString()));
          child.on("close", (code) => {
            console.log(`[${projectName}] Cycle finished (exit ${code})`);
            for (const listener of info.listeners) {
              try {
                listener.write(`event: end\ndata: ${JSON.stringify({ code })}\n\n`);
                listener.end();
              } catch {}
            }
            // Move to finished history (so users can still see what happened)
            finishedCycles.set(projectName, {
              project: projectName,
              path: info.path,
              pid: info.pid,
              cycles: info.cycles,
              startedAt: info.startedAt,
              finishedAt: new Date().toISOString(),
              exitCode: code,
              output: info.output,
              durationMs: Date.now() - new Date(info.startedAt).getTime(),
            });
            runningCycles.delete(projectName);
          });

          runningCycles.set(projectName, info);
          console.log(`[${projectName}] Started ${cycles} cycle(s), PID ${child.pid}`);

          return json(res, { started: true, project: projectName, cycles, pid: child.pid });
        } catch (err) {
          return json(res, { error: `Failed to start: ${err.message}` }, 500);
        }
      }

      case "/api/stop": {
        const projectName = params.get("project") || null;

        if (projectName && runningCycles.has(projectName)) {
          const info = runningCycles.get(projectName);
          try { process.kill(info.pid, "SIGTERM"); } catch {}
          runningCycles.delete(projectName);
          return json(res, { stopped: true, project: projectName });
        }

        // Stop all if no project specified
        if (!projectName && runningCycles.size > 0) {
          const stopped = [];
          for (const [name, info] of runningCycles) {
            try { process.kill(info.pid, "SIGTERM"); } catch {}
            stopped.push(name);
          }
          runningCycles.clear();
          return json(res, { stopped: true, projects: stopped });
        }

        return json(res, { error: "No cycle running" }, 404);
      }

      case "/api/running": {
        const running = getRunningState();
        const finished = Array.from(finishedCycles.values()).map((f) => ({
          project: f.project,
          path: f.path,
          pid: f.pid,
          cycles: f.cycles,
          started_at: f.startedAt,
          finished_at: f.finishedAt,
          exit_code: f.exitCode,
          duration_ms: f.durationMs,
          output_lines: f.output ? f.output.split("\n").length : 0,
        }));
        return json(res, {
          running: running.length > 0,
          count: running.length,
          cycles: running,
          finished,
        });
      }

      case "/api/output": {
        const projectName = params.get("project");
        const last = parseInt(params.get("last") || "50", 10);

        // Check running first
        if (projectName && runningCycles.has(projectName)) {
          const info = runningCycles.get(projectName);
          const lines = info.output.split("\n");
          return json(res, {
            project: projectName,
            pid: info.pid,
            status: "running",
            total_lines: lines.length,
            output: lines.slice(-last).join("\n"),
          });
        }

        // Then finished
        if (projectName && finishedCycles.has(projectName)) {
          const info = finishedCycles.get(projectName);
          const lines = (info.output || "").split("\n");
          return json(res, {
            project: projectName,
            pid: info.pid,
            status: "finished",
            exit_code: info.exitCode,
            finished_at: info.finishedAt,
            duration_ms: info.durationMs,
            total_lines: lines.length,
            output: lines.slice(-last).join("\n"),
          });
        }

        return json(res, { error: "Project not found in running or recently finished" }, 404);
      }

      case "/api/pixel-events": {
        const p = params.get("project") || params.get("path") || ORCH_ROOT;
        const since = parseInt(params.get("since") || "0", 10);
        const agents = readPixelEvents(p, since);
        return json(res, {
          project: basename(p),
          agents,
          now: new Date().toISOString(),
        });
      }

      case "/api/chat": {
        if (req.method !== "POST") {
          return json(res, { error: "POST required" }, 405);
        }
        let body;
        try {
          body = await readBody(req);
        } catch (err) {
          return json(res, { error: `Invalid JSON: ${err.message}` }, 400);
        }
        const agentId = (body.agent || "").trim();
        const message = (body.message || "").trim();
        const projectPath = expandHome(body.project || ORCH_ROOT);

        if (!agentId || !message) {
          return json(res, { error: "agent and message required" }, 400);
        }

        // Find the agent prompt path from agents.conf
        const confPath = existsSync(join(projectPath, "agents.conf"))
          ? join(projectPath, "agents.conf")
          : join(projectPath, "scripts", "agents.conf");
        const confAgents = parseAgentsConf(confPath);
        const agent = confAgents.find((a) => a.id === agentId);
        if (!agent) {
          return json(res, { error: `Agent ${agentId} not found in agents.conf` }, 404);
        }

        const promptFullPath = join(projectPath, agent.prompt_path);
        let systemPrompt = "";
        if (existsSync(promptFullPath)) {
          try {
            systemPrompt = readFileSync(promptFullPath, "utf-8");
          } catch {}
        }

        // Compose the full prompt: agent prompt + user question
        const fullPrompt = [
          `You are the ${agent.label} (${agent.id}) for the OrchyStraw project.`,
          `Your role and current tasks are described below:`,
          "",
          systemPrompt,
          "",
          `---`,
          `User question: ${message}`,
          ``,
          `Respond concisely and in character as the ${agent.label}.`,
        ].join("\n");

        // Spawn claude CLI with the prompt
        try {
          const child = spawn("claude", ["-p", fullPrompt], {
            cwd: projectPath,
            env: { ...process.env },
            stdio: ["ignore", "pipe", "pipe"],
          });

          let stdout = "";
          let stderr = "";
          let finished = false;

          const timeout = setTimeout(() => {
            if (!finished) {
              try { child.kill("SIGTERM"); } catch {}
            }
          }, 120_000);

          child.stdout.on("data", (d) => { stdout += d.toString(); });
          child.stderr.on("data", (d) => { stderr += d.toString(); });

          const response = await new Promise((resolveP) => {
            child.on("close", (code) => {
              finished = true;
              clearTimeout(timeout);
              resolveP({
                agent: agentId,
                response: stdout.trim() || `(no output) ${stderr.trim()}`,
                exit_code: code,
              });
            });
            child.on("error", (err) => {
              finished = true;
              clearTimeout(timeout);
              resolveP({
                agent: agentId,
                response: `Error invoking claude CLI: ${err.message}`,
                exit_code: -1,
              });
            });
          });

          return json(res, response);
        } catch (err) {
          return json(res, { error: `Failed to invoke claude: ${err.message}` }, 500);
        }
      }

      case "/api/stream/output": {
        const p = params.get("project") || params.get("path") || ORCH_ROOT;
        const projectName = basename(p);

        // SSE headers
        res.writeHead(200, {
          "Content-Type": "text/event-stream",
          "Cache-Control": "no-cache",
          Connection: "keep-alive",
          "Access-Control-Allow-Origin": "*",
        });
        res.write(`event: hello\ndata: ${JSON.stringify({ project: projectName })}\n\n`);

        if (runningCycles.has(projectName)) {
          const info = runningCycles.get(projectName);
          // Send buffered output first
          if (info.output) {
            res.write(`data: ${JSON.stringify({ chunk: info.output })}\n\n`);
          }
          info.listeners.add(res);
          req.on("close", () => {
            info.listeners.delete(res);
          });
        } else {
          res.write(`event: end\ndata: ${JSON.stringify({ reason: "not_running" })}\n\n`);
          res.end();
        }
        return;
      }

      case "/api/browse": {
        // List directories at a given path for folder picking
        let dirPath = params.get("path") || homedir();
        try {
          if (!existsSync(dirPath)) {
            return json(res, { error: "Path does not exist", path: dirPath }, 404);
          }
          const stat = statSync(dirPath);
          if (!stat.isDirectory()) {
            return json(res, { error: "Not a directory", path: dirPath }, 400);
          }

          const entries = readdirSync(dirPath, { withFileTypes: true })
            .filter((e) => e.isDirectory() && !e.name.startsWith("."))
            .map((e) => {
              const fullPath = join(dirPath, e.name);
              const hasAgentsConf = existsSync(join(fullPath, "agents.conf"));
              return {
                name: e.name,
                path: fullPath,
                is_orchystraw_project: hasAgentsConf,
              };
            })
            .sort((a, b) => a.name.localeCompare(b.name));

          // Parent dir for navigation
          const parent = dirPath !== "/" ? join(dirPath, "..") : null;

          return json(res, {
            current: dirPath,
            parent,
            entries,
          });
        } catch (err) {
          return json(res, { error: err.message }, 500);
        }
      }

      case "/api/init-project": {
        if (req.method !== "POST") {
          return json(res, { error: "POST required" }, 405);
        }
        let body;
        try {
          body = await readBody(req);
        } catch (err) {
          return json(res, { error: `Invalid JSON: ${err.message}` }, 400);
        }
        const folder = expandHome(body.path || "");
        if (!folder) {
          return json(res, { error: "path required" }, 400);
        }
        if (!existsSync(folder)) {
          return json(res, { error: `Path does not exist: ${folder}` }, 404);
        }

        const detection = detectCodebase(folder);
        const templateOverride = body.template || detection.suggested_template;
        const agentsConfPreview = readTemplateAgentsConf(templateOverride);

        // Dry-run mode: just return the preview
        if (body.dry_run !== false) {
          return json(res, {
            ...detection,
            template: templateOverride,
            agents_conf_preview: agentsConfPreview,
            dry_run: true,
          });
        }

        // Actually initialize: copy agents.conf to project root if missing
        try {
          const targetConf = join(folder, "agents.conf");
          if (!existsSync(targetConf) && agentsConfPreview) {
            writeFileSync(targetConf, agentsConfPreview, "utf-8");
          }
          // Create .orchystraw dir
          const stateDir = join(folder, ".orchystraw");
          if (!existsSync(stateDir)) {
            mkdirSync(stateDir, { recursive: true });
          }
          // Register project
          const registryDir = join(homedir(), ".orchystraw");
          if (!existsSync(registryDir)) mkdirSync(registryDir, { recursive: true });
          const existing = readRegistry();
          if (!existing.some((r) => r.path === folder)) {
            const entry = {
              name: basename(folder),
              path: folder,
              template: templateOverride,
              registered_at: new Date().toISOString(),
            };
            writeFileSync(
              REGISTRY_FILE,
              (existing.length ? existing.map((e) => JSON.stringify(e)).join("\n") + "\n" : "") +
                JSON.stringify(entry) +
                "\n"
            );
          }
          return json(res, {
            ...detection,
            template: templateOverride,
            agents_conf_preview: agentsConfPreview,
            initialized: true,
          });
        } catch (err) {
          return json(res, { error: `Init failed: ${err.message}` }, 500);
        }
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

const server = createServer(async (req, res) => {
  // Preflight CORS
  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    });
    res.end();
    return;
  }
  if (req.url.startsWith("/api/")) {
    await handleApi(req.url, req, res);
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
