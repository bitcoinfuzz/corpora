#!/usr/bin/env bash
set -euo pipefail

CORPUS_DIR="$1"
TARGET="$2"
CXXFLAGS="$3"
ASAN_OPTIONS="${4:-}"
CXX="${5}"

if [ -d "./${CORPUS_DIR}" ]; then
  echo "Using corpora for ${TARGET}"
  cd bitcoinfuzz
  export CXXFLAGS="${CXXFLAGS}"
  export CXX="${CXX}"
  [[ -n "${ASAN_OPTIONS}" ]] && export ASAN_OPTIONS="${ASAN_OPTIONS}"
  make
  FUZZ="${TARGET}" ./bitcoinfuzz -runs=1 "../${CORPUS_DIR}"
else
  echo "Corpus ./${CORPUS_DIR} does not exist. Skipping."
fi
