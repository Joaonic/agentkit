# AgentKit — Landing Page Design Specification

> Design document for the AgentKit product landing page.
> Target: developer tools audience, dark-mode-first, high-conversion.

---

## 1. Design Principles

| Principle | Implementation |
|-----------|---------------|
| **Dark-mode-first** | Deep navy/charcoal background (#0d1117), neon accent on CTA |
| **Developer-centric** | Terminal-style code blocks, monospace typography, syntax highlighting |
| **Motion** | Subtle scroll-reveal animations, no heavy animations |
| **Conversion** | Primary CTA above fold, repeated every 2 sections |
| **Trust** | GitHub stars badge, metrics, before/after evidence |
| **Speed** | Static site (Next.js SSG or Astro), <1s LCP |

## 2. Color Palette

```
Background:    #0d1117  (GitHub dark)
Surface:       #161b22  (card backgrounds)
Border:        #30363d  (subtle borders)
Text Primary:  #e6edf3  (light gray)
Text Secondary:#8b949e  (muted gray)
Accent:        #58a6ff  (blue links)
CTA Primary:   #238636  (green — GitHub-style)
CTA Hover:     #2ea043  (lighter green)
Pro Badge:     #a371f7  (purple)
Free Badge:    #3fb950  (green)
Warning:       #d29922  (amber)
Code BG:       #0d1117  (same as bg, bordered)
```

## 3. Typography

```
Headings:    Inter, -apple-system, sans-serif — 700 weight
Body:        Inter, -apple-system, sans-serif — 400 weight
Code/Terminal: JetBrains Mono, Fira Code, monospace — 400 weight
Hero Title:  clamp(2.5rem, 5vw, 4rem)
Section H2:  clamp(1.8rem, 3vw, 2.5rem)
Body:        1rem / 1.6 line-height
```

## 4. Page Sections (scroll order)

### 4.1 Hero (above fold)

```
┌─────────────────────────────────────────────────────────────┐
│  [GitHub Stars Badge]              [Docs] [Pricing] [GitHub]│
│                                                             │
│      ⚡ AgentKit                                            │
│      AI Engineering Governance Framework                    │
│                                                             │
│      Stop your AI agent from writing spaghetti code.        │
│      67 skills · 51 rules · 11 agents · 4 pipeline scripts │
│                                                             │
│      ┌──────────────────────────────────────────────┐       │
│      │ $ curl -fsSL agentkit.dev/install | bash     │ [📋]  │
│      └──────────────────────────────────────────────┘       │
│                                                             │
│      [Get Free]  [Get Pro — $79]                            │
│                                                             │
│      Works with: [Cursor] [Copilot] [Windsurf] [Cline]     │
└─────────────────────────────────────────────────────────────┘
```

**Design notes:**
- Background: dark with subtle gradient (#0d1117 → #161b22)
- "AgentKit" in large bold, lightning bolt emoji or icon
- Tagline in Text Secondary
- Terminal block with green border, copy button
- Two CTAs: Free (outlined) and Pro (solid green)
- Tool logos in grayscale, hover → color
- Floating particles or grid background (very subtle)

### 4.2 Problem Statement

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  "Your AI agent can code. But can it engineer?"             │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │ ❌ Without       │  │ ✅ With AgentKit │                  │
│  │ AgentKit        │  │                 │                  │
│  ├─────────────────┤  ├─────────────────┤                  │
│  │ Skips tests     │  │ TDD-first       │                  │
│  │ No code review  │  │ Mandatory review│                  │
│  │ Spaghetti arch  │  │ Hexagonal clean │                  │
│  │ No planning     │  │ Plan → Issue →  │                  │
│  │ Guesses context │  │ Evidence-based  │                  │
│  │ No docs         │  │ Auto-documented │                  │
│  └─────────────────┘  └─────────────────┘                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Design notes:**
- Two-column comparison cards
- Left card: red-tinted border (#f85149)
- Right card: green-tinted border (#3fb950)
- Animate: slide in from sides on scroll

### 4.3 How It Works (3-step)

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  How It Works                                               │
│                                                             │
│  ┌──────────┐  ───→  ┌──────────┐  ───→  ┌──────────┐     │
│  │ 1. Install│       │ 2. Code  │       │ 3. Ship   │     │
│  │           │       │           │       │           │     │
│  │ One-liner │       │ AI agent │       │ Auto CI/CD│     │
│  │ installer │       │ follows  │       │ changelog │     │
│  │ auto-     │       │ skills,  │       │ version   │     │
│  │ detects   │       │ rules &  │       │ tag &     │     │
│  │ your VCS  │       │ agents   │       │ deploy    │     │
│  └──────────┘       └──────────┘       └──────────┘     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Design notes:**
- Three cards in a row, connected by arrows
- Each card: icon at top, number badge, title, description
- Icons: terminal, brain, rocket
- Subtle entrance animation (fade up with stagger)

### 4.4 Skills Showcase (interactive tabs)

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  67 Skills for Every Phase                                  │
│                                                             │
│  [Planning] [Implementation] [Testing] [Review] [DevOps]   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  new-plan          Create execution-ready plans     │    │
│  │  implement-plan    Execute plan with TDD gates      │    │
│  │  create-milestone  Multi-front parallel planning    │    │
│  │  new-use-case      Hexagonal use case scaffold      │    │
│  │  new-api-resource  Full CRUD resource generator     │    │
│  │  ...               +62 more skills                  │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  [Browse All Skills →]                                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Design notes:**
- Tab bar with category filters
- Each skill: name (monospace, accent color) + description
- Show 5-6 per tab, "Browse all" link
- Code-editor-like styling (line numbers optional)

### 4.5 CI/CD Pipeline Showcase (NEW — add-on)

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Ship with Confidence                                       │
│  Trunk-based CI/CD with AI-powered changelogs               │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Push to main                                       │    │
│  │    ↓                                                │    │
│  │  CI: build + test + lint          ✅ 45s            │    │
│  │    ↓                                                │    │
│  │  AI Changelog (gpt-4o-mini)       ✅ 8s             │    │
│  │    ↓                                                │    │
│  │  Version bump: 1.2.3 → 1.2.4     ✅ 2s             │    │
│  │    ↓                                                │    │
│  │  Docker build (arm64 + amd64)     ✅ 120s           │    │
│  │    ↓                                                │    │
│  │  Deploy to production             ✅ 15s            │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  Supports: [Java/Maven] [Node.js] [Bun] [GitLab] [GitHub]  │
│                                                             │
│  [Get CI/CD Pack →]                                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Design notes:**
- Pipeline visualization with green checkmarks
- Animated: steps appear one by one on scroll
- Stack badges at bottom (language/provider logos)

### 4.6 Pricing

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Choose Your Plan                                           │
│                                                             │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   │
│  │  FREE         │   │  PRO          │   │  TEAM         │   │
│  │               │   │  ★ Popular    │   │               │   │
│  │  $0           │   │  $79          │   │  $199         │   │
│  │  forever      │   │  one-time     │   │  /year        │   │
│  │               │   │               │   │               │   │
│  │  14 skills    │   │  67 skills    │   │  Everything   │   │
│  │  10 rules     │   │  51 rules     │   │  in Pro +     │   │
│  │  4 agents     │   │  11 agents    │   │               │   │
│  │               │   │  4 scripts    │   │  Priority     │   │
│  │               │   │  CI/CD pack   │   │  support      │   │
│  │               │   │  Deploy pack  │   │  1yr updates  │   │
│  │               │   │  Workflow docs│   │  Team license  │   │
│  │               │   │               │   │               │   │
│  │  [Get Free]   │   │ [Get Pro] ◀── │   │  [Contact]    │   │
│  └──────────────┘   └──────────────┘   └──────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Add-ons (works with any tier)                      │    │
│  │                                                     │    │
│  │  CI/CD Pipeline Pack .... $29    [Add]              │    │
│  │  Deploy Scripts Pack .... $29    [Add]              │    │
│  │  Design Patterns ...... included in Pro             │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Design notes:**
- Three cards, Pro highlighted with purple border + "Popular" badge
- Free: outlined card, Pro: filled card with glow, Team: outlined
- Add-ons section below as a separate row
- All prices in USD

### 4.7 Design Patterns Section (Pro)

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  22 GoF Design Patterns — As Executable Skills              │
│                                                             │
│  Not just theory. Each pattern is a step-by-step skill      │
│  your AI agent can follow to implement it correctly.        │
│                                                             │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐   │
│  │Strategy│ │Observer│ │Factory │ │Adapter │ │Builder │   │
│  ├────────┤ ├────────┤ ├────────┤ ├────────┤ ├────────┤   │
│  │Facade  │ │Command │ │State   │ │Proxy   │ │Bridge  │   │
│  ├────────┤ ├────────┤ ├────────┤ ├────────┤ ├────────┤   │
│  │Decorator│ │Composite│ │Iterator│ │Mediator│ │Memento │   │
│  ├────────┤ ├────────┤ ├────────┤ ├────────┤ ├────────┤   │
│  │Visitor │ │Chain   │ │Template│ │Flyweight│ │Singleton│  │
│  ├────────┤ ├────────┤                                     │
│  │Prototype│ │Abstract│                                     │
│  │        │ │Factory │                                     │
│  └────────┘ └────────┘                                     │
│                                                             │
│  [Included in Pro →]                                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 4.8 Supported Stacks

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Works With Your Stack                                      │
│                                                             │
│  Languages & Frameworks:                                    │
│  [Java/Spring Boot] [TypeScript] [NestJS] [Next.js]        │
│  [React] [Node.js] [Bun] [Python]                          │
│                                                             │
│  AI Tools:                                                  │
│  [Cursor] [GitHub Copilot] [Windsurf] [Cline] [Aider]     │
│                                                             │
│  VCS:                                                       │
│  [GitHub] [GitLab]                                          │
│                                                             │
│  Infrastructure:                                            │
│  [PostgreSQL] [Redis] [RabbitMQ] [Docker] [Elasticsearch]  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Design notes:**
- Logo grid, grayscale → color on hover
- Grouped by category
- Responsive: 4 per row desktop, 2 mobile

### 4.9 Social Proof / Metrics

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Built by engineers who ship daily                          │
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ 67       │  │ 51       │  │ 22       │  │ 4        │  │
│  │ Skills   │  │ Rules    │  │ Patterns │  │ Pipeline │  │
│  │          │  │          │  │          │  │ Scripts  │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
│                                                             │
│  "Reduced our PR review cycle from 3 days to 4 hours"      │
│  — Engineering team using AgentKit in production            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 4.10 Final CTA

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Ready to govern your AI agent?                             │
│                                                             │
│  ┌──────────────────────────────────────────────┐           │
│  │ $ curl -fsSL agentkit.dev/install | bash     │ [📋]     │
│  └──────────────────────────────────────────────┘           │
│                                                             │
│  [Get Free]  [Get Pro — $79]  [View on GitHub]              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 4.11 Footer

```
┌─────────────────────────────────────────────────────────────┐
│  AgentKit    Docs          Product         Legal            │
│              Getting Started  Free vs Pro  MIT License      │
│  © 2026     Installation     Pricing       Privacy          │
│              Skills Catalog   Changelog     Terms            │
│  [GitHub]   Pipeline Guide   Roadmap                        │
│  [Twitter]  Creating Skills  FAQ                            │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. Responsive Breakpoints

| Breakpoint | Layout |
|-----------|--------|
| Desktop (≥1024px) | 3-column pricing, 5-col pattern grid, side-by-side comparison |
| Tablet (768-1023px) | 2-column pricing, stacked comparison, 3-col patterns |
| Mobile (<768px) | Single column everything, hamburger nav, compact pricing |

## 6. Interactions & Animations

| Element | Animation | Trigger |
|---------|-----------|---------|
| Hero terminal | Typing effect on install command | Page load |
| Comparison cards | Slide in from sides | Scroll into view |
| How It Works steps | Fade up with 200ms stagger | Scroll into view |
| Pipeline steps | Appear one-by-one with checkmarks | Scroll into view |
| Pattern grid | Subtle scale on hover (1.05) | Hover |
| Pricing Pro card | Pulsing purple glow | Always |
| Counters | Count-up animation (0 → 67) | Scroll into view |
| Copy button | "Copied!" tooltip for 2s | Click |

## 7. Technical Stack (recommended)

| Option | Stack | Deploy |
|--------|-------|--------|
| **A (fastest)** | Astro + Tailwind CSS + static | Vercel/Cloudflare Pages |
| **B (feature-rich)** | Next.js SSG + Tailwind + MDX | Vercel |
| **C (simplest)** | Single HTML + Tailwind CDN | GitHub Pages |

Recommended: **Option A** — Astro for static generation, Tailwind for styling, no JS framework needed.

## 8. SEO & Meta

```html
<title>AgentKit — AI Engineering Governance Framework</title>
<meta name="description" content="67 skills, 51 rules, 11 agents that make your AI coding agent write production-grade code. TDD, code review, hexagonal architecture — enforced automatically.">
<meta property="og:title" content="AgentKit — Stop AI agents from writing spaghetti code">
<meta property="og:description" content="Governance framework for Cursor, Copilot, Windsurf, and any AI coding agent. Skills, rules, agents, and CI/CD pipelines.">
<meta property="og:image" content="https://agentkit.dev/og-image.png">
<meta name="twitter:card" content="summary_large_image">
```

## 9. Domain & Hosting

- Primary domain: `agentkit.dev` (to purchase)
- Fallback: `agentkit.sh` or hosted on `joaonic.github.io/agentkit`
- CDN: Cloudflare or Vercel Edge
- Analytics: Plausible (privacy-first) or Umami

## 10. Content Variants

### English (default)
- All sections in English
- USD pricing
- `/` route

### Portuguese
- Full translation
- BRL pricing (R$)
- `/pt` route or `pt.agentkit.dev` subdomain

## 11. Conversion Funnel

```
Landing → Install (Free) → Use → Hit limits → Upgrade to Pro
                                    ↓
                              Buy add-ons (CI/CD, Deploy)
```

- Free tier has enough value to hook
- Pro upsell visible but not aggressive
- Add-ons as separate purchase for flexibility
- Email capture optional (newsletter for updates)

## 12. Asset Requirements

| Asset | Format | Notes |
|-------|--------|-------|
| Logo | SVG | Lightning bolt + "AgentKit" text |
| OG Image | PNG 1200x630 | Dark bg, logo, tagline |
| Tool logos | SVG/PNG | Cursor, Copilot, Windsurf, Cline |
| Stack logos | SVG/PNG | Java, TypeScript, React, etc. |
| Favicon | ICO + SVG | Lightning bolt icon |
| Screenshots | PNG/WebP | Terminal with skills, rules output |
