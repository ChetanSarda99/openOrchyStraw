import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Diff Viewer — OrchyStraw",
  description:
    "Unified diff viewer for OrchyStraw cycles. Filter by agent or cycle, view syntax-highlighted file changes across your codebase.",
};

export default function DiffViewerLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return children;
}
