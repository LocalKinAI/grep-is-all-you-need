# Grep is All You Need

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.19777260.svg)](https://doi.org/10.5281/zenodo.19777260)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Production](https://img.shields.io/badge/production-faith.localkin.ai_·_heal.localkin.ai-brightgreen)](https://localkin.dev)

**用 `grep` 替换你的整个 RAG 流水线。100% 准确率，<25ms 延迟，零基础设施。**

> 对于领域特定的知识检索——词汇可预测、语料库有界——整个 RAG 技术栈都是多余的。检索不需要智能，LLM 才是智能。

[📄 论文 v1.1（Zenodo）](https://doi.org/10.5281/zenodo.19777260) · [Markdown](paper/grep_is_all_you_need.md) · [PDF](paper/grep_is_all_you_need.pdf) · [English README](README.md)

---

## 为什么？

| | Grep is All You Need | 向量 RAG | GraphRAG |
|---|---|---|---|
| **准确率** | 100% | 85-95% | 90-95% |
| **延迟** | <25ms（500 文件语料库）| 50-200ms | 100-500ms |
| **每查询预处理** | 0 秒 | 数小时（前置）| 数小时（前置）|
| **基础设施** | 无 | 向量数据库 | 图数据库 + 嵌入 API |
| **添加文档** | 放个文件 | 重新嵌入、重建索引 | 重新抽取实体、重建图谱 |
| **输出格式** | 人类可读 Markdown | 不透明向量 | 实体三元组 |
| **代码行数（检索侧）** | ~30 行 bash | 300-500+ Python | 1,000+ Python |
| **成本** | $0 | $$$ | $$$$$ |

## 快速开始

```bash
git clone https://github.com/LocalKinAI/grep-is-all-you-need.git
cd grep-is-all-you-need

# 搜索示例语料库（中医草药）
./search.sh --keywords "astragalus" --collection tcm

# 搜索全部示例
./search.sh --keywords "prayer,silence"
```

完了。不需要 pip install，不需要 docker，不需要数据库，不需要 API key。

## 工作原理

**两层检索 — 两层都用 `grep`：**

```
第一层：grep -r -i -C 8 搜索所有原始 .txt 和 .md 源文件
        → 返回带 8 行上下文的原始段落

第二层：grep -r -i -C 8 同时遍历 _compiled/<file>_concepts.md
        和 _compiled/<file>_faq.md —— 每个源文件由 LLM 蒸馏的
        概念和 FAQ 条目，作为多语言语义桥梁回到字面的第一层语料库。
```

一次 `grep` 调用同时遍历两层。LLM 在同一次调用中收到原始段落和结构化摘要。LLM 提供智能——检索只是 `grep`。

> 📖 完整架构、第二层从"备用"框架升级为"概念桥梁"框架的来由，以及一次记录在案的 0/5 → 4/4 零幻觉可复现周期，全在**论文里**（[Zenodo DOI](https://doi.org/10.5281/zenodo.19777260)）。

## 使用你自己的语料库

```bash
# 1. 组织你的知识库
mkdir -p my_knowledge/topic_a
cp your_documents.txt my_knowledge/topic_a/

# 2. 搜索
KNOWLEDGE_BASE=./my_knowledge ./search.sh --keywords "your,terms"
```

### 可选：编译第二层概念 + FAQ 文件

跨语言查询和纯关键词搜索遗漏的概念跳跃，需要运行自主编译步骤。**默认免费本地 Ollama (Kimi 2.6)**；Ollama 不可用时自动回退到付费 Anthropic Haiku。

```bash
# 免费路径（推荐）—— 本地 Ollama 运行 kimi-k2.6:cloud
ollama pull kimi-k2.6:cloud   # 一次性
./compile.sh my_knowledge/topic_a/document.txt

# 付费回退 —— Anthropic Haiku
ANTHROPIC_API_KEY=sk-ant-... ./compile.sh my_knowledge/topic_a/document.txt

# 每个源文件生成：
#   my_knowledge/topic_a/_compiled/document_concepts.md  (~3 KB，5-10 个核心概念 + 原文引文)
#   my_knowledge/topic_a/_compiled/document_faq.md       (~2.5 KB，5-8 个 Q&A 对)
```

这些编译文件自动包含在搜索结果中，给 LLM 与原始文本一起的预结构化知识——尤其重要的是，为**与源语料库不同语言的查询**提供桥梁。

## 目录结构

```
your_knowledge_base/
├── domain_a/
│   ├── collection_1/
│   │   ├── source.txt              # 原始文本（第一层：grep 目标）
│   │   ├── source2.md
│   │   └── _compiled/              # 可选（第二层：每源概念+FAQ）
│   │       ├── source_concepts.md
│   │       ├── source_faq.md
│   │       ├── source2_concepts.md
│   │       └── source2_faq.md
│   └── collection_2/
│       └── ...
└── domain_b/
    └── ...
```

## 适用场景

- **领域特定词汇**（医学术语、法律术语、宗教文本、技术文档）
- **有界语料库**（<10GB、<10K 文件 —— `grep` 很快）
- **可预测查询**（用户问的是语料库中已知主题）
- **跨语言查询经第二层桥接**（中文查询英文源语料，反之亦然）
- **LLM 作为消费者**（LLM 综合；检索只负责找段落）

## 不适用场景

- **真正开放域语义搜索**（任何作者词汇中都没有匹配概念名的查询）
- **超大语料库**（10GB+ 时 `grep` 延迟变明显）
- **实体关系遍历**（显式图查询）

## 生产部署

这套方法支撑 [LocalKin](https://localkin.dev) —— 一台 Mac mini 上零幻觉、自我改进的多智能体系统。截至 2026 年 4 月，它作为以下系统的知识骨干：

- **39 个传统中医智能体**（`heal.localkin.ai`）—— 4,500 年经典医学文本，从黄帝到健在的国医大师
- **37 个基督教灵修方向智能体**（`faith.localkin.ai`）—— 1,900 年文本，从爱任纽（130 AD）到史百克（1971）
- **1 个美国公民辅导智能体**

**约 500 份原始文献、76 个专业智能体、180 MB 语料库、两种语言、四千五百年人类思想**——全部由 `grep` 检索。

`_compiled/` 第二层文件每夜由一条基于 cron 的自主流水线生长（详见论文 §9），在 2026 年 4 月将编译 LLM 由付费 Anthropic Haiku 迁移到本地 Ollama 上服务的 Kimi 2.6 之后，**API 成本 $0/年**。

## 可复现性

论文记录了一次单日失败-恢复周期（§6.5），你可以重放：

- **失败**：智能体杜撰了 5 处带章节归属的引文。`grep` 验证：**语料库中 0/5**。
- **根因**：人格提示中以 `**"..."**` 格式书写的签名短语被 LLM 当作正典文本并附以虚假章节归属再次输出。
- **修复**：60 行脚本自动剥离 79 个 souls 中的 41 处假引文标记；追加引用硬约束块。从诊断到部署 **25 分钟**。
- **恢复**：同一查询，**4/4 引文 grep 验证通过**。

架构的安全属性可以仅通过提示卫生恢复——无需重训，无需基础设施变更。详见论文 §6.5。

## 论文

- **Zenodo（标准 DOI 版）**：[10.5281/zenodo.19777260](https://doi.org/10.5281/zenodo.19777260)
- **Markdown 源**：[paper/grep_is_all_you_need.md](paper/grep_is_all_you_need.md)（双语 EN + 中文，1064 行）
- **PDF**：[paper/grep_is_all_you_need.pdf](paper/grep_is_all_you_need.pdf)（33 页，1.6 MB）
- **网页版**：[localkin.dev/papers/grep-is-all-you-need](https://www.localkin.dev/papers/grep-is-all-you-need)

## 引用

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

## 许可证

MIT —— 随便用。

---

*来自 [LocalKin](https://localkin.dev) 的创建者们 —— 一台 Mac mini 上的零幻觉、自我改进的 76 智能体系统。*

*"Grep is All You Need" 是对 Vaswani et al.（2017）的刻意致敬。我们相信这种讽刺意味不会被遗漏。*
