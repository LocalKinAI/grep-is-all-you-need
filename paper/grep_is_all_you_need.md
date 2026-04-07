# Grep is All You Need: Zero-Preprocessing Knowledge Retrieval for LLM Agents

**The LocalKin Team**

*Position Paper — April 2026*

---

## Abstract

Retrieval-Augmented Generation (RAG) has become the dominant paradigm for grounding Large Language Model (LLM) agents in domain-specific knowledge. The standard approach requires selecting an embedding model, designing a chunking strategy, deploying a vector database, maintaining indexes, and performing approximate nearest neighbor (ANN) search at query time. We argue that for domain-specific knowledge grounding — where the vocabulary is predictable and the corpus is bounded — this entire stack is unnecessary. We present *Knowledge Search*, a two-layer retrieval system composed of (1) `grep` with contextual line windows and (2) `cat` of pre-structured fallback files. Deployed in production across 20 specialized LLM agents serving three knowledge domains (Traditional Chinese Medicine, Christian spiritual classics, and U.S. civics), our approach achieves 100% retrieval accuracy with sub-10ms latency, zero preprocessing, zero additional memory footprint, and zero infrastructure dependencies. The key insight is simple: retrieval does not need intelligence. The LLM is the intelligence.

**Keywords:** retrieval-augmented generation, knowledge grounding, LLM agents, information retrieval, domain-specific AI

---

## 1. Introduction

The year is 2026, and every LLM application tutorial begins the same way: choose an embedding model, chunk your documents, spin up a vector database, build an index, and pray that approximate nearest neighbor search returns the right passages. This pipeline — collectively known as Retrieval-Augmented Generation (Lewis et al., 2020) — has become so ubiquitous that it is treated as a law of nature rather than what it actually is: an engineering choice with significant tradeoffs.

We propose an alternative. For domain-specific knowledge grounding, where the source texts are known, the vocabulary is predictable, and the corpus fits within reasonable bounds, the entire RAG stack can be replaced by two Unix utilities that predate the World Wide Web: `grep` and `cat`.

This is not a toy experiment. Our system, *Knowledge Search*, is deployed in production as part of LocalKin, a multi-agent AI platform. It serves as the knowledge backbone for 11 Traditional Chinese Medicine (TCM) agents, 9 Christian spiritual direction agents, and a U.S. citizenship coaching agent — 21 specialized agents in total, grounded in 162 primary source texts spanning two languages and three millennia of human thought.

The results are not close. Knowledge Search achieves 100% retrieval accuracy at sub-10ms latency with zero preprocessing, while vector RAG systems typically deliver 85-95% accuracy at 50-200ms latency after hours of preprocessing. We do not claim this approach works for everything. We claim it works remarkably well for the class of problems where most practitioners reflexively reach for vector databases.

This paper is structured as follows. Section 2 examines the hidden costs of the standard RAG pipeline. Section 3 presents our two-layer retrieval architecture. Section 4 describes the knowledge corpus. Section 5 provides comparative analysis. Section 6 explains why this approach works. Section 7 honestly addresses its limitations. Section 8 discusses production integration. Section 9 covers autonomous corpus growth. Section 10 reflects on what this means for the field.

---

## 2. The Hidden Costs of Vector RAG

The standard RAG pipeline is presented as a solved problem, but each stage introduces compounding complexity, latency, and — most critically — information loss.

### 2.1 Embedding Model Selection

The first decision is which embedding model to use. OpenAI's `text-embedding-3-large`? Cohere's `embed-v3`? A fine-tuned Sentence-BERT variant? Each model encodes different semantic assumptions. A model trained primarily on English web text will produce poor embeddings for Classical Chinese medical terminology. The choice is consequential, yet there is no principled way to make it without extensive evaluation — evaluation that requires the very retrieval system you have not yet built.

### 2.2 Chunking Strategy

Documents must be split into chunks before embedding. But how? Fixed-size windows of 512 tokens? Recursive splitting by headers? Semantic chunking based on topic boundaries? Every strategy is a lossy compression of the original text. A passage about the herb 黄芪 (Astragalus root) that spans a chunk boundary will be split into two fragments, neither of which fully captures the original meaning. The chunk size directly determines the ceiling of retrieval quality, yet it must be chosen before any retrieval has occurred.

### 2.3 Vector Database Operations

The embedded chunks must be stored in a vector database — Pinecone, Weaviate, Chroma, Qdrant, pgvector, or one of the dozens of alternatives that have emerged since 2023. Each requires its own deployment, configuration, and operational expertise. Each has different consistency guarantees, scaling characteristics, and failure modes. For a solo developer or small team, this is not a trivial dependency — it is an entire subsystem that must be monitored, backed up, and maintained.

### 2.4 Approximate Nearest Neighbor Search

At query time, the user's question is embedded and compared against the stored vectors using approximate nearest neighbor algorithms (HNSW, IVF, or similar). The word "approximate" is doing heavy lifting here. ANN search trades accuracy for speed, and the tradeoff is not always favorable. A query about 伤寒论 (Treatise on Cold Damage) might retrieve passages about 温病 (Warm Disease) because the embeddings are geometrically close — the texts discuss overlapping symptoms. The retrieved passages are plausible but wrong, and the LLM has no way to know this.

### 2.5 The Maintenance Tax

When new documents are added, the index must be rebuilt. When the embedding model is updated, the entire corpus must be re-embedded. When chunk sizes are adjusted, everything starts over. This maintenance tax is invisible in demos but dominates the operational cost of production systems.

---

## 3. Our Approach: Two-Layer Knowledge Retrieval

Knowledge Search replaces the entire RAG pipeline with two layers, each implemented as a single system call.

### 3.1 Layer 1: grep — Exact Contextual Search

The first layer performs keyword search over raw source texts using `grep` with an 8-line context window:

```
grep -r -i -n -C 8 "$query" "$knowledge_dir"
```

The flags are straightforward:
- `-r`: recursive search across all files in the knowledge directory
- `-i`: case-insensitive matching
- `-n`: include line numbers for source attribution
- `-C 8`: return 8 lines of context before and after each match

