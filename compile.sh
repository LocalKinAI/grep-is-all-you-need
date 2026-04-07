#!/bin/bash
# Knowledge Compile — One-time LLM knowledge extraction
# Converts raw text into structured concepts + FAQ via Anthropic API
#
# Usage:
#   ANTHROPIC_API_KEY=sk-ant-... ./compile.sh path/to/document.txt
#   ./compile.sh --force path/to/document.md    # recompile even if exists
#
# Output:
#   path/to/_compiled/document_concepts.md
#   path/to/_compiled/document_faq.md
#
# Requires: curl, jq (optional, for prettier output)
# Cost: ~$0.15-0.20 per file (Claude Haiku)

set -euo pipefail

# ── Config ──
API_URL="https://api.anthropic.com/v1/messages"
MODEL="${COMPILE_MODEL:-claude-haiku-4-5-20251001}"
MAX_TOKENS=2000
MAX_INPUT_BYTES=153600  # 150KB
FORCE=false

# ── Parse args ──
INPUT_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force|-f) FORCE=true; shift ;;
        --model|-m) MODEL="$2"; shift 2 ;;
        --help|-h)
            cat <<'EOF'
Knowledge Compile — One-time LLM knowledge extraction

Usage:
  ANTHROPIC_API_KEY=sk-ant-... ./compile.sh [options] <file>

Options:
  --force, -f    Recompile even if output exists
  --model, -m    LLM model (default: claude-haiku-4-5-20251001)
  --help, -h     Show this help

Environment:
  ANTHROPIC_API_KEY    Your Anthropic API key (required)
  COMPILE_MODEL        Override default model

Output:
  Creates _compiled/ directory next to source file with:
  - {name}_concepts.md  (5-10 core concepts, key quotes, practical points)
  - {name}_faq.md       (5-8 Q&A pairs for common reader questions)

Cost: ~$0.15-0.20 per file using Claude Haiku
EOF
            exit 0 ;;
        *) INPUT_FILE="$1"; shift ;;
    esac
done

if [ -z "$INPUT_FILE" ]; then
    echo "Error: no input file specified"
    echo "Usage: ./compile.sh path/to/document.txt"
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: file not found: $INPUT_FILE"
    exit 1
fi

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    echo "Error: ANTHROPIC_API_KEY not set"
    echo "Get your key at: https://console.anthropic.com/"
    exit 1
fi

# ── Setup output ──
DIR="$(dirname "$INPUT_FILE")"
BASENAME="$(basename "$INPUT_FILE")"
STEM="${BASENAME%.*}"
COMPILED_DIR="$DIR/_compiled"
CONCEPTS_FILE="$COMPILED_DIR/${STEM}_concepts.md"
FAQ_FILE="$COMPILED_DIR/${STEM}_faq.md"

# Skip if already compiled (unless --force)
if [ "$FORCE" = false ] && [ -f "$CONCEPTS_FILE" ] && [ -f "$FAQ_FILE" ]; then
    echo "Already compiled: $STEM (use --force to recompile)"
    exit 0
fi

mkdir -p "$COMPILED_DIR"

# ── Read source ──
RAW=$(head -c "$MAX_INPUT_BYTES" "$INPUT_FILE")
if [ "$(wc -c < "$INPUT_FILE")" -gt "$MAX_INPUT_BYTES" ]; then
    RAW="$RAW

[...truncated at 150KB...]"
fi

# ── Detect language (Chinese vs English) ──
if echo "$RAW" | grep -qP '[\x{4e00}-\x{9fff}]' 2>/dev/null || echo "$RAW" | grep -q '[一-龥]' 2>/dev/null; then
    LANG_HINT="Output in Chinese (中文)."
    CONCEPTS_HEADER="核心概念"
    FAQ_HEADER="常见问题"
else
    LANG_HINT="Output in English."
    CONCEPTS_HEADER="Core Concepts"
    FAQ_HEADER="FAQ"
fi

# ── Call Anthropic API ──
call_api() {
    local prompt="$1"
    local escaped_prompt
    escaped_prompt=$(printf '%s' "$prompt" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')

    local response
    response=$(curl -s --max-time 90 "$API_URL" \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "{
            \"model\": \"$MODEL\",
            \"max_tokens\": $MAX_TOKENS,
            \"system\": \"You are an expert knowledge curator. Be concise and structured.\",
            \"messages\": [{\"role\": \"user\", \"content\": $escaped_prompt}]
        }")

    # Extract text content
    if command -v jq &>/dev/null; then
        echo "$response" | jq -r '.content[0].text // empty' 2>/dev/null
    else
        echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('content',[{}])[0].get('text',''))" 2>/dev/null
    fi
}

# ── Concepts extraction ──
echo "Compiling concepts: $STEM..."
CONCEPTS_PROMPT="Extract core knowledge from this text. $LANG_HINT

$RAW

Output format:
# $BASENAME — $CONCEPTS_HEADER

## Thesis
(1-2 sentence summary)

## $CONCEPTS_HEADER (5-10)
- **Concept**: Definition + 1 key quote

## Key Quotes (3-5, with chapter/section reference)
> \"Quote\" — section

## Practical Points
- Point 1
- Point 2

TARGET: <3000 chars, concrete not abstract"

CONCEPTS_RESULT=$(call_api "$CONCEPTS_PROMPT")

if [ -z "$CONCEPTS_RESULT" ]; then
    echo "Error: concepts extraction failed for $STEM"
    exit 1
fi

echo "$CONCEPTS_RESULT" > "$CONCEPTS_FILE"
echo "  -> $CONCEPTS_FILE ($(wc -c < "$CONCEPTS_FILE") bytes)"

# ── FAQ generation ──
echo "Compiling FAQ: $STEM..."
FAQ_PROMPT="Generate FAQ from this text. $LANG_HINT

$RAW

Output format:
# $BASENAME — $FAQ_HEADER

## Q1: (a real question a reader would have)
A: (direct answer, 2-3 sentences, reference source)

## Q2: ...

(Generate 5-8 Q&A pairs)

TARGET: <3000 chars"

FAQ_RESULT=$(call_api "$FAQ_PROMPT")

if [ -z "$FAQ_RESULT" ]; then
    echo "Error: FAQ generation failed for $STEM"
    exit 1
fi

echo "$FAQ_RESULT" > "$FAQ_FILE"
echo "  -> $FAQ_FILE ($(wc -c < "$FAQ_FILE") bytes)"

echo "Done: $STEM compiled successfully"
