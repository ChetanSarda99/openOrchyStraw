import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Create PR — OrchyStraw",
  description:
    "One-click pull request creation from OrchyStraw cycles. Select branches, review diffs, check quality gates, and ship.",
};

export default function CreatePrLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return children;
}