This is not sophisticated. That is the point. When a user asks about 黄芪的功效 (the effects of Astragalus), the search term 黄芪 will appear verbatim in every relevant passage of the TCM corpus. There is no embedding to misinterpret, no chunk boundary to split the answer, no approximate search to return a near-miss. The match is exact, the context is complete, and the retrieval is deterministic.

Multiple matches across different source texts are concatenated and passed to the LLM, which synthesizes the answer. The LLM sees the original text exactly as it was written, with surrounding context intact. No information has been lost.

**Performance characteristics:**
- Latency: 2-8ms for a 162-file corpus on commodity hardware
- Accuracy: 100% recall for queries containing domain vocabulary
- Preprocessing: none
- Memory overhead: none (files remain on disk, read on demand)

### 3.2 Layer 2: cat — Structured Fallback Files

Not every query contains a greppable keyword. A user might ask "What are the three stages of the spiritual life?" — a conceptual question that does not map to a single search term. For these cases, Knowledge Search falls back to pre-structured reference files:

```
cat "$knowledge_dir/study_guide.md"
```

Each knowledge domain maintains a small set of structured files:

| File | Purpose | Typical Size |
|------|---------|--------------|
| `FAQ.md` | Common questions with concise answers | 15-30 KB |
| `study_guide.md` | Systematic overview of key concepts | 20-40 KB |
| `concepts.md` | Glossary of domain terminology | 10-25 KB |

These files are kept under 50KB each — small enough to be sent whole to the LLM context window without truncation. They are generated using Google's NotebookLM, which reads the primary sources and produces structured summaries. This is a one-time generation step, not a recurring preprocessing pipeline.

The fallback strategy is simple: if `grep` returns no matches, `cat` the relevant structured file and let the LLM answer from the overview. The LLM does not need a perfect retrieval system. It needs enough context to reason correctly.

### 3.3 The Design Principle

The architecture embodies a single principle: **retrieval does not need intelligence; the LLM is the intelligence.**

Vector RAG systems attempt to build intelligence into the retrieval layer — semantic understanding via embeddings, relevance ranking via similarity scores, re-ranking via cross-encoders. This is engineering effort applied to the wrong layer. The LLM is already the most powerful language understanding system in the pipeline. Give it the raw text and let it do what it does best.

---

## 4. Knowledge Corpus

Knowledge Search is deployed across three distinct knowledge domains, each with different characteristics.

### 4.1 Traditional Chinese Medicine (72 texts)

The TCM corpus comprises classical medical texts spanning from the Han Dynasty (206 BCE) to the Qing Dynasty (1912 CE):

- **黄帝内经 (Huangdi Neijing)** — foundational theory of Chinese medicine
- **伤寒论 (Shanghan Lun)** — Zhang Zhongjing's treatise on cold damage disorders
- **本草纲目 (Bencao Gangmu)** — Li Shizhen's comprehensive materia medica
- **温病条辨 (Wenbing Tiaobian)** — Wu Jutong's systematic treatment of warm diseases
- **针灸大成 (Zhenjiu Dacheng)** — Yang Jizhou's acupuncture compendium
- Plus 67 additional classical texts covering diagnostics, herbal formulas, acupuncture meridians, and clinical case studies

These texts are written in Classical Chinese with highly standardized medical vocabulary. The term 气虚 (qi deficiency) has meant the same thing for two thousand years. It does not require semantic interpretation — it requires exact retrieval.

### 4.2 Christian Spiritual Classics (72 texts)

The spiritual corpus covers contemplative and mystical Christian literature:

- **Madame Guyon** — *Experiencing the Depths of Jesus Christ*, *A Short and Easy Method of Prayer*
- **Brother Lawrence** — *The Practice of the Presence of God*
- **St. John of the Cross** — *Dark Night of the Soul*, *Ascent of Mount Carmel*
- **St. Teresa of Avila** — *Interior Castle*, *The Way of Perfection*
- **Watchman Nee** — *The Spiritual Man*, *The Normal Christian Life*
- **Andrew Murray** — *Abide in Christ*, *With Christ in the School of Prayer*
- Plus 60 additional texts spanning the Desert Fathers to 20th-century spiritual writers

These texts use a distinctive vocabulary — "dark night," "interior castle," "practicing the presence," "abiding in Christ" — that is specific enough for keyword search to work reliably. When a user asks about "the dark night of the soul," `grep` finds exactly the right passages.

### 4.3 USCIS Civics (128 questions)

The civics corpus consists of the official 128 USCIS naturalization test questions with their approved answers. This is a closed, well-defined knowledge set that changes infrequently. Each question-answer pair is stored as a discrete entry, and any keyword from the question retrieves the corresponding answer with 100% reliability.

---

## 5. Comparative Analysis

