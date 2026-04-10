// Shared agent color palette + label helpers
// Used by AgentFlow, PixelAgents, AgentCard, AgentDetail, anywhere agents are visualized
//
// Locked palette per role — keep consistent across the whole app

const EXACT_COLORS: Record<string, string> = {
  "00-cofounder": "#f97316",
  "01-ceo": "#8b5cf6",
  "02-cto": "#06b6d4",
  "03-pm": "#ec4899",
  "06-backend": "#22c55e",
  "11-web": "#3b82f6",
  "09-qa-code": "#eab308",
  "09-qa-visual": "#eab308",
  "10-security": "#ef4444",
  "12-designer": "#a855f7",
  "13-hr": "#14b8a6",
  "08-pixel": "#f43f5e",
};

/**
 * Strip the numeric prefix from an agent ID.
 *   "06-backend" → "backend"
 *   "09-qa-code" → "qa-code"
 *   "05b-twitter-tiktok" → "twitter-tiktok"
 */
export function agentRole(id: string): string {
  return id.replace(/^\d+[a-z]?-/, "");
}

/**
 * Get the canonical color for an agent ID.
 * Uses exact role match (no substring) so "pm-issues" doesn't match "pm".
 */
export function agentColor(id: string): string {
  if (EXACT_COLORS[id]) return EXACT_COLORS[id];

  const role = agentRole(id);

  // Exact role match — no substring confusion
  if (role === "cofounder" || role === "co-founder" || role === "founder") return "#f97316";
  if (role === "ceo") return "#8b5cf6";
  if (role === "cto") return "#06b6d4";
  if (role === "pm" || role === "pm-coordinator") return "#ec4899";
  if (role === "backend") return "#22c55e";
  if (role === "web" || role === "web-dev" || role === "frontend") return "#3b82f6";
  if (role === "qa-code" || role === "qa-visual" || role === "qa") return "#eab308";
  if (role === "security") return "#ef4444";
  if (role === "designer") return "#a855f7";
  if (role === "hr") return "#14b8a6";
  if (role === "pixel" || role === "pixel-agents") return "#f43f5e";

  // Domain-specific worker patterns (AIVA, content automation, etc.)
  if (role.includes("issue")) return "#94a3b8"; // pm-issues
  if (role.includes("content")) return "#0ea5e9";
  if (role.includes("linkedin")) return "#0a66c2";
  if (role.includes("instagram")) return "#e1306c";
  if (role.includes("reddit") || role.includes("youtube")) return "#ff4500";
  if (role.includes("twitter") || role.includes("tiktok") || role.includes("x-")) return "#1da1f2";
  if (role.includes("engagement")) return "#10b981";
  if (role.includes("analytics") || role.includes("growth")) return "#f59e0b";
  if (role.includes("research")) return "#8b5cf6";
  if (role.includes("ios") || role.includes("swift")) return "#3b82f6";
  if (role.includes("tauri")) return "#f59e0b";

  return "#6b7280";
}

/**
 * Tool name → status color (for live activity / pixel events).
 */
export function toolColor(tool: string): string {
  const t = (tool || "").toLowerCase();
  if (t.includes("write") || t.includes("edit")) return "#22c55e";
  if (t.includes("read")) return "#3b82f6";
  if (t.includes("bash") || t.includes("run") || t.includes("exec")) return "#eab308";
  if (t.includes("grep") || t.includes("search")) return "#a855f7";
  if (t.includes("glob") || t.includes("list")) return "#06b6d4";
  if (t.includes("fetch") || t.includes("web")) return "#ec4899";
  if (t.includes("task") || t.includes("delegate")) return "#f97316";
  return "#6b7280";
}

/**
 * Human-readable label for a tool name.
 */
export function toolLabel(tool: string): string {
  const t = (tool || "").toLowerCase();
  if (t.includes("write") || t.includes("edit")) return "writing";
  if (t.includes("read")) return "reading";
  if (t.includes("bash") || t.includes("run") || t.includes("exec")) return "running";
  if (t.includes("grep") || t.includes("search")) return "searching";
  if (t.includes("glob") || t.includes("list")) return "listing";
  if (t.includes("fetch") || t.includes("web")) return "fetching";
  if (t.includes("task") || t.includes("delegate")) return "delegating";
  return tool || "idle";
}

/**
 * Categorize an agent into a chain-of-command layer.
 */
export type AgentLayer = "leader" | "coordinator" | "worker";

export function agentLayer(id: string, interval: number): AgentLayer {
  const role = agentRole(id);
  if (role === "cofounder" || role === "co-founder" || role === "founder") return "leader";
  if (role === "ceo" || role === "cto") return "leader";
  if (interval === 0) return "coordinator";
  return "worker";
}
