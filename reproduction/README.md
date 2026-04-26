# Reproduction artifacts for paper §6.5

This directory contains everything needed to replay the
zero-hallucination failure-and-recovery cycle from the paper.

## Files

- `corpus/` — 3 public-domain Austin-Sparks works (~500 KB total).
  Contains the original English + Chinese passages that the post-fix
  agent quotes from in Phase 3.
- `responses/phase1_failure_quotes.tsv` — captured agent response
  before the fix. 5 fabricated quotes; column 3 is a "needle" we
  use for fast grep.
- `responses/phase3_recovery_quotes.tsv` — captured agent response
  after the fix. 4 grep-verified quotes; column 3 is the matching
  needle.

## Run

From the repo root:

```bash
./reproduce_zero_hallucination.sh
```

The script does NOT call an LLM. It replays the TSV responses and
runs LIVE `grep` against `corpus/` to verify which quotes are real
substrings of which source files.

## How were the responses captured?

Phase 1: query against austin_sparks agent on the production fleet
when soul prompt still had `**"..."**` signature phrases. Output
captured 2026-04-25 19:43 PT.

Phase 3: after applying commit 3e365a9 (strip 41 fake-quote markers
across 79 souls + append citation hard-rule), same query. Output
captured 2026-04-25 20:04 PT.

The full diagnostic conversation is in the LocalKin Claude Code
session log; the salient facts are recorded in paper §6.5.

## Why replay vs live LLM?

- Reproducible: same TSV → same outputs every time
- No API key needed: anyone can run this without setup
- The interesting verification (does the quote exist?) IS done live
  via grep
