#!/bin/bash
# benchmark.sh — grep vs vector RAG on the included examples/ corpus
#
# Runs 30 queries against both retrieval systems, reports:
#   - Median latency
#   - P99 latency
#   - Index build time (one-time cost)
#   - Memory overhead
#   - Retrieval accuracy (recall on hand-graded relevance)
#
# Vector RAG implementation uses sentence-transformers + FAISS for a
# fair comparison. Both systems search the same corpus; the only
# difference is the retrieval mechanism.
#
# Setup is automatic:
#   - First run: creates a venv and installs sentence-transformers + faiss
#   - Subsequent runs: reuses cached venv + index
#
# Output: benchmark_results.md

set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
VENV="$ROOT/.bench_venv"
RESULTS="$ROOT/benchmark_results.md"

if [ -t 1 ]; then
  G='\033[0;32m'; B='\033[0;34m'; D='\033[2m'; N='\033[0m'
else
  G=''; B=''; D=''; N=''
fi

hr()    { printf "${B}═══ %s ═══${N}\n" "$1"; }
faded() { printf "${D}%s${N}\n" "$1"; }

hr "grep vs vector RAG — benchmark"
echo ""

# ── Step 1: ensure Python venv with deps ──
if [ ! -d "$VENV" ]; then
    hr "First run — installing benchmark dependencies"
    faded "  This will take 1-2 minutes (one-time setup, ~600 MB venv)"
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install --quiet --upgrade pip
    "$VENV/bin/pip" install --quiet sentence-transformers faiss-cpu numpy
    echo ""
    faded "  ✓ Dependencies installed at $VENV"
    echo ""
fi

# ── Step 2: run the actual benchmark ──
hr "Running 30 queries against both systems"
echo ""
"$VENV/bin/python" "$ROOT/bench/run_benchmark.py" "$ROOT/examples" "$RESULTS"

echo ""
hr "Done"
echo ""
echo "Results written to: $RESULTS"
echo ""
cat "$RESULTS" | head -40
