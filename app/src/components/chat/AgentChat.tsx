import { useState, useEffect, useRef, type KeyboardEvent } from "react";
import { useQuery } from "@tanstack/react-query";
import { Send, Loader2, User, Bot, Trash2 } from "lucide-react";
import { useAppStore } from "@/stores/app";
import { listAgents, sendChatMessage } from "@/services/tauri";
import type { ChatMessage } from "@/types";

function nextId(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

export function AgentChat() {
  const currentProjectPath = useAppStore((s) => s.currentProjectPath);
  const messages = useAppStore((s) => s.chatMessages);
  const addMessage = useAppStore((s) => s.addChatMessage);
  const clearMessages = useAppStore((s) => s.clearChatMessages);
  const selectedAgent = useAppStore((s) => s.selectedChatAgent);
  const setSelectedAgent = useAppStore((s) => s.setSelectedChatAgent);

  const [input, setInput] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const scrollRef = useRef<HTMLDivElement>(null);

  const { data: agents = [] } = useQuery({
    queryKey: ["agents", currentProjectPath],
    queryFn: () => listAgents(currentProjectPath),
  });

  // Set default selected agent — prefer co-founder, then first agent
  useEffect(() => {
    if (agents.length > 0 && !agents.some((a) => a.id === selectedAgent)) {
      const cofounder = agents.find((a) => a.id.includes("cofounder")) || agents.find((a) => a.id.includes("founder"));
      setSelectedAgent(cofounder?.id || agents[0].id);
    }
  }, [agents, selectedAgent, setSelectedAgent]);

  // Auto-scroll on new messages
  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages, sending]);

  const handleSend = async (): Promise<void> => {
    const text = input.trim();
    if (!text || sending || !selectedAgent) return;

    setError(null);
    const userMsg: ChatMessage = {
      id: nextId(),
      role: "user",
      content: text,
      timestamp: new Date().toISOString(),
    };
    addMessage(userMsg);
    setInput("");
    setSending(true);

    try {
      const resp = await sendChatMessage(selectedAgent, text, currentProjectPath);
      const agentMsg: ChatMessage = {
        id: nextId(),
        role: "agent",
        agent: resp.agent,
        content: resp.response,
        timestamp: new Date().toISOString(),
      };
      addMessage(agentMsg);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      setError(msg);
      addMessage({
        id: nextId(),
        role: "agent",
        agent: selectedAgent,
        content: `Error: ${msg}`,
        timestamp: new Date().toISOString(),
      });
    } finally {
      setSending(false);
    }
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLTextAreaElement>): void => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      void handleSend();
    }
  };

  const activeAgent = agents.find((a) => a.id === selectedAgent);

  return (
    <div className="flex flex-col h-[calc(100vh-140px)]">
      {/* Header */}
      <div className="flex items-center gap-3 mb-4">
        <h2 className="text-sm font-medium text-text-muted">Chat with Agent</h2>
        <select
          value={selectedAgent}
          onChange={(e) => setSelectedAgent(e.target.value)}
          className="bg-bg-secondary border border-border rounded-md px-3 py-1.5 text-sm text-text focus:outline-none focus:border-accent cursor-pointer"
        >
          {agents.map((a) => (
            <option key={a.id} value={a.id}>
              {a.id} — {a.label}
            </option>
          ))}
        </select>
        {activeAgent && (
          <span className="text-xs text-text-dim font-mono truncate max-w-[260px]">
            {activeAgent.ownership}
          </span>
        )}
        <button
          onClick={clearMessages}
          className="ml-auto flex items-center gap-1.5 text-xs text-text-dim hover:text-text transition-colors"
          title="Clear conversation"
        >
          <Trash2 size={12} />
          Clear
        </button>
      </div>

      {/* Messages */}
      <div
        ref={scrollRef}
        className="flex-1 overflow-y-auto bg-bg-secondary border border-border rounded-lg p-4 space-y-4"
      >
        {messages.length === 0 && !sending && (
          <div className="h-full flex items-center justify-center text-sm text-text-dim text-center">
            <div>
              <Bot size={32} className="mx-auto mb-2 opacity-50" />
              <p>Start a conversation with the {activeAgent?.label ?? "selected agent"}.</p>
              <p className="text-[10px] mt-1">Messages are routed through the claude CLI.</p>
            </div>
          </div>
        )}

        {messages.map((msg) => (
          <div
            key={msg.id}
            className={`flex gap-3 ${msg.role === "user" ? "justify-end" : "justify-start"}`}
          >
            {msg.role === "agent" && (
              <div className="w-7 h-7 rounded-full bg-bg-tertiary border border-border flex items-center justify-center shrink-0">
                <Bot size={14} className="text-accent" />
              </div>
            )}
            <div
              className={`max-w-[75%] rounded-lg px-3.5 py-2.5 text-sm ${
                msg.role === "user"
                  ? "bg-accent text-white"
                  : "bg-bg-tertiary border border-border text-text"
              }`}
            >
              {msg.role === "agent" && msg.agent && (
                <div className="text-[10px] font-mono text-text-dim mb-1">{msg.agent}</div>
              )}
              <div className="whitespace-pre-wrap leading-relaxed">{msg.content}</div>
              <div
                className={`text-[9px] mt-1.5 ${
                  msg.role === "user" ? "text-white/60" : "text-text-dim"
                }`}
              >
                {new Date(msg.timestamp).toLocaleTimeString()}
              </div>
            </div>
            {msg.role === "user" && (
              <div className="w-7 h-7 rounded-full bg-accent/20 border border-accent/40 flex items-center justify-center shrink-0">
                <User size={14} className="text-accent" />
              </div>
            )}
          </div>
        ))}

        {sending && (
          <div className="flex gap-3">
            <div className="w-7 h-7 rounded-full bg-bg-tertiary border border-border flex items-center justify-center shrink-0">
              <Bot size={14} className="text-accent" />
            </div>
            <div className="bg-bg-tertiary border border-border rounded-lg px-3.5 py-2.5 text-sm flex items-center gap-2 text-text-muted">
              <Loader2 size={14} className="animate-spin" />
              <span>Thinking…</span>
            </div>
          </div>
        )}
      </div>

      {/* Input */}
      <div className="mt-4">
        {error && (
          <div className="text-xs text-status-red mb-2 px-1">{error}</div>
        )}
        <div className="flex gap-2 items-end">
          <textarea
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder={
              activeAgent
                ? `Message ${activeAgent.label}... (Enter to send, Shift+Enter for newline)`
                : "Loading agents..."
            }
            disabled={sending || !selectedAgent}
            rows={2}
            className="flex-1 bg-bg-secondary border border-border rounded-md px-3 py-2 text-sm text-text placeholder:text-text-dim focus:outline-none focus:border-accent resize-none disabled:opacity-50"
          />
          <button
            onClick={() => void handleSend()}
            disabled={sending || !input.trim() || !selectedAgent}
            className="h-[46px] px-4 bg-accent text-white text-sm rounded-md hover:bg-accent-hover transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
          >
            {sending ? <Loader2 size={14} className="animate-spin" /> : <Send size={14} />}
            Send
          </button>
        </div>
      </div>
    </div>
  );
}
