# hippocampus-research

Methodology, experiment logs, and raw results for [Hippocampus](https://github.com/z10-labs/hippocampus) — decision memory for AI coding agents.

This repo is the *why we believe it works* half. The server lives in [hippocampus](https://github.com/z10-labs/hippocampus); the harness it was tested against lives in [hippocampus-validation](https://github.com/z10-labs/hippocampus-validation).

## The two questions

A decision-memory system can fail at either end. It can fail to **produce** good records — agents log `"used Redis"` with no reasoning, no links, and the store fills with noise. Or it can produce good records that fail to be **consumed** — the data is there, but a fresh agent still can't get what it needs without opening every file.

We ran a series against each.

### poc-003 — production quality

*Will agents write records with accurate `Relationships` and `Alternatives` fields, unprompted?*

Experiments 3.1 through 3.7. Each phase changed one layer — the log command, the skill instructions, the hooks — and rebuilt features of a job processor from a fresh spec version. Before each run we wrote down the decisions a well-behaved agent *should* log, then compared.

The breakthrough was making `log` surface related prior records **at the moment of writing**, rather than telling the agent to go query first. Agents don't reliably follow a "query before you log" instruction. They do reliably use information already in front of them.

**Stopping condition met:** 3/3 records per run with both `Relationships` and `Alternatives` non-empty.

→ [`poc-003-experiment-log.md`](poc-003-experiment-log.md)

### poc-004 — cold-read usability

*Can an agent that has never seen the codebase understand its architecture from the decision index alone?*

A fresh agent, no source access, three tasks: explain a persistence choice and its rejected alternatives; design a new feature that correctly inherits prior constraints; self-assess whether the records beat reading `git log`.

The baseline was poor for a specific reason — query output returned *filenames*, not content. So the agent dutifully opened 13 of 21 record files. The fix was to inline `Why`, `Rejected`, and `Depends-on` directly into query results.

| Iteration | Source files the cold-read agent had to open |
|---|---|
| 4.1 — baseline | 13 / 21 |
| 4.2 — inline Why + Depends-on | 1 / 21 |
| 4.3 — inline Rejected alternatives | **0 / 21** |

By 4.3 the agent answered every architecture question and proposed a correctly-constrained new feature without opening a single file.

→ [`poc-004-experiment-log.md`](poc-004-experiment-log.md)

## What this is not

Read the numbers for what they are. This is **n=1** — one harness, one codebase, one model family. It shows the mechanism works under controlled conditions; it does not show it generalises to your repo. We publish the full logs, including the runs that failed, so you can judge rather than take our word.

The token-usage study (`token-usage/`) is **scaffolding only** — the methodology and scripts are written, the results table is empty. It has not been run.

## Contents

| Path | What it is |
|---|---|
| `poc-003-experiment-log.md` | Production-quality series, 3.1–3.7 — hypotheses, changes, outcomes |
| `poc-004-experiment-log.md` | Cold-read series, 4.1–4.3 — test design and agent transcripts |
| `hippocampus-experiment-skill.md` | The skill definition used to drive the experiment runs |
| `snip-v3-decision-tracking.md` · `snip-v4-decision-tracking.md` | Decision-tracking prompts under test |
| `token-usage/` | Methodology + scripts for a token-cost comparison. **Not yet run.** |

## License

MIT
