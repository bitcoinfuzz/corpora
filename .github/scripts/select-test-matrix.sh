#!/usr/bin/env bash
set -euo pipefail

BASE_SHA="${1:-}"
HEAD_SHA="${2:-}"
MATRIX_FILE="${3:-.github/test-matrix.json}"

FULL_MATRIX="$(jq -c . "$MATRIX_FILE")"

# Fall back to the current CI behavior whenever filtering is not possible.
select_all() {
  echo "Using the full test matrix" >&2
  echo "matrix=$FULL_MATRIX"
  exit 0
}

# A failed or empty diff is handled by the generic "select_all" fallback.
CHANGED_FILES="$(git diff --name-only "$BASE_SHA...$HEAD_SHA" 2>/dev/null || true)"

declare -A KNOWN_CORPORA=()
declare -A SELECTED_CORPORA=()
USE_FULL_MATRIX=false

while IFS= read -r corpus; do
  KNOWN_CORPORA["$corpus"]=1
done < <(jq -r '.[].corpus' "$MATRIX_FILE" | sort -u)

# Every changed path must belong to a corpus represented in the matrix.
while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  folder="${file%%/*}"
  if [[ "$file" != */* || -z "${KNOWN_CORPORA[$folder]:-}" ]]; then
    USE_FULL_MATRIX=true
    break
  fi
  SELECTED_CORPORA["$folder"]=1
done <<< "$CHANGED_FILES"

if [[ "$USE_FULL_MATRIX" == true || "${#SELECTED_CORPORA[@]}" -eq 0 ]]; then
  select_all
fi

SELECTED_JSON="$(
  printf '%s\n' "${!SELECTED_CORPORA[@]}" |
    jq -Rsc 'split("\n") | map(select(length > 0))'
)"

# Filtering by corpus keeps every target associated with a changed folder.
FILTERED_MATRIX="$(
  jq -c --argjson selected "$SELECTED_JSON" \
    '[.[] | select(.corpus as $corpus | $selected | index($corpus))]' \
    "$MATRIX_FILE"
)"

echo "Selected corpora: $(jq -r 'join(",")' <<< "$SELECTED_JSON")" >&2
echo "matrix=$FILTERED_MATRIX"
