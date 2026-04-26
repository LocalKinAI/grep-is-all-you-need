# Sun Simiao 孙思邈 — 千金食治 (*Qianjin Shizhi* / Dietetics)

**Source**: Sun Simiao's *Beiji Qianjin Yaofang* (备急千金要方, ~652 CE),
**dietetics chapters** (千金食治). Public domain (~1,400 years old).

## File

- `qianjin_shizhi_dietetics.txt` — Classical Chinese dietetics text,
  ~52 KB / ~17,000 characters. The pre-Tang theoretical foundation
  for Chinese medicinal eating, covering ~155 foods, their natures
  (寒 cold / 凉 cool / 平 neutral / 温 warm / 热 hot), and indications.

## Why include this in a grep paper repo?

This is the **canonical "Classical Chinese works for grep"** case:

1. **Standardized vocabulary** — 气虚 means "qi deficiency" today
   the same as it did in 652 CE. No semantic drift.
2. **No translation needed at retrieval time** — grep on the
   original Chinese works perfectly when the query uses the same
   Chinese terms.
3. **Embedding models struggle here** — most multilingual embeddings
   are trained on modern Mandarin web text, not classical Chinese.
   Vector RAG often returns the wrong herb when 麻黄 (Ephedra) and
   桂枝 (Cinnamon Twig) are discussed in adjacent passages.

## Try grep

```bash
./search.sh -k "气虚"   --collection sun_simiao
./search.sh -k "黄芪"   --collection sun_simiao   # Astragalus
./search.sh -k "脾胃"   --collection sun_simiao   # Spleen-stomach
./search.sh -k "酒,葡萄" --collection sun_simiao   # multi-keyword
```
