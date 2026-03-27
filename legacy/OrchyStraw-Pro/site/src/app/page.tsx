import dynamic from "next/dynamic";
import { Hero } from "@/components/hero";

const SupportedTools = dynamic(() =>
  import("@/components/supported-tools").then((m) => m.SupportedTools)
);
const HowItWorks = dynamic(() =>
  import("@/components/how-it-works").then((m) => m.HowItWorks)
);
const Features = dynamic(() =>
  import("@/components/features").then((m) => m.Features)
);
const PixelDemo = dynamic(() =>
  import("@/components/pixel-demo").then((m) => m.PixelDemo)
);
const SocialProof = dynamic(() =>
  import("@/components/social-proof").then((m) => m.SocialProof)
);
const FAQ = dynamic(() =>
  import("@/components/faq").then((m) => m.FAQ)
);
const Footer = dynamic(() =>
  import("@/components/footer").then((m) => m.Footer)
);

export default function Home() {
  return (
    <>
      <a
        href="#main"
        className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded-lg focus:bg-accent focus:px-4 focus:py-2 focus:text-accent-foreground focus:text-sm focus:font-semibold"
      >
        Skip to content
      </a>
      <main id="main" className="flex-1">
        <Hero />
        <SupportedTools />
        <HowItWorks />
        <Features />
        <PixelDemo />
        <SocialProof />
        <FAQ />
      </main>
      <Footer />
    </>
  );
}
