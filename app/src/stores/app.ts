import { create } from "zustand";
import type { View } from "@/types";

interface AppState {
  currentProject: string;
  currentProjectPath: string;
  sidebarOpen: boolean;
  activeView: View;
  selectedAgentId: string | null;

  setCurrentProject: (name: string, path: string) => void;
  toggleSidebar: () => void;
  setSidebarOpen: (open: boolean) => void;
  setActiveView: (view: View) => void;
  setSelectedAgent: (agentId: string | null) => void;
}

export const useAppStore = create<AppState>((set) => ({
  currentProject: "openOrchyStraw",
  currentProjectPath: "~/Projects/openOrchyStraw",
  sidebarOpen: true,
  activeView: "dashboard",
  selectedAgentId: null,

  setCurrentProject: (name, path) => set({ currentProject: name, currentProjectPath: path }),
  toggleSidebar: () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),
  setSidebarOpen: (open) => set({ sidebarOpen: open }),
  setActiveView: (view) => set({ activeView: view, selectedAgentId: null }),
  setSelectedAgent: (agentId) => set({ selectedAgentId: agentId, activeView: "agents" }),
}));
