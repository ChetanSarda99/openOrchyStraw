import { Component, type ErrorInfo, type ReactNode } from "react";
import { AlertTriangle, RefreshCw } from "lucide-react";

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false, error: null };

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, info: ErrorInfo): void {
    console.error("ErrorBoundary caught:", error, info);
  }

  handleReload = (): void => {
    this.setState({ hasError: false, error: null });
    window.location.reload();
  };

  render(): ReactNode {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen bg-bg flex items-center justify-center p-6">
          <div className="max-w-xl bg-bg-secondary border border-border rounded-lg p-8 space-y-4">
            <div className="flex items-center gap-3">
              <AlertTriangle size={24} className="text-status-red" />
              <h1 className="text-lg font-semibold text-text">Something went wrong</h1>
            </div>
            <p className="text-sm text-text-muted">
              The app hit an unexpected error. This is usually a bug — please reload.
            </p>
            {this.state.error && (
              <pre className="bg-bg-tertiary border border-border rounded p-3 text-xs font-mono text-text-dim overflow-auto max-h-40">
                {this.state.error.message}
              </pre>
            )}
            <button
              onClick={this.handleReload}
              className="flex items-center gap-2 px-4 py-2 text-sm font-medium bg-accent text-white rounded-md hover:bg-accent-hover transition-colors"
            >
              <RefreshCw size={14} />
              Reload app
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
