# Phase 1 — Pure evaluation fixture adapter

2026-11-12. **Public synthetic preparation only; P1-A5 PARTIAL, Phase 1 OPEN.**
The [prospective protocol](../decisions/0006-phase-1-evaluation-protocol.md) remains
proposed. This unit does not modify the [evidence ledger](phase-1-feasibility-ledger.md)
or close any phase. Phase 0 remains an offline foundation, not a working companion.

## Bounded unit and preregistered mapping

[Adapter contract](../../experiments/evaluation-adapter/README.md) declares the
mapping before any future pilot: separately trusted corpus digest; exact ASCII
metadata/hash recipe; independent scope/count/cap/hash/anchor checks; LF-only
content; complete selected-source line map; all eligible gold, never top-eight
gold; stale rejection; conformance-only families; original input preservation;
private oracle separation; explicit unsupported non-query score-manifest mapping.
No recipe reconstruction, parser, source execution, retrieval or scorer import.

| Requirement / acceptance | This unit's synthetic evidence | Not established |
| --- | --- | --- |
| TM-02 | Six-field exact source anchors; frozen limited coverage binds hashes/version; macro/dynamic gaps explicit | Extraction, syntax certification or completeness of any result |
| TM-04 | All selected-scope sources retained; current irrelevant anchors available; all definition/call gold beyond eight; original 4096-byte rejection and declared 8/8192 candidate budgets | Retrieval ranking, candidate-output admission or quality measurements |
| TM-05 | Exact original query/instructions and original/constraints retained; no invented query for negation family | Refinement or semantic intent/permission validation |
| TM-07 | Current/stale/foreign/unknown distinction; every oracle anchor validated; unknowns/recipes preserved as expectations | Observed failure/recovery evidence or accepted product knowledge |
| TM-10 | Pure nonmutating existing-value API; no IO/execution/provider/host operations; trusted pin separated from candidate | Authorization/authentication, worker containment or cancellation |
| P1-A5 **PARTIAL ONLY** | Versioned mapping and miniature synthetic negative controls under ADR 0006 | Representative study, full corpus/scorer compatibility, evaluation hardware, host certification, independent outcome review |

Definition family retains the original broad all-resolve objective. Decision
family gold contains only current scoped decisions. Stale anchors are explicitly
rejected; foreign roots are absent from selected maps; old-scope oracle anchors
fail closed. Negation and recovery families have no relevance gold/scores.
No semantic permission or forbidden status is invented from source text.

The private sidecar preserves every manifest/oracle/input field; only immutable
selected source bytes and declared original task data are future arm inputs.
The non-query conformance task has `method_task=None`, score mapping
`NOT_AVAILABLE`; query families have task-field mapping only. All arm/runner
implementations remain **NOT_IMPLEMENTED / NOT_RUN**. Case counts are not quality
results. No candidate envelope or completeness assertion is produced.

## Public source pins and integration limits

Compatibility design read only these authored corpus/scorer sources, never their
implementation imports/execution or generated corpus. Immutable references:

