# Token Usage Experiment — Hippocampus vs No Hippocampus

## Hypothesis

The naive assumption is that hippocampus adds tokens — query output lands in context.
The counter-hypothesis is that without hippocampus, agents spend more tokens re-deriving context:
reading source files, tracing why things were done a certain way, sometimes going down wrong paths.

We expect hippocampus to be net token-negative at scale. This experiment measures whether that holds.

---

## Conditions

| Condition | Description |
|-----------|-------------|
| **A — With Hippocampus** | `.claude/` skill present, hook blocks direct `.decisions/` reads, agent uses `hippocampus:query` |
| **B — Without Hippocampus** | `.claude/` directory absent, `.decisions/` absent, agent works from code alone |

Condition B is not "hippocampus present but ignored." It is completely absent so the agent has no
choice but to derive context from source files.

---

## Fixed Task

The task prompt must be identical across all runs and conditions. Copy it verbatim.

```
Add password protection to individual links in Snip.

Requirements:
- A link can optionally have a password set at creation time
- Visitors clicking a password-protected link see a prompt before being redirected
- Wrong password shows an error and re-prompts — do not redirect
- The dashboard shows which links are password-protected
- The dashboard allows changing or removing a password on an existing link
- Password attempts should not be logged as real clicks

Do not add any features beyond what is listed. Commit when done.
```

This task was chosen because it intersects multiple past decisions:
- Auth approach (DR-0004 — bcrypt + cookie)
- Schema/SQLite (DR-0002 — database choice)
- Redirect route (DR-0001 — Hono)
- Click analytics (DR-0005 — analytics in same DB)

Without hippocampus, the agent must read `auth.ts`, `schema.ts`, `redirect.ts`, and the dashboard
to understand existing patterns before it can make consistent choices.

---

## Baseline State

Each run must start from the same git commit. Before every run:

```bash
git -C /path/to/hippo-poc-002 stash
git -C /path/to/hippo-poc-002 checkout <BASELINE_COMMIT>
```

Record the baseline commit hash here before running:

```
BASELINE_COMMIT=
```

---

## Setup: Two Repo Copies

To avoid switching branches mid-experiment, maintain two copies of the repo:

```bash
# Condition A — with hippocampus (normal state)
cp -r hippo-poc-002 hippo-poc-002-exp-a

# Condition B — without hippocampus
cp -r hippo-poc-002 hippo-poc-002-exp-b
rm -rf hippo-poc-002-exp-b/.claude
rm -rf hippo-poc-002-exp-b/.decisions
rm -rf hippo-poc-002-exp-b/hippocampus
```

Verify condition B has no decision memory:

```bash
ls hippo-poc-002-exp-b/.claude 2>/dev/null && echo "FAIL — .claude still present" || echo "OK"
ls hippo-poc-002-exp-b/.decisions 2>/dev/null && echo "FAIL — .decisions still present" || echo "OK"
```

---

## Automation Script

Save as `experiments/token-usage/run.sh`. Run once per condition per run number.

```bash
#!/usr/bin/env bash
set -euo pipefail

CONDITION=${1:?usage: run.sh <with|without> <run-number>}
RUN=${2:?usage: run.sh <with|without> <run-number>}
RUNS_DIR="$(dirname "$0")/runs"
TASK_PROMPT="Add password protection to individual links in Snip.

Requirements:
- A link can optionally have a password set at creation time
- Visitors clicking a password-protected link see a prompt before being redirected
- Wrong password shows an error and re-prompts — do not redirect
- The dashboard shows which links are password-protected
- The dashboard allows changing or removing a password on an existing link
- Password attempts should not be logged as real clicks

Do not add any features beyond what is listed. Commit when done."

if [[ "$CONDITION" == "with" ]]; then
  REPO="$(dirname "$0")/../../hippo-poc-002-exp-a"
else
  REPO="$(dirname "$0")/../../hippo-poc-002-exp-b"
fi

OUTPUT_FILE="$RUNS_DIR/${RUN}-${CONDITION}-hippocampus.jsonl"

echo "Running condition=$CONDITION run=$RUN"
echo "Repo: $REPO"
echo "Output: $OUTPUT_FILE"

cd "$REPO"

claude \
  --output-format stream-json \
  --dangerously-skip-permissions \
  -p "$TASK_PROMPT" \
  | tee "$OUTPUT_FILE"

echo ""
echo "--- Token Summary ---"
jq -rs '
  map(select(.type == "result")) | .[0] |
  "Input tokens:         \(.usage.input_tokens // 0)",
  "Output tokens:        \(.usage.output_tokens // 0)",
  "Cache read tokens:    \(.usage.cache_read_input_tokens // 0)",
  "Cache create tokens:  \(.usage.cache_creation_input_tokens // 0)"
' "$OUTPUT_FILE"
```

