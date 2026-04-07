#!/bin/bash
# Grep is All You Need — Knowledge Search
# Two-layer retrieval: grep + cat fallback
# 100% accuracy, <10ms, zero infrastructure
#
# Usage:
#   ./search.sh --keywords "astragalus,herbs" --collection tcm
#   ./search.sh --keywords "prayer" --base /path/to/knowledge
#   KNOWLEDGE_BASE=./examples ./search.sh --keywords "prayer"
#
# Environment:
#   KNOWLEDGE_BASE  — root directory of your knowledge corpus (default: ./examples)
#
# See: https://localkin.dev/papers/grep-is-all-you-need

set -euo pipefail

# ── Parse arguments ──
COLLECTION=""
KEYWORDS=""
BASE="${KNOWLEDGE_BASE:-./examples}"
CONTEXT_LINES=8
MAX_GREP_LINES=80
MAX_REF_SIZE=51200  # 50KB

show_help() {
    cat <<'EOF'
Grep is All You Need — Knowledge Search

Usage:
  ./search.sh --keywords "term1,term2" [--collection name] [--base /path] [--context 8]

Options:
  --keywords, -k    Comma-separated search terms (required)
  --collection, -c  Search only this subdirectory (optional, searches all if omitted)
  --base, -b        Knowledge base root (default: $KNOWLEDGE_BASE or ./examples)
  --context, -C     Lines of context around grep matches (default: 8)
  --help, -h        Show this help

Environment:
  KNOWLEDGE_BASE    Root directory of your knowledge corpus

Examples:
  ./search.sh -k "astragalus,compatibility" -c tcm
  ./search.sh -k "prayer,silence" -c spiritual
  KNOWLEDGE_BASE=/data/docs ./search.sh -k "authentication"

How it works:
  Layer 1: grep -r -i -C 8 across all .txt and .md files
  Layer 2: cat small reference files (*_concepts.md, *_faq.md) for structured context

Paper: https://localkin.dev/papers/grep-is-all-you-need
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --keywords|-k)  KEYWORDS="$2"; shift 2 ;;
        --collection|-c) COLLECTION="$2"; shift 2 ;;
        --base|-b)      BASE="$2"; shift 2 ;;
        --context|-C)   CONTEXT_LINES="$2"; shift 2 ;;
        --help|-h)      show_help ;;
        *)
            # Legacy positional: search.sh <collection> <keywords>
            if [ -z "$COLLECTION" ]; then COLLECTION="$1"
            elif [ -z "$KEYWORDS" ]; then KEYWORDS="$1"
            fi
            shift ;;
    esac
done

if [ -z "$KEYWORDS" ]; then
    echo "Error: --keywords is required"
    echo "Run: ./search.sh --help"
    exit 1
fi

if [ ! -d "$BASE" ]; then
    echo "Error: knowledge base not found: $BASE"
    echo "Set KNOWLEDGE_BASE or use --base /path/to/your/corpus"
    exit 1
fi

# ── Discover search directories ──
DIRS=""
if [ -n "$COLLECTION" ]; then
    # Search for this collection across all domain subdirectories
    while IFS= read -r d; do
        DIRS="$DIRS $d"
    done < <(find "$BASE" -maxdepth 2 -type d -name "$COLLECTION" 2>/dev/null)

    if [ -z "$DIRS" ]; then
        echo "No knowledge files found for collection: $COLLECTION"
        echo "Available collections:"
        find "$BASE" -mindepth 1 -maxdepth 2 -type d | sed "s|$BASE/||" | sort
        exit 1
    fi
else
    # Search all directories
    DIRS="$BASE"
fi

# ── Layer 1: grep keywords ──
IFS=',' read -ra KW_ARRAY <<< "$KEYWORDS"

RESULTS=""
MATCH_COUNT=0

for kw in "${KW_ARRAY[@]}"; do
    kw=$(echo "$kw" | xargs)
    [ -z "$kw" ] && continue

    for dir in $DIRS; do
        matches=$(grep -r -i -C "$CONTEXT_LINES" --include="*.txt" --include="*.md" "$kw" "$dir" 2>/dev/null | head -40)
        if [ -n "$matches" ]; then
            RESULTS="$RESULTS
--- [$kw] ---
$matches
"
            MATCH_COUNT=$((MATCH_COUNT + 1))
        fi
    done
done

# ── Layer 2: cat fallback for small reference files ──
# Always include structured files (concepts, FAQ) for richer context
REFS=""
find_refs() {
    local dir="$1"
    for ref in "$dir"/*_faq.md "$dir"/*_FAQ.md "$dir"/*_study_guide.md "$dir"/*_concepts.md \
               "$dir"/FAQ.md "$dir"/study_guide.md "$dir"/concepts.md \
               "$dir"/_compiled/*_faq.md "$dir"/_compiled/*_concepts.md; do
        if [ -f "$ref" ]; then
            size=$(wc -c < "$ref" 2>/dev/null)
            if [ "$size" -lt "$MAX_REF_SIZE" ]; then
                fname=$(basename "$ref")
                REFS="$REFS
=== [$fname] ===
$(cat "$ref")
"
            fi
        fi
    done
}

for dir in $DIRS; do
    find_refs "$dir"
    # Also check subdirectories (author/collection level)
    for subdir in "$dir"/*/; do
        [ -d "$subdir" ] && find_refs "$subdir"
    done
done

# ── Output ──
if [ -z "$RESULTS" ] && [ -z "$REFS" ]; then
    echo "No matches found for: $KEYWORDS"
    [ -n "$COLLECTION" ] && echo "Collection: $COLLECTION"
    echo "Searched in: $BASE"
    exit 0
fi

if [ -n "$RESULTS" ]; then
    echo "$RESULTS" | head -"$MAX_GREP_LINES"
    echo ""
    echo "[$MATCH_COUNT keyword(s) matched]"
fi

if [ -n "$REFS" ]; then
    echo ""
    echo "$REFS"
fi
