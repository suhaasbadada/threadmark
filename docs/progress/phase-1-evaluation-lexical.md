# Phase 1 — Finite lexical baseline

2026-11-12. **Phase 1 OPEN; P1-A1 baseline portion / P1-A5 PARTIAL.**
TM-02/04/07/10. [Phase 1](../spec/phase-1-feasibility.md),
[product requirements](../product.md), [ADR 0006](../decisions/0006-phase-1-evaluation-protocol.md)
and [ledger](phase-1-feasibility-ledger.md) remain authoritative; this unit does
not complete extraction acceptance, justify Graphify adoption or authorize Phase 2.

## Parent finalization and independent review

Full committed implementation: `dc7dafe3eb9986262b89b46299f1cec12b3817cb`.
Primary inspected all files and repaired avoidable all-match materialization:
ranking now retains the best eight incrementally, at most nine candidates during
insertion. Validation releases decoded lines after each file; selection decodes
one file at a time rather than retaining the entire decoded input. The frozen
overlap/path/line ordering is unchanged. Added a 1024-matching-line regression
measuring peak live candidate objects; all **21** tests passed. This does not
measure total RSS or establish a hostile-input/timeout boundary.

Primary also removed the main-only PR-base filter from the new experiment
workflow, preserving main-only push and all read-only/pinned/timeout settings.
Offline foundation, cached cargo-deny, staged secrets and whitespace passed on
the same implementation tree before commit.

Joffrey independently reviewed that exact commit: no substantive findings or
must-fix issues. His 21-test suite, 200 tiny independent ranking comparisons and
commit-range whitespace checks passed; clean worktree retained. He did not rerun
foundation or remote CI. No additional review of this evidence-only follow-up is
claimed. The 20-test/uncommitted child snapshot below remains historical.

Parent publishes a separate dependent PR on green, unmerged CI prerequisite
PR #11 (itself based on PR #8). Only this task branch integrates the exact CI
prerequisite; no PR or other task branch is merged, changed or retargeted. The
lexical-layer diff remains five files. Its final full head/native CI run must
be verified separately; inherited or sibling greens do not certify it. No actual
corpus integration, full-envelope validation, pilot, worker or phase acceptance
follows from these tiny conformance tests. No merge/deployment authorized.

## Bounded implementation and preregistration

Only [pure lexical API](../../experiments/evaluation-lexical/lexical.py),
[authored conformance tests](../../experiments/evaluation-lexical/test_lexical.py),
[method README](../../experiments/evaluation-lexical/README.md), this record and a
[path-scoped workflow](../../.github/workflows/evaluation-lexical.yml) are new.
The frozen method is query-only unique lowercase ASCII identifier tokens; whole
LF-split source lines with one terminal CR removed; nonzero distinct overlap;
descending overlap then UTF-8 POSIX path bytes then numeric line; top eight whole
six-field source anchors with unique coordinates. No stopwords, intent rewrite,
semantic filters, relevance classifications, gold/hash inputs or hidden file
selection. Query/instructions stay verbatim. Only the two relevance families are
implemented; conformance/other families explicitly reject.

Predeclared limits: 2048 sources, 32 MiB aggregate, 64 KiB per file; canonical
query/instructions object at most 4096 UTF-8 bytes; selected anchor list at most
8192 canonical UTF-8 bytes and eight items. Canonical means sorted JSON keys,
compact separators, raw UTF-8, no NaN/newline. Checks are post-allocation, not
hostile transport, memory, worker or timeout containment. Path/scope/types/order,
duplicate paths and UTF-8 failures reject, never silently skip foreign sources.
Scope labels are bounded fixture IDs, not authenticated approval or Git facts.

**Primary boundary:** this API returns selected anchors, never `complete` coverage
or a scorer candidate. Private coverage/oracle hashes must stay outside retrieval.
List-only overflow rejects without truncation; fitting does not establish full
envelope fit. A separately reviewed trusted normalizer must validate scope/source
identity, anchors and reviewed coverage, assemble schema/scope/coverage/items and
check the full 8192-byte budget without changing the frozen top eight. Source
selection completeness cannot be proven from this source tuple alone.

