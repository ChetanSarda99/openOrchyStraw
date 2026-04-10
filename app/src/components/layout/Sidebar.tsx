import { useQuery } from "@tanstack/react-query";
import {
  LayoutDashboard,
  Users,
  ScrollText,
  FileCode,
  Settings,
  ChevronLeft,
  ChevronRight,
  FolderOpen,
  MessageSquare,
  Plus,
} from "lucide-react";
import { useAppStore } from "@/stores/app";
import { listProjects } from "@/services/tauri";
import type { View } from "@/types";

const NAV_ITEMS: { view: View; label: string; icon: typeof LayoutDashboard }[] = [
  { view: "dashboard", label: "Dashboard", icon: LayoutDashboard },
  { view: "agents", label: "Agents", icon: Users },
  { view: "chat", label: "Chat", icon: MessageSquare },
  { view: "logs", label: "Logs", icon: ScrollText },
  { view: "config", label: "Config", icon: FileCode },
  { view: "settings", label: "Settings", icon: Settings },
];

export function Sidebar() {
  const {
    sidebarOpen,
    toggleSidebar,
    activeView,
    setActiveView,
    currentProject,
    setCurrentProject,
    setWizardOpen,
  } = useAppStore();
  const { data: projects = [] } = useQuery({
    queryKey: ["projects"],
    queryFn: listProjects,
  });

  return (
    <aside
      className="fixed left-0 top-0 h-screen bg-bg-secondary border-r border-border flex flex-col z-20 transition-all duration-200"
      style={{ width: sidebarOpen ? 240 : 56 }}
    >
      {/* Project selector */}
      <div className="p-3 border-b border-border space-y-2">
        {sidebarOpen ? (
          <>
            <select
              value={currentProject}
              onChange={(e) => {
                const proj = projects.find((p) => p.name === e.target.value);
                if (proj) setCurrentProject(proj.name, proj.path);
              }}
              className="w-full bg-bg-tertiary text-text text-sm px-3 py-2 rounded-md border border-border focus:outline-none focus:border-accent cursor-pointer"
            >
              {projects.map((p) => (
                <option key={p.name} value={p.name}>
                  {p.name}
                </option>
              ))}
            </select>
            <button
              onClick={() => setWizardOpen(true)}
              className="w-full flex items-center justify-center gap-1.5 bg-bg-tertiary hover:bg-border text-xs text-text-muted hover:text-text rounded-md border border-border border-dashed py-1.5 transition-colors"
            >
              <Plus size={12} />
              Add Project
            </button>
          </>
        ) : (
          <>
            <button
              className="w-8 h-8 flex items-center justify-center text-text-muted hover:text-text rounded"
              title={currentProject}
            >
              <FolderOpen size={18} />
            </button>
            <button
              onClick={() => setWizardOpen(true)}
              className="w-8 h-8 flex items-center justify-center text-text-muted hover:text-text rounded"
              title="Add Project"
            >
              <Plus size={18} />
            </button>
          </>
        )}
      </div>

      {/* Navigation */}
      <nav className="flex-1 py-2">
        {NAV_ITEMS.map(({ view, label, icon: Icon }) => {
          const active = activeView === view;
          return (
            <button
              key={view}
              onClick={() => setActiveView(view)}
              className={`w-full flex items-center gap-3 px-4 py-2.5 text-sm transition-colors ${
                active
                  ? "bg-bg-tertiary text-text border-r-2 border-accent"
                  : "text-text-muted hover:text-text hover:bg-bg-tertiary/50"
              }`}
              title={label}
            >
              <Icon size={18} className="shrink-0" />
              {sidebarOpen && <span>{label}</span>}
            </button>
          );
        })}
      </nav>

      {/* Collapse toggle */}
      <button
        onClick={toggleSidebar}
        className="p-3 border-t border-border text-text-muted hover:text-text flex items-center justify-center"
      >
        {sidebarOpen ? <ChevronLeft size={18} /> : <ChevronRight size={18} />}
      </button>
    </aside>
  );
}
