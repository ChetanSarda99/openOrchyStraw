"use client";

import { ArrowLeft, Play, Users, FileText, RefreshCw } from "lucide-react";
import { useState, useCallback } from "react";

const defaultConfig = `# agents.conf — define your team
[agent.backend]
name = Backend Engineer
model = claude
frequency = every_cycle
owns = src/core/, scripts/

[agent.frontend]
name = Frontend Developer
model = gemini
frequency = every_cycle
owns = src/components/, src/styles/

[agent.qa]
name = QA Engineer
model = claude
frequency = every_3rd_cycle
owns = tests/

[agent.pm]
name = Project Manager
model = claude
frequency = every_cycle
owns = prompts/03-pm/`;

interface Agent {
  id: string;
  name: string;
  model: string;
  frequency: string;
  owns: string[];
}

interface CycleEvent {
  agent: string;
  message: string;
  type: "start" | "work" | "context" | "done";
}

function parseConfig(text: string): Agent[] {
  const agents: Agent[] = [];
  const blocks = text.split(/\[agent\./);

  for (const block of blocks.slice(1)) {
    const idMatch = block.match(/^(\w+)\]/);
    if (!idMatch) continue;

    const id = idMatch[1];
    const nameMatch = block.match(/name\s*=\s*(.+)/);
    const modelMatch = block.match(/model\s*=\s*(.+)/);
    const freqMatch = block.match(/frequency\s*=\s*(.+)/);
    const ownsMatch = block.match(/owns\s*=\s*(.+)/);

    agents.push({
      id,
      name: nameMatch?.[1]?.trim() ?? id,
      model: modelMatch?.[1]?.trim() ?? "claude",
      frequency: freqMatch?.[1]?.trim() ?? "every_cycle",
      owns: ownsMatch?.[1]?.split(",").map((s) => s.trim()) ?? [],
    });
  }

  return agents;
}

const modelColors: Record<string, string> = {
  claude: "text-orange-400",
  gemini: "text-status-info",
  codex: "text-status-success",
  aider: "text-purple-400",
};

function generateCycleEvents(agents: Agent[]): CycleEvent[] {
  const events: CycleEvent[] = [];

  for (const agent of agents) {
    events.push({ agent: agent.name, message: `Reading prompt...`, type: "start" });
    events.push({
      agent: agent.name,
      message: `Working on ${agent.owns[0] ?? "assigned files"}`,
      type: "work",
    });
    events.push({ agent: agent.name, message: `Writing to shared context`, type: "context" });
    events.push({ agent: agent.name, message: `Done`, type: "done" });
  }

  return events;
}

const eventTypeColors: Record<string, string> = {
  start: "text-status-warning",
  work: "text-status-info",
  context: "text-purple-400",
  done: "text-status-success",
};

