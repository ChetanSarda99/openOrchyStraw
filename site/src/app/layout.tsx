import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "OrchyStraw — Multi-Agent AI Coding Orchestration",
  description:
    "Run a team of AI coding agents on any codebase. Markdown prompts + bash script. No framework. No dependencies.",
  keywords: [
    "multi-agent",
    "AI coding",
    "orchestration",
    "Claude Code",
    "Codex",
    "Cursor",
    "bash",
    "open source",
  ],
  authors: [{ name: "Chetan Sarda" }],
  openGraph: {
    title: "OrchyStraw — Multi-Agent AI Coding Orchestration",
    description:
      "Run a team of AI coding agents on any codebase. No framework. No dependencies.",
    type: "website",
    url: "https://chetansarda99.github.io/openOrchyStraw/",
    siteName: "OrchyStraw",
  },
  twitter: {
    card: "summary_large_image",
    title: "OrchyStraw — Multi-Agent AI Coding Orchestration",
    description:
      "Run a team of AI coding agents on any codebase. No framework. No dependencies.",
  },
  metadataBase: new URL("https://chetansarda99.github.io/openOrchyStraw/"),
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased dark`}
    >
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
