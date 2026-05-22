#!/usr/bin/env bash
# Parse token usage from a single run JSONL file
# Usage: parse.sh <file.jsonl>
set -euo pipefail

FILE=${1:?usage: parse.sh <file.jsonl>}

jq -rs '
  map(select(.type == "result")) | .[0] |
  {
    input_tokens:                (.usage.input_tokens // 0),
    output_tokens:               (.usage.output_tokens // 0),
    cache_read_input_tokens:     (.usage.cache_read_input_tokens // 0),
    cache_creation_input_tokens: (.usage.cache_creation_input_tokens // 0),
    total_tokens:               ((.usage.input_tokens // 0) + (.usage.output_tokens // 0)),
    duration_ms:                 (.duration_ms // null)
  }
' "$FILE"