Contract references read only, not copied/imported/run:
[PR #10 scorer at reviewed 00bd8e957c45ba8ad9742a320751364263391da4](https://github.com/suhaasbadada/threadmark/blob/00bd8e957c45ba8ad9742a320751364263391da4/experiments/evaluation-scoring/scoring.py)
and [README](https://github.com/suhaasbadada/threadmark/blob/00bd8e957c45ba8ad9742a320751364263391da4/experiments/evaluation-scoring/README.md),
supplied head `23ad31623dba76fa518de1865c2d92ee836225c1`;
[PR #12 adapter at reviewed 318dc02e3d9dd299b66b1c080892c4e0a1954f1c](https://github.com/suhaasbadada/threadmark/blob/318dc02e3d9dd299b66b1c080892c4e0a1954f1c/experiments/evaluation-adapter/adapter.py)
and [README](https://github.com/suhaasbadada/threadmark/blob/318dc02e3d9dd299b66b1c080892c4e0a1954f1c/experiments/evaluation-adapter/README.md),
supplied final head `3220bde0ecceea5c1e03d4632be007837222df68`.
No remote checks were queried; no full corpus instantiated. Adapter method-task
bytes need a future explicit decoder; its CR rejection versus this unit's
terminal-CR normalization needs a caller compatibility gate, not edits to the
other experiment. Embedded CR remaining after normalization rejects because
the scorer cannot represent it. No semantic parsing is attempted.

## Observed synthetic counterexamples and acceptance

Twenty deterministic unittest methods passed, including golden exact anchors,
ASCII/case/digit/underscore/multibyte tokenization, no-token query, retained
stopwords, repeated-token dedup, distinct-overlap ranking, UTF-8 path/numeric-line
ties, same-text distinct coordinates, top-eight scope, comments/strings/Markdown,
cross-root negatives, LF/CRLF/interior blank numbering, malformed values,
inclusive count/source/query/anchor byte bounds, multibyte overflow without
truncation, unsupported families, nonmutation and fresh invocation recovery.

Observed counterexamples: stale/old-revision/foreign-looking Markdown and negated
source text are retrieved normally; nine earlier Markdown matches displace a
later function declaration. These deliberately remain baseline behavior, not
bugs to fix with oracle-aware filtering. Irrelevant admitted hits may become
false positives; separately marked stale/forbidden hits may invalidate a future
scored case. No scorer was run, no scores/quality or performance comparison are
claimed. Empty retrieval is not a perfect quality result or safety success.

TM-02: exact normalized source provenance only, no complete-coverage claim.
TM-04: deterministic bounded selection, not demonstrated task relevance.
TM-07: no invented semantic status; counterexamples and unknowns retained.
TM-10: no IO/execution/admission/host authority; labels cannot grant permission.
P1-A1 gains one baseline portion only; P1-A5 remains partial method preparation.

## Verification and handoff gates

- `python3 -B -m unittest discover -s experiments/evaluation-lexical -v`: passed,
  20 tests, zero failures; independent authored bytes only.
- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: passed format, build, Clippy,
  foundation tests, rustdoc, finite smoke diagnostics, local links and intentional
  failing assertion gate. It does not discover these experiment unittests.
- `cargo deny --offline --locked check`: passed advisories/bans/licenses/sources;
  offline cached advisory data is not a freshly fetched vulnerability audit.
- `python3 scripts/secrets.py` after staging all five new files: passed tracked
  files/history and correctly rejected the synthetic sentinel.
- `git diff --cached --check`: passed; staged diff contains only the five files
  listed above, with no pre-existing user changes or unstaged edits.

Assigned branch `t3/evaluation-lexical-matcher-baseline`, inherited base
`9227571c6e9f0b090ec883121dc9babfc25cc59f`; changes returned staged/uncommitted.
There is no new tested commit SHA, independent review, PR or exact CI run/head.
Parent owns independent review, full tested SHA and exact-head Linux/macOS CI.
The new read-only five-minute workflow installs nothing and has only path-scoped
PR/main-push triggers; existing foundation triggers are untouched. Parent may
separately integrate CI prerequisite PR #11 and publish a dependent PR; no such
integration occurs here.

Full candidate assembly/coverage and source-provenance validation, actual
adapter/scorer integration, symbol/candidate arms, worker cancellation/dependency
failure/timeout/output/descendant containment, evaluation manifest/environment,
actual quality trials and independent outcome review remain separate gates.
Fresh-value recovery is not process recovery. No runner, pilot, inference,
real source discovery/execution, host action, runtime/site/dependency/lockfile
change, Docker, additional worker/watch/reminder, commit/push/merge/deploy or phase
closure occurred.
