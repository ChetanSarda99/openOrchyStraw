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

const siteUrl = "https://orchystraw.dev";
const title = "OrchyStraw — Multi-Agent AI Coding Orchestration";
const description =
  "Run a team of AI coding agents on any codebase. Markdown prompts + bash script. No framework. No dependencies. Works with Claude Code, Codex, Gemini, Aider, Windsurf, Cursor.";

export const metadata: Metadata = {
  title,
  description,
  metadataBase: new URL(siteUrl),
  keywords: [
    "multi-agent",
    "AI coding",
    "orchestration",
    "Claude Code",
    "Codex",
    "Gemini",
    "Aider",
    "bash",
    "developer tools",
    "open source",
  ],
  authors: [{ name: "OrchyStraw" }],
  robots: {
    index: true,
    follow: true,
  },
  openGraph: {
    title,
    description,
    url: siteUrl,
    siteName: "OrchyStraw",
    type: "website",
    locale: "en_US",
    images: [
      {
        url: `${siteUrl}/opengraph-image.png`,
        width: 1200,
        height: 630,
        alt: title,
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title,
    description,
    images: [`${siteUrl}/twitter-image.png`],
  },
  alternates: {
    canonical: siteUrl,
  },
};

const jsonLd = [
  {
    "@context": "https://schema.org",
    "@type": "Organization",
    name: "OrchyStraw",
    url: siteUrl,
    logo: `${siteUrl}/opengraph-image.png`,
    sameAs: [
      "https://github.com/ChetanSarda99/OrchyStraw-Pro",
      "https://github.com/ChetanSarda99/openOrchyStraw",
    ],
  },
  {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: "OrchyStraw",
    description,
    url: siteUrl,
    applicationCategory: "DeveloperApplication",
    operatingSystem: "Linux, macOS, Windows (WSL)",
    offers: {
      "@type": "Offer",
      price: "0",
      priceCurrency: "USD",
    },
    license: "https://opensource.org/licenses/MIT",
  },
];

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
      <head>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
        <script
          defer
          data-domain="orchystraw.dev"
          src="https://plausible.io/js/script.js"
        />
      </head>
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
