# Thomas à Kempis — *The Imitation of Christ* (c. 1418-1427)

**Source**: Project Gutenberg eBook #1653 (William Benham translation, 1873).
**Public domain.** Use freely.

## File

- `imitation_of_christ.txt` — The complete work, 4 books, 114 chapters,
  ~340 KB / ~63,000 words. Pre-cleaned (Gutenberg headers stripped).

## What it is

Devotio Moderna spiritual classic — second only to the Bible in total
print across Christian history. Concise meditation chapters on humility,
self-denial, communion, and inner contemplation.

## Try grep

```bash
./search.sh -k "humility"           --base examples/spiritual
./search.sh -k "vanity,humility"    --base examples/spiritual
./search.sh -k "vain"               --collection thomas_a_kempis
```

## Layer 2 (compiled)

The `_compiled/` subdirectory contains LLM-compiled concept and FAQ
extracts (generated via Kimi 2.6 local Ollama). These give grep
multilingual semantic-bridge coverage. To regenerate:

```bash
./compile.sh --kimi examples/spiritual/thomas_a_kempis/imitation_of_christ.txt
```
