import { Navbar } from "@/components/navbar";
import { Hero } from "@/components/hero";
import { HowItWorks } from "@/components/how-it-works";
import { Features } from "@/components/features";
import { SupportedTools } from "@/components/supported-tools";
import { Demo } from "@/components/demo";
import { Comparison } from "@/components/comparison";
import { Testimonials } from "@/components/testimonials";
import { CTA } from "@/components/cta";
import { FAQ } from "@/components/faq";
import { Footer } from "@/components/footer";

export default function Home() {
  return (
    <>
      <Navbar />
      <main className="flex-1">
        <Hero />
        <SupportedTools />
        <Demo />
        <HowItWorks />
        <Features />
        <Comparison />
        <Testimonials />
        <FAQ />
        <CTA />
      </main>
      <Footer />
    </>
  );
}