Make it executable:

```bash
chmod +x experiments/token-usage/run.sh
```

---

## Running the Experiment

Run all six sessions (3 per condition). Reset to baseline between runs of the same condition.

```bash
# Condition A — with hippocampus
./run.sh with 001
git -C ../../hippo-poc-002-exp-a checkout <BASELINE_COMMIT>
./run.sh with 002
git -C ../../hippo-poc-002-exp-a checkout <BASELINE_COMMIT>
./run.sh with 003

# Condition B — without hippocampus
./run.sh without 001
git -C ../../hippo-poc-002-exp-b checkout <BASELINE_COMMIT>
./run.sh without 002
git -C ../../hippo-poc-002-exp-b checkout <BASELINE_COMMIT>
./run.sh without 003
```

---

## What to Capture Per Run

Extract from each `.jsonl` file using the parse script below, then fill into `results.md`.

```bash
#!/usr/bin/env bash
# parse.sh <jsonl-file>
FILE=${1:?usage: parse.sh <file.jsonl>}
jq -rs '
  map(select(.type == "result")) | .[0] |
  {
    input_tokens:                .usage.input_tokens,
    output_tokens:               .usage.output_tokens,
    cache_read_input_tokens:     .usage.cache_read_input_tokens,
    cache_creation_input_tokens: .usage.cache_creation_input_tokens,
    total_tokens:               (.usage.input_tokens + .usage.output_tokens),
    duration_ms:                 .duration_ms
  }
' "$FILE"
```

For condition A runs, also manually count from the JSONL:
- Number of `hippocampus:query` tool calls made
- Number of `hippocampus:log` tool calls made

```bash
grep -o '"tool_name":"Bash"' <jsonl> | wc -l   # rough proxy for tool calls
# or look for the hippocampus npm run invocations in tool inputs
grep 'hippocampus:query' <jsonl> | wc -l
grep 'hippocampus:log' <jsonl> | wc -l
```

---

## Metrics

| Metric | What it tells us |
|--------|-----------------|
| `input_tokens` | How much context the agent consumed |
| `output_tokens` | How much the agent generated |
| `cache_read_input_tokens` | Tokens served from prompt cache — lower cost |
| `cache_creation_input_tokens` | Tokens written into cache |
| `total_tokens` | Input + output combined |
| `duration_ms` | Wall clock time for the session |
| `hippocampus_queries` | How many times the agent queried (condition A only) |
| `hippocampus_logs` | How many decisions the agent logged (condition A only) |

---

## Analysis

After all 6 runs, compute in `results.md`:

- **Mean total tokens** per condition
- **Token delta**: `(A_mean - B_mean) / B_mean` — negative means hippocampus saved tokens
- **Cache hit rate** in condition A: `cache_read / (cache_read + input)` — hippocampus query results that get reused
- **Query overhead**: estimated tokens consumed by hippocampus query calls specifically
  - Approximate as: `(A_mean - B_mean)` if delta is positive, meaning net cost
  - Or isolate by counting the tool call output sizes in the JSONL

---

## Notes

- `--dangerously-skip-permissions` is used in the script so the agent doesn't pause for confirmations mid-run. Only use on the experiment copies, never on the main repo.
- Runs are not deterministic — the same prompt can produce different paths. Three runs per condition gives enough signal to spot a trend.
- Do not run both conditions simultaneously. Complete all runs for one condition before switching.
- Record the exact model used. Token counts are model-specific.
