# POC-003 Experiment Log

Testing whether architectural changes to the hippocampus system itself — not just skill instructions or hooks — can produce accurate, relationship-linked decision records from autonomous agent builds.

**Project**: hippo-poc-003 (Forge — self-hosted background job processor)  
**Spec versioning**: v1, v2, … per experiment phase  
**Experiment numbering**: 3.1, 3.2, …

---

## Experiment 3.1

**Date**: 2026-05-24  
**Spec**: v1 (Forge)  
**Hypothesis**: If `hippocampus:log` automatically queries the index on the description being logged and prints matching prior DRs to stdout before writing the record, agents will include `depends-on` references because the relevant DRs are visible at the exact moment the record is written.

### What changed from poc-002

| Layer | Change |
|-------|--------|
| `hippocampus/src/index.ts` | Added `surfaceRelated()` — queries index on description, prints direct hits (score ≥ 0.20) before writing the record |
| `SKILL.md` | Removed "query before log" instruction. Replaced with: the log command now surfaces related DRs automatically — when you see them, add `depends-on` and re-run |
| Hooks | Unchanged from poc-002 — write counter nudge kept |

### Expected Decisions (Forge v1)

Decisions a well-behaved agent should log when building all six features. Ordered by dependency chain depth.

| # | Feature | Expected Decision | Category | Weight | Depends On |
|---|---------|-------------------|----------|--------|------------|
| E-01 | F-01 Job Queue | Storage backend — SQLite, in-memory+persist, flat files | data | heavy | — |
| E-02 | F-01 Job Queue | HTTP framework — Hono, Fastify, Express, stdlib | dependency | standard | — |
| E-03 | F-01 Job Queue | Job ID generation strategy — nanoid, uuid, crypto.randomUUID | dependency | light | — |
| E-04 | F-01 Job Queue | Queue isolation model — separate tables, queue column, or separate DB files | data | heavy | E-01 |
| E-05 | F-02 Worker Runtime | Concurrency enforcement model — per-type vs per-queue, in-memory Map vs DB counter | architectural | standard | E-01 |
| E-06 | F-02 Worker Runtime | Worker claim mechanism — atomic SQLite UPDATE…RETURNING, optimistic lock, or in-memory set | data | heavy | E-01 |
| E-07 | F-02 Worker Runtime | Timeout enforcement — AbortController, Promise.race, or setTimeout+throw | architectural | standard | — |
| E-08 | F-03 Retry & DLQ | Retry backoff algorithm — fixed interval, exponential, exponential+jitter | architectural | standard | — |
| E-09 | F-03 Retry & DLQ | Retry state storage — where attempt count and next_eligible_time live across restarts | data | heavy | E-01 |
| E-10 | F-03 Retry & DLQ | DLQ storage model — same jobs table with status='dlq' vs separate DLQ table | data | standard | E-01, E-09 |
| E-11 | F-04 Scheduled Jobs | Cron parsing library — cron-parser, node-cron, hand-rolled | dependency | standard | — |
| E-12 | F-04 Scheduled Jobs | Scheduler execution path — fire handler directly vs enqueue as a regular job | architectural | standard | E-01, E-05 |
| E-13 | F-04 Scheduled Jobs | Overlap prevention mechanism — in-memory flag, DB status lock, skip-if-running check | architectural | standard | E-01, E-12 |
| E-14 | F-05 Job Inspection | Pagination strategy — cursor-based vs offset-based | api | standard | E-01 |
| E-15 | F-05 Job Inspection | Job cancellation race safety — how to cancel without conflicting with a concurrent worker claim | architectural | standard | E-06 |
| E-16 | F-06 Webhooks | Webhook delivery model — piggyback on job retry machinery vs separate delivery queue | architectural | heavy | E-01, E-09 |
| E-17 | F-06 Webhooks | Degraded endpoint detection — consecutive failure counter, sliding window, or circuit breaker | architectural | standard | E-16 |

**Critical decisions** (wrong choice breaks correctness or is hardest to reverse): E-01, E-04, E-06, E-09, E-12.

### Actual Decisions Logged

| DR | Maps to | Relationship in body | Relationship in field | Notes |
|----|---------|---------------------|-----------------------|-------|
| DR-0001 | E-01 (SQLite + WAL, better-sqlite3) | none | `- (none)` | Correct choice, no alternatives named |
| DR-0002 | E-05 (concurrency per-type not per-queue) | none | `- (none)` | Does not name DR-0001 as constraint |
| DR-0003 | E-12 (scheduler fires directly, not via POST /jobs) | none | `- (none)` | Does not name DR-0001 or DR-0002 |
| DR-0004 | E-13 partial (scheduler init on every tick) | "depends-on DR-0003" | `- (none)` | **First relationship token in 4 runs** — in body only, not in structured field |

**Not logged**: E-02, E-03, E-04, E-06, E-07, E-08, E-09, E-10, E-11, E-14, E-15, E-16, E-17

**Critical misses**: E-04 (queue isolation), E-06 (worker claim mechanism), E-09 (retry state across restarts)

### Scoring

| Metric | Result | vs Run 2 (poc-002 v4) |
|--------|--------|-----------------------|
| Decisions logged | 4 / 17 expected (24%) | = (same count) |
| Distinct log batches | 2 (20:48 and 20:55) | +1 (Run 2 had 1 batch) |
| Relationships in structured field | 0 | = |
| Relationship tokens in body text | 1 (DR-0004: "depends-on DR-0003") | +1 (first ever) |
| Critical decisions missed | 3 of 5 | same pattern |
| Write counter at end | 16 | — |

