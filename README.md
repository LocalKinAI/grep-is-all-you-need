# Grep is All You Need

**Replace your entire RAG pipeline with `grep`. 100% accuracy, <10ms, zero infrastructure.**

> For domain-specific knowledge grounding — where the vocabulary is predictable and the corpus is bounded — the entire RAG stack is unnecessary. Retrieval does not need intelligence. The LLM is the intelligence.

[Paper](paper/grep_is_all_you_need.md) | [中文](README_zh.md)

---

## Why?

| | Grep is All You Need | Vector RAG | GraphRAG |
|---|---|---|---|
| **Accuracy** | 100% | 85-95% | 90-95% |
| **Latency** | <10ms | 50-200ms | 100-500ms |
| **Preprocessing** | 0 seconds | Hours | Hours |
| **Infrastructure** | None | Vector DB | Graph DB + Embedding API |
| **Adding docs** | Drop a file | Re-embed, re-index | Re-extract entities, rebuild graph |
| **Output format** | Human-readable Markdown | Opaque vectors | Entity triples |
| **Lines of code** | ~100 bash | 300-500+ Python | 1,000+ Python |
| **Cost** | $0 | $$$ | $$$$$ |

## Quick Start

```bash
git clone https://github.com/LocalKinAI/grep-is-all-you-need.git
cd grep-is-all-you-need

# Search the example corpus
./search.sh --keywords "astragalus" --collection tcm

# Search across all examples
./search.sh --keywords "prayer,silence"
```

That's it. No pip install, no docker, no database, no API keys.

## How It Works

**Two-layer retrieval:**

```
Layer 1: grep -r -i -C 8 across all .txt and .md files
         → returns raw passages with 8 lines of context

Layer 2: cat *_concepts.md, *_faq.md (small reference files)
         → returns pre-structured knowledge summaries
```

Your LLM receives both raw passages and structured summaries. The LLM does the intelligence — retrieval is just `grep`.

## Use Your Own Corpus

```bash
# 1. Organize your knowledge base
mkdir -p my_knowledge/topic_a
cp your_documents.txt my_knowledge/topic_a/

# 2. Search it
KNOWLEDGE_BASE=./my_knowledge ./search.sh --keywords "your,terms"
```

### Optional: Compile Structured Summaries

For richer retrieval context, compile your documents into concepts + FAQ:

```bash
# Requires Anthropic API key (~$0.15 per file using Haiku)
ANTHROPIC_API_KEY=sk-ant-... ./compile.sh my_knowledge/topic_a/document.txt

# Creates:
#   my_knowledge/topic_a/_compiled/document_concepts.md  (5-10 core concepts)
#   my_knowledge/topic_a/_compiled/document_faq.md       (5-8 Q&A pairs)
```

These compiled files are automatically included in search results, giving your LLM pre-structured knowledge alongside raw text.

## Directory Structure

```
your_knowledge_base/
├── domain_a/
│   ├── collection_1/
│   │   ├── source.txt              # Raw text (Layer 1: grep target)
│   │   ├── source2.md
│   │   └── _compiled/              # Optional (Layer 2: structured)
│   │       ├── source_concepts.md
│   │       └── source_faq.md
│   └── collection_2/
│       └── ...
└── domain_b/
    └── ...
```

## When This Works Best

- **Domain-specific vocabulary** (medical terms, legal jargon, religious texts, technical docs)
- **Bounded corpus** (<10GB, <10K files — grep is fast)
- **Predictable queries** (users ask about known topics in the corpus)
- **LLM as consumer** (the LLM synthesizes; retrieval just finds passages)

## When to Use Something Else

- **Fuzzy semantic search** (user vocabulary doesn't match corpus)
- **Massive corpus** (10GB+ where grep latency matters)
- **Cross-lingual retrieval** (Chinese query → English document)
- **Entity-relationship traversal** (explicit graph queries)

## Production Deployment

This approach powers [LocalKin](https://localkin.dev), a 75-agent self-evolving AI swarm. It serves as the knowledge backbone for:

- 11 Traditional Chinese Medicine agents (grounded in classical texts from 200 CE)
- 9 Christian spiritual direction agents (texts spanning 600 years)
- 1 U.S. citizenship coaching agent

192 source texts, two languages, three millennia of human thought — all retrieved by `grep`.

## Paper

Read the full paper: [Grep is All You Need: Zero-Preprocessing Knowledge Retrieval for LLM Agents](paper/grep_is_all_you_need.md)

## License

MIT — use it however you want.

---

*From the creators of [LocalKin](https://localkin.dev) — a 75-agent self-evolving AI swarm running on a single Mac Mini.*
