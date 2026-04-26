# Grep is All You Need

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.19777260.svg)](https://doi.org/10.5281/zenodo.19777260)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Production](https://img.shields.io/badge/production-faith.localkin.ai_·_heal.localkin.ai-brightgreen)](https://localkin.dev)

**Replace your entire RAG pipeline with `grep`. 100% accuracy, sub-25ms latency, zero infrastructure.**

> For domain-specific knowledge grounding — where the vocabulary is predictable and the corpus is bounded — the entire RAG stack is unnecessary. Retrieval does not need intelligence. The LLM is the intelligence.

[📄 Paper v1.1 (Zenodo)](https://doi.org/10.5281/zenodo.19777260) · [Markdown](paper/grep_is_all_you_need.md) · [PDF](paper/grep_is_all_you_need.pdf) · [中文 README](README_zh.md)

---

## Why?

| | Grep is All You Need | Vector RAG | GraphRAG |
|---|---|---|---|
| **Accuracy** | 100% | 85-95% | 90-95% |
| **Latency** | <25ms (500-file corpus) | 50-200ms | 100-500ms |
| **Preprocessing per query** | 0 seconds | Hours upfront | Hours upfront |
| **Infrastructure** | None | Vector DB | Graph DB + Embedding API |
| **Adding docs** | Drop a file | Re-embed, re-index | Re-extract entities, rebuild graph |
| **Output format** | Human-readable Markdown | Opaque vectors | Entity triples |
| **Lines of code (retrieval)** | ~30 bash | 300-500+ Python | 1,000+ Python |
| **Cost** | $0 | $$$ | $$$$$ |

## Quick Start

```bash
git clone https://github.com/LocalKinAI/grep-is-all-you-need.git
cd grep-is-all-you-need

# Search the example corpus (TCM herbs)
./search.sh --keywords "astragalus" --collection tcm

# Search across all examples
./search.sh --keywords "prayer,silence"
```

That's it. No pip install, no docker, no database, no API keys.

## How It Works

**Two-layer retrieval — both layers are `grep`:**

```
Layer 1: grep -r -i -C 8 over all .txt and .md raw source files
         → returns raw passages with 8 lines of context

Layer 2: grep -r -i -C 8 also walks _compiled/<file>_concepts.md
         and _compiled/<file>_faq.md — per-source LLM-distilled
         concept and FAQ entries that act as a multilingual
         semantic bridge back into the literal Layer 1 corpus.
```

A single `grep` invocation walks both layers. Your LLM receives both raw passages and structured summaries from the same call. The LLM does the intelligence — retrieval is just `grep`.

> 📖 The full architecture, the *concept-bridge* framing of Layer 2 (vs the older "fallback" framing), and a documented 0/5 → 4/4 zero-hallucination reproducibility cycle are in **the paper** ([Zenodo DOI](https://doi.org/10.5281/zenodo.19777260)).

## Use Your Own Corpus

```bash
# 1. Organize your knowledge base
mkdir -p my_knowledge/topic_a
cp your_documents.txt my_knowledge/topic_a/

# 2. Search it
KNOWLEDGE_BASE=./my_knowledge ./search.sh --keywords "your,terms"
```

### Optional: Compile Layer 2 Concept + FAQ Files

For cross-lingual queries and concept jumps that pure keyword search misses, run the autonomous compilation step. **Default is free local Ollama (Kimi 2.6)**; falls back to paid Anthropic Haiku if Ollama is unavailable.

```bash
# Free path (recommended) — local Ollama with kimi-k2.6:cloud
ollama pull kimi-k2.6:cloud   # one-time
./compile.sh my_knowledge/topic_a/document.txt

# Paid fallback — Anthropic Haiku
ANTHROPIC_API_KEY=sk-ant-... ./compile.sh my_knowledge/topic_a/document.txt

# Creates per source file:
#   my_knowledge/topic_a/_compiled/document_concepts.md  (~3 KB, 5-10 core concepts + verbatim quotes)
#   my_knowledge/topic_a/_compiled/document_faq.md       (~2.5 KB, 5-8 Q&A pairs)
```

These compiled files are automatically included in search results, giving your LLM pre-structured knowledge alongside raw text — and crucially providing a **bridge for queries in a language different from the source corpus**.

## Directory Structure

```
your_knowledge_base/
├── domain_a/
│   ├── collection_1/
│   │   ├── source.txt              # Raw text (Layer 1: grep target)
│   │   ├── source2.md
│   │   └── _compiled/              # Optional (Layer 2: per-source concept+FAQ)
│   │       ├── source_concepts.md
│   │       ├── source_faq.md
│   │       ├── source2_concepts.md
│   │       └── source2_faq.md
│   └── collection_2/
│       └── ...
└── domain_b/
    └── ...
```

## When This Works Best

- **Domain-specific vocabulary** (medical terms, legal jargon, religious texts, technical docs)
- **Bounded corpus** (<10GB, <10K files — `grep` is fast)
- **Predictable queries** (users ask about known topics in the corpus)
- **Cross-lingual queries via Layer 2** (Chinese query against English source corpus, or vice versa)
- **LLM as consumer** (the LLM synthesizes; retrieval just finds passages)

## When to Use Something Else

- **Truly open-domain semantic search** (no concept name in any author's vocabulary matches the query)
- **Massive corpus** (10GB+ where `grep` latency matters)
- **Entity-relationship traversal** (explicit graph queries)

## Production Deployment

This approach powers [LocalKin](https://localkin.dev), a self-hallucination-free, self-improving multi-agent system on a single Mac mini. As of April 2026 it serves as the knowledge backbone for:

- **39 Traditional Chinese Medicine agents** (`heal.localkin.ai`) — 4,500 years of classical texts, from Huang Di to living National Grand Masters
- **37 Christian spiritual direction agents** (`faith.localkin.ai`) — 1,900 years of texts, from Irenaeus (130 AD) to T. Austin-Sparks (1971)
- **1 U.S. citizenship coaching agent**

**~500 source texts, 76 specialized agents, 180 MB corpus, two languages, four-and-a-half millennia of human thought** — all retrieved by `grep`.

The `_compiled/` Layer 2 files grow nightly via a cron-driven autonomous pipeline (see paper §9) at **$0/year** in API costs, after migrating the compilation LLM from paid Anthropic Haiku to local-Ollama-served Kimi 2.6 in April 2026.

## Reproducibility

The paper documents a one-day failure-and-recovery cycle (§6.5) that you can replay:

- **Failure**: agent fabricated 5 quotes with chapter attribution. `grep` verification: **0/5 in corpus**.
- **Root cause**: persona-prompt signature phrases formatted as `**"..."**` were treated as canonical text by the LLM and re-emitted with false attribution.
- **Fix**: 60-line script auto-stripped 41 fake-quote markers across 79 souls; appended a citation hard-rule block. **25 minutes** from diagnosis to deploy.
- **Recovery**: same query, **4/4 quotes grep-verified** to corpus.

The architecture's safety property is recoverable through prompt hygiene alone — no retraining, no infrastructure change. Detailed in paper §6.5.

## Paper

- **Zenodo (canonical, DOI'd)**: [10.5281/zenodo.19777260](https://doi.org/10.5281/zenodo.19777260)
- **Markdown source**: [paper/grep_is_all_you_need.md](paper/grep_is_all_you_need.md) (bilingual EN + 中文, 1064 lines)
- **PDF**: [paper/grep_is_all_you_need.pdf](paper/grep_is_all_you_need.pdf) (33 pages, 1.6 MB)
- **Web version**: [localkin.dev/papers/grep-is-all-you-need](https://www.localkin.dev/papers/grep-is-all-you-need)

## Cite

```bibtex
@misc{localkin2026grep,
  author    = {{The LocalKin Team}},
  title     = {Grep is All You Need: Zero-Preprocessing Knowledge
               Retrieval for LLM Agents},
  year      = {2026},
  month     = apr,
  publisher = {Zenodo},
  doi       = {10.5281/zenodo.19777260},
  url       = {https://doi.org/10.5281/zenodo.19777260}
}
```

## License

MIT — use it however you want.

---

*From the creators of [LocalKin](https://localkin.dev) — a self-hallucination-free, self-improving 76-agent system running on a single Mac mini.*

*"Grep is All You Need" is a deliberate homage to Vaswani et al. (2017). We trust the irony is not lost.*