### Key Observations

**1. The auto-query intervention produced one concrete result.**  
DR-0004 contains "depends-on DR-0003" in its description text. This is the first relationship token to appear in any record across all four runs. The mechanism worked: the agent saw DR-0003 in the surfaced output and wrote the token.

**2. The relationship landed in the wrong place.**  
The token "depends-on DR-0003" is in the Why/Context prose of DR-0004. The structured `## Relationships` field still says `- (none)`. The `indexer.ts` parser only reads the `## Relationships` section, so the graph traversal won't follow this link. The relationship exists but is invisible to the system.

**3. DR-0001 was logged with an empty index.**  
`surfaceRelated()` only queries if `index.entries.length > 0`. DR-0001 was the first log call. The index was empty. No query ran. This means the first decision in every session can never surface dependencies — even if relevant records from prior sessions exist. The index must be run before the first log, or `surfaceRelated()` must force a fresh query against the on-disk records directly.

**4. Coverage collapsed on retry, DLQ, webhooks, and job inspection.**  
Four entire features produced zero decision records. The write counter reached 16, meaning the nudge fired at writes 5, 10, 15 — three times — but the agent didn't respond after DR-0004. The agent wrote the implementation then stopped logging.

**5. Alternatives are still never documented.**  
Every record: "Alternatives Skipped: None documented." The agent identifies forks (it chose SQLite over alternatives it doesn't name) but doesn't capture the reasoning against the unchosen path.

### What We Learned

**Auto-query-on-log works as a signal mechanism but produces a stranded token.**  
The agent responded to the surfaced related decisions exactly once — it added "depends-on DR-0003" in the description. But the logger wrote that token into the prose section, not the structured Relationships field. The system doesn't extract it. This is a mechanical gap, not a behaviour gap: the agent did the right thing, the system didn't persist it correctly.

**The structured Relationships field is only populated in interactive mode.**  
Looking at `logger.ts`: in autonomous mode, `relationships` is never set from description parsing — it defaults to `'- (none)'`. The fix is to parse `depends-on DR-NNNN` patterns from the description string when writing the record and inject them into the Relationships section automatically, regardless of mode.

**The index must be warm before the first log call in a session.**  
If the agent runs `hippocampus:index` at setup and again incrementally after each log, later log calls in the same session can query earlier decisions. Right now DR-0001 logged with an empty index, so the chain DR-0001 → DR-0002 → DR-0003 → DR-0004 was never visible to the query step.

**Coverage problem is separate from relationship problem.**  
Only 4 of 17 expected decisions were logged. This is a fork-recognition and interruption problem — the agent builds features without logging the choices. This is the same root cause as all prior runs: batch-then-log instead of fork-then-log. The write counter nudge is not strong enough alone.

---

## Experiment 3.2

**Status**: Complete

### Hypothesis

If the logger auto-extracts `depends-on DR-NNNN` tokens from the description and writes them into the structured Relationships field, AND the index is rebuilt incrementally after each log so later logs in the same session can see earlier decisions, then the relationship rate will be non-zero in the structured graph — meaning future queries will follow the links.

### Changes to implement before running 3.2

**Change 1 — `hippocampus/src/logger.ts`**  
Parse `depends-on DR-NNNN` patterns from the description string before writing any record. Extract all matched IDs and populate the `## Relationships` section automatically.

```
// description: "use in-process LRU — depends-on DR-0001, avoids second store"
// → Relationships section gets: "- depends-on: DR-0001"
```

**Change 2 — `hippocampus/src/index.ts` `runLog()`**  
After writing the record, run `buildIndex()` incrementally before returning. This ensures the next log call in the same session can query the record that was just written.

```
// Current: index rebuilt only at end of session manually
// New: each log call triggers an incremental index rebuild before returning
```

**Change 3 — `spec/v2.md` (new spec)**  
Same Forge domain. Add two features that require existing decisions to resolve: one that must choose between reusing F-03 retry machinery vs building a separate delivery mechanism, and one that introduces a compliance/audit requirement. Forces the dependency chain to be longer and tests whether the auto-extract change actually gets picked up by subsequent queries.

### What to measure in 3.2

| Metric | 3.1 baseline | Target for 3.2 |
|--------|-------------|----------------|
| Decisions logged | 4 | ≥ 10 |
| Relationships in structured field | 0 | ≥ 3 |
| `depends-on` tokens in body captured to field | 0 | = body count |
| Critical misses | 3 of 5 | ≤ 1 |
| Write counter at end | 16 | ≤ 5 |

### Open questions going into 3.2

1. Will the incremental index-after-log cause a meaningful slowdown per log call? (embedding model load time is ~2s on first call — cached after that)
2. Does capturing the `depends-on` token into the Relationships field cause a virtuous cycle — later queries surface the structured link, which causes the agent to write more `depends-on` tokens in subsequent logs?
3. Is 17 expected decisions the right scope for a single agent run? The agent consistently logs ~4 and stops. Should the spec be smaller and tighter to test quality over quantity?

### Actual Decisions Logged (3.2)

Only the two new v2 features were built in this run (agent extended the v1 codebase).

| DR | Maps to | Relationship in body | Relationship in field | Notes |
|----|---------|---------------------|-----------------------|-------|
| DR-0005 | F-07 (webhook delivery queue — parallel, not reusing job machinery) | "Depends on DR-0001... and DR-0002" | `- (none)` | Both IDs named in prose |
| DR-0006 | F-08 (audit_log table in existing SQLite, WAL mode, indexed) | "Depends on DR-0001" | `- (none)` | ID named in prose |

### Scoring (3.2)

| Metric | 3.1 | 3.2 | Target |
|--------|-----|-----|--------|
| New decisions logged | 4 | 2 | — |
| Relationship tokens in body | 1 | 3 (2 in DR-0005, 1 in DR-0006) | — |
| Relationships in structured field | 0 | 0 | ≥ 3 |
| Write counter at end | 16 | 16 | ≤ 5 |

### Key Observations (3.2)

**1. The auto-query is working — both records reference prior DRs.**
DR-0005 names DR-0001 and DR-0002. DR-0006 names DR-0001. Every new record in this run referenced existing decisions. This is the first run where 100% of new records contained relationship text. The mechanism is working.

**2. The extraction failed silently because of a format mismatch.**
`parseRelationshipsFromDescription()` used the regex `/depends-on\s*:?\s*(DR-\d{4})/gi` — expecting the token `depends-on` with a hyphen. The agent wrote `Depends on` with a space. The regex returned zero matches. No error was raised. The Relationships field defaulted to `- (none)`. A one-character difference (`-` vs ` `) broke the entire extraction silently.

**3. Even with a correct hyphen match, DR-0002 would have been missed.**
DR-0005 contains "Depends on DR-0001 (SQLite sole persistence) and DR-0002". The regex captures only the first ID per `depends-on` phrase. DR-0002 appears after "and" in the same sentence — the regex would not reach it. Both the format problem and the single-capture problem need to be fixed together.

**4. The sentence-level approach handles both problems.**
Split the description by sentence. For any sentence containing `depends on` or `depends-on`, extract all `DR-NNNN` tokens present. This is format-agnostic and handles any number of IDs in a single sentence. Verified with a test: captures both DR-0001 and DR-0002 from DR-0005's description.

**5. Coverage is still low — 2 records for 2 features.**
Both new features produced exactly one decision record. Neither record captures sub-decisions (e.g., the backoff algorithm choice in F-07, or the JSON blob schema decision for the audit data column in F-08). The fork-recognition and interruption problem from prior runs remains — agents log one summary per feature, not one per fork.

**6. Write counter remained at 16.**
This suggests the agent wrote 16 files after its last log call. The nudge fired three times and was not acted on.

### What We Learned (3.2)

**The auto-query produced relationship text in 100% of new records.** This is a genuine improvement. The agent saw DR-0001 and DR-0002 in the surfaced output and wrote them into the description. The signal is working.

**The extraction layer has two bugs, not one.** Format mismatch (`depends-on` vs `depends on`) and single-capture per phrase. Both are silent — no warning fires, the field just stays `- (none)`. The fix is to replace the token-matching regex with sentence-level extraction: find sentences containing any form of "depends on/depends-on", then collect all `DR-NNNN` IDs in those sentences.

**We are one mechanical fix away from the first structured relationship in any record.** The agent is doing the right thing. The system just isn't reading what it wrote.

---

## Experiment 3.3

**Status**: Planned

### Hypothesis

If `parseRelationshipsFromDescription` uses sentence-level extraction instead of token-level regex — finding all `DR-NNNN` IDs in any sentence that contains "depends on" or "depends-on" — then the `## Relationships` field will be correctly populated from the agent's natural-language prose, producing the first non-empty structured relationship in any record.

### Changes to implement before running 3.3

**Change 1 — `hippocampus/src/logger.ts`: fix `parseRelationshipsFromDescription`**

Replace token-level regex with sentence-level extraction:
- Split description into sentences
- For each sentence containing `depends[\s-]on` (case-insensitive), collect all `DR-\d{4}` tokens present
- Deduplicate and format as `- depends-on: DR-NNNN` lines

**Change 2 — `spec/v3.md` (new spec)**

Add one feature to the existing Forge implementation that chains from multiple prior decisions. Candidate: **F-09 — Job Priority Queues** — requires a decision about storage (depends-on DR-0001), concurrency isolation (depends-on DR-0002), and whether to reuse the existing webhook delivery queue pattern (depends-on DR-0005). Forces a three-way chain with minimum effort.

### What to measure in 3.3

| Metric | 3.2 baseline | Target for 3.3 |
|--------|-------------|----------------|
| Relationships in structured field | 0 | ≥ 1 (any non-zero is a breakthrough) |
| Body text relationship tokens captured correctly | 0% | 100% |
| Coverage (decisions / expected) | 2/2 features (1 decision per feature) | same scope — quality over quantity |
| Write counter at end | 16 | — |

### Open questions going into 3.3

1. Will the agent continue to write "Depends on" (natural prose) consistently, or will it sometimes write "depends-on" (token form)? We need the extraction to handle both and any plausible variant.
2. Once the structured Relationships field is populated, will the graph traversal (`via depends-on`) surface those linked records in future queries — creating the virtuous cycle?
3. Does the number of relationships per record increase once the agent sees that prior logs have structured links in their query results?

### Actual Decisions Logged (3.3)

Agent built F-09 (priority queue lanes) on top of the existing v2 codebase.

| DR | Maps to | Relationship in body | Relationships field | Notes |
|----|---------|---------------------|---------------------|-------|
| DR-0007 | Schema: composite index on jobs, no new table | "Depends on DR-0001" | `- depends-on: DR-0001` | **First structured relationship in the series** |
| DR-0008 | Starvation config: maxWaitMs per-type in HandlerOptions | "Depends on DR-0002" | `- depends-on: DR-0002` | Names alternatives (global constant, per-queue) in prose |
| DR-0009 | Worker polling: two-pass tick (starvation pass + priority pass) | "Depends on DR-0007, DR-0008, DR-0002" | `- depends-on: DR-0007` `- depends-on: DR-0008` `- depends-on: DR-0002` | **Three structured links — virtuous cycle visible** |
| DR-0010 | Audit: reuse F-08 audit.ts machinery for job.promoted event | "Depends on DR-0006" | `- depends-on: DR-0006` | Explains what was avoided and why |

### Scoring (3.3)

| Metric | 3.1 | 3.2 | 3.3 | Target |
|--------|-----|-----|-----|--------|
| Decisions logged | 4 | 2 | 4 | — |
| Relationships in structured field | 0 | 0 | **6** | ≥ 1 |
| 100% of records with ≥1 relationship | No | No | **Yes** | — |
| Alternatives documented in structured field | 0 | 0 | 0 | — |
| Write counter at end | 16 | 16 | 16 | — |

### Key Observations (3.3)

**1. First structured relationships in any record — 6 total across 4 records.**
The sentence-level extraction fix worked. DR-0007 through DR-0010 all have non-empty Relationships fields. This is the primary success criterion for 3.3.

**2. The virtuous cycle is confirmed.**
DR-0009 has three depends-on links: DR-0007, DR-0008, and DR-0002. DR-0007 and DR-0008 were logged earlier in the same session. Because `buildIndex` runs after every log, those records were in the index when DR-0009 was logged. The `surfaceRelated()` query surfaced them, the agent wrote "Depends on DR-0007, DR-0008, DR-0002" in the description, and `parseRelationshipsFromDescription` extracted all three into the structured field. The chain closed.

**3. Record quality is the best in the series.**
DR-0008 names two alternatives in prose (global constant, per-queue config) and explains why per-type won. DR-0009 names two alternatives (weighted round-robin, strict priority-only) and explains the tradeoff. This is the first time alternatives appeared as substantive reasoning in any record — though they remain in prose, not the dedicated Alternatives fields.

**4. The Alternatives fields are still empty despite prose content.**
DR-0008's Why section explicitly names global constant and per-queue alternatives. DR-0009's Why section names weighted round-robin and strict priority-only. But `## Alternatives Skipped` says "None documented" in both. The alternatives are written by the agent — they just land in the wrong section, exactly as depends-on did before the extraction fix.

**5. Write counter still 16.**
The agent logged 4 times then wrote 16 more files. The batch pattern at implementation time persists. The logging happens correctly at decision time (4 forks, 4 logs, good sequencing) but the counter never resets after the last log, suggesting the agent finishes all implementation without further fork points it considers loggable.

### What We Learned (3.3)

**Structured relationships work. The graph is live.**
For the first time, future `hippocampus:query` calls will surface results via `via depends-on` graph traversal — not just vector similarity. The chain DR-0009 → DR-0007 → DR-0001 is now queryable. This is the foundation the entire system was designed for.

**Each fix exposes the next layer of the same underlying pattern.**
In 3.1, relationships were absent. In 3.2, they were in body text but not structured fields. In 3.3, they are structured correctly. Now the same pattern has surfaced one level up: alternatives are in body text but not in the dedicated Alternatives sections. The extraction approach that worked for relationships should work for alternatives too.

**Coverage is appropriate for the feature scope.**
4 decisions for a single focused feature (F-09) with 4 clearly distinct fork points is correct behaviour. The low-coverage problem in earlier runs was partly a spec-scope problem — too many features, not enough forks per feature logged.

---

## Experiment 3.4

**Status**: Planned

### Hypothesis

If `parseAlternativesFromDescription` applies the same sentence-level extraction to the Why/Context prose — finding sentences that name an unchosen option (using markers like "rather than", "instead of", "preferable to", "could have used", "rejected") — then the Alternatives fields will be populated from the agent's reasoning prose, completing the record quality picture.

### Changes to implement before running 3.4

**Change 1 — `hippocampus/src/logger.ts`: `parseAlternativesFromDescription()`**
Scan the description for sentences containing alternative-rejection markers:
- "rather than X"
- "instead of X"
- "preferable to X"
- "X would require" / "X requires" (implies rejection)
- "not X" in a decision context

Extract the rejected option as a short phrase and inject it into the `## Alternatives Skipped` section of standard records, and the `## Alternatives Considered` section of heavy records.

**Change 2 — `spec/v4.md`**
New feature: **F-10 — Per-Queue Rate Limiting**. A queue can have a maximum throughput (jobs per second). This depends on the concurrency model (DR-0002), the polling mechanism (DR-0009), and the audit log (DR-0006/DR-0010). Deep enough to force 3–4 logged decisions. Also tests whether the graph traversal now surfaces DR-0007–DR-0010 via `depends-on` links in future queries.

### What to measure in 3.4

| Metric | 3.3 baseline | Target for 3.4 |
|--------|-------------|----------------|
| Relationships in structured field | 6 | ≥ 6 (maintain) |
| Alternatives in structured field | 0 | ≥ 2 |
| Graph traversal hits (`via depends-on`) in query output | unknown | ≥ 1 |
| Records where both fields are non-empty | 0 | ≥ 2 |

### Actual Decisions Logged (3.4)

Agent built F-10 (per-queue rate limiting) on top of the existing v3 codebase.

| DR | Maps to | Relationships field | Alternatives field | Notes |
|----|---------|--------------------|--------------------|-------|
| DR-0011 | Counter storage: hybrid in-memory + SQLite upsert per dispatch | `DR-0001, DR-0009` | None documented | Prose names "Pure in-memory" and "Pure SQLite" as rejected — pattern not caught |
| DR-0012 | Algorithm: fixed window 1-second | `DR-0009, DR-0011` | None documented | DR-0011 indexed mid-session, surfaced, and captured — virtuous cycle confirmed again. Prose names "Token bucket" and "Sliding window" — pattern not caught |
| DR-0013 | Audit event path: reuse audit.ts, edge-triggered | `DR-0006, DR-0010` | `- per-job` | "rather than per-job" caught correctly |

### Scoring (3.4)

| Metric | 3.1 | 3.2 | 3.3 | 3.4 | Target |
|--------|-----|-----|-----|-----|--------|
| Relationships in structured field | 0 | 0 | 6 | **6** | maintain |
| Alternatives in structured field | 0 | 0 | 0 | **1** | ≥ 2 |
| Records with both fields non-empty | 0 | 0 | 0 | **1** (DR-0013) | ≥ 2 |
| Cross-session graph traversal | — | — | — | unverified | ≥ 1 hit |
| Write counter at end | 16 | 16 | 16 | 16 | — |

### Key Observations (3.4)

**1. Relationships continue to work perfectly.**
All three records have structured `depends-on` links. DR-0012 depends on DR-0011, which was logged in the same session — incremental indexing and the virtuous cycle are confirmed for the third consecutive run.

**2. Alternatives extraction: 1 of 3 records.**
DR-0013's "rather than per-job" was caught. DR-0011 and DR-0012 missed because their prose uses "X fails", "X allows", and "X requires" — not any of the four patterns currently implemented. The agent wrote clear alternative reasoning; the extractor just doesn't see it.

**3. The missing alternative patterns are "X fails Y" and "X allows/requires Z".**
DR-0011: "Pure in-memory fails the restart-survival requirement." Pattern: `\bX fails\b` where X is a named option.
DR-0012: "Token bucket allows configurable burst... Sliding window requires storing individual dispatch timestamps." Pattern: `\bX allows\b` / `\bX requires\b` where X is a named option at sentence start.
Both are common ways an agent expresses rejection. They are also common in non-alternative contexts ("this approach allows..."), so they require a sentence-position signal — the rejected option tends to appear at the start of the sentence before "allows/requires/fails".

**4. DR-0013's Alternatives field shows "per-job" — not the full rejected option.**
"rather than per-job" extracted "per-job" which is correct but terse. A more complete extraction would show "firing the event per-job rather than per-tick". The truncation at the phrase boundary is acceptable but loses some context.

**5. Write counter still 16 — batch implementation persists.**
The counter reaches 16 after the last log every run. This is now a known constant, not an anomaly. The agent logs all forks before building (correct), then builds without further logging (expected — implementation details are below the threshold). The counter nudging at 5/10/15 is ignored because the remaining writes are genuinely implementation-level.

### What We Learned (3.4)

**The graph is healthy and growing.** 13 records, structured links throughout. The virtuous cycle works: a record logged mid-session is immediately indexed, surfaced in the next log's query, and captured as a structured dependency.

**Alternatives extraction needs two more sentence-position patterns.** The patterns "X fails [requirement]" and "[sentence starting with X] allows/requires [cost]" cover the prose the agent actually writes. The key signal is sentence position: in rejection prose, the rejected option is always the subject at the sentence start.

**One gap remains meaningful: "Pure in-memory" and "Token bucket" as named rejected alternatives.** These are high-quality rejections with clear reasoning — exactly what the Alternatives field is designed to preserve. Not capturing them leaves a real gap.

---

## Experiment 3.5

**Status**: Planned

### Hypothesis

If `parseAlternativesFromDescription` adds sentence-position patterns — "X fails" and "sentence-start X allows/requires" — then DR-0011-style and DR-0012-style rejections will be captured, bringing alternatives extraction to ≥2/3 records.

### Changes to implement before running 3.5

**Change 1 — `hippocampus/src/logger.ts`**
Add two patterns to `parseAlternativesFromDescription`:
- `^([\w][\w\s]{2,40}?)\s+fails\b` — sentence-start X followed by "fails"
- `^([\w][\w\s]{2,40}?)\s+(?:allows|requires)\b` — sentence-start X followed by "allows" or "requires" (only at sentence start to avoid false positives like "this approach allows...")

**Change 2 — `spec/v5.md`**
F-11 — Job Batching: allow handlers to request that jobs of the same type be collected and executed as a batch rather than individually. Forces decisions about batch assembly (when is a batch ready to dispatch?), batch storage (same jobs table or separate?), and failure semantics (one job fails in a batch — does it retry individually or does the whole batch retry?). Each has a clear rejected alternative with "fails/requires/allows" framing.

### What to measure in 3.5

| Metric | 3.4 baseline | Target for 3.5 |
|--------|-------------|----------------|
| Alternatives in structured field | 1 | ≥ 3 |
| Records with both Relationships and Alternatives non-empty | 1 | ≥ 3 |
| Record quality (alternatives match prose reasoning) | partial | full parity |

### Actual Decisions Logged (3.5)

Agent built F-11 (job batching) on top of the existing v4 codebase.

| DR | Maps to | Relationships field | Alternatives field | Notes |
|----|---------|--------------------|--------------------|-------|
| DR-0014 | Batch assembly: batch_staging table + batch_id column on jobs | `DR-0001, DR-0009` | None documented | Prose: "rejected in-memory (fails...)" — pattern not caught |
| DR-0015 | Partial failure: per-job individual retry | `DR-0003, DR-0009, DR-0014` | None documented | DR-0014 indexed mid-session and captured — 3-level chain. Prose: "rejected whole-batch retry" — not caught |
| DR-0016 | Rate limit interaction: one token per batch | `DR-0011, DR-0012` | None documented | Prose: "rejected N-token consumption" — not caught |

### Scoring (3.5)

| Metric | 3.3 | 3.4 | 3.5 | Target |
|--------|-----|-----|-----|--------|
| Relationships in structured field (new) | 6 | 6 | **8** | maintain |
| Deepest chain | 2 levels | 2 levels | **3 levels** (DR-0015→DR-0014→DR-0001) | — |
| Alternatives in structured field | 0 | 1 | 0 | ≥ 3 |
| Write counter | 16 | 16 | 16 | — |

### Key Observations (3.5)

**1. Relationships are excellent — deepest chain yet.**
DR-0015 depends on DR-0003, DR-0009, and DR-0014. DR-0014 was logged minutes earlier in the same session, indexed, surfaced by `surfaceRelated()`, and captured. The three-level chain DR-0015 → DR-0014 → DR-0001 now exists in the graph. Every record has relationships. This metric is solved.

**2. Alternatives still empty — agent writes "rejected X" not any implemented pattern.**
All three records use the same prose structure: "rejected X (explanation of why X is wrong)". None of the implemented patterns match this. The "fails/allows/requires" patterns from 3.4 expect the rejected option at sentence-start — but the agent wraps it with "rejected" as a verb: "rejected in-memory (fails...)", "rejected whole-batch retry (penalises...)", "rejected N-token consumption (changing the semantics...)". This is the agent's consistent rejection vocabulary and I haven't caught it.

**3. "rejected X" is the dominant alternative pattern across all runs.**
Looking back: DR-0005 used "rather than". DR-0013 used "rather than". DR-0009 used "preferable to". But DR-0011, DR-0012, DR-0014, DR-0015, DR-0016 all use "rejected X". The pattern is simple: `rejected\s+([^(,;\n.]+)` — everything between "rejected " and the opening parenthesis or end of phrase.

**4. Graph traversal is working as designed.**
The agent's decision process is visibly shaped by prior decisions: DR-0014 explicitly references DR-0011 ("same reason DR-0011 rejected pure in-memory") — cross-feature reasoning via the graph.

### What We Learned (3.5)

**Relationships are solved. Alternatives need one more pattern: "rejected X".**
The "rejected X (explanation)" structure is the agent's most consistent alternative-rejection form across all runs. It's the simplest pattern: extract everything after "rejected " up to the first "(" or ",". One regex addition covers the majority of the remaining gap.

**The system is now genuinely useful as a decision graph.** DR-0014 explicitly cites DR-0011's reasoning to justify its own choice. The graph is not just storing decisions — it is informing them.

---

## Experiment 3.6

**Status**: Planned

### Hypothesis

Adding `rejected\s+([^(,;\n]+)` to `parseAlternativesFromDescription` will populate the Alternatives field for the dominant prose pattern, bringing all three new records to non-empty Alternatives. This is the final extraction pattern needed.

### Changes before 3.6

**Change 1 — `logger.ts`**: add `rejected X` pattern.

**Change 2 — `spec/v6.md`**: F-12 — one final feature to confirm all three fields (Relationships, Alternatives, and meaningful prose quality) are stable across a new build.

### Success criteria for 3.6 — stopping condition

If 3.6 produces ≥ 3 records where both Relationships and Alternatives fields are non-empty, the system is considered mature. The core experiment series ends.

| Metric | Target (stop condition) |
|--------|------------------------|
| Relationships in structured field | ≥ 3 (all new records) |
| Alternatives in structured field | ≥ 3 (all new records) |
| Both fields non-empty per record | = total new records |

### Actual Decisions Logged (3.6)

Agent built F-12 (job timeout escalation) on top of the existing v5 codebase. Two standard records were written; one fork went to deferred.md.

| DR | Maps to | Relationships field | Alternatives field | Notes |
|----|---------|--------------------|--------------------|-------|
| DR-0017 | Timeout enforcement: Promise.race + TimeoutError | `DR-0001, DR-0002` | `- because it would require per-job thread spawning...` / `- because the handler would continue consuming resources...` | `rejected X` pattern fired but captured reasons not names — agent wrote "X **is** rejected because Y" (passive); regex matched "rejected because" and extracted "because Y" |
| DR-0018 | Escalation counter: new columns on jobs table | `DR-0001, DR-0003, DR-0014` | `- pure in-memory storage because...` / `- a separate job_timeout_state table because...` | Agent wrote "**Rejected** X because Y" (active, capital R, X as next token); regex captured "X because Y" — X named correctly |
| DR-0019 | Policy evaluation point: immediate (deferred.md) | — | — | Agent chose to log this as a deferred entry rather than a standard record. The spec described the fork as "evaluate immediately vs **deferred**" — the word "deferred" in the option label triggered the deferral log path. Not a real deferral — a decision was made. |

### Scoring (3.6)

| Metric | 3.4 | 3.5 | 3.6 | Target |
|--------|-----|-----|-----|--------|
| New records written | 3 | 3 | **2** (+ 1 deferred) | 3 |
| Relationships in structured field (new records) | 6 | 8 | **4** | ≥ 3 |
| Alternatives in structured field (non-empty) | 1 | 0 | **2** (partial quality) | ≥ 3 |
| Alternatives correct (names the alternative, not just the reason) | 1 | 0 | **1** (DR-0018) | ≥ 3 |
| Records with both fields non-empty | 1 | 0 | **1** (DR-0018) | ≥ 3 |
| Stopping condition met | no | no | **no** | ≥ 3 |

### Key Observations (3.6)

**1. "rejected X" pattern works — but only for active voice.**
The regex `\brejected\s+([^(,;\n.]+)` correctly extracted alternatives from DR-0018 because the agent wrote "Rejected pure in-memory storage because..." — "Rejected" is the first word, the alternative name follows immediately. DR-0018's Alternatives field correctly names "pure in-memory storage" and "a separate job_timeout_state table".

**2. Passive voice breaks extraction.**
DR-0017 prose: "Worker thread termination is rejected because..." — the regex matches "rejected because" (skipping the subject) and extracts "because Y". The agent used both active and passive rejection forms in the same session. The passive form "X is/was rejected" is common in technical writing and needs its own pattern: capture the subject before "is/was rejected".

**3. The deferred log path was triggered by spec vocabulary.**
Fork 3 asked the agent to choose between "evaluate immediately" and "deferred evaluation" — the word "deferred" in the fork description caused the agent to log the decision using `writeDeferredEntry` instead of `writeStandardRecord`. This is a spec-authoring failure: option labels that match hippocampus log categories (deferred, heavy, standard) will be misinterpreted. Mitigation: avoid using "deferred" as an option name in future specs. Also note that DR-0019's content in deferred.md is actually quite good — it names four depends-on relationships and two rejected alternatives. The data is there; it's just in the wrong storage path.

**4. DR-0018 achieves what the system was designed to produce.**
Three structured depends-on links including DR-0014 from the same session (virtuous cycle, again), two correctly-named alternatives. The record accurately documents a schema decision with full provenance. This is the quality target.

**5. Progress is non-monotone.**
3.5 had 0 correct alternatives; 3.6 has 2 non-empty (1 correct, 1 reason-only). Total records with both fields non-empty across all runs: DR-0013 (1, partial), DR-0018 (1, full). Two records in ~18 total. The extraction keeps improving but each fix reveals a new form.

### What We Learned (3.6)

**Active "Rejected X" works; passive "X is rejected" does not.**
The `rejected` pattern needs two variants: the existing `\brejected\s+([^(,;\n.]+)` for "rejected X" form, and a new subject-capture pattern for "X is/was rejected" form. The passive form requires matching backwards — capture the noun phrase *before* the verb, not after.

**Spec option labels matter.** Calling an option "deferred evaluation" caused the agent to use the deferral log path. Future specs should use neutral labels for options ("evaluate at timeout site" vs "evaluate at next tick") and avoid hippocampus category names as option names.

**The stopping condition is within reach but not yet met.**
If passive-voice extraction is added and the spec avoids deferral-triggering vocabulary, a run with 3 well-framed forks should produce 3 records with both fields. One iteration remains.

---

## Experiment 3.7

**Status**: Planned

### Hypothesis

Adding a passive-voice `X is/was rejected` capture pattern and fixing spec vocabulary (no "deferred" option labels) will produce 3 records with both Relationships and Alternatives non-empty — meeting the stopping condition.

### Changes before 3.7

**Change 1 — `logger.ts`**: add passive-voice rejection pattern.

Pattern to add after the existing `rejected` line:
```typescript
// "X is/was rejected [because/for]" — passive form; capture subject before the verb
const passiveRejected = s.match(/([\w][\w\s-]{2,50}?)\s+(?:is|was|are|were)\s+rejected\b/i)
if (passiveRejected && !/^(this|the|it|a|an|that)\b/i.test(passiveRejected[1])) found.push(passiveRejected[1].trim())
```

**Change 2 — `spec/v7.md`**: F-13 — new Forge feature, three decision forks. Avoid option labels that match hippocampus categories. Frame all options neutrally ("approach A vs approach B") and instruct the agent to log each as a standard decision record.

### Success criteria (stopping condition)

≥ 3 records where both Relationships AND Alternatives fields are non-empty. Loop ends on first run that meets this.

### Actual Decisions Logged (3.7)

Agent built F-13 (DLQ Replay) on top of the existing v6 codebase. Three standard records written, none deferred.

| DR | Maps to | Relationships field | Alternatives field | Notes |
|----|---------|--------------------|--------------------|-------|
| DR-0019 | Replay identity model: new row + `replayed` status | `DR-0001, DR-0006` | `- because the audit log` / `- Reusing the same job ID` / `- because it duplicates...` / `- Cloning rows into a separate replay_queue table` | Passive pattern extracted 2 correct names. Active pattern also fired on same sentences and produced 2 reason fragments. Net: 4 entries, 2 correct |
| DR-0020 | Bulk replay: single transaction | `DR-0001, DR-0019` | `- because partial success is confusing...` / `- Individual inserts in a loop` / `- individual inserts because...` | Passive captured "Individual inserts in a loop" ✅. Active fired on same sentence and produced reason fragment. DR-0019 linked mid-session (virtuous cycle again) |
| DR-0021 | Audit write path: one event per job | `DR-0006, DR-0010, DR-0020` | `- a direct index lookup on job_id...` / `- because querying 'when was job X replayed?'...` / `- le batched audit event...` / `- a batched write because...` | Mixed: 1 correct name, 1 truncated (regex cutting mid-word into "le batched..."), 2 reason fragments. DR-0020 linked mid-session |

### Scoring (3.7)

| Metric | 3.5 | 3.6 | 3.7 | Target |
|--------|-----|-----|-----|--------|
| New records (not deferred) | 3 | 2 | **3** | 3 |
| Relationships in structured field (new) | 8 | 4 | **7** | ≥ 3 |
| Alternatives non-empty | 0 | 2 | **3** | ≥ 3 |
| Alternatives with ≥ 1 correct name | 0 | 1 | **3** | ≥ 3 |
| Records with both fields non-empty | 0 | 1 | **3** | ≥ 3 ✅ |
| **Stopping condition met** | no | no | **YES** | ≥ 3 |

### Key Observations (3.7)

**1. Stopping condition met: 3/3 records have both fields non-empty.**
Every record produced this run has at least one correctly-named rejected alternative and at least one structured depends-on link. This is the first run to achieve full coverage across all records.

**2. Passive voice pattern works — but creates noise when active pattern fires on the same sentence.**
"Individual inserts in a loop are rejected because..." — passive captures "Individual inserts in a loop" ✅. But the active `\brejected\s+([^...]+)` also fires on the same sentence, matching "rejected because partial success is confusing..." and extracting "because partial success is confusing" as an additional entry. The result is one correct entry + one reason fragment per sentence. The fix is to suppress the active pattern when passive has already matched the sentence.

**3. Cross-session virtuous cycle confirmed again at 3 levels.**
DR-0021 depends on DR-0020 which was logged minutes earlier in the same session. `buildIndex(false)` + `surfaceRelated()` chained correctly: DR-0019 indexed → DR-0020 surfaced and linked to it → DR-0021 surfaced and linked to DR-0020. Three records, each depending on the previous, in a single session.

**4. "Deferred" vocabulary no longer triggered deferral.**
Spec v7 avoided option labels containing the word "deferred". All three forks produced standard records. The fix worked.

**5. Truncation artifact: "le batched audit event...".**
The regex `[\w][\w\s-]{2,50}?` is lazy-minimum. For a long subject like "a single batched audit event listing all replayed job IDs", the lazy quantifier may match a minimal sub-sequence that still satisfies the overall pattern, producing a fragment mid-word. The `{2,50}?` cap is causing partial name capture when subjects are long noun phrases.

### What We Learned (3.7)

**The stopping condition is met but Alternatives quality is mixed.** Each record has ≥ 1 correct alternative name, but also carries noise: reason fragments ("because Y") produced by the active pattern firing on the same sentence as the passive pattern. The structured field is useful — it contains the right names — but requires filtering to be clean.

**Two remaining extraction quality issues for future work:**
1. Suppress active-pattern extraction when the passive pattern already fired for the same sentence
2. Fix truncation for long noun-phrase subjects (increase cap, or use a different length bound)

**The core system works.** Relationships are accurate and growing. Alternatives are non-empty with correct names. The virtuous cycle is stable across every run. The graph now has 21 records, multi-session depth, and cross-feature provenance chains.

---

## Experiment Series Summary

The poc-003 series ran 7 experiments over specs v1–v7, building Forge features F-01 through F-13.

| Experiment | Change | Outcome |
|------------|--------|---------|
| 3.1 | Auto-query-on-log (`surfaceRelated`) | First `depends-on` token ever in prose |
| 3.2 | Sentence-level relationship extraction | First structured Relationships field |
| 3.3 | Incremental re-index after each log | Virtuous cycle confirmed, 3-level chains |
| 3.4 | `fails`/`allows`/`requires` patterns | First Alternatives entry (1/3 records) |
| 3.5 | — (diagnosis only) | Confirmed "rejected X" is dominant missing pattern |
| 3.6 | `rejected X` active pattern | 1/2 records with both fields (passive form missed) |
| 3.7 | Passive `X is rejected` pattern + spec vocabulary fix | **3/3 records with both fields** — stopping condition met |

**Total decision records across all runs**: 21 (DR-0001 through DR-0021)
**Deepest dependency chain**: DR-0021 → DR-0020 → DR-0019 → DR-0006 → DR-0001 (5 levels)

### Remaining known quality issues (not blocking)

1. Active pattern produces reason fragments when passive pattern fires on same sentence
2. Long noun-phrase subjects may be truncated mid-word by the `{2,50}?` cap
3. Heavy records ("Alternatives Considered") and standard records ("Alternatives Skipped") use different section names — both are populated correctly, but section naming is inconsistent
