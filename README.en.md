<sub>🌐 <a href="README.md">中文</a> · <b>English</b></sub>

<div align="center">

# ggplot2-pub

> *「Nine out of ten agent-made charts look like drafts — and the tenth is a blank image. This skill saves you all nine.」*

[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-ggplot2--pub-blueviolet)](SKILL.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![smoke](https://img.shields.io/badge/smoke-8%20checks%20%2F%200%20FAIL-brightgreen)](scripts/smoke-cjk.R)
[![skills.sh](https://skills.sh/b/zhjx19/ggplot-pub)](https://skills.sh/zhjx19/ggplot-pub)

**Publication-grade ggplot2 skill: every rule verified on real hardware, built to survive Chinese/CJK environments.**

[See it work](#what-it-delivers) · [Install](#quick-start) · [Triggers](#trigger-phrases) · [How it differs](#how-it-differs) · [Safety](#safety-boundaries)

</div>

---

![demo](assets/demo.gif)

<sub>A real terminal replay of the 8-check smoke test (`scripts/make-demo.R` regenerates this GIF; no staged screenshots).</sub>

| What agents draw by default | With this skill |
| --- | --- |
| ![before](assets/before.png) | ![after](assets/after.png) |

<sub>Same data, same ggplot2 — the only difference is a set of hardware-verified rules. Both images rendered by [make-showcase.R](scripts/make-showcase.R); reproduce them anytime.</sub>

---

## Why this exists

Here's the thing: ask an agent to plot something in R and nine times out of ten you get the left image — grey panel, five default hues, alphabetical ordering that buries the point, a title that just names a column, and a legend nobody needs. The agent isn't incapable; nobody ever told it what "publication-grade" means.

Chinese users get a bonus trap: run an R script from a terminal and legacy locales silently mangle CJK text. Best case your labels turn into □□□; worst case `ggsave` dies with an arcane `gridtext ... isn't supported` error and exports a **completely blank image** — nothing in the message hints at encoding. We reproduced every one of these failures on real hardware ([evidence](examples/cjk-crash-mojibake.png)) and wrote the symptom → cause → fix into the skill itself.

This skill doesn't invent new aesthetics. It does three things: turns publication rules into an executable 8-step workflow; converts silent CJK failures into a defense table with verified fixes; and backs key claims with a smoke test, so rules are runnable code rather than oral tradition.

## What it delivers

Real inputs (three canonical scenarios, acceptance criteria in [test-prompts.json](test-prompts.json)):

```text
① "Plot mean conversion per channel in R, for my boss"
② "Make a pie chart of revenue share per product line"
③ "Reviewers say my figure's text is too small, labels overlap, colors look rainbow"
```

Expected behavior: ① aggregate and sort before plotting, highlight the key group over neutral grey, insight-style left-aligned title, export 300 dpi PNG and **open the file to verify**; ② offer a sorted bar/dot alternative once with reasoning, then comply if you insist; ③ hit the `base_size` / `ggrepel` / Okabe-Ito trio.

## Quick start

```bash
npx skills add zhjx19/ggplot-pub
```

R-side dependencies — the core 4 are auto-installed; **palettes and templates are zero-dependency, no obscure packages pushed on you**:

```r
install.packages(c("ggrepel", "patchwork"))
```

Then say to your agent:

```text
Plot this CSV as a publication-grade comparison: sort by value, highlight the
key group, insight-style title, export 300 dpi PNG and open it to verify CJK renders.
```

## Trigger phrases

- "plot / draw / make a figure" (in an R context)
- "this ggplot2 chart looks off, fix it"
- "a figure for my paper"
- "ggsave output has a transparent background / Chinese shows as boxes"
- "revise per reviewer comments"
- "combine two plots (patchwork)"
- "make the palette colorblind-safe"

## How it differs

| Dimension | Typical rules / peers | ggplot2-pub |
| --- | --- | --- |
| Form | rule lists or Cursor rules keyed on filenames | SKILL.md workflow + trigger-rich description + layered references |
| CJK environments | mostly unhandled | symptom→cause→fix defense table + smoke test, each reproduced on hardware |
| Rule credibility | oral tradition | key claims carry measured numbers (pseudo-guide 1 vs 0; locale fix flips WARN→PASS) |
| Dependency policy | recommend a pile of packages, break when missing | core 4 auto-installed; only ggrepel+patchwork suggested; palettes/significance-brackets/heatmap-clustering are zero-dependency |
| Install | copy files by hand | one line via `npx skills add` |

## Safety boundaries

- Never modifies your data files; reads them to plot only.
- Never runs `install.packages`, registers system fonts, or edits `.Rprofile` without asking first.
- Makes no network requests (except package installation, with your confirmation).
- If you insist on a pie/3D/dual-axis chart: one suggestion of alternatives, then it complies — no nagging.
- Scope is R + ggplot2 static figures; Python (matplotlib/plotnine), plotly interactivity, and dashboards are out of scope.

## File structure

```text
ggplot2-pub/
├── SKILL.md                        # main spec: 8-step workflow + defense table + antipatterns
├── test-prompts.json               # 3 functional scenarios + trigger/negative-trigger cases
├── references/
│   ├── palettes.md                 # tidyecology default palette + Okabe-Ito/Tol HEX + zero-dep CVD check
│   ├── recipes.md                  # error bars/CI, significance brackets, axis transforms, heatmaps
│   ├── multipanel.md               # facet-vs-split decision table, per-panel highlight, size estimation
│   ├── antipatterns.md             # before/after antipattern fixes (images + code)
│   ├── img/cjk-crash-mojibake.png  # real crash evidence (mojibake title)
│   └── baseline-v1.2-cursor-rule.md  # original v1.2 rules, archived
├── scripts/
│   ├── smoke-cjk.R                 # environment smoke test: 8 checks, all-PASS before delivery
│   ├── make-showcase.R             # re-render the README before/after images
│   └── make-demo.R                 # regenerate assets/demo.gif from a real smoke replay
├── assets/                         # before/after PNGs, demo.gif + vhs tape
├── examples/                       # real crash evidence archive
├── README.md / README.en.md / LICENSE / .claude-plugin/  # packaging
└── this folder doubles as an OpenCode skill directory
```

## Verification

```bash
Rscript scripts/smoke-cjk.R    # expect: all PASS (1 locale WARN under plain terminals, see defense table)
```

Acceptance prompt: hand the agent a CSV with a categorical column and say "plot it as a publication-grade comparison". Pass = sorting, highlight, `theme_pub`, explicit export parameters, and the agent proactively opening the exported file to verify rendering. Before touching any rendering rule, run the smoke test; run it again after — both must be all-PASS.

## Credits

- [tidyecology.com](https://tidyecology.com/) — source of the default datasheet theme & palette
- [rfigure.skill](https://github.com/qwlei328-maker/rfigure.skill) — the craft of rules backed by measured evidence
- [meodai/skill.color-expert](https://github.com/meodai/skill.color-expert) — layered progressive disclosure & trigger evals
- [elsevier-figure-style](https://github.com/guhou-hvi/elsevier-figure-style) — rules with sources and profiles
- [posit-dev/skills](https://github.com/posit-dev/skills) — official description trigger phrasing
- [K-Dense-AI/scientific-agent-skills](https://github.com/K-Dense-AI/scientific-agent-skills) — "non-negotiable guardrails" style
- [mckinsey-style-visualization-skill](https://github.com/kgraph57/mckinsey-style-visualization-skill) / [AgentFigureGallery](https://github.com/Dsadd4/AgentFigureGallery) — showcase craft
- Palettes: Okabe-Ito & Paul Tol public palettes; polished with the [Luban skill workshop](https://github.com/LearnPrompt)

## License

[MIT](LICENSE)
