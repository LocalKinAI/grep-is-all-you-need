# Grep is All You Need

**用 `grep` 替换你的整个 RAG 流水线。100% 准确率，<10ms 延迟，零基础设施。**

> 对于领域特定的知识检索——词汇可预测、语料库有界——整个 RAG 技术栈都是多余的。检索不需要智能，LLM 才是智能。

[论文](paper/grep_is_all_you_need.md) | [English](README.md)

---

## 为什么？

| | Grep is All You Need | 向量 RAG | GraphRAG |
|---|---|---|---|
| **准确率** | 100% | 85-95% | 90-95% |
| **延迟** | <10ms | 50-200ms | 100-500ms |
| **预处理** | 0 秒 | 数小时 | 数小时 |
| **基础设施** | 无 | 向量数据库 | 图数据库 + 嵌入 API |
| **添加文档** | 放个文件 | 重新嵌入、重建索引 | 重新抽取实体、重建图谱 |
| **输出格式** | 人类可读 Markdown | 不透明向量 | 实体三元组 |
| **代码行数** | ~100 行 bash | 300-500+ Python | 1,000+ Python |
| **成本** | $0 | $$$ | $$$$$ |

## 快速开始

```bash
git clone https://github.com/LocalKinAI/grep-is-all-you-need.git
cd grep-is-all-you-need

# 搜索示例语料库
./search.sh --keywords "astragalus" --collection tcm

# 搜索全部示例
./search.sh --keywords "prayer,silence"
```

完了。不需要 pip install，不需要 docker，不需要数据库，不需要 API key。

## 工作原理

**两层检索：**

```
第一层：grep -r -i -C 8 搜索所有 .txt 和 .md 文件
        → 返回带 8 行上下文的原始段落

第二层：cat *_concepts.md, *_faq.md（小型结构化参考文件）
        → 返回预结构化的知识摘要
```

你的 LLM 同时获得原始段落和结构化摘要。LLM 负责智能——检索只是 `grep`。

## 使用你自己的语料库

```bash
# 1. 组织你的知识库
mkdir -p my_knowledge/topic_a
cp your_documents.txt my_knowledge/topic_a/

# 2. 搜索
KNOWLEDGE_BASE=./my_knowledge ./search.sh --keywords "你的,关键词"
```

### 可选：编译结构化摘要

为了更丰富的检索上下文，将文档编译为概念 + FAQ：

```bash
# 需要 Anthropic API key（每文件约 $0.15，使用 Haiku）
ANTHROPIC_API_KEY=sk-ant-... ./compile.sh my_knowledge/topic_a/document.txt

# 生成：
#   my_knowledge/topic_a/_compiled/document_concepts.md  （5-10 个核心概念）
#   my_knowledge/topic_a/_compiled/document_faq.md       （5-8 个问答对）
```

这些编译文件自动包含在搜索结果中，为你的 LLM 提供预结构化知识和原始文本。

## 适用场景

- **领域特定词汇**（医学术语、法律用语、宗教文本、技术文档）
- **有界语料库**（<10GB，<10K 文件 —— grep 很快）
- **可预测的查询**（用户围绕语料库中的已知主题提问）
- **LLM 作为消费者**（LLM 做综合推理，检索只负责找到段落）

## 生产部署

这套方案驱动着 [LocalKin](https://localkin.dev)，一个 75 智能体自进化 AI 蜂群：

- 11 个中医智能体（植根于公元 200 年的经典文献）
- 9 个基督教灵修导师智能体（跨越 600 年的文献）
- 1 个美国公民考试辅导智能体

192 份源文本，两种语言，三千年人类思想——全部由 `grep` 检索。

## 论文

阅读完整论文：[Grep is All You Need: Zero-Preprocessing Knowledge Retrieval for LLM Agents](paper/grep_is_all_you_need.md)

## 许可

MIT — 随便用。

---

*来自 [LocalKin](https://localkin.dev) 的创造者 — 一个在单台 Mac Mini 上运行的 75 智能体自进化 AI 蜂群。*
