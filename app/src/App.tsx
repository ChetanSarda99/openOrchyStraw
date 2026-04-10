import { useAppStore } from "@/stores/app";
import { Sidebar } from "@/components/layout/Sidebar";
import { Header } from "@/components/layout/Header";
import { Dashboard } from "@/components/dashboard/Dashboard";
import { AgentDetail } from "@/components/agents/AgentDetail";
import { LogViewer } from "@/components/logs/LogViewer";
import { ConfigEditor } from "@/components/config/ConfigEditor";
import { Settings } from "@/components/settings/Settings";
import { AgentChat } from "@/components/chat/AgentChat";
import { IssuesView } from "@/components/issues/IssuesView";
import { ProjectWizard } from "@/components/onboarding/ProjectWizard";

function MainContent() {
  const activeView = useAppStore((s) => s.activeView);

  switch (activeView) {
    case "dashboard":
      return <Dashboard />;
    case "agents":
      return <AgentDetail />;
    case "chat":
      return <AgentChat />;
    case "issues":
      return <IssuesView />;
    case "logs":
      return <LogViewer />;
    case "config":
      return <ConfigEditor />;
    case "settings":
      return <Settings />;
    default:
      return <Dashboard />;
  }
}

export default function App() {
  const sidebarOpen = useAppStore((s) => s.sidebarOpen);

  return (
    <div className="flex h-screen bg-bg text-text overflow-hidden">
      <Sidebar />
      <div
        className="flex flex-col flex-1 min-w-0 transition-all duration-200"
        style={{ marginLeft: sidebarOpen ? 240 : 56 }}
      >
        <Header />
        <main className="flex-1 overflow-y-auto p-6">
          <MainContent />
        </main>
      </div>
      <ProjectWizard />
    </div>
  );
}
