# Cinematic  -  shared scroll-driven animation components

Pure React + CSS animation primitives. Zero runtime deps beyond React 18+
(no Framer Motion, no GSAP, no Lenis). Works in any Next.js / Vite / CRA
project. Drop the `cinematic/` folder into your project's components dir
or symlink it.

## Why no GSAP / Framer / Lenis here?

Each consumer project (AIVA, Klaro, openOrchyStraw) has different
bundle-size budgets. Forcing GSAP (~50kb) or Framer Motion (~30kb) on every
import would bloat sites that only need ScrollReveal. These primitives use
IntersectionObserver + CSS transitions  -  same UX, ~2kb total.

Projects that DO want GSAP/Lenis can layer them on top. The components
forward refs and accept className overrides.

## Components

| Component | Purpose |
|---|---|
| `ScrollReveal` | Fade/slide/scale children in once on scroll |
| `StaggerGrid` | Reveal grid items in sequence with delay |
| `FloatingElements` | Orbit/float items around a center |
| `GlowCard` | Card with cursor-aware radial glow |
| `MagneticButton` | Button that pulls toward the cursor |
| `TextReveal` | Word-by-word or char-by-char reveal |
| `CountUp` | Animated number counter (triggers on scroll) |
| `ProgressScroll` | Top-of-page scroll progress bar |
| `ParallaxHero` | Full-screen hero with parallax scroll layers |
| `HorizontalScroll` | Pin section, scroll horizontally |
| `CursorSpotlight` | Page-level cursor-follow radial spotlight, spring-smoothed |
| `GradientBlobs` | Soft animated blurred radial blobs (hero backdrop) |
| `PinnedSequence` | Sticky 100vh × N steps; scroll progress drives active step (eden.so canvas pattern) |
| `ScribbleAccent` | Italic word + hand-drawn SVG underline that strokes on view |
| `LogoMarquee` | Infinite-scroll logo strip with edge-fade mask |
| `SmoothScrollProvider` | Lenis-powered physics smooth scroll (dynamic import  -  opt-in dep) |

## Install

```bash
# Symlink approach (preferred  -  picks up updates):
ln -s ~/Projects/shared/components/cinematic web/src/components/cinematic

# Or copy:
cp -r ~/Projects/shared/components/cinematic web/src/components/
```

## Usage

```tsx
import { ScrollReveal, StaggerGrid, GlowCard, CountUp } from "@/components/cinematic";

<ScrollReveal direction="up" delay={100}>
  <h2>Animates in once on scroll</h2>
</ScrollReveal>

<StaggerGrid stagger={80}>
  {items.map(i => <Card key={i.id} />)}
</StaggerGrid>

<CountUp to={1000} suffix="+" />
```

## Browser support

Modern evergreen (Chrome, Firefox, Safari 14+, Edge). Falls back to
visible/static when IntersectionObserver is missing.
