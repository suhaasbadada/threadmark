# Phase 1 symbol declaration baseline — local implementation evidence

Date: 2026-11-12. **TM-02/04/07/10; P1-A1 baseline portion / P1-A5 PARTIAL.**
Phase 1 remains open, ADR 0006 remains proposed, and the full agreed product
scope remains required. No quality, performance, working-companion or Phase 2
claim follows from this prerequisite.

## Change and checkout identity

- Task branch: `t3/phase1-symbol-declaration-baseline`, existing assigned worktree;
  no branch switching, alternate checkout edits or new worktree.
- Full base HEAD: `c10e9ee5ec31569c908dab9d2a556b3c0c99a6d7`.
  Parent supplied tree equivalence to merged main
  `700f5fbe1f258818a41a22ac20087fde59fe2544`; not independently re-queried.
- Deliverable is **staged, uncommitted changes**, so that base SHA alone is **not**
  a committed tested implementation SHA. Parent must record the eventual exact
  tested commit, independent review and remote CI run/head after integration.
- Files: [implementation](../../experiments/evaluation-symbol/symbol.py),
  [observable tests](../../experiments/evaluation-symbol/test_symbol.py),
  [contract/coverage](../../experiments/evaluation-symbol/README.md), this record.
- No runtime/site/lockfile, other evaluation algorithm/pin, or shared workflow
  edits. PR 15 and its branch/watch were not queried or touched. Parent owns the
  symbol test workflow command after latest-main integration.

## Acceptance evidence and exclusions

- **TM-02 / P1-A1 baseline portion:** source-bound immutable six-field anchors
  from both Rust and Python; full-input validation, line normalization and
  fail-closed recognition tests, no partial results. Python AST/token syntax
  distinguishes declarations from comments/strings. Rust constrained lexical
  recognition handles declared kinds, modifiers/impl/associated declarations,
  textual cfg branches, nested comments/literal forms, raw ASCII names, generic
  parameters, pointer types and excluded macro token trees.
- **TM-04 / P1-A5 PARTIAL:** frozen case-sensitive first-query-identifier ranking,
  UTF-8 path/numeric-line ties, unique coordinates, incremental eight retained
  candidates (at most nine during insertion), and canonical UTF-8 byte boundaries.
  Sources: 2048 / 32 MiB / 64 KiB each; original query/instructions object: 4096;
  selected list: 8192 / eight items. All are inclusive postallocation limits, not
  hostile transport, CPU or RSS containment. Full coverage-envelope candidate
  assembly/budget validation is future integration, not proven by list fitting.
- **TM-07:** precise predeclared coverage gaps/counterexamples in the README;
  no Rust grammar certification, Python grammar depends on runtime version.
  No semantic stale/negation/permission filtering or authenticity claim. Markdown
  validates but contributes no symbols. Caller completeness/provenance stays a
  separate trust gate. No last-good cache/fallback.
- **TM-10:** no input mutation, source execution, subprocess/compiler, listener,
  host/config/clipboard action, credential reuse, network, inference, dependencies,
  persistence/export, worker, or Docker in this baseline. In-process mocked
  parser dependency failure and fresh-value recovery are tested. Actual process
  cancellation/timeout/worker recovery belong to a future runner, not this API.

The only actual-corpus retrieval is tiny frozen **small** selected-root
conformance: 16 selected `harbor` sources from the paired 32-source fixture,
expected eight whole declaration lines independently authored; no macro-body or
call-site retrieval. No oracle/gold/hash/private coverage inputs to retrieval.
No medium/large retrieval, full-corpus pilot, scoring metrics, quality comparison,
performance measurement, transitive/call graph or semantic product index.

Rust limitations include malformed item grammar that can still match text,
lifetime-versus-malformed-character context ambiguity, constrained generic angle
handling, noncertified escape/Unicode/edition validity, no macro expansion/cfg
evaluation/aliases. Python uses AST syntax, not compiler context/type validation,
and excludes Unicode/multiline names, runtime definitions and unsupported runtime
grammar/BOM input. These are explicit limitations, not silent completeness.

## Local checks

Executed on the uncommitted implementation over the full base HEAD above, with
Python **3.12.6**. Foundation checks exercise trusted repository code and their
owned intentional-failure gate crate; synthetic corpus source strings are never
compiled/executed.

| Command | Observed result |
| --- | --- |
| `python3 -B -m unittest discover -s experiments/evaluation-symbol -v` | PASS, 34 tests |
| `python3 -B -m unittest discover -s experiments/evaluation-lexical -v` | PASS, 21 tests |
| `python3 -B -m unittest discover -s experiments/evaluation-scoring -v` | PASS, 24 tests; existing frozen manifest digest unchanged |
| `python3 -B -m unittest discover -s experiments/evaluation-adapter -v` | PASS, 18 tests |
| `python3 -B -m unittest discover -s experiments/evaluation-corpus -v` | PASS, 10 tests; existing tier generation/validation only, not symbol retrieval beyond small |
| `CARGO_NET_OFFLINE=true python3 scripts/check.py` | PASS: fmt/build/clippy/test/docs/finite CLI+daemon diagnostics, local doc links, intentional-failure gate |
| `cargo deny --offline --locked check` | PASS: advisories/bans/licenses/sources using cached advisory data; freshness not verified, no network refresh |
| `python3 scripts/secrets.py` after staging | PASS: tracked-file scan and synthetic-secret rejection |
| `git diff --cached --check` | PASS |

Independent review: **not run by child; parent-owned**. Remote CI run/head:
**not run by child; parent-owned**. Exact committed tested implementation SHA:
**not available (staged/uncommitted handoff)**. No commit, push, PR, merge, deploy,
watch, scheduler or delegation performed. No phase closure.
