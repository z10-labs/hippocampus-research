# Experiment: Snip v4 Decision Tracking

Testing whether agents using the hippocampus skill log decisions at the right moments, with the right relationships, and in a form that remains useful as a query target.

**Spec**: `hippo-poc-002/spec/v4.md`
**Repo**: `hippo-poc-002`
**Hippocampus skill version**: recognise-log-implement + fork triggers + and-rule

---

## Expected Decisions

Decisions we anticipate a well-behaved agent should log when building v4. Ordered by the feature they belong to.

| # | Feature | Expected Decision | Category | Weight | Depends On |
|---|---------|-------------------|----------|--------|------------|
| E-01 | Redirect Caching | Whether to add a cache layer at all — SQLite WAL may be sufficient, needs a benchmark justification either way | architectural | heavy | DR-0001 (Hono), DR-0002 (SQLite) |
| E-02 | Redirect Caching | Which cache store — Redis, Valkey, in-process LRU, or something else — given the ≤ 1 GB memory constraint | dependency | heavy | E-01 |
| E-03 | Redirect Caching | Cache key design — slug alone vs slug+host-header to handle same slug on different custom domains | data | standard | E-02, DR-0003 (custom domains) |
| E-04 | Redirect Caching | Cache invalidation strategy — TTL-only vs event-driven invalidation on link update/delete | architectural | standard | E-02 |
| E-05 | Real-time Dashboard | Transport for live click feed — WebSocket vs SSE vs long-polling | architectural | standard | DR-0001 (Hono) |
| E-06 | Real-time Dashboard | Whether live feed state is per-link or workspace-level — affects what the server fans out to connected clients | architectural | standard | E-05 |
| E-07 | Abuse Prevention | Where rate limit counters live — in-process, Redis, or SQLite — given the restart-survival requirement | data | heavy | E-02 |
| E-08 | Abuse Prevention | What threshold triggers automatic link suspension vs alert-only — and whether workspace owners can override | security | heavy | — |
| E-09 | Abuse Prevention | Whether bot fingerprinting runs inline (at redirect time) or async — tradeoff is latency vs accuracy | performance | standard | — |
| E-10 | GDPR | How erasure is implemented — hard delete rows vs anonymise-in-place vs mark-deleted — must not corrupt aggregates | compliance | heavy | DR-0005 (analytics), E-12 (v3 retention aggregates) |
| E-11 | GDPR | Whether GDPR consent is tracked per-visitor fingerprint or per-workspace configuration | compliance | heavy | — |
| E-12 | GDPR | Data portability export format — structured JSON vs CSV vs GDPR-standard format | api | standard | — |
| E-13 | Audit Log | Storage for audit entries — separate SQLite table vs separate DB file vs append-only flat file | data | heavy | DR-0002 (SQLite) |
| E-14 | Audit Log | Whether audit log retention is a separate configurable policy from click data retention | operational | standard | E-13, E-12 (v3 data retention) |
| E-15 | Audit Log | How system-initiated actions (retention job, abuse suspension) are attributed in audit entries | architectural | standard | E-13 |
| E-16 | API Rate Limiting | Rate limit algorithm — fixed window vs sliding window vs token bucket — each has different memory and accuracy tradeoffs | architectural | standard | — |
| E-17 | API Rate Limiting | Whether API rate limit counters share the same state store as abuse prevention counters | architectural | standard | E-07, E-16 |
| E-18 | Billing Foundation | Whether click quota enforcement is a hard stop or soft cap — user-facing behaviour differs significantly | architectural | heavy | — |
| E-19 | Billing Foundation | How monthly click consumption is metered accurately — real-time counter vs daily aggregate vs batch count | data | heavy | DR-0005 (analytics), E-18 |
| E-20 | Billing Foundation | Whether to defer the actual billing integration decision or commit to a processor now | cost | deferred | E-18 |

---

## Actual Decisions Logged

Fill this in after the agent builds v4. For each expected decision, record whether it was logged, what DR ID was assigned, and any notes on quality.

| Expected | DR Logged | Description Match | Relationship Captured | Notes |
|----------|-----------|------------------|-----------------------|-------|
| E-01 | — | — | — | |
| E-02 | — | — | — | |
| E-03 | — | — | — | |
| E-04 | — | — | — | |
| E-05 | — | — | — | |
| E-06 | — | — | — | |
| E-07 | — | — | — | |
| E-08 | — | — | — | |
| E-09 | — | — | — | |
| E-10 | — | — | — | |
| E-11 | — | — | — | |
| E-12 | — | — | — | |
| E-13 | — | — | — | |
| E-14 | — | — | — | |
| E-15 | — | — | — | |
| E-16 | — | — | — | |
| E-17 | — | — | — | |
| E-18 | — | — | — | |
| E-19 | — | — | — | |
| E-20 | — | — | — | |

