import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Playground — OrchyStraw",
  description:
    "Try OrchyStraw in the browser. Edit agents.conf, preview your agent team, and simulate orchestration cycles interactively.",
};

export default function PlaygroundLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return children;
}
