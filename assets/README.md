# OrchyStraw Assets

Source of truth for all visual assets. All brand colors, dimensions, and
naming follow `brand-guide.md`.

## Directory layout

```
assets/
├── brand-guide.md           Brand rules (colors, typography, logo usage)
├── README.md                This file
├── branding/                Logo variants (mark + wordmark)
├── icons/                   Favicons, app icons
├── social/                  Platform-specific social graphics
│   ├── og/                    Open Graph default (FB, Slack, Discord, iMessage)
│   ├── github/                GitHub repository social preview
│   ├── twitter/               (reserved — not yet populated)
│   ├── linkedin/              (reserved — not yet populated)
│   ├── instagram/             (reserved — not yet populated)
│   └── youtube/               (reserved — not yet populated)
└── source/                  Working files, iterations, design scratch
```

## Brand colors (authoritative)

| Token | Hex |
|-------|-----|
| Background | `#0a0a0a` |
| Surface | `#111111` |
| Border | `#1e293b` |
| Text primary | `#fafafa` |
| Text muted | `#94a3b8` |
| Accent blue | `#3b82f6` |

**Note:** Older assets used `#58a6ff` (GitHub-style blue). All current sources
in this directory use `#3b82f6` per the brand guide. If you find `#58a6ff` in
a new file, it's a regression — fix it.

## Handoff to web

`site/public/` is maintained by 11-web. When web needs updated art, copy the
relevant SVG from `assets/branding/` or `assets/icons/` into `site/public/`
and run the site build. The designer agent does not write to `site/`.

Known web assets currently in `site/public/` that have newer sources here:

| site/public | newer source |
|-------------|--------------|
| `logo.svg` | `assets/branding/logo-mark-dark-512.svg` (512 source; rescale for 128 use) |
| `favicon.svg` | `assets/icons/favicon-32.svg` (the existing one has a broken transform outside the viewBox) |
| `og-image.svg` | `assets/social/og/social-og-default-1200x630.svg` |

## Naming convention

```
[category]-[name]-[variant]-[dimensions].[ext]
```

Examples: `logo-mark-dark-512.svg`, `favicon-32.svg`, `social-og-default-1200x630.svg`.