---

## Scoring

After the build, score the agent run:

| Metric | Formula | Score |
|--------|---------|-------|
| Coverage | decisions logged / 20 expected | —/20 |
| Relationship rate | decisions with depends-on / decisions logged | — |
| Surprise decisions | decisions logged not in expected list | — |
| Missed critical | E-02, E-07, E-10, E-13, E-18, E-19 not logged = fail | — |

**Critical decisions** (E-02, E-07, E-10, E-13, E-18, E-19) are the ones where a wrong choice breaks correctness, violates compliance, or is hardest to reverse. An agent that misses any of these is considered to have failed the test regardless of overall coverage.

---

## What v4 Tests Differently From v3

v3 tested: recognition of decision forks at all.
v4 tests: **decision chains** — whether agents carry relationships forward across features that depend on earlier choices.

The cache store choice (E-02) should appear in E-03, E-04, E-07, and E-17.
The GDPR erasure choice (E-10) depends on two v3 decisions.
E-20 tests whether agents correctly classify a conscious deferral as a decision worth logging.

An agent that logs 20 isolated decisions with no relationships has still failed the relationship test.

---

## Agent Runs

### Run 0 — v4 agent, no nudge hook (baseline)

**Date**: 2026-05-23  
**Spec**: v4  
**Hook**: none (write counter not yet installed)

| Metric | Result |
|--------|--------|
| Decisions logged | 1 |
| Distinct log events | 1 (end of session) |
| Relationships | 0 |
| Alternatives documented | 0 |

**What happened**: Agent planned everything, built everything, then wrote one blob record (DR-0008) at the very end containing cache keys, SSE transport, rate limit storage, GDPR erasure, and audit log all in a single paragraph. Classic batch-then-summarise pattern.

---

### Run 1 — v3 agent, with nudge hook (hook effectiveness test)

**Date**: 2026-05-23  
**Spec**: v3 (custom domains, data retention, email digests, bundles, visitor cap, background jobs)  
**Hook**: write counter — nudge at ≥5 consecutive writes without a log; reset on each `hippocampus:log` call

| Metric | Result |
|--------|--------|
| Decisions logged | 6 (DR-0007–0012) |
| Distinct log events | 2 (12:39 and 12:54) |
| Relationships | 0 (every record: `- (none)`) |
| Alternatives documented | 0 (every record: "None documented") |
| Mini-blobs | 2 — DR-0007 (6 choices in one record), DR-0012 (4 concerns bundled) |

**Decisions logged**:

| DR | Description | Weight | Notes |
|----|-------------|--------|-------|
| DR-0007 | Custom domain routing via Host header + ACME TLS + SNI callback | standard | Contains 6 separate decisions in one record |
| DR-0008 | Data retention: link_stats aggregates + daily batch delete in 500-row chunks | heavy | Correctly scoped |
| DR-0009 | Email digests via nodemailer SMTP + sendmail fallback | standard | Miscategorised as `error-handling` |
| DR-0010 | Bundle storage: bundle_items child table + nullable bundle_item_id on clicks | standard | Clean |
| DR-0011 | Visitor fingerprint: SHA256(IP + date) for visitor_cap rules | heavy | Correctly scoped |
| DR-0012 | All background jobs via setInterval at startup; also bundled CSV import behaviour | heavy | Mini-blob — retention + digest + cert renewal + CSV in one record |

**What the hook changed**: Count went from 1 → 6. Agent logged mid-session (two batches) rather than only at the end, suggesting the nudge prompt did interrupt the batch-then-summarise rhythm at least once.

**What the hook did not change**: Every record still has `- (none)` in Relationships. No alternatives documented anywhere. Some records are still mini-blobs. The hook improved *quantity* and *timing* but had no effect on *quality*.

**Key finding**: The relationship problem is not addressable by a counter hook. The agent never looked at earlier records before writing a new one. Declaring `depends-on` requires the skill to explicitly instruct: query existing decisions before logging, then name any that the current decision builds on.

---

### Run 2 — v4 agent, nudge hook + "query before log" skill instruction

**Date**: 2026-05-23  
**Spec**: v4 (redirect caching, real-time dashboard, abuse prevention, GDPR, audit log, API rate limiting, billing foundation)  
**Hook**: write counter nudge (≥5 writes without log → stderr reminder)  
**Skill change**: mandatory `hippocampus:query` before every `hippocampus:log`; `depends-on` framed as required not optional; anti-patterns expanded

| Metric | Result |
|--------|--------|
| Decisions logged | 4 (DR-0013–0016) |
| Distinct log events | 1 (all at 13:26 — end of session) |
| Relationships | 0 (every record: `- (none)`) |
| Alternatives documented | 0 |
| Mini-blobs | 3 of 4 records |

