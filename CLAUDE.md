# Hippocampus Experiments — Agent Instructions

This repo tracks experiments that test and evolve the **Hippocampus** decision-memory system. It is a companion to the application repos (`hippo-poc-001`, `hippo-poc-003`, etc.) — not a runnable project.

## What lives here

| File / Directory | Purpose |
|-----------------|---------|
| `hippocampus-experiment-skill.md` | Canonical skill file — full methodology for running a Hippocampus experiment series |
| `.claude/skills/hippocampus-experiment/SKILL.md` | Skill installed for Claude Code |
| `poc-003-experiment-log.md` | Experiments 3.1–3.7: decision record production quality |
| `poc-004-experiment-log.md` | Experiments 4.1–4.3: cold-read usability |
| `snip-v3-decision-tracking.md` | Snip v3 decision tracking experiment |
| `snip-v4-decision-tracking.md` | Snip v4 decision tracking experiment |
| `token-usage/` | Token usage methodology and results |

## Running an experiment

Use the hippocampus-experiment skill:

```
/hippocampus-experiment
```

Or read `.claude/skills/hippocampus-experiment/SKILL.md` directly for the full step-by-step methodology.

## Experiment series summary

### poc-003: Production Quality (experiments 3.1–3.7)

**Question**: Will agents write decision records with accurate Relationships and Alternatives fields?

**Stopping condition met (3.7)**: ≥3 records per run with both Relationships AND Alternatives non-empty.

Key mechanisms:
- `surfaceRelated()` queries index and prints related DRs inline before each log write
- `buildIndex(false)` after each log — mid-session DRs become queryable immediately (virtuous cycle)
- Passive-voice alternatives extraction (`X is rejected because Y`) runs before active form
- Classifier deferred-trigger narrowed to first-person intent phrases only

### poc-004: Cold-Read Usability (experiments 4.1–4.3)

**Question**: Can a fresh agent understand the architecture from the decision index alone?

| Experiment | Key change | File reads |
|------------|-----------|------------|
| 4.1 baseline | Title + filename only | 13/21 |
| 4.2 | Inline Why/Rejected/Depends-on + `chain` command | 1/21 |
| 4.3 | Explicit "none documented" + `list` command | **0/21** |

Agent verdict: *"The dependency graph turns a flat collection of notes into a navigable causal model. Decisively better than git log for the why."*

## Adding a new experiment log

1. Create `<poc-name>-experiment-log.md` following the structure in existing logs
2. Reference the application repo (e.g. `hippo-poc-003`) and the spec version under test
3. Record hypothesis, actual results, and findings per experiment
4. Update the series summary table in this CLAUDE.md

## Application repos

- `hippo-poc-001` — Hippocampus core system (this is where the CLI lives)
- `hippo-poc-003` — Forge background job processor (21 decisions, F-01 through F-13)
