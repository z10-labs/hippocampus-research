# Experiment: Snip v3 Decision Tracking

Testing whether agents using the hippocampus skill log decisions at the right moments, with the right relationships, and in a form that remains useful as a query target.

**Spec**: `hippo-poc-002/spec/v3.md`
**Repo**: `hippo-poc-002`
**Hippocampus skill version**: caveman mode + relationship carry-forward

---

## Expected Decisions

Decisions we anticipate a well-behaved agent should log when building v3. Ordered by the feature they belong to.

| # | Feature | Expected Decision | Category | Weight | Depends On |
|---|---------|-------------------|----------|--------|------------|
| E-01 | Custom Domains | How to route requests by custom domain — host header matching vs reverse proxy vs SNI | architectural | heavy | DR-0001 (Hono) |
| E-02 | Custom Domains | How to verify DNS ownership before activating a custom domain | security | heavy | — |
| E-03 | Custom Domains | How TLS certificates are obtained and stored for custom domains | security | heavy | E-02 |
| E-04 | Custom Domains | How TLS certificates are renewed automatically without downtime | operational | heavy | E-03 |
| E-05 | Link Bundles | Storage model for bundles — separate table vs JSON column vs child rows | data | standard | DR-0002 (SQLite) |
| E-06 | Link Bundles | Whether bundle theme (logo, colour) lives in DB or filesystem | data | standard | E-05 |
| E-07 | Smart Redirects | How per-visitor fingerprint is computed server-side without cookies or JS | security | heavy | DR-0001 (Hono) |
| E-08 | Smart Redirects | How time-of-day window conditions are evaluated without bloating the rules engine | architectural | standard | DR-0006 (rules engine) |
| E-09 | Email Digests | How email is sent without a third-party API — library and transport choice | dependency | heavy | — |
| E-10 | Email Digests | What triggers the weekly digest — cron, setInterval, or event-driven | operational | standard | — |
| E-11 | Email Digests | How digest job state survives a server restart | error-handling | standard | E-10 |
| E-12 | Data Retention | How retention is enforced — background delete job vs on-read filter vs DB trigger | architectural | heavy | DR-0002 (SQLite) |
| E-13 | Data Retention | How aggregated counts are preserved when raw events are deleted | data | heavy | E-12, DR-0005 (analytics) |
| E-14 | Public Stats | Cache strategy for public stats pages — TTL, invalidation trigger | performance | standard | DR-0001 (Hono) |
| E-15 | Public Stats | Whether password-protected stats pages use same auth as dashboard | security | standard | DR-0004 (auth) |
| E-16 | Bulk Operations | How CSV import handles partial failures — single transaction vs batched vs row-level errors | error-handling | heavy | DR-0002 (SQLite) |
| E-17 | Bulk Operations | Memory strategy for large CSV imports on ≤ 1 GB VPS — stream vs load-all | performance | standard | — |
| E-18 | Background Jobs | What runs recurring work (retention, digest, cert renewal) on a single VPS with no queue | operational | heavy | E-10, E-12, E-04 |

---

## Actual Decisions Logged

Fill this in after the agent builds v3. For each expected decision, record whether it was logged, what DR ID was assigned, and any notes on quality.

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

---

## Scoring

After the build, score the agent run:

| Metric | Formula | Score |
|--------|---------|-------|
| Coverage | decisions logged / 18 expected | —/18 |
| Relationship rate | decisions with depends-on / decisions logged | — |
| Surprise decisions | decisions logged not in expected list | — |
| Missed critical | E-03, E-07, E-12, E-13, E-16 not logged = fail | — |

**Critical decisions** (E-03, E-07, E-12, E-13, E-16) are security or data-integrity choices that, if reversed, break the system. An agent that misses any of these is considered to have failed the test regardless of overall coverage.

---

## Notes

_Add observations here during or after the build._
