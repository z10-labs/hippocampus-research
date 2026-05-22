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

if [[ ! -d "$REPO" ]]; then
  echo "ERROR: Repo not found at $REPO"
  echo "Run the setup steps in methodology.md first."
  exit 1
fi

echo "=== Snip Token Usage Experiment ==="
echo "Condition : $CONDITION hippocampus"
echo "Run       : $RUN"
echo "Repo      : $REPO"
echo "Output    : $OUTPUT_FILE"
echo ""

cd "$REPO"

claude \
  --output-format stream-json \
  --dangerously-skip-permissions \
  -p "$TASK_PROMPT" \
  | tee "$OUTPUT_FILE"

echo ""
echo "=== Token Summary ==="
jq -rs '
  map(select(.type == "result")) | .[0] |
  "Input tokens:         \(.usage.input_tokens // 0)",
  "Output tokens:        \(.usage.output_tokens // 0)",
  "Cache read tokens:    \(.usage.cache_read_input_tokens // 0)",
  "Cache create tokens:  \(.usage.cache_creation_input_tokens // 0)",
  "Total tokens:         \((.usage.input_tokens // 0) + (.usage.output_tokens // 0))",
  "Duration (ms):        \(.duration_ms // "unknown")"
' "$OUTPUT_FILE"

if [[ "$CONDITION" == "with" ]]; then
  echo ""
  echo "=== Hippocampus Usage ==="
  QUERIES=$(grep -c 'hippocampus:query' "$OUTPUT_FILE" 2>/dev/null || echo 0)
  LOGS=$(grep -c 'hippocampus:log' "$OUTPUT_FILE" 2>/dev/null || echo 0)
  echo "Query calls : $QUERIES"
  echo "Log calls   : $LOGS"
fi

echo ""
echo "Done. Fill results into experiments/token-usage/results.md"
