"use client";

/**
 * Scroll-triggered cinematic showcase of the agent roster.
 * Uses the shared cinematic primitives (no GSAP, no extra deps).
 */

import {
  ScrollReveal,
  StaggerGrid,
  GlowCard,
  CountUp,
} from "@/components/cinematic";

const agents = [
  { id: "00", role: "Co-Founder", owns: "agents.conf, operations" },
  { id: "01", role: "CEO", owns: "docs/strategy/" },
  { id: "02", role: "CTO", owns: "docs/architecture/" },
  { id: "03", role: "PM", owns: "prompts/, docs/" },
  { id: "06", role: "Backend", owns: "scripts/, src/core/" },
  { id: "08", role: "Pixel", owns: "src/pixel/" },
  { id: "09", role: "QA Code", owns: "tests/, reports/" },
  { id: "09", role: "QA Visual", owns: "reports/visual/" },
  { id: "10", role: "Security", owns: "(read-only audit)" },
  { id: "11", role: "Web", owns: "site/" },
  { id: "12", role: "Designer", owns: "assets/, images/" },
  { id: "13", role: "HR", owns: "docs/team/" },
];

const stats = [
  { value: 12, suffix: "", label: "Agents shipping in parallel" },
  { value: 35, suffix: "", label: "Bash modules" },
  { value: 278, suffix: "", label: "Tests in the gate" },
  { value: 0, suffix: "", label: "External dependencies" },
];

export function AgentCinematic() {
  return (
    <section className="relative overflow-hidden border-t border-card-border py-24 sm:py-32">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <ScrollReveal direction="up">
          <p
            className="font-mono uppercase tracking-widest text-text-tertiary"
            style={{ fontSize: "var(--font-size-micro)" }}
          >
            The Roster
          </p>
        </ScrollReveal>

        <ScrollReveal direction="up" delay={80}>
          <h2
            className="mt-4 max-w-3xl font-medium text-foreground"
            style={{
              fontSize: "var(--font-size-h2)",
              lineHeight: 1.1,
              letterSpacing: "-0.02em",
              textWrap: "balance",
            }}
          >
            Twelve roles. One bash script. Zero merge conflicts.
          </h2>
        </ScrollReveal>

        <ScrollReveal direction="up" delay={140}>
          <p
            className="mt-5 max-w-2xl text-text-secondary"
            style={{
              fontSize: "var(--font-size-body)",
              lineHeight: 1.6,
            }}
          >
            Each agent owns a slice of the repo and talks to the others through a
            shared context file. No frameworks, no orchestration engine, no
            agent runtime. Just markdown prompts and a shell loop.
          </p>
        </ScrollReveal>

        <div className="mt-14 grid grid-cols-2 gap-4 sm:grid-cols-4 sm:gap-6">
          {stats.map((s, i) => (
            <ScrollReveal key={i} direction="up" delay={i * 80} className="">
              <div
                className="rounded-xl border border-card-border bg-card/30 p-5 text-center backdrop-blur-sm"
              >
                <div
                  className="font-medium text-foreground"
                  style={{
                    fontSize: "var(--font-size-h2)",
                    lineHeight: 1,
                    letterSpacing: "-0.02em",
                  }}
                >
                  <CountUp to={s.value} suffix={s.suffix} duration={1400} />
                </div>
                <div
                  className="mt-2 text-text-tertiary"
                  style={{ fontSize: "var(--font-size-micro)" }}
                >
                  {s.label}
                </div>
              </div>
            </ScrollReveal>
          ))}
        </div>

        <div className="mt-16">
          <StaggerGrid
            stagger={50}
            direction="up"
            className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3"
          >
            {agents.map((a) => (
              <GlowCard
                key={`${a.id}-${a.role}`}
                glowColor="rgba(139, 92, 246, 0.18)"
                className="group rounded-xl border border-card-border bg-card/40 p-5 backdrop-blur-sm transition-colors hover:border-card-border-hover"
              >
                <div className="flex items-baseline justify-between">
                  <span
                    className="font-mono text-text-tertiary"
                    style={{ fontSize: "var(--font-size-micro)" }}
                  >
                    {a.id}
                  </span>
                  <span
                    className="font-mono text-text-quaternary"
                    style={{ fontSize: "var(--font-size-micro)" }}
                  >
                    agent
                  </span>
                </div>
                <div
                  className="mt-3 font-medium text-foreground"
                  style={{ fontSize: "var(--font-size-h3)" }}
                >
                  {a.role}
                </div>
                <div
                  className="mt-1 font-mono text-text-secondary"
                  style={{ fontSize: "var(--font-size-micro)" }}
                >
                  {a.owns}
                </div>
              </GlowCard>
            ))}
          </StaggerGrid>
        </div>
      </div>
    </section>
  );
}