**Decisions logged**:

| DR | Maps to | Quality |
|----|---------|---------|
| DR-0013 | E-03 (cache key: workspace:slug not slug-only) | Best record of all three runs — correct insight, specific |
| DR-0014 | E-05 (SSE transport) + pub/sub + feature-gating bundled | Mini-blob |
| DR-0015 | E-16 (rate limit algorithm) + E-17 (SQLite store) bundled | Mini-blob |
| DR-0016 | E-18 + E-19 + E-20 all bundled — billing deferral buried in body text | Three decisions in one |

**Critical decisions missed entirely**: E-02 (cache store selection), E-07 (abuse counter store), E-08–E-09 (abuse thresholds and fingerprinting), E-10–E-12 (GDPR erasure, consent, export), E-13–E-15 (audit log storage and retention)

**What the skill change changed**: Nothing measurable. Count regressed (6 → 4). Still one batch at session end. Relationships unchanged at 0.

**Key finding**: The "query before log" instruction added friction to the log path without changing when logging happens. The agent batch-logged at the end regardless, and with more steps required per log, it logged less. Extra instruction ≠ better behaviour.

**Most revealing detail**: DR-0013 correctly explains that two workspaces can share a slug on different custom domains and chose workspace:slug as the cache key for that reason — the agent understood the dependency on DR-0007. But it still wrote `- (none)`. The gap is between understanding a relationship and recording it, not between understanding and building.

---

## Experiment Conclusions

**Status**: Complete — 3 runs across 2 builds

### What moved

| Intervention | Effect |
|---|---|
| Nudge hook (count) | Quantity improved: 1 → 6. Mid-session logging appeared. |
| Nudge hook (count) | Quality unchanged: 0 relationships, 0 alternatives, mini-blobs persist |
| "Query before log" skill instruction | Quantity regressed: 6 → 4. Quality unchanged. |

### What never moved

Relationships: 0 across every run. This was the primary test metric and it did not budge once.

### Root cause

Agents operate in a plan → implement → summarise loop. The skill instruction says "interrupt at each fork and log before the code." Agents ignore this — not because they misread the skill, but because the loop is structural. By the time an agent decides to log, the implementation is already written and the context that would reveal dependencies has scrolled past.

The gap is not comprehension. DR-0013 proves the agent understood the custom-domain cache key dependency — it named it in the description, derived the correct solution from it — but still wrote `(none)` in the relationships field. The agent knows the dependency exists. It just doesn't connect "I understand this" to "I must write `depends-on DR-0007`."

### What this means for the system design

Skill text alone cannot enforce relationship capture. The agent has to want to look backward, and the current log workflow gives it no moment to do so. The log command accepts a description string and writes a record. There is no step in that command that surfaces prior decisions as context.

The fix is architectural, not instructional: the log step itself must surface candidate dependencies before writing the record, so the agent is forced to evaluate them in the same moment it logs.

---

## Recommendations for Next Experiment

### Hypothesis to test

If the `hippocampus:log` command automatically runs a query on the description being logged and prints matching prior DRs to stdout before writing the record, agents will include `depends-on` references because the relevant DRs are visible at the exact moment the record is written.

### Proposed change

Modify `hippocampus:log` to:

1. Take the description string
2. Run a vector query against it before writing the record
3. Print any `direct` results (score ≥ 0.20) to stdout as: `[Hippocampus] Related: DR-NNNN — <title>`
4. Write the record

The agent sees the related DRs in the same output as the log confirmation. It can immediately issue a second log with `depends-on DR-NNNN` added, or amend the first. Either way, the dependency is visible at the moment it is needed — not earlier, when it scrolls past in a query at feature-planning time.

### Why this is different from the current approach

Current approach: agent must remember to query before logging, then remember the results, then carry them into the description. Three separate acts of will across a long session.

Proposed approach: query is automatic on every log call. Agent sees the results in the same stdout line as the log confirmation. One act of will: decide whether to add `depends-on` to the next log.

### What to measure

Same metrics, same scoring formula:

| Metric | Run 2 baseline | Target |
|--------|---------------|--------|
| Decisions logged | 4 | ≥ 10 |
| Relationships | 0 | ≥ 5 |
| Critical misses | 8 of 6 critical | ≤ 2 |
| Mini-blobs | 3 of 4 | ≤ 1 |

### Secondary test

Run the same v4 spec twice — once with the automatic query-on-log, once without — and compare relationship rates directly. Keeps everything else constant.

### What to keep

- Write counter nudge hook — it helped quantity in Run 1 and costs nothing to keep
- v4 spec — the expected decisions list is now calibrated; reuse it

### What to remove

- "Query before log" skill instruction — it added friction with no benefit. Remove it and let the command handle the query automatically instead.