- Corpus reviewed source `df49ecbfd38dbd6c39be3ff214bf2de383dd51a1`:
  [module](https://github.com/suhaasbadada/threadmark/blob/df49ecbfd38dbd6c39be3ff214bf2de383dd51a1/experiments/evaluation-corpus/corpus.py),
  [README](https://github.com/suhaasbadada/threadmark/blob/df49ecbfd38dbd6c39be3ff214bf2de383dd51a1/experiments/evaluation-corpus/README.md).
  Supplied unmerged PR #9 head `eba04746fcbf0857e7b8af18e217b047f0353829`.
- Scorer reviewed source `00bd8e957c45ba8ad9742a320751364263391da4`:
  [module](https://github.com/suhaasbadada/threadmark/blob/00bd8e957c45ba8ad9742a320751364263391da4/experiments/evaluation-scoring/scoring.py),
  [README](https://github.com/suhaasbadada/threadmark/blob/00bd8e957c45ba8ad9742a320751364263391da4/experiments/evaluation-scoring/README.md).
  Supplied unmerged PR #10 head `23ad31623dba76fa518de1865c2d92ee836225c1`.

No remote queries were made; these are task-supplied source/head records, not new
CI or review verification. Corpus metadata uses ASCII canonical JSON; prospective
scorer payloads use canonical UTF-8. The adapter preserves text and rejects CR or
other unsupported line separators rather than normalizing the corpus's
`splitlines()` ambiguity. Negation's original/constraints shape cannot be
represented by the scorer's query-only task without a later declared extension.
Plain fixture data requires later explicit scorer-type construction; **no actual
PR #9/#10 full corpus or scorer integration is claimed**.

Tests use a two-file hand-authored artifact with both fixture roots, all four
families and a separately frozen miniature pin, plus a three-file variant proving
that a second selected file and its nongold lines remain available. Counts may be below tier ceilings
only under a corresponding trusted miniature pin. This does not certify the real
32/256/2048-file recipes. All source/project/worktree/revision data is synthetic;
no metadata from user repositories appears in artifacts. Limits apply after
allocation and are not hostile-transport memory containment.

## Local verification and handoff

Assigned branch: `t3/evaluation-adapter-fixture-tests`. Inherited/base SHA:
`9227571c6e9f0b090ec883121dc9babfc25cc59f`. Worktree and branch retained without
switches or another checkout. Changes are **staged, uncommitted**; that base SHA
does not contain this unit and is not a full tested implementation SHA.
Independent review, final full tested SHA, exact published head/CI run and any
separately declared pinned compatibility check are **parent-owned / NOT RUN**.
No commits, push, PR, merge, workflow dispatch/watch, reminder, delegate or deploy.

Commands and actual final outcomes are recorded below after verification.
The new path-scoped Linux/macOS workflow is read-only, five minutes, pinned
checkout with persisted credentials disabled and no installation. It has PR path
filters and main-only push paths; no existing CI base filters are changed.
It is not evidence that CI ran. Native foundation PR #11 remains a separately
supplied unmerged prerequisite; the parent may need supplemental exact-head
foundation CI when publishing this dependent unit on PR #8.

### Verification results

- `python3 -B -m unittest discover -s experiments/evaluation-adapter -v`:
  **PASS, 17 tests**, including independently pinned miniature fixtures, all four
  families, all gold beyond eight/across files, current irrelevant anchors, stale
  rejection, selected-scope isolation, malformed metadata/source/oracle, wrong
  schema/revision/pin, forged self-refreeze, hash/count/cap/order failures,
  LF-only rejection, exact 4096-byte boundary and overflow, lossless original/
  constraints/unknowns/recipes, private-answer separation and nonmutating fresh
  valid-value recovery. Boundary/negative-control tests sometimes deliberately
  trust an alternate test artifact to exercise validation beyond the digest gate;
  they do not authorize deriving a production pin from a candidate.
- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **PASS**, foundation format,
  build, Clippy, unit/integration/doc tests, rustdoc, finite diagnostics, local
  documentation links and intentional failing-assertion rejection probe.
- `cargo deny --offline --locked check`: **PASS**, advisories/bans/licenses/sources
  against **cached advisory data**; no claim of a fresh online advisory check.
- `python3 scripts/secrets.py`, after staging all new files: **PASS**, tracked
  files/history and synthetic scanner rejection sentinel. Repeated after the
  final evidence update and restaging.
- `git diff --cached --check` and `git diff --check`: **PASS**.

Miniature fixed pins are
`783168de23907f1158c9594495f8f74d7d473606f200a0522bd21fedb00f139f`
and `dcf98ee6b0a67d0e060342302c313cd59556420c635f226fce364a49b78872d2`.
These identify test artifacts only, not PR #9 corpus tiers. No actual corpus/scorer
integration, worker, retrieval, evaluation, inference, costs, quality measurement,
host certification, independent review, remote CI or phase-completion result was
produced. Local passes do not replace final exact-head checks or parent review.
