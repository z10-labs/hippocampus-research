# POC-004 Experiment Log

Testing whether the Hippocampus decision index can serve as a **stand-alone reference** for a cold-read agent — one that has never seen the codebase — to understand design decisions faster and with less context than reading `git log`.

**Scope shift from poc-003**: poc-003 tested *production* of records (do agents write good records?). poc-004 tests *consumption* of records (are the records useful to a different agent reading them cold?).

**Success criterion**: A fresh agent given only `hippocampus:query` access can:
1. Correctly answer "why" questions about Forge's architecture without reading source files
2. Propose a new feature design that correctly inherits prior constraints
3. Self-report that the decision records saved meaningful time vs reading git history

**Improvement target**: Reduce the time-to-comprehension for a cold-read agent. Currently the agent must read 21+ markdown files to understand the decision graph. The goal is to surface decision content inline in query results so the agent gets what it needs from query output alone.

---

## Experiment 4.1 — Baseline cold-read (current system)

**Date**: 2026-05-27
**Hypothesis**: A fresh agent given only `hippocampus:query` will be able to answer architecture questions correctly but will spend most of its time reading individual record files — the query output gives filenames, not content, so the cold-read cost is high.

### Test design

Three tasks for the cold-read agent:
1. **Comprehension**: "Without reading any source files, answer: what persistence mechanism does Forge use, and why was it chosen over alternatives?"
2. **Design extension**: "Propose an architecture for F-14 (Job Tagging: jobs can have string tags; queries can filter by tag). Name the prior decisions it depends on, and explain what alternatives you rejected."
3. **Self-assessment**: "Did the decision records help you understand the codebase more efficiently than reading git log would have? Be specific about what worked and what didn't."

The agent is given:
- Access to `hippocampus:query` and `hippocampus:index` commands
- Access to read `.decisions/records/` files (to simulate the current fallback path)
- NO access to `src/` source files
- NO access to git log

### Actual results (4.1)

| Metric | Result |
|--------|--------|
| Queries run | 6 |
| Record files opened | 13 of 21 |
| Task 1 answered from query output alone | No — required file reads |
| Task 2 produced correct architecture | Yes (sophisticated: denormalized shadow table with index) |
| Self-reported: better than git log | Yes for "why" questions; git log faster for "what schema exists" |

**Key findings:**
- Titles alone not enough — agent opened files to get Why/Alternatives content
- 11 of 13 records had empty Alternatives — the most useful section was the emptiest
- Filename truncation forced file opens to distinguish similar records
- No schema roll-up forced reconstruction across 8 records
- `git log` would have been faster for "what columns does jobs have now?" but slower for "why SQLite over Redis?"

---

## Experiment 4.2 — Improved cold-read (inline content in query output)

**Date**: 2026-05-27
**Changes from 4.1**: Query output now shows Why/Rejected/Depends-on inline; `hippocampus:chain DR-NNNN` command added; passive-voice extraction noise suppressed; classifier deferred-trigger narrowed.

### Actual results (4.2)

| Metric | 4.1 baseline | 4.2 improved |
|--------|-------------|--------------|
| Queries run | 6 | **4** |
| Record files opened | 13 | **1** |
| Task 1 answered from query output alone | No | **Almost — 1 file to confirm empty alternatives** |
| Task 2 produced correct architecture | Yes | **Yes, with explicit DR citations** |
| Self-reported: better than git log | Yes for why-questions | **Yes — definitively** |

**The chain command delivered concrete value**: `chain DR-0014` revealed DR-0014 → DR-0001 and DR-0009 in one call, establishing the column-on-jobs-table pattern with full provenance. Without it, 3-4 additional queries would have been needed.

### Remaining gaps identified (4.2)

1. **Truncated Why snippets cause uncertainty** — DR-0001's snippet ends "…No Redis, no external broker…" with no indicator of whether more content follows. The agent opened the file to check for a structured Alternatives section. Fix: explicitly show `Alternatives: none documented` in query output when the section is empty — removes the uncertainty that triggers file opens.

