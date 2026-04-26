# Grep is All You Need

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.19777260.svg)](https://doi.org/10.5281/zenodo.19777260)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Faith](https://img.shields.io/badge/live-faith.localkin.ai-emerald?logo=googlechrome&logoColor=white)](https://faith.localkin.ai)
[![Heal](https://img.shields.io/badge/live-heal.localkin.ai-emerald?logo=googlechrome&logoColor=white)](https://heal.localkin.ai)

**Replace your entire RAG pipeline with `grep`. 100% accuracy, sub-25ms latency, zero infrastructure.**

> For domain-specific knowledge grounding — where the vocabulary is predictable and the corpus is bounded — the entire RAG stack is unnecessary. Retrieval does not need intelligence. The LLM is the intelligence.

[📄 Paper v1.1 (Zenodo)](https://doi.org/10.5281/zenodo.19777260) · [Markdown](paper/grep_is_all_you_need.md) · [PDF](paper/grep_is_all_you_need.pdf) · [中文 README](README_zh.md)

---

## 🟢 Try it live — production deployment, no signup, no API key

This isn't a research demo. **It's running right now**, serving 76 LLM agents on a single Mac mini.

| Live system | What's there | Try this query |
|---|---|---|
| **🌐 [faith.localkin.ai](https://faith.localkin.ai)** | 37 Christian spiritual masters spanning 1,900 years (Irenaeus 130 AD → T. Austin-Sparks 1971), with a multi-master debate arena | Click [Augustine](https://faith.localkin.ai/augustine) → ask *"What is the relationship between grace and free will?"* — every quote you'll see is grep-verifiable in his actual writings. |
| **🌐 [heal.localkin.ai](https://heal.localkin.ai)** | 39 Traditional Chinese Medicine masters spanning 4,500 years (Yellow Emperor → living National Grand Masters), with school debates | Click [Zhang Zhongjing](https://heal.localkin.ai/zhang_zhongjing) → ask *"What's the difference between 桂枝汤 and 麻黄汤?"* — answers grounded in 18 versions of *Shanghan Lun*. |

**Both subdomains use Knowledge Search (this repo) as their retrieval layer.** The `examples/` corpus you can `grep` locally is a public-domain subset of what those agents query against. The architecture, code, and zero-hallucination contract documented in the paper are exactly what serves those URLs.

If anything below seems too good to be true, **click those links and break it yourself** — that's why they're live.

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

# Search the example corpus
./search.sh --keywords "humility"      --collection thomas_a_kempis
./search.sh --keywords "气虚,黄芪"      --collection sun_simiao
./search.sh --keywords "supreme law"   --collection uscis
```

That's it. No pip install, no docker, no database, no API keys.

## Three things you can run in this repo, no setup

| Script | Purpose | Time |
|---|---|---|
| `./search.sh -k "<query>"` | Layer 1 + Layer 2 grep against `examples/` | <100 ms |
| `./reproduce_zero_hallucination.sh` | Replay the paper's §6.5 case: 0/5 fabricated quotes → 4/4 grep-verified, with `grep` running LIVE on your machine | 2 sec |
| `./benchmark.sh` | grep vs sentence-transformers + FAISS, head-to-head on 30 queries (latency, recall by query type) | ~1 min first run, ~5 sec subsequent |

The last two scripts exist to make the paper's claims falsifiable. **If you don't trust 100% retrieval accuracy / 0/5 → 4/4 / "grep wins"**, run them yourself; everything is on your machine.

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

## Bundled Examples

The `examples/` directory contains three real, public-domain corpora —
not toy data, real books / real questions / real classical Chinese:

| Domain | Corpus | Size | Source |
|---|---|---|---|
| **Spiritual** | `examples/spiritual/thomas_a_kempis/` — Thomas à Kempis, *Imitation of Christ* (4 books, 114 chapters) | 340 KB | Project Gutenberg #1653 |
| **Civics** | `examples/civics/uscis/` — USCIS 100 official naturalization questions + answers | 16 KB | uscis.gov (public domain, US Government) |
| **TCM** | `examples/tcm/sun_simiao/` — Sun Simiao 千金食治 (Dietetics, ~652 CE), classical Chinese | 52 KB | Public domain (~1,400 years) |

Each comes with a real `_compiled/` Layer 2 directory containing
`<source>_concepts.md` (5-10 core concepts with verbatim quotes
attributed to chapters) and `<source>_faq.md` (5-8 Q&A pairs),
all generated by Kimi 2.6 via local Ollama at $0 cost.

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

## Production Deployment — click and verify

This approach powers [LocalKin](https://localkin.dev), a self-hallucination-free, self-improving multi-agent system on a **single Mac mini**. As of April 2026 it serves as the knowledge backbone for **76 specialized LLM agents** spanning two languages and four-and-a-half millennia of human thought:

### 🌐 [heal.localkin.ai](https://heal.localkin.ai) — 39 TCM masters
Sample agents (each link goes to a real chat page, free, no signup):

| Master | Era | Try asking |
|---|---|---|
| [黄帝 / Yellow Emperor](https://heal.localkin.ai/huang_di) | ~2500 BCE | 五行学说的根源是什么？ |
| [张仲景 / Zhang Zhongjing](https://heal.localkin.ai/zhang_zhongjing) | 150-219 AD | 桂枝汤与麻黄汤如何辨证？ |
| [李时珍 / Li Shizhen](https://heal.localkin.ai/li_shizhen) | 1518-1593 | 黄芪和人参的药性区别 |
| [倪海厦 / Ni Haixia](https://heal.localkin.ai/ni_haixia) | 1954-2012 | 经方派与温病派的本质分歧 |

### 🌐 [faith.localkin.ai](https://faith.localkin.ai) — 37 Christian spiritual masters

| Master | Era | Try asking |
|---|---|---|
| [Irenaeus](https://faith.localkin.ai/irenaeus) | 130-202 AD | What is your view of apostolic tradition? |
| [Augustine](https://faith.localkin.ai/augustine) | 354-430 AD | What is the relationship between grace and free will? |
| [Madame Guyon](https://faith.localkin.ai/guyon) | 1648-1717 | What does inner prayer look like in daily life? |
| [T. Austin-Sparks](https://faith.localkin.ai/austin_sparks) | 1885-1971 | 您与倪柝声在 Honor Oak 都讨论了什么？ |

**~500 source texts, 76 agents, 180 MB corpus** — all retrieved by `grep`.

The `_compiled/` Layer 2 files grow nightly via a cron-driven autonomous pipeline (see paper §9) at **$0/year** in API costs, after migrating the compilation LLM from paid Anthropic Haiku to local-Ollama-served Kimi 2.6 in April 2026.

### Why this matters for skeptics

The strongest evidence that "grep is all you need" is not in this repo's `search.sh` (30 lines look trivial) or even in the paper's tables. It is in those URLs above. **Click any one, ask any question, then ask the agent for its source.** Every quote you receive is a literal substring of an actual public-domain text in our corpus — verifiable on your end with the same `grep` command this repo ships.

## Reproducibility

The paper documents a one-day failure-and-recovery cycle (§6.5) that you can replay locally — `grep` runs live on your machine against the included Austin-Sparks corpus:

```bash
./reproduce_zero_hallucination.sh
```

What it does:
- **Phase 1**: replays a real agent response from 2026-04-25 (5 fabricated quotes attributed to specific chapters), then runs LIVE `grep` against `reproduction/corpus/` → **0/5 found**.
- **Phase 2**: shows the actual one-line fix (auto-strip `**"..."**` markers + append citation hard-rule).
- **Phase 3**: replays the post-fix agent response (4 quotes attributed), runs LIVE `grep` → **4/4 found**.

The script does **not** call an LLM at runtime — it replays captured responses then verifies them with `grep` so the experiment is bit-for-bit reproducible without any API key. To reproduce with a live LLM, see paper §6.5 or commit `3e365a9` in [LocalKinAI/localkin-core](https://github.com/LocalKinAI).

## Benchmark

```bash
./benchmark.sh
```

Compares grep vs Vector RAG (sentence-transformers `all-MiniLM-L6-v2` + FAISS `IndexFlatIP`) on 30 hand-graded queries spanning the three example corpora. First run sets up a venv (~2 minutes); subsequent runs take seconds. Output is a `benchmark_results.md` Markdown report with:

- Median + P99 latency
- Recall@5 per query type (exact / concept / fuzzy)
- Honest tradeoff analysis — **grep wins exact-keyword + tail-latency; vector wins fuzzy/paraphrase**. The paper does not deny this (§7.2).
- Index build time (vector pays N seconds upfront, grep pays 0).

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
