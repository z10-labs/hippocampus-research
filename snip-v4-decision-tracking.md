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

## Notes

_Add observations here during or after the build._
