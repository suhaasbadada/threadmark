# Phase 1 — Graphify comparison outcome

TM-02/04/07/10; P1-A1/P1-A5 partial. **Phase 1 OPEN; single trial complete.**
[ADR 0010](../decisions/0010-graphify-retrieval-comparison.md) and
[protocol](../../experiments/graphify-comparison/README.md).

## Historical implementation snapshot (before execution)

One coherent fixed 12-worker comparative unit is implemented: existing authored
directcall selection versus actual Graphify AST selection, both using the shared
interleaved chooser, original SMALL query/instructions, all 16 files per project
including four Markdown files, and the unchanged full adapter/scorer gold of 16.
Raw Graphify metadata is not copied; source anchors and selected provenance/
confidence are separately validated. No old quality results are rescored.

Only installed public source was inspected read-only to confirm callable markers,
structural Markdown `file_type=document`/optional `node_kind`, and extraction API
accounting. No Graphify/native parser import, extraction, worker or actual pilot
execution occurred. Mocked transport and historical raw fixtures are NOT new
native/quality evidence. No inference, network, source execution, host changes,
commit, push or PR. Native P1-A2 launch pause is unchanged.

## Historical implementation verification and gates

Base/tested worktree HEAD: `6b880c74ccf87907fd50214708553ee58a350c7b` plus
uncommitted changes listed by the new manifest's authored hash bindings on a
future authorized run. No new commit SHA or CI run exists for these changes.
The parent's prior post-merge CI 43417822169 / integrated 43417822071 evidence
belongs to the existing merged content, not this uncommitted comparison.

Local pure checks passed: comparison 26; existing selector 21; scoped normalizer
21; scorer 24; corpus 10; adapter 18 (120 tests total). Canonical historical
demonstration stdout hashes remain unchanged in both projects. Historical pilot
report/manifest hashes, old algorithm hashes, corpus and original tasks are
checked without rescoring old candidates. Actual-worker gate **CLOSED** pending
primary independent review and existing 20-test retained-owner lifecycle gate;
neither is claimed complete here. Full check.py/runtime tests are intentionally
not used as a substitute for that gate under this child's pure-test restriction.

`python3 scripts/check.py docs`, `cargo deny --locked --offline check`
(cached advisories/bans/licenses/sources), `python3 scripts/secrets.py` after
staging owned files, and `git diff --cached --check` passed. Full check.py was
not run under the pure-test restriction. New suite is not added to existing CI.
All five pre-existing unstaged progress appends are preserved and not staged.

## Historical pre-run limitations

Actual retrieval utility and complete 12-case runtime lifecycle remain unobserved.
No engine adoption, quality improvement, native readiness, representative scaling,
OS-cold/warm timing, RSS/memory enforcement, task-success or phase-closure claim.
The existing owner may lose partial stdout/stderr on cleanup failure; the trial
stops and preserves its partial public report, without a new diagnostics guarantee.

## Primary review and single-trial decision

Joffrey independently reviewed the meaningful change. His medium finding: the
manifest omitted `evaluation-pilot/pilot.py`, although its helper functions execute
in this trial. Primary added that dependency binding and a simulated-drift
regression; historical evidence/hashes were untouched. Bounded worker stdout is
now retained alongside private stderr before admission, aiding failed-admission
diagnosis without exposing diagnostics in the public report. This does not add a
raw-graph capture or new owner/cleanup guarantee.

All **27 corrected comparison tests** and **20 existing retained-owner lifecycle
tests** passed. No other substantive scoring, oracle-isolation, coverage or
ownership issue was found by review. The shared chooser's old byte-compatible
behavior remains covered. Primary authorizes **one** prospective twelve-condition
invocation under the already-declared protocol, with manifest retention before
the first worker and unchanged strict caps. Stop at the first failure, retain it,
and do not retry, change ranking or waive coverage. This supersedes the initial
pre-review CLOSED status, not any native-host/provider/T3 authority boundary.

## Executed outcome — authoritative current status

The one authorized invocation registered at `2026-11-13T12:09:22.239584+00:00`
and completed in 8.71857437491417 seconds. All twelve conditions were ready,
target exit zero, cleanup verified; all four project/backend repetition groups
were byte-deterministic. Primary and Joffrey independently recomputed all twelve
candidates, scores and hashes, and checked order, bindings, private worker replies
and unchanged historical-reference copies. No second trial or matcher change ran.

