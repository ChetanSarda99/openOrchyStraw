import { create } from "zustand";
import type { View, ChatMessage } from "@/types";

type Theme = "dark" | "light";

interface AppState {
  currentProject: string;
  currentProjectPath: string;
  sidebarOpen: boolean;
  activeView: View;
  selectedAgentId: string | null;
  wizardOpen: boolean;
  chatMessages: ChatMessage[];
  selectedChatAgent: string;
  theme: Theme;

  setCurrentProject: (name: string, path: string) => void;
  toggleSidebar: () => void;
  setSidebarOpen: (open: boolean) => void;
  setActiveView: (view: View) => void;
  setSelectedAgent: (agentId: string | null) => void;
  setWizardOpen: (open: boolean) => void;
  addChatMessage: (msg: ChatMessage) => void;
  clearChatMessages: () => void;
  setSelectedChatAgent: (agentId: string) => void;
  toggleTheme: () => void;
}

const applyTheme = (theme: Theme): void => {
  if (typeof document === "undefined") return;
  const root = document.documentElement;
  if (theme === "light") root.classList.add("light");
  else root.classList.remove("light");
  try { localStorage.setItem("orch-theme", theme); } catch {}
};

const initialTheme: Theme = (() => {
  try {
    const saved = localStorage.getItem("orch-theme");
    if (saved === "light" || saved === "dark") return saved;
  } catch {}
  return "dark";
})();
applyTheme(initialTheme);

export const useAppStore = create<AppState>((set) => ({
  currentProject: "openOrchyStraw",
  currentProjectPath: "~/Projects/openOrchyStraw",
  sidebarOpen: true,
  activeView: "dashboard",
  selectedAgentId: null,
  wizardOpen: false,
  chatMessages: [],
  selectedChatAgent: "00-cofounder",
  theme: initialTheme,

  setCurrentProject: (name, path) => set({ currentProject: name, currentProjectPath: path }),
  toggleSidebar: () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),
  setSidebarOpen: (open) => set({ sidebarOpen: open }),
  setActiveView: (view) => set({ activeView: view, selectedAgentId: null }),
  setSelectedAgent: (agentId) => set({ selectedAgentId: agentId, activeView: "agents" }),
  setWizardOpen: (open) => set({ wizardOpen: open }),
  addChatMessage: (msg) => set((s) => ({ chatMessages: [...s.chatMessages, msg] })),
  clearChatMessages: () => set({ chatMessages: [] }),
  setSelectedChatAgent: (agentId) => set({ selectedChatAgent: agentId }),
  toggleTheme: () => set((s) => {
    const next: Theme = s.theme === "dark" ? "light" : "dark";
    applyTheme(next);
    return { theme: next };
  }),
}));
