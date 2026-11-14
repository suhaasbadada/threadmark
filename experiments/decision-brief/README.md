# Current audit decision brief — offline syntactic experiment

TM-02, TM-04–TM-08, TM-10; partial P1-A1/P1-A4/P1-A5 evidence, not phase closure.
See [ADR 0011](../../docs/decisions/0011-current-audit-decision-brief.md) and
[progress](../../docs/progress/phase-1-decision-brief.md). This is a runnable
deterministic source-cited brief for the frozen SMALL conflicting-rule and
negation/permission families, not AI refinement, runtime knowledge semantics,
Graphify adoption, an executor, or a user-value study.

## Fixed interface and interpretation

```sh
python3 -B experiments/decision-brief/cli.py --synthetic harbor
python3 -B experiments/decision-brief/cli.py --synthetic harbour
python3 -B -m unittest discover -s experiments/decision-brief -v
```

No argument means help only. No arbitrary project, path, query, budget, command,
filesystem reader, worker, inference, network, host, clipboard or source execution
interface exists. Inputs are generated public synthetic bytes, not files from a
repository; symlinks have no representation. The stdlib imports only authored
corpus/helpers, not Graphify/native parsers, extractors or scoped runners.

Commands: `show`, `json`, `inspect`, `project harbor|harbour`, `stale`,
`unavailable`, `recover`, `cancel`, `quit`, `help`. Failure controls are simulated.
Inspection is a local label, never approval, permission, delivery or send. Every
inspection freshly reloads/validates the synthetic snapshot. Project switch,
failure and recovery clear inspection. Dependency recovery displays a fresh
uninspected candidate; it never restores previous inspection. No persisted state.
Cancel, EOF, oversized input, or 32-command exhaustion ends with original-only
output, zero evidence and no inspected brief. Earlier previews are not erased
from stdout; no candidate is emitted after cancellation.

## Marker contract (not general Markdown or NLP)

Only exact whole physical lines beginning `Current rule: ` in `.md` count.
The remaining nonblank value is opaque, case-sensitive source data. No indentation,
list/quote prefix, case folding, multiline continuation, heading interpretation,
date ranking or authority/precedence inference. Code fences have no special
meaning either: this deliberately narrow marker protocol is NOT Markdown.
Retired markers never count. LF coordinates use the existing `source_lines`
helper; CRLF normalizes to LF without changing source-byte hashes. Control or
Unicode line separators inside a marker reject the whole candidate. Unicode
values otherwise remain exact. Empty markers reject; unsupported marker spellings
are absent, not guessed.

One distinct value yields a current-marker answer referencing all matching
citations, even when four files repeat it. Multiple distinct values yield explicit
ambiguity with all cited conflicting marker lines and **no usable current answer**;
this is not semantic contradiction detection. No markers yields unknown and a
question. Document text is untrusted quoted evidence, not injected instructions
or independently verified truth. JSON escapes quotations/control characters in
the readable view. Permission is always unresolved under the unchanged public
original, constraints and instructions, irrespective of source claims.

## Atomic consistency and bounds

`select(sources, task, snapshot)` accepts immutable tuples of relative POSIX paths
and bytes, a fixed public task, and a frozen `Snapshot` containing caller-supplied
scope and expected `(path, byte count, SHA-256)` rows. These are consistency labels,
not authenticated identity, Git verification or live freshness. The synthetic
loader checks the original frozen SMALL manifest digest and public input hash.
Tests may explicitly supply new snapshots for counterexamples; such snapshots
cannot certify source authority or permission.

Validate all 16 selected sources, including non-Markdown, against the expected
manifest: exact path set, scope/project/worktree/revision, byte counts, hashes,
UTF-8, duplicates and path syntax. No traversal, foreign root or silent missing
source. At most 16 files, 64 KiB aggregate (also per-file ceiling); original task
at most 4 KiB; at most eight evidence items and 8,192 bytes for the **whole
canonical JSON brief**, not just excerpts. Canonical JSON uses ASCII escapes,
so this is conservatively also a UTF-8 byte bound. Reject on overflow, never
drop facts to make ambiguity disappear. Invalid/stale/unavailable means the fixed
original plus unresolved permission, zero evidence and no answer. No oracle
metadata is accepted by selection. Pure tests independently read the oracle and
use the unchanged exact-anchor scorer for relevance assertions only, not a trial,
refinement/task-quality score or performance claim.

## Recorded local outcome

After independent review and correction of C1 control rejection, all 27 pure
tests and the six prospectively declared mechanical CLI journeys passed. Both
projects returned their own four current-marker quotations; project switch and
simulated failure/recovery cleared prior inspection, and cancellation/EOF ended
original-only. See the [outcome record](../../docs/progress/phase-1-decision-brief.md)
for transcript hashes, acceptance boundaries and observed verbosity friction.
These are fixed synthetic mechanics, not live freshness, human usability,
permission, task quality or Phase 1 closure.
