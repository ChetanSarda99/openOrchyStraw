import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Checkpoints — OrchyStraw",
  description:
    "Browse orchestration cycle checkpoints. View per-agent file changes, diffs, and revert to any previous cycle state.",
};

export default function CheckpointsLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return children;
}