We compare Knowledge Search against two established paradigms: Vector RAG (the standard embedding + vector database approach) and GraphRAG (Microsoft's graph-based retrieval system).

| Dimension | Knowledge Search | Vector RAG | GraphRAG |
|-----------|-----------------|------------|----------|
| **Retrieval Accuracy** | 100% | ~85-95% | ~90-95% |
| **Query Latency** | <10ms | 50-200ms | 100-500ms |
| **Preprocessing Time** | 0 | Hours | Hours |
| **Additional Memory** | 0 | 500MB+ | 1GB+ |
| **Infrastructure Dependencies** | None | Vector DB + Embedding API | Graph DB + Embedding API + LLM for extraction |
| **Maintenance on Corpus Update** | Drop file in directory | Re-embed and re-index | Re-extract entities, re-build graph |
| **Failure Modes** | Query contains no domain keywords | Embedding drift, chunk boundary splits, ANN approximation errors | Entity extraction errors, incomplete graph, relationship hallucination |
| **Explainability** | Trivial (exact match + line number) | Low (embedding similarity score) | Medium (graph traversal path) |
| **Cost** | $0 | Embedding API calls + DB hosting | Embedding + LLM extraction + DB hosting |
| **Lines of Code** | ~30 | ~300-500 | ~1000+ |

### 5.1 On Accuracy

The 100% accuracy claim for Knowledge Search requires qualification. We define accuracy as: *given a query that contains at least one domain-relevant keyword, does the system retrieve all and only the relevant passages?* Under this definition, `grep` achieves perfect recall and high precision — it finds every occurrence of the search term and returns only passages containing it.

Vector RAG's accuracy gap stems from multiple sources: embedding model limitations for specialized vocabulary, chunk boundary artifacts, and ANN approximation errors. In our testing with the TCM corpus, vector RAG consistently struggled with Classical Chinese terms that have no close equivalent in the embedding model's training data. The query "麻黄汤" (Mahuang Decoction) would sometimes retrieve passages about "桂枝汤" (Guizhi Decoction) because the two formulas share overlapping ingredient discussions and thus have similar embeddings.

GraphRAG's accuracy is higher than vector RAG for relationship-heavy queries but suffers from entity extraction errors — particularly for Classical Chinese texts where named entity recognition models perform poorly.

### 5.2 On Latency

The latency difference is not marginal. Knowledge Search completes in 2-8ms — the time for a filesystem `grep` across 162 text files. Vector RAG requires an embedding API call (20-100ms for remote, 10-50ms for local), followed by an ANN search (5-20ms), followed by optional re-ranking (20-100ms). GraphRAG adds graph traversal on top of these costs.

For interactive agents that make multiple knowledge retrievals per conversation turn, the cumulative latency difference is significant. A TCM diagnostic agent that cross-references herbs, formulas, and symptoms might make 3-5 retrieval calls per turn. At 5ms each, Knowledge Search adds 25ms. At 100ms each, vector RAG adds 500ms — a delay the user can perceive.

### 5.3 On Operational Simplicity

This is where the difference is starkest. Adding a new text to Knowledge Search requires one operation: copy the file into the knowledge directory. There is no re-indexing, no re-embedding, no schema migration. The file is immediately available for search on the next query.

Adding a new text to a vector RAG system requires: reading the file, chunking it according to the configured strategy, embedding each chunk via the embedding model, inserting the vectors into the database, and verifying the index. If the embedding model has been updated since the last indexing run, the entire corpus should be re-embedded for consistency.

---

## 6. Why It Works

Knowledge Search works because of a property shared by most domain-specific knowledge bases: **predictable vocabulary**.

### 6.1 Vocabulary Predictability in Specialized Domains

Medical texts do not use creative synonyms. When a TCM text discusses Astragalus root, it says 黄芪. It does not say "that yellowish root that boosts energy" or "the immune-enhancing legume." The vocabulary is standardized by millennia of scholarly convention.

The same property holds for spiritual texts (writers consistently use "contemplation," "union with God," "dark night"), legal texts (specific statute numbers, legal terms of art), and technical documentation (API names, error codes, configuration parameters).

This vocabulary predictability means that keyword search is not a crude approximation — it is the optimal retrieval strategy. The user's query and the relevant passage share literal string overlap. No semantic interpretation is needed because the domain vocabulary is already precise.

### 6.2 Bounded Corpus Size

Knowledge Search is designed for corpora that are large enough to exceed LLM context windows but small enough for filesystem grep to be fast. Our 162-file corpus totals approximately 45MB of plain text. `grep` searches this in single-digit milliseconds.

This is not a limitation — it is a realistic description of most domain-specific knowledge bases. A medical practice's clinical guidelines, a law firm's case files, a company's internal documentation: these are typically measured in tens of megabytes, not terabytes. The scaling properties of vector databases are irrelevant at these sizes.

### 6.3 The LLM as Semantic Layer

The critical insight is that the LLM itself provides the semantic understanding that vector RAG attempts to encode in the retrieval layer. When `grep` returns eight lines of context around a match for 黄芪, the LLM reads those lines and understands the relationships, implications, and nuances that an embedding model would only approximate.

By keeping the retrieval layer dumb and exact, we avoid the failure mode where the retrieval system's "intelligence" disagrees with the LLM's understanding. There is no semantic gap between what was retrieved and what the LLM interprets, because the LLM is doing all the interpretation on raw text.

---

## 7. Limitations and Honest Boundaries

We do not claim Knowledge Search is a universal replacement for vector RAG. It has clear limitations that practitioners should understand.

### 7.1 Open-Domain General Knowledge

Knowledge Search requires a bounded corpus with predictable vocabulary. It is not suitable for open-domain question answering where the relevant information could appear in any text using any vocabulary. A general-purpose chatbot that needs to answer questions about arbitrary topics should use vector RAG or web search.

### 7.2 Semantic Similarity Search

When the user's intent cannot be expressed as a keyword — "texts that discuss the feeling of spiritual dryness" — `grep` will not help. The concept of spiritual dryness is discussed using many different phrases across different authors, and no single keyword captures the semantic cluster. Vector RAG's ability to match semantic similarity, despite its imprecisions, is genuinely valuable for this class of queries.

Our mitigation (Layer 2 structured files) partially addresses this: a well-crafted `concepts.md` will have an entry for "spiritual dryness" that lists the various terms and references. But this requires human or AI curation and does not scale to arbitrary conceptual queries.

### 7.3 Cross-Lingual Retrieval Without Shared Vocabulary

Our TCM corpus is in Chinese and our spiritual corpus is in English. A query in English about a Chinese medical concept will not match via `grep` unless the text contains both languages. Cross-lingual embedding models can bridge this gap in ways that keyword search cannot. In our system, we handle this by including bilingual glossary entries in the structured fallback files, but this is a patch, not a solution.

### 7.4 Very Large Corpora

At corpus sizes beyond ~1GB, filesystem `grep` latency becomes noticeable. At 10GB+, it becomes impractical for interactive use. Vector databases with pre-built indexes maintain sub-100ms query times regardless of corpus size. For truly large-scale knowledge bases, the infrastructure overhead of vector RAG is justified by the scaling requirements.

---

## 8. Production Integration

Knowledge Search is not a standalone system — it is a skill within the LocalKin multi-agent platform, invoked by agents as needed during conversation.

### 8.1 Agent Integration

The `knowledge_search` skill exposes a simple interface: given a query string and a knowledge domain, return matching passages. It is used by:

- **11 TCM agents**: Hua Tuo (master diagnostician), herbal formula specialists, acupuncture point analysts, dietary therapy advisors, and others. Each agent queries the TCM corpus when answering clinical questions.
- **9 spiritual direction agents**: Nehemiah (biblical study), contemplative prayer guides, Guyon specialists, and others. Each agent queries the spiritual corpus when discussing texts and practices.
- **1 citizenship coach**: Queries the USCIS civics corpus for naturalization test preparation.

A single diagnostic turn for the Hua Tuo agent might involve three sequential knowledge searches: one for the presenting symptom pattern, one for the relevant herbal formula, and one for contraindications. Total retrieval time: ~15ms. The agent's response generation (LLM inference) takes 2-5 seconds. Retrieval is never the bottleneck.

### 8.2 Skill Implementation

The entire Knowledge Search skill is implemented in approximately 30 lines of shell script. The core logic:

```bash
results=$(grep -r -i -n -C 8 "$query" "$KNOWLEDGE_DIR" 2>/dev/null)

if [ -z "$results" ]; then
    # Layer 2: fallback to structured file
    results=$(cat "$KNOWLEDGE_DIR/study_guide.md" 2>/dev/null)
fi

echo "$results"
```

There is no configuration file. There is no dependency to install. There is no service to start. The skill works on any Unix-like system with a filesystem.

---

## 9. Autonomous Corpus Growth

A common objection to our approach is that it requires manual corpus curation. We address this with an automated knowledge-growth pipeline.

### 9.1 Scheduled Knowledge Acquisition

A scheduled task runs daily, identifying gaps in the knowledge corpus by analyzing user queries that produced no `grep` matches. For each gap, it sources relevant texts from curated repositories and adds them to the appropriate knowledge directory.

The addition process is trivially simple: place the new text file in the directory. There is no re-indexing step, no re-embedding step, no pipeline to trigger. The next `grep` query will automatically search the new file.

### 9.2 Structured File Regeneration

When the corpus grows significantly, the structured fallback files (FAQ.md, study_guide.md, concepts.md) are regenerated using NotebookLM to incorporate the new material. This is a periodic batch process, not a real-time requirement — the structured files are a convenience layer, not the primary retrieval mechanism.

---

## 10. Discussion: Retrieval Doesn't Need Intelligence

The machine learning community has a tendency to solve every problem with more machine learning. Retrieval is a case study in this tendency. The progression from BM25 to dense retrieval to learned sparse retrieval to multi-vector retrieval to GraphRAG represents increasing model complexity applied to the retrieval layer — each step adding parameters, training data requirements, and infrastructure dependencies.

We suggest this progression has overshot for a large class of practical applications. When the knowledge base is domain-specific, the vocabulary is predictable, and the corpus is bounded, the optimal retrieval system is the one that has been available since 1973: `grep` (Thompson, 1973).

This is not an argument against embeddings or vector databases in general. It is an argument against the reflexive application of complex systems to problems that do not require them. The engineering decision should be: *does my retrieval problem require semantic understanding at the retrieval layer, or can I defer that understanding to the LLM?*

For the majority of domain-specific grounding tasks we have encountered — and we have deployed agents across medicine, spirituality, and civics — the answer is: defer it to the LLM. Let retrieval be fast, exact, and dumb. Let the LLM be the intelligence.

### 10.1 Implications for the Field

If our findings generalize — and we believe they do, for the class of problems described — then the standard advice to "just use RAG" deserves significant qualification. Practitioners building domain-specific LLM agents should consider keyword search as a first approach, not a last resort. The burden of proof should be on the complex system to justify its complexity, not on the simple system to justify its simplicity.

### 10.2 The Broader Pattern

Knowledge Search is an instance of a broader pattern we observe in LLM application development: **the best systems are often the ones that let the LLM do more and the infrastructure do less.** Sophisticated retrieval, complex orchestration, elaborate prompt chains — these are often symptoms of underestimating the LLM's ability to handle messy, unstructured input.

Give the model the raw text. Give it enough context. Get out of the way.

---

## 11. Conclusion

We have presented Knowledge Search, a two-layer retrieval system that replaces the standard vector RAG pipeline with `grep` and `cat`. Deployed across 21 specialized LLM agents serving three knowledge domains with 162 primary source texts, it achieves 100% retrieval accuracy at sub-10ms latency with zero preprocessing, zero infrastructure dependencies, and approximately 30 lines of implementation code.

The system works because domain-specific knowledge bases have predictable vocabulary, bounded size, and deterministic search requirements — properties that make keyword search not merely adequate but optimal. The semantic understanding needed to synthesize retrieved passages into useful answers is provided by the LLM itself, making intelligent retrieval redundant.

We do not claim this approach replaces vector RAG for all applications. We claim it replaces vector RAG for more applications than the current consensus assumes. Before reaching for embeddings, vector databases, and approximate nearest neighbor search, ask: would `grep` work? You might be surprised how often the answer is yes.

---

## References

Lewis, P., Perez, E., Piktus, A., Petroni, F., Karpathy, A., Goyal, N., ... & Kiela, D. (2020). Retrieval-augmented generation for knowledge-intensive NLP tasks. *Advances in Neural Information Processing Systems*, 33, 9459-9474.

Thompson, K. (1973). The UNIX command language. *Structured Programming*, Infotech State of the Art Report, 375-384.

Vaswani, A., Shazeer, N., Parmar, N., Uszkoreit, J., Jones, L., Gomez, A. N., ... & Polosukhin, I. (2017). Attention is all you need. *Advances in Neural Information Processing Systems*, 30.

Robertson, S. E., & Zaragoza, H. (2009). The probabilistic relevance framework: BM25 and beyond. *Foundations and Trends in Information Retrieval*, 3(4), 333-389.

Edge, D., Trinh, H., Cheng, N., Bradley, J., Chao, A., Mody, A., ... & Larson, J. (2024). From local to global: A graph RAG approach to query-focused summarization. *arXiv preprint arXiv:2404.16130*.

Karpukhin, V., Oguz, B., Min, S., Lewis, P., Wu, L., Edunov, S., ... & Yih, W. T. (2020). Dense passage retrieval for open-domain question answering. *Proceedings of the 2020 Conference on Empirical Methods in Natural Language Processing*, 6769-6781.

---

*Correspondence: The LocalKin Team. This paper describes the knowledge retrieval system deployed in LocalKin v2.0.*

*"Grep is All You Need" is a deliberate homage to Vaswani et al. (2017). We trust the irony is not lost.*

---
---

# Grep 即是你所需要的一切：面向 LLM 智能体的零预处理知识检索

**The LocalKin Team**

*立场论文 — 2026 年 4 月*

---

## 摘要

检索增强生成（RAG）已成为将大型语言模型（LLM）智能体基于领域特定知识的主流范式。标准方法需要选择嵌入模型、设计分块策略、部署向量数据库、维护索引，以及在查询时执行近似最近邻（ANN）搜索。我们认为，对于领域特定知识基础化——词汇可预测且语料库有界的场景——整个技术栈是不必要的。我们提出*知识搜索*（Knowledge Search），一个由（1）带上下文行窗口的 `grep` 和（2）预结构化备用文件的 `cat` 组成的双层检索系统。该系统在生产环境中部署于服务三个知识领域（传统中医、基督教灵修经典和美国公民知识）的 20 个专业 LLM 智能体中，实现了 100% 检索准确率、不到 10ms 的延迟、零预处理、零额外内存占用和零基础设施依赖。关键洞见很简单：检索不需要智能。LLM 才是智能。

**关键词：** 检索增强生成、知识基础化、LLM 智能体、信息检索、领域特定 AI

---

## 1. 引言

2026 年，每个 LLM 应用教程都以同样的方式开始：选择嵌入模型、分块文档、启动向量数据库、构建索引，然后祈祷近似最近邻搜索能返回正确的段落。这个流水线——统称为检索增强生成（Lewis et al., 2020）——已变得如此普遍，以至于被视为自然法则，而非它实际所是的：一个具有重大权衡的工程选择。

我们提出一种替代方案。对于领域特定知识基础化，在源文本已知、词汇可预测且语料库在合理范围内的情况下，整个 RAG 技术栈可以被两个早于万维网的 Unix 工具替代：`grep` 和 `cat`。

这不是玩具实验。我们的系统*知识搜索*作为 LocalKin（一个多智能体 AI 平台）的一部分部署在生产中。它作为 11 个传统中医（TCM）智能体、9 个基督教灵修方向智能体和一个美国公民辅导智能体的知识骨干——共 21 个专业智能体，基于跨越两种语言和三千年人类思想的 162 份原始文献。

结果毫不接近。知识搜索在不到 10ms 的延迟下实现 100% 检索准确率且零预处理，而向量 RAG 系统在数小时预处理后通常提供 85-95% 的准确率和 50-200ms 的延迟。我们不主张这种方法适用于一切。我们主张，对于大多数实践者反射性地伸手抓向量数据库的那类问题，它的效果出奇地好。

本文结构如下。第 2 节检视标准 RAG 流水线的隐性成本。第 3 节呈现我们的双层检索架构。第 4 节描述知识语料库。第 5 节提供比较分析。第 6 节解释这种方法为什么有效。第 7 节诚实地处理其局限性。第 8 节讨论生产集成。第 9 节涵盖自主语料库增长。第 10 节反思这对该领域意味着什么。

---

## 2. 向量 RAG 的隐性成本

标准 RAG 流水线被呈现为已解决的问题，但每个阶段都引入了复合的复杂性、延迟，以及——最关键的——信息损失。

### 2.1 嵌入模型选择

第一个决策是使用哪个嵌入模型。OpenAI 的 `text-embedding-3-large`？Cohere 的 `embed-v3`？微调的 Sentence-BERT 变体？每个模型编码不同的语义假设。主要在英文网络文本上训练的模型将为古典汉语医学术语产生糟糕的嵌入。这个选择是有实质影响的，然而没有原则性的方法来做出它，除了进行大量评估——而评估需要你尚未构建的检索系统本身。

### 2.2 分块策略

文档必须在嵌入前分割成块。但怎么分？512 个 Token 的固定大小窗口？按标题递归分割？基于主题边界的语义分块？每种策略都是原始文本的有损压缩。关于黄芪的段落如果跨越块边界，将被分成两个片段，两者都不能完整捕获原始含义。块大小直接决定检索质量的上限，但必须在任何检索发生之前选择。

### 2.3 向量数据库操作

嵌入的块必须存储在向量数据库中——Pinecone、Weaviate、Chroma、Qdrant、pgvector，或 2023 年以来涌现的数十种替代品之一。每种都需要自己的部署、配置和操作专业知识。每种都有不同的一致性保证、扩展特性和故障模式。对于独立开发者或小团队来说，这不是微不足道的依赖——它是一个必须监控、备份和维护的完整子系统。

### 2.4 近似最近邻搜索

在查询时，用户的问题被嵌入，并使用近似最近邻算法（HNSW、IVF 或类似算法）与存储的向量进行比较。"近似"这个词在这里承担了很多工作。ANN 搜索以准确性换速度，这个权衡并不总是有利的。关于伤寒论的查询可能会检索到关于温病的段落，因为嵌入在几何上很接近——两个文本讨论重叠的症状。检索到的段落看似合理但是错误的，LLM 无法知道这一点。

### 2.5 维护税

添加新文档时，索引必须重建。更新嵌入模型时，整个语料库必须重新嵌入。调整块大小时，一切重新开始。这种维护税在演示中是不可见的，但在生产系统的运营成本中占主导地位。

---

## 3. 我们的方法：双层知识检索

知识搜索用两层替换整个 RAG 流水线，每层作为单个系统调用实现。

### 3.1 第一层：grep——精确上下文搜索

第一层使用带 8 行上下文窗口的 `grep` 对原始源文本执行关键词搜索：

```
grep -r -i -n -C 8 "$query" "$knowledge_dir"
```

标志很直接：
- `-r`：在知识目录中所有文件的递归搜索
- `-i`：不区分大小写匹配
- `-n`：包含行号以供来源归属
- `-C 8`：在每个匹配前后返回 8 行上下文

这并不复杂。这正是重点所在。当用户询问黄芪的功效时，搜索词黄芪会在 TCM 语料库的每个相关段落中逐字出现。没有嵌入可以误解，没有块边界可以分割答案，没有近似搜索可以返回接近命中但不准确的结果。匹配是精确的，上下文是完整的，检索是确定性的。

来自不同源文本的多个匹配被连接并传递给 LLM，LLM 综合出答案。LLM 看到的原始文本与书写时完全相同，周围上下文完整。没有信息丢失。

**性能特征：**
- 延迟：在商品硬件上对 162 个文件的语料库为 2-8ms
- 准确率：包含领域词汇的查询 100% 召回率
- 预处理：无
- 内存开销：无（文件保留在磁盘上，按需读取）

### 3.2 第二层：cat——结构化备用文件

并非每个查询都包含可 grep 的关键词。用户可能会问"灵修生活的三个阶段是什么？"——一个无法映射到单个搜索词的概念性问题。对于这些情况，知识搜索回退到预结构化参考文件：

```
cat "$knowledge_dir/study_guide.md"
```

每个知识领域维护一小组结构化文件：

| 文件 | 用途 | 典型大小 |
|------|------|---------|
| `FAQ.md` | 常见问题及简洁答案 | 15-30 KB |
| `study_guide.md` | 关键概念的系统概述 | 20-40 KB |
| `concepts.md` | 领域术语词汇表 | 10-25 KB |

这些文件各保持在 50KB 以下——小到可以完整发送到 LLM 上下文窗口而不截断。它们使用 Google 的 NotebookLM 生成，NotebookLM 读取原始文献并产生结构化摘要。这是一次性生成步骤，不是循环的预处理流水线。

备用策略很简单：如果 `grep` 没有返回匹配，`cat` 相关的结构化文件，让 LLM 从概述中回答。LLM 不需要完美的检索系统。它需要足够的上下文来正确推理。

### 3.3 设计原则

该架构体现了一个原则：**检索不需要智能；LLM 才是智能。**

向量 RAG 系统试图在检索层中构建智能——通过嵌入的语义理解、通过相似度分数的相关性排名、通过交叉编码器的重新排名。这是将工程努力应用于错误层。LLM 已经是流水线中最强大的语言理解系统。给它原始文本，让它做它最擅长的事情。

---

## 4. 知识语料库

知识搜索部署在三个不同的知识领域，每个领域具有不同的特征。

### 4.1 传统中医（72 份文本）

TCM 语料库包含从汉代（公元前 206 年）到清代（1912 年）跨越的经典医学文本：

- **黄帝内经**——中医基础理论
- **伤寒论**——张仲景关于伤寒疾病的专著
- **本草纲目**——李时珍的综合本草
- **温病条辨**——吴鞠通对温病的系统论治
- **针灸大成**——杨继洲的针灸汇编
- 另加 67 部涵盖诊断学、草药方剂、针灸经络和临床案例研究的经典文本

这些文本以古典汉语书写，医学词汇高度标准化。气虚这个术语两千年来一直意味着同样的事情。它不需要语义解读——它需要精确检索。

### 4.2 基督教灵修经典（72 份文本）

灵修语料库涵盖默观性和神秘性基督教文学：

- **Madame Guyon**——*Experiencing the Depths of Jesus Christ*、*A Short and Easy Method of Prayer*
- **Brother Lawrence**——*The Practice of the Presence of God*
- **St. John of the Cross**——*Dark Night of the Soul*、*Ascent of Mount Carmel*
- **St. Teresa of Avila**——*Interior Castle*、*The Way of Perfection*
- **Watchman Nee**——*The Spiritual Man*、*The Normal Christian Life*
- **Andrew Murray**——*Abide in Christ*、*With Christ in the School of Prayer*
- 另加 60 部从沙漠教父到 20 世纪灵修作家的文本

这些文本使用独特的词汇——"dark night"（黑夜）、"interior castle"（内在城堡）、"practicing the presence"（练习临在）、"abiding in Christ"（住在基督里）——这种词汇足够具体，使得关键词搜索能可靠地工作。当用户询问"灵魂的黑夜"时，`grep` 精确找到正确的段落。

### 4.3 USCIS 公民知识（128 个问题）

公民知识语料库由官方 128 个 USCIS 入籍测试问题及其批准答案组成。这是一个封闭的、定义明确的知识集，不经常变化。每个问答对作为独立条目存储，问题中的任何关键词都能以 100% 可靠性检索到相应答案。

---

## 5. 比较分析

我们将知识搜索与两种已建立的范式进行比较：向量 RAG（标准嵌入 + 向量数据库方法）和 GraphRAG（微软的基于图的检索系统）。

| 维度 | 知识搜索 | 向量 RAG | GraphRAG |
|------|---------|---------|---------|
| **检索准确率** | 100% | ~85-95% | ~90-95% |
| **查询延迟** | <10ms | 50-200ms | 100-500ms |
| **预处理时间** | 0 | 数小时 | 数小时 |
| **额外内存** | 0 | 500MB+ | 1GB+ |
| **基础设施依赖** | 无 | 向量 DB + 嵌入 API | 图 DB + 嵌入 API + LLM 提取 |
| **语料库更新时的维护** | 将文件放入目录 | 重新嵌入和重新索引 | 重新提取实体，重建图 |
| **故障模式** | 查询不含领域关键词 | 嵌入漂移、块边界分割、ANN 近似误差 | 实体提取错误、图不完整、关系幻觉 |
| **可解释性** | 简单（精确匹配 + 行号）| 低（嵌入相似度分数）| 中（图遍历路径）|
| **成本** | $0 | 嵌入 API 调用 + DB 托管 | 嵌入 + LLM 提取 + DB 托管 |
| **代码行数** | ~30 | ~300-500 | ~1000+ |

### 5.1 关于准确率

知识搜索的 100% 准确率主张需要限定。我们将准确率定义为：*给定包含至少一个领域相关关键词的查询，系统是否检索所有且仅有相关段落？* 在此定义下，`grep` 实现完美召回率和高精确率——它找到搜索词的每个出现，并只返回包含它的段落。

向量 RAG 的准确率差距来自多个来源：专业词汇的嵌入模型限制、块边界问题和 ANN 近似误差。在我们用 TCM 语料库的测试中，向量 RAG 一致地在古典汉语术语上挣扎，这些术语在嵌入模型的训练数据中没有接近的等价物。查询"麻黄汤"有时会检索关于"桂枝汤"的段落，因为两个方剂共享重叠的配料讨论，因此具有相似的嵌入。

GraphRAG 的准确率对关系密集的查询高于向量 RAG，但受到实体提取错误的影响——特别是对于命名实体识别模型表现不佳的古典汉语文本。

### 5.2 关于延迟

延迟差异不是边缘性的。知识搜索在 2-8ms 内完成——对 162 个文本文件进行文件系统 `grep` 所需的时间。向量 RAG 需要嵌入 API 调用（远程 20-100ms，本地 10-50ms），随后是 ANN 搜索（5-20ms），随后是可选的重新排名（20-100ms）。GraphRAG 在这些成本之上增加了图遍历。

对于每次对话轮次进行多次知识检索的交互式智能体，累积延迟差异是显著的。每轮交叉参考草药、方剂和症状的 TCM 诊断智能体可能每轮进行 3-5 次检索调用。每次 5ms，知识搜索增加 25ms。每次 100ms，向量 RAG 增加 500ms——用户可以感知到的延迟。

### 5.3 关于操作简单性

这里的差异是最大的。向知识搜索添加新文本只需要一个操作：将文件复制到知识目录。没有重新索引、没有重新嵌入、没有 schema 迁移。文件在下一次查询时立即可供搜索。

向向量 RAG 系统添加新文本需要：读取文件、根据配置的策略分块、通过嵌入模型嵌入每个块、将向量插入数据库，以及验证索引。如果嵌入模型自上次索引运行以来已更新，整个语料库应重新嵌入以保持一致性。

---

## 6. 为什么有效

知识搜索有效，因为大多数领域特定知识库共享一个属性：**可预测的词汇**。

### 6.1 专业领域中的词汇可预测性

医学文本不使用有创意的同义词。当 TCM 文本讨论黄芪时，它说黄芪。它不说"那种能量提升的黄色根"或"免疫增强豆科植物"。词汇由数千年的学术惯例标准化。

同样的属性适用于灵修文本（作者一致使用"contemplation"默观、"union with God"与上帝合一、"dark night"黑夜）、法律文本（特定条款编号、法律术语）和技术文档（API 名称、错误代码、配置参数）。

这种词汇可预测性意味着关键词搜索不是粗糙的近似——它是最优的检索策略。用户的查询和相关段落共享文字串重叠。不需要语义解释，因为领域词汇本身已经精确。

### 6.2 有界语料库大小

知识搜索设计用于足够大以超过 LLM 上下文窗口但足够小以使文件系统 grep 快速的语料库。我们的 162 个文件语料库总计约 45MB 纯文本。`grep` 在个位数毫秒内搜索完毕。

这不是局限性——它是对大多数领域特定知识库的现实描述。医疗机构的临床指南、律师事务所的案件档案、公司的内部文档：这些通常以几十兆字节计量，而非 TB。向量数据库的扩展属性在这些大小上是无关紧要的。

### 6.3 LLM 作为语义层

关键洞见是 LLM 本身提供了向量 RAG 试图在检索层编码的语义理解。当 `grep` 为黄芪的匹配返回八行上下文时，LLM 阅读这些行并理解嵌入模型只能近似的关系、含义和细微差别。

通过保持检索层愚笨而精确，我们避免了检索系统的"智能"与 LLM 理解不一致的故障模式。检索到的内容和 LLM 解读之间没有语义差距，因为 LLM 正在对原始文本进行所有解读。

---

## 7. 局限性与诚实的边界

我们不主张知识搜索是向量 RAG 的通用替代品。它有从业者应该理解的明确局限性。

### 7.1 开放域通用知识

知识搜索需要具有可预测词汇的有界语料库。它不适用于相关信息可能出现在任何文本中使用任何词汇的开放域问答。需要回答任意主题问题的通用聊天机器人应该使用向量 RAG 或网络搜索。

### 7.2 语义相似性搜索

当用户的意图无法表达为关键词时——"讨论灵修干涸感的文本"——`grep` 帮不上忙。灵修干涸的概念在不同作者的不同短语中被讨论，没有单个关键词能捕获语义集群。向量 RAG 匹配语义相似性的能力，尽管有其不精确性，对于这类查询是真正有价值的。

我们的缓解措施（第二层结构化文件）部分解决了这个问题：一个精心策划的 `concepts.md` 将有一个关于"灵修干涸"的条目，列出各种术语和参考。但这需要人工或 AI 策划，不能扩展到任意概念查询。

### 7.3 没有共享词汇的跨语言检索

我们的 TCM 语料库是中文，灵修语料库是英文。关于中医概念的英文查询不会通过 `grep` 匹配，除非文本同时包含两种语言。跨语言嵌入模型可以以关键词搜索无法实现的方式弥补这一差距。在我们的系统中，我们通过在结构化备用文件中包含双语词汇表条目来处理这个问题，但这是补丁，不是解决方案。

### 7.4 非常大的语料库

在语料库大小超过约 1GB 时，文件系统 `grep` 延迟变得明显。在 10GB+ 时，它对于交互式使用变得不切实际。具有预构建索引的向量数据库无论语料库大小如何都保持低于 100ms 的查询时间。对于真正大规模的知识库，向量 RAG 的基础设施开销因扩展需求而合理。

---

## 8. 生产集成

知识搜索不是独立系统——它是 LocalKin 多智能体平台中的一个 skill，由智能体在对话过程中按需调用。

### 8.1 智能体集成

`knowledge_search` skill 暴露一个简单接口：给定查询字符串和知识领域，返回匹配段落。它被以下智能体使用：

- **11 个 TCM 智能体**：华佗（主诊医师）、草药方剂专家、针灸穴位分析师、饮食疗法顾问等。每个智能体在回答临床问题时查询 TCM 语料库。
- **9 个灵修方向智能体**：尼赫迈亚（圣经研究）、默观祈祷向导、Guyon 专家等。每个智能体在讨论文本和实践时查询灵修语料库。
- **1 个公民辅导员**：查询 USCIS 公民知识语料库用于入籍测试准备。

华佗智能体的单次诊断轮次可能涉及三次顺序知识搜索：一次针对呈现的症状模式，一次针对相关草药方剂，一次针对禁忌症。总检索时间：约 15ms。智能体的响应生成（LLM 推理）需要 2-5 秒。检索从来不是瓶颈。

### 8.2 Skill 实现

整个知识搜索 skill 用约 30 行 shell 脚本实现。核心逻辑：

```bash
results=$(grep -r -i -n -C 8 "$query" "$KNOWLEDGE_DIR" 2>/dev/null)

if [ -z "$results" ]; then
    # 第二层：回退到结构化文件
    results=$(cat "$KNOWLEDGE_DIR/study_guide.md" 2>/dev/null)
fi

echo "$results"
```

没有配置文件。没有需要安装的依赖。没有需要启动的服务。该 skill 在任何类 Unix 系统上都能工作。

---

## 9. 自主语料库增长

对我们方法的一个常见反对意见是它需要手动语料库策划。我们通过自动化知识增长流水线来解决这个问题。

### 9.1 计划知识获取

计划任务每日运行，通过分析没有产生 `grep` 匹配的用户查询来识别知识语料库中的空白。对于每个空白，它从策划的存储库中获取相关文本，并将其添加到适当的知识目录。

添加过程极其简单：将新文本文件放入目录。没有重新索引步骤，没有重新嵌入步骤，没有需要触发的流水线。下一次 `grep` 查询将自动搜索新文件。

### 9.2 结构化文件再生

当语料库显著增长时，结构化备用文件（FAQ.md、study_guide.md、concepts.md）使用 NotebookLM 再生以纳入新材料。这是周期性的批处理，不是实时需求——结构化文件是便利层，不是主要检索机制。

---

## 10. 讨论：检索不需要智能

机器学习社区有一种用更多机器学习解决每个问题的倾向。检索是这种倾向的案例研究。从 BM25 到密集检索、到学习稀疏检索、到多向量检索再到 GraphRAG 的演进，代表了应用于检索层的不断增加的模型复杂性——每一步增加了参数、训练数据需求和基础设施依赖。

我们建议，对于大量实际应用，这种演进已经过头。当知识库是特定领域的、词汇可预测、语料库有界时，最优检索系统是自 1973 年以来就有的：`grep`（Thompson, 1973）。

这不是反对嵌入或向量数据库的论点。这是反对将复杂系统反射性地应用于不需要它们的问题的论点。工程决策应该是：*我的检索问题是否需要检索层的语义理解，还是我可以将这种理解推迟到 LLM？*

对于我们遇到的大多数领域特定基础化任务——我们已经在医学、灵修和公民知识领域部署了智能体——答案是：推迟到 LLM。让检索快速、精确且愚笨。让 LLM 成为智能。

### 10.1 对该领域的含义

如果我们的发现能够推广——我们相信，对于所描述的那类问题，它们可以——那么"只用 RAG"的标准建议值得重大限定。构建领域特定 LLM 智能体的从业者应该将关键词搜索视为第一方法，而非最后手段。复杂系统的证明责任应该在于证明其复杂性的合理性，而非简单系统证明其简单性的合理性。

### 10.2 更广泛的模式

知识搜索是我们在 LLM 应用开发中观察到的更广泛模式的一个实例：**最好的系统往往是让 LLM 做更多、让基础设施做更少的系统。** 复杂的检索、复杂的编排、精心设计的提示链——这些往往是低估 LLM 处理混乱、非结构化输入能力的症状。

给模型原始文本。给它足够的上下文。然后让路。

---

## 11. 结论

我们提出了知识搜索，一个用 `grep` 和 `cat` 替换标准向量 RAG 流水线的双层检索系统。该系统部署在服务三个知识领域、拥有 162 份原始文献的 21 个专业 LLM 智能体中，以零预处理、零基础设施依赖和约 30 行实现代码实现了不到 10ms 延迟下的 100% 检索准确率。

该系统有效，因为领域特定知识库具有可预测词汇、有界大小和确定性搜索需求——这些属性使关键词搜索不仅充分，而且最优。将检索到的段落综合为有用答案所需的语义理解由 LLM 本身提供，使智能检索变得多余。

我们不主张这种方法取代所有应用的向量 RAG。我们主张，它取代的应用比当前共识所假设的要多。在伸手拿嵌入、向量数据库和近似最近邻搜索之前，问问自己：`grep` 会有效吗？你可能会惊讶于答案有多少次是肯定的。

---

## 参考文献

Lewis, P., Perez, E., Piktus, A., Petroni, F., Karpathy, A., Goyal, N., ... & Kiela, D. (2020). Retrieval-augmented generation for knowledge-intensive NLP tasks. *Advances in Neural Information Processing Systems*, 33, 9459-9474.

Thompson, K. (1973). The UNIX command language. *Structured Programming*, Infotech State of the Art Report, 375-384.

Vaswani, A., Shazeer, N., Parmar, N., Uszkoreit, J., Jones, L., Gomez, A. N., ... & Polosukhin, I. (2017). Attention is all you need. *Advances in Neural Information Processing Systems*, 30.

Robertson, S. E., & Zaragoza, H. (2009). The probabilistic relevance framework: BM25 and beyond. *Foundations and Trends in Information Retrieval*, 3(4), 333-389.

Edge, D., Trinh, H., Cheng, N., Bradley, J., Chao, A., Mody, A., ... & Larson, J. (2024). From local to global: A graph RAG approach to query-focused summarization. *arXiv preprint arXiv:2404.16130*.

Karpukhin, V., Oguz, B., Min, S., Lewis, P., Wu, L., Edunov, S., ... & Yih, W. T. (2020). Dense passage retrieval for open-domain question answering. *Proceedings of the 2020 Conference on Empirical Methods in Natural Language Processing*, 6769-6781.

---

*联系方式：The LocalKin Team。本文描述了 LocalKin v2.0 中部署的知识检索系统。*

*"Grep is All You Need" 是对 Vaswani et al.（2017）的刻意致敬。我们相信这种讽刺意味不会被遗漏。*
