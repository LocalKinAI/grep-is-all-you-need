# USCIS Naturalization Test — 100 Civics Questions

**Source**: Official US Citizenship and Immigration Services (uscis.gov),
2008 version (the version in active use through 2026 for most applicants).
**Public domain** — produced by US Government, not copyrighted.

## File

- `100_questions_2008.txt` — All 100 civics questions and their official
  approved answers (~16 KB).

## Why include this in a grep paper repo?

USCIS questions are the **canonical example** of a corpus where keyword
search is provably optimal:

1. **Bounded** — exactly 100 Q&A pairs, ~16 KB total
2. **Predictable vocabulary** — answers use government-issue language
3. **Closed set** — questions don't change frequently
4. **Discrete entries** — each Q&A is self-contained

A query containing any keyword from the question retrieves the exact
matching answer with 100% reliability. There is no embedding model,
no chunking strategy, no ANN index that would do this better. There
is also no need.

## Try grep

```bash
./search.sh -k "supreme law" --collection uscis     # → Constitution
./search.sh -k "longest river" --collection uscis   # → Mississippi
./search.sh -k "cabinet" --collection uscis         # → cabinet members
```
