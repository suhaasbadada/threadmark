# Prospective evidence-assisted synthetic draft

TM-02/04/07/10; P1-A1/P1-A5 **partial**, Phase 1 OPEN. See
[ADR 0008](../../docs/decisions/0008-bounded-evidence-selection.md).

Python 3.10+ stdlib, repository root:

```sh
python3 -B -m unittest discover -s experiments/evidence-selection -v
python3 -B experiments/evidence-selection/selection.py --synthetic harbor
python3 -B experiments/evidence-selection/selection.py --synthetic harbour
python3 -B experiments/evidence-selection/selection.py --synthetic harbor --json
```

No arguments prints help, without building corpus/extracting. Only these two
fixed in-memory public synthetic examples are CLI inputs: no arbitrary paths,
commands, hosts, network, inference, clipboard or send. Default stdout is a
human-readable review with the original request, instructions, cited source lines
and coverage limitations. `--json` retains the complete canonical envelope.
Neither format is AI refinement or a delivery receipt.
Original request and instructions appear unchanged in `original_task`; evidence
has exact `path`/`line` citations and whole normalized source text. Coverage is
from the real reviewed extractor, including unresolved spans and gaps.

## Frozen prospective policy

`select(sources, task) -> bytes` accepts only the five-field existing task schema
with explicit `definition_directcall` family. No intent classifier. Immutable
source tuples must already be sorted by UTF-8 path and scoped to one project;
all input is validated by public `directcall.extract`, including irrelevant files.
No oracle, fixture, score, rank override, plugin or dynamic loader input exists.
Exact project/worktree/revision labels apply to every anchor. The API cannot
independently establish actual Git identity, detect omitted files or stale bytes
relabelled current; callers must establish the authorized complete snapshot.

`evidence-selection/1` uses exact case-sensitive maximal ASCII query identifiers
in unique first-occurrence order (not instruction words). All matched declarations
and resolved one-hop calls to them are collected **before** selection. Separate
groups sort by identifier index / UTF-8 path / numeric line, deduplicate at best
rank, then alternate definition/call beginning with definition. Skip coordinates
already chosen, spill the other group when exhausted, stop at eight whole unique
lines. Shared lines retain both categories without claiming both are separate
slots. Available category counts are unique line counts, not quality scores.

Canonical JSON: sorted keys, compact separators, raw UTF-8, no NaN; entire envelope
at most 8192 bytes, original query/instructions object at most 4096 bytes. Both
are inclusive postallocation limits, not hostile-input resource containment.
Overflow rejects everything: no truncation, metadata omission or cheaper line
fallback. The readable rendering separately rejects output above 8192 bytes,
without truncation. CLI adds one terminal LF outside either bounded representation.

The extractor's static binding assumptions, grammar and coverage limitations are
[unchanged](../evaluation-directcall/README.md), including unresolved dynamic calls
and Rust macros. No independent parser, relation resolver or full-graph claim.
No old candidate/scorer admission compatibility is asserted. Frozen pilot,
ranking, query, source pins and evidence are untouched. Tests/demos are selection
conformance and feasibility only; no 18-case rerun, benchmark or new quality study.
Review and future preregistered comparisons precede any adoption decision.
