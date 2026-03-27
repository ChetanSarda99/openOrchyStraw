import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Merge Checklist — OrchyStraw",
  description:
    "Interactive merge checklist with quality gates for tests, file ownership, code review, and security before merging agent changes.",
};

export default function TodosLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return children;
}
