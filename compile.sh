#!/bin/bash
# Knowledge Compile — One-time LLM knowledge extraction (Layer 2 builder)
# Converts raw text into per-source concepts.md + faq.md.
#
# Default LLM: kimi-k2.6:cloud via local Ollama (free, ~$0/file)
# Fallback   : Anthropic Haiku 4.5 via API (paid, ~$0.01/file)
#
# Usage:
#   ./compile.sh path/to/document.txt              # uses local Ollama Kimi 2.6
#   ./compile.sh --force path/to/document.md       # recompile
#   COMPILE_BACKEND=anthropic ANTHROPIC_API_KEY=sk-ant-... ./compile.sh ...
#
# Output:
#   path/to/_compiled/document_concepts.md   (~3 KB, 5-10 core concepts)
#   path/to/_compiled/document_faq.md        (~2.5 KB, 5-8 Q&A pairs)
#
# Requires: curl, python3 (for JSON), Ollama (default) OR ANTHROPIC_API_KEY (fallback)
# See:      https://doi.org/10.5281/zenodo.19777260

set -euo pipefail

# ── Backend selection ──
# kimi (default) | anthropic
BACKEND="${COMPILE_BACKEND:-auto}"

# Kimi (Ollama) config
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434/api/generate}"
KIMI_MODEL="${KIMI_MODEL:-kimi-k2.6:cloud}"

# Anthropic config (fallback)
ANTHROPIC_URL="https://api.anthropic.com/v1/messages"
HAIKU_MODEL="${ANTHROPIC_MODEL:-claude-haiku-4-5-20251001}"

MAX_TOKENS=2000
MAX_INPUT_BYTES=153600  # 150KB
FORCE=false

# ── Parse args ──
INPUT_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force|-f) FORCE=true; shift ;;
        --backend|-b) BACKEND="$2"; shift 2 ;;
        --kimi) BACKEND="kimi"; shift ;;
        --anthropic) BACKEND="anthropic"; shift ;;
        --help|-h)
            cat <<'EOF'
Knowledge Compile — Layer 2 builder for grep-is-all-you-need

Usage:
  ./compile.sh [options] <file>

Options:
  --force, -f      Recompile even if output exists
  --backend, -b    LLM backend: kimi | anthropic | auto (default: auto)
  --kimi           Force local Kimi (free)
  --anthropic      Force Anthropic Haiku (paid, requires ANTHROPIC_API_KEY)
  --help, -h       Show this help

Backends:
  kimi (default, free, ~$0/file)
    - Requires Ollama running locally with kimi-k2.6:cloud
    - Set up: brew install ollama && ollama pull kimi-k2.6:cloud
    - Override: KIMI_MODEL=kimi-k2.5:cloud OLLAMA_URL=http://...

  anthropic (fallback, paid, ~$0.01/file with Haiku 4.5)
    - Requires ANTHROPIC_API_KEY environment variable
    - Override model: ANTHROPIC_MODEL=claude-sonnet-4-5-20251001

  auto (default behavior)
    - Tries Kimi first; falls back to Anthropic if Ollama unavailable
      AND ANTHROPIC_API_KEY is set

Output:
  Creates _compiled/ directory next to source file with:
  - {name}_concepts.md  (5-10 core concepts, key quotes, practical points)
  - {name}_faq.md       (5-8 Q&A pairs for common reader questions)

Cost: $0/file with Kimi local; ~$0.01/file with Haiku.
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

# ── Backend availability checks ──
have_kimi() {
    curl -s --max-time 3 "${OLLAMA_URL%/api/generate}/api/tags" 2>/dev/null \
        | grep -q "$KIMI_MODEL"
}

have_anthropic() {
    [ -n "${ANTHROPIC_API_KEY:-}" ]
}

# Resolve auto → concrete backend
if [ "$BACKEND" = "auto" ]; then
    if have_kimi; then
        BACKEND="kimi"
    elif have_anthropic; then
        BACKEND="anthropic"
    else
        echo "Error: no usable backend found"
        echo "  Kimi: Ollama with $KIMI_MODEL not running at $OLLAMA_URL"
        echo "  Anthropic: ANTHROPIC_API_KEY not set"
        echo ""
        echo "Set up Kimi (recommended, free):"
        echo "  brew install ollama && ollama serve &"
        echo "  ollama pull $KIMI_MODEL"
        echo ""
        echo "Or set up Anthropic (paid):"
        echo "  export ANTHROPIC_API_KEY=sk-ant-..."
        exit 1
    fi
fi

if [ "$BACKEND" = "kimi" ] && ! have_kimi; then
    echo "Error: --kimi requested but $KIMI_MODEL not reachable at $OLLAMA_URL"
    exit 1
fi
if [ "$BACKEND" = "anthropic" ] && ! have_anthropic; then
    echo "Error: --anthropic requested but ANTHROPIC_API_KEY not set"
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

SYSTEM_PROMPT="You are an expert knowledge curator. Be concise and structured."

# ── Backend implementations ──
call_kimi() {
    local prompt="$1"
    local payload
    payload=$(python3 -c "
import json, sys
prompt = sys.argv[1]
system = sys.argv[2]
print(json.dumps({
    'model': '$KIMI_MODEL',
    'prompt': system + '\n\n' + prompt,
    'stream': False,
    'options': {'temperature': 0.3, 'num_predict': $MAX_TOKENS * 2},
}))
" "$prompt" "$SYSTEM_PROMPT")

    local response
    response=$(curl -s --max-time 120 "$OLLAMA_URL" \
        -H "Content-Type: application/json" \
        -d "$payload")

    python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('response',''))" <<< "$response"
}

call_anthropic() {
    local prompt="$1"
    local escaped_prompt
    escaped_prompt=$(printf '%s' "$prompt" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')

    local response
    response=$(curl -s --max-time 90 "$ANTHROPIC_URL" \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "{
            \"model\": \"$HAIKU_MODEL\",
            \"max_tokens\": $MAX_TOKENS,
            \"system\": \"$SYSTEM_PROMPT\",
            \"messages\": [{\"role\": \"user\", \"content\": $escaped_prompt}]
        }")

    if command -v jq &>/dev/null; then
        echo "$response" | jq -r '.content[0].text // empty' 2>/dev/null
    else
        echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('content',[{}])[0].get('text',''))" 2>/dev/null
    fi
}

call_llm() {
    if [ "$BACKEND" = "kimi" ]; then
        call_kimi "$1"
    else
        call_anthropic "$1"
    fi
}

# ── Concepts extraction ──
echo "Compiling concepts: $STEM (backend=$BACKEND)..."
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

CONCEPTS_RESULT=$(call_llm "$CONCEPTS_PROMPT")

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

FAQ_RESULT=$(call_llm "$FAQ_PROMPT")

if [ -z "$FAQ_RESULT" ]; then
    echo "Error: FAQ generation failed for $STEM"
    exit 1
fi

echo "$FAQ_RESULT" > "$FAQ_FILE"
echo "  -> $FAQ_FILE ($(wc -c < "$FAQ_FILE") bytes)"

echo "Done: $STEM compiled successfully (backend=$BACKEND)"