- [Manifest](../../experiments/graphify-comparison/evidence-v1/manifest.json)
  SHA-256: `b41fb915b1abfca54800fdee28818f9755cf06c813bb0f478edbe2cb10e3e109`.
- [Report](../../experiments/graphify-comparison/evidence-v1/report.json)
  SHA-256: `cc2c75e283ff417062eb0078f0ae8864dbbb2b00159c42d67dc9520bee163cf8`.
- Private evidence-manifest SHA-256:
  `76c8af894d39beebd958ca4d6048da9f0da7be61f9315d46d129c7113a723237`;
  24 bounded stdout/stderr streams retained outside the repository. Final read-only
  open-file diagnostic found zero processes holding owned diagnostic files.

Every condition scored TP=8/FP=0/FN=8, precision=1.0, recall=.5 and slot ceiling=.5.
Both selected four definitions/four callers. **The selected source sets differ:**
authored selected four Rust/four Python lines (units 0000/0001/0004/0005), while
Graphify adapter selected eight Python lines (0001/0005/0009/0013), in each project.
Available categories were authored 8 definitions/8 callers versus Graphify 4/4.
Graphify selected confidence facts were four EXTRACTED/four UNDECLARED; authored
eight UNDECLARED. These labels are not relationship/confidence correctness scores.

### Coverage counterexample and correction

The primary initially stated in chat that selected lines were identical. A
subsequent readback assertion failed because the source sets differed; that claim
was explicitly corrected. This was a failed diagnostic assertion, not a failed
worker or reason to modify results. Equal capped aggregate scores hid the gap.

The predeclared adapter requires `_callable=true` for declarations. Read-only
pinned `graphify/extractors/rust.py` producer inspection (node fields at 351–360,
function nodes at 517–532), together with the historical raw holdout and
`test_historical_raw_holdout_and_no_missing_marker_guess`, supports missing Rust
markers as the adapter-contract explanation. No current full raw graph was
retained: do not claim a fresh raw-field capture or that Graphify cannot extract
Rust. Historical evidence already contains Rust nodes/calls. This foreseeable
matching-contract gap prevents adequate Rust/overall backend comparison despite
valid scores within the declared limited envelope.

Joffrey independently confirmed the coverage gap and stale status as medium
publication findings, with no new execution/scoring blocker. Current headings,
README and ADR now state the executed outcome and bounded interpretation.

Decision: no justification for default Graphify adoption from this trial; no
general Graphify rejection or backend-equivalence claim. Stop here, preserving
the frozen matcher/results. No silent relaxation, rerun or historical rescoring.

### Descriptive lifecycle observations (seconds)

These include existing process-owner lifecycle, not retrieval-only performance;
three repetitions are not independent samples. No historical timing comparison.

| Scope/backend | Median | Range |
| --- | --- | --- |
| harbor/authored | .6027 | .593–.6158 |
| harbor/Graphify | .7994 | .7839–.8983 |
| harbour/authored | .5959 | .5932–.6034 |
| harbour/Graphify | .7869 | .7853–.7900 |

Integrated CI now includes the 27 pure/mocked comparison tests, not actual Graphify
workers. Native-host launches remain paused. No inference/provider authorization,
real composer handoff, representative scaling, enforced RSS, user-value acceptance,
runtime redistribution closure or Phase 1 closure is claimed. Five inherited
unstaged progress appends remain outside this change.

## Integrated local verification before publication

Primary ran the integrated offline scope: **716 Python tests and 100 Node tests
passed**, including 27 comparison tests, the existing 20 retained-owner tests and
five runtime-selection tests. `python3 scripts/check.py` passed Rust formatting,
build, warning-denying Clippy, tests, docs, bounded CLI/daemon smoke diagnostics,
local documentation links and the intentional-failure gate probe.
`cargo deny --locked check` passed advisories/bans/licenses/sources, and the
staged `python3 scripts/secrets.py` scan passed. No Graphify trial or installed
native-host launch was repeated by this verification. Remote CI for the new
publication head is a separate pending gate, not the earlier main runs.
