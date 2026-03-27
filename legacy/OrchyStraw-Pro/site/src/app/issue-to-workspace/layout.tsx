import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Issue to Workspace — OrchyStraw",
  description:
    "Visualize the pipeline from GitHub issue to agent workspace. See how OrchyStraw triages, assigns, and gates work automatically.",
};

export default function IssueToWorkspaceLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return children;
}