export default function PlaygroundPage() {
  const [config, setConfig] = useState(defaultConfig);
  const [agents, setAgents] = useState<Agent[]>(parseConfig(defaultConfig));
  const [events, setEvents] = useState<CycleEvent[]>([]);
  const [running, setRunning] = useState(false);
  const [currentEvent, setCurrentEvent] = useState(-1);

  const handleParse = useCallback(() => {
    const parsed = parseConfig(config);
    setAgents(parsed);
    setEvents([]);
    setCurrentEvent(-1);
    setRunning(false);
  }, [config]);

  const handleRun = useCallback(() => {
    if (agents.length === 0) return;

    const cycleEvents = generateCycleEvents(agents);
    setEvents([]);
    setCurrentEvent(0);
    setRunning(true);

    let i = 0;
    const interval = setInterval(() => {
      if (i >= cycleEvents.length) {
        clearInterval(interval);
        setRunning(false);
        return;
      }
      setEvents((prev) => [...prev, cycleEvents[i]]);
      setCurrentEvent(i);
      i++;
    }, 400);
  }, [agents]);

  return (
    <main className="min-h-screen px-4 py-16 sm:px-6 sm:py-24">
      <div className="mx-auto max-w-6xl">
        <a
          href="/"
          className="mb-8 inline-flex items-center gap-1.5 text-sm text-muted transition-colors hover:text-foreground"
        >
          <ArrowLeft className="h-3.5 w-3.5" />
          Back to home
        </a>

        <h1 className="text-3xl font-bold tracking-tight sm:text-4xl">
          Playground
        </h1>
        <p className="mt-3 text-muted">
          Edit an agents.conf below and see how OrchyStraw maps it to an agent
          team. Hit <strong className="text-foreground">Run Cycle</strong> to
          simulate orchestration.
        </p>

        <div className="mt-12 grid gap-8 lg:grid-cols-2">
          {/* Editor */}
          <div>
            <div className="flex items-center justify-between">
              <h2 className="flex items-center gap-2 text-sm font-semibold text-muted">
                <FileText className="h-4 w-4" />
                agents.conf
              </h2>
              <button
                onClick={handleParse}
                className="rounded-md bg-card px-3 py-1.5 text-xs font-medium text-muted transition-colors hover:text-foreground border border-card-border"
              >
                Parse
              </button>
            </div>
            <textarea
              value={config}
              onChange={(e) => setConfig(e.target.value)}
              spellCheck={false}
              className="mt-3 h-[420px] w-full resize-none rounded-xl border border-card-border bg-card p-4 font-mono text-xs leading-relaxed text-foreground/90 focus:outline-none focus:ring-1 focus:ring-accent"
            />
          </div>

          {/* Preview */}
          <div>
            <div className="flex items-center justify-between">
              <h2 className="flex items-center gap-2 text-sm font-semibold text-muted">
                <Users className="h-4 w-4" />
                Agent Team ({agents.length})
              </h2>
              <button
                onClick={handleRun}
                disabled={running || agents.length === 0}
                className="inline-flex items-center gap-1.5 rounded-md bg-accent px-3 py-1.5 text-xs font-semibold text-accent-foreground transition-colors hover:bg-accent/90 disabled:opacity-50"
              >
                {running ? (
                  <RefreshCw className="h-3 w-3 animate-spin" />
                ) : (
                  <Play className="h-3 w-3" />
                )}
                {running ? "Running..." : "Run Cycle"}
              </button>
            </div>

            {/* Agent cards */}
            <div className="mt-3 grid gap-3 sm:grid-cols-2">
              {agents.map((agent) => (
                <div
                  key={agent.id}
                  className="rounded-lg border border-card-border bg-card p-3"
                >
                  <div className="flex items-center justify-between">
                    <span className="text-sm font-medium">{agent.name}</span>
                    <span
                      className={`font-mono text-xs ${modelColors[agent.model] ?? "text-muted"}`}
                    >
                      {agent.model}
                    </span>
                  </div>
                  <div className="mt-1.5 text-xs text-muted">
                    {agent.frequency.replace(/_/g, " ")}
                  </div>
                  <div className="mt-1 flex flex-wrap gap-1">
                    {agent.owns.map((path) => (
                      <span
                        key={path}
                        className="rounded bg-accent/10 px-1.5 py-0.5 font-mono text-[10px] text-accent"
                      >
                        {path}
                      </span>
                    ))}
                  </div>
                </div>
              ))}
            </div>

            {/* Cycle output */}
            {(events.length > 0 || running) && (
              <div className="mt-6 rounded-xl border border-card-border bg-code-bg p-4">
                <div className="mb-2 flex items-center gap-2 text-xs text-muted">
                  <span className="inline-block h-2 w-2 rounded-full bg-status-success" />
                  Cycle simulation
                </div>
                <div className="space-y-1 font-mono text-xs">
                  {events.map((ev, i) => (
                    <div
                      key={i}
                      className={`${eventTypeColors[ev.type]} ${i === currentEvent ? "opacity-100" : "opacity-70"}`}
                    >
                      <span className="text-muted">[{ev.agent}]</span> {ev.message}
                    </div>
                  ))}
                  {!running && events.length > 0 && (
                    <div className="mt-2 text-status-success">
                      Cycle complete — {agents.length} agents ran.
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>
        </div>

        <div className="mt-12 rounded-xl border border-card-border bg-card p-6">
          <h2 className="text-lg font-semibold">How it works</h2>
          <p className="mt-3 text-sm leading-relaxed text-muted">
            In a real OrchyStraw cycle, each agent launches as an independent
            process (Claude Code, Codex, Gemini CLI, etc). They read their
            markdown prompt, do their work within their file boundaries, and
            write status to shared context. The PM agent runs last to
            coordinate. This playground simulates that flow so you can
            experiment with team composition before running it for real.
          </p>
        </div>

        <div className="mt-8 text-center">
          <a
            href="https://github.com/ChetanSarda99/openOrchyStraw"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 rounded-lg bg-accent px-6 py-3 text-sm font-semibold text-accent-foreground transition-colors hover:bg-accent/90"
          >
            Get Started
          </a>
        </div>
      </div>
    </main>
  );
}