2. **No discovery by category** — the DR-0002 "queue-as-filter" precedent was only found because the agent thought to query it. A `hippocampus:list --category api` command would surface all api-category records for discovery without requiring the right query phrasing.

---

## Experiment 4.3 — Zero-file-open target

**Hypothesis**: Showing `Alternatives: none documented` explicitly in query output + adding a `hippocampus:list` command will eliminate the remaining file opens for cold-read agents.

### Actual results (4.3)

| Metric | 4.1 baseline | 4.2 improved | 4.3 final |
|--------|-------------|--------------|-----------|
| Queries/commands run | 6 | 4 | **~9** (list+query+chain) |
| Record files opened | 13 | 1 | **0** ✅ |
| Task 1 from commands only | No | Almost | **Yes** |
| Architecture quality | Sophisticated | Sophisticated | **6-decision design with full DR citations** |
| Self-reported vs git log | Yes for why-questions | Definitively yes | **"Decisively better for the why"** |

**Agent verdict (verbatim):** "It is genuinely useful: the dependency graph turns a flat collection of notes into a navigable causal model, and the chain command makes ripple-effect analysis instantaneous rather than manual."

**Specific credits:**
- `hippocampus:list --weight=heavy` immediately surfaced DR-0005 and DR-0006 before any semantic query connected to them — without list, those would have been invisible
- Category sweep (`--category=state`, `--category=error-handling`, etc.) surfaced DR-0015, DR-0016, DR-0017 which never appeared in top-5 of any semantic query
- "Rejected: (none documented)" functioned as an explicit confidence signal — records with documented alternatives felt authoritative; records without felt lower-confidence — without requiring a file open to discover the silence
- `hippocampus:chain DR-0009` showed "which future features are load-bearing on this decision" without manual archaeology

**Two remaining gaps (not blocking, legitimate limitations):**

1. Full SQL DDL (column types, NOT NULL constraints, index definitions) not recoverable from decisions — records describe what was added and why, not the full current schema artifact. This is a feature, not a bug: the system records reasoning, not state. State lives in the schema files.
2. Full status enum values not listed — DR-0019 mentions `'replayed'`, DR-0014 implies `'queued'`, but the complete list is not in any record. For a feature adding a new status value this matters at implementation time (not design time).

---

## Experiment Series Summary (poc-004)

### Cold-read progression

| Experiment | Key change | File reads | Agent verdict |
|------------|-----------|-----------|---------------|
| 4.1 (baseline) | Current system — titles + filenames only | 13/21 | Worked but expensive |
| 4.2 | Inline Why/Rejected/Depends-on + `chain` command | 1/21 | "Definitively better than git log" |
| 4.3 | Explicit "none documented" + `hippocampus:list` | **0/21** | "Genuinely useful — dependency graph is a causal model" |

### What moved the needle most (ranked)

1. **Inline Why in query output** — single biggest reduction in file opens. Agents needed the content, not the filename.
2. **`hippocampus:chain`** — turned ripple-effect analysis from manual (4+ queries) to one command. The agent called it out specifically for F-15 design.
3. **"Rejected: (none documented)"** — explicit absence is as informative as explicit presence. Eliminated the "is there more below the truncation?" file-open trigger.
4. **`hippocampus:list --category`** — structural discovery that semantic queries cannot provide. Surfaced records that were invisible to similarity search.

### The system's value proposition (now validated)

The decision graph does something git history cannot: it records **why alternatives were rejected** and **which future decisions are load-bearing on each choice**. DR-0002's constraint ("Queue is a routing label, not a capacity boundary") was described by the agent as the kind of sentence that would require "PR description, ticket, team chat thread to reconstruct from a diff." The chain command surfaces that sentence in under a second.

The two artifacts are complementary: git log tells you what was built; the decision graph tells you why the architecture is constrained the way it is. For cold-read design work, the decision graph is faster and more reliable than archaeology through commit history.

