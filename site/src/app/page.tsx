import { Hero } from "@/components/hero";
import { Features } from "@/components/features";
import { HowItWorks } from "@/components/how-it-works";
import { Comparison } from "@/components/comparison";
import { Footer } from "@/components/footer";

export default function Home() {
  return (
    <>
      <main className="flex-1">
        <Hero />
        <Features />
        <HowItWorks />
        <Comparison />
      </main>
      <Footer />
    </>
  );
}
