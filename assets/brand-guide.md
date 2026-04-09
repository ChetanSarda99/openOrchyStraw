# OrchyStraw Brand Guide

## Colors

| Role | Hex | Usage |
|------|-----|-------|
| Background (dark) | `#0a0a0a` | Primary background, cards, surfaces |
| Text (light) | `#fafafa` | Primary text on dark backgrounds |
| Text (muted) | `#94a3b8` | Secondary text, descriptions, labels |
| Accent Blue | `#3b82f6` | Links, interactive elements, brand accent |
| Success Green | `#22c55e` | Pass states, success messages, health indicators |
| Warning Amber | `#f59e0b` | Warnings, caution states, pending items |
| Error Red | `#ef4444` | Errors, failures, critical alerts |
| Surface | `#111111` | Elevated surfaces, card backgrounds |
| Border | `#1e293b` | Subtle borders, dividers |

### Gradients

- **Background gradient:** `#0a0a0a` to `#111111` (top to bottom)
- **Accent glow:** `#3b82f6` at 10-15% opacity for hover states and highlights

## Typography

| Context | Font | Fallback |
|---------|------|----------|
| Code, CLI output, logo | JetBrains Mono | SF Mono, Fira Code, monospace |
| UI text, body copy | Inter | Geist, system-ui, sans-serif |

### Sizes

- **Hero title:** 48-64px, weight 700, letter-spacing -2px
- **Section headings:** 28-32px, weight 600
- **Body text:** 16-18px, weight 400
- **Code/labels:** 14px, weight 400-500
- **Small/caption:** 12px, weight 400

## Logo

The OrchyStraw logo is two overlapping hexagons with a center node and connection lines, representing multi-agent orchestration and interconnected workflows.

### Usage Rules

1. **Minimum size:** 16x16px (favicon), 32x32px (inline), 64x64px (standalone)
2. **Clear space:** Maintain at least 25% of the logo width as padding on all sides
3. **On dark backgrounds:** Use the accent blue (`#3b82f6`) stroke and fill
4. **On light backgrounds:** Use `#0a0a0a` stroke with blue accents
5. **Never distort** the aspect ratio or rotate the logo
6. **Never place** the logo on busy or low-contrast backgrounds

### Files

| File | Purpose | Dimensions |
|------|---------|------------|
| `site/public/logo.svg` | Website logo | 128x128 |
| `site/public/favicon.svg` | Browser favicon | 32x32 (scales to 16x16) |
| `assets/og-image.svg` | Social sharing / Open Graph | 1200x630 |
| `assets/social-preview.svg` | GitHub social preview | 1280x640 |

## Tone & Voice

- **Technical:** Write for developers. Assume competence.
- **Concise:** Short sentences. No filler words.
- **Developer-first:** CLI examples over UI screenshots. Code over prose.
- **Confident but not arrogant:** State what OrchyStraw does, not what it claims to be.
- **Active voice:** "OrchyStraw orchestrates agents" not "agents are orchestrated by OrchyStraw."

### Examples

Good: "12 agents. Zero dependencies. One bash script."
Bad: "Our revolutionary AI-powered platform leverages cutting-edge technology..."

Good: "Run `orchystraw run ~/project --cycles 5` to start."
Bad: "Simply navigate to the configuration panel and select your preferred options."

## Dark Mode Priority

All assets are designed dark-mode-first. The `#0a0a0a` background is the default. Light mode is secondary and should maintain the same visual hierarchy with inverted contrast.
