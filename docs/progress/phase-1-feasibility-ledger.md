# Phase 1 — Feasibility evidence and open gates

## Current decision snapshot — 2026-11-13

**Phase 1 remains OPEN. No Phase 2 transition or scope reduction is approved by
this report.** TM-02, TM-04–TM-08, TM-10; P1-A1–P1-A5 are partial or blocked.
This section supersedes the current-status implications of the historical
2026-11-12 snapshot below, without changing its evidence or failed experiments.
Continued implementation and qualified merges are authorized; new product
inference, trust boundaries, native-host launches and deployment are not implied.

### What a developer can actually run

The Rust workspace still provides finite offline diagnostics and synthetic
contracts, not an installed companion, listener, storage or persistent index.
Two additional explicit synthetic inspection paths are runnable from source:

```sh
python3 -B experiments/evidence-review/cli.py --synthetic orbit
python3 -B experiments/decision-brief/cli.py --synthetic harbor
```

The first quotes retained, source-checked structural evidence; the second quotes
exact current-rule markers from generated public source bytes. Both preserve the
original request, label inspection as non-authorizing and end original-only on
cancel/EOF. They are not AI refinement, real project indexing, host consent or
draft delivery. Earlier stdout previews are not erased by cancellation.

### Updated acceptance ledger

| Gate | Established evidence | Still required; not substituted by green CI |
| --- | --- | --- |
| P1-A1 extraction | [Scoped normalization](phase-1-scoped-extraction.md) separates colliding producer IDs across two roots, checks exact anchors, preserves provenance/confidence and rejects malformed Python before Graphify import. Historical rename/deletion and failure observations remain recorded. [Retrieval comparison](phase-1-graphify-comparison.md) completed twelve bounded conditions. | Graphify default adoption is not justified. The callable-marker adapter excluded Rust evidence; equal eight-slot-ceiling scores do not establish backend equivalence or adequate Rust comparison. Full language/resource/packaging validation remains open. No persistence or incremental importer is proven. |
| P1-A2 OpenCode | Authentic SDK compiler discovery and source bridge exist; [native journey record](phase-1-native-journey.md) separates source, mock and installed-host observations. The bridge passes documentation-backed `resume: false`. | Installed 2.2.5/Bun 1.4.4 crashed before readiness. No native review, approval-one/cancel-zero inbox behavior or installed-server admission-only semantics were observed. All native-host launches remain paused. |
| P1-A3 T3 | [Pinned-source copy preparation](phase-1-t3.md) validates exact text/destination and rejects changed/oversized prompt-link content; copy-only output is effect-free. | No actual clipboard/composer placement, occupied-draft preservation or destination acknowledgment. Available thread-send tools submit messages, not draft-prefill proof. Do not substitute them, prompt-bearing URLs, UI scraping or database writes. |
| P1-A4 UX | [Recorded-evidence review](phase-1-evidence-review.md) and [current-decision brief](phase-1-decision-brief.md) each have six scripted mechanical journeys covering project changes, cancellation and simulated failure/recovery; ambiguity and source-injection conformance are explicit. | No declared human usability/review-effort study or normal-host comparison. Terminal verbosity, manual scope choice, retained prior previews and inability to resolve permission remain friction/counterexamples. Simulated outages are not actual daemon recovery. |
| P1-A5 capability/evaluation | Frozen [corpus](phase-1-evaluation-corpus.md), [scoring](phase-1-evaluation-scoring.md), reviewed [runner](phase-1-evaluation-runner.md), prospective budgets and recorded small trials exist. | Synthetic scale is not representative-repository validation. Memory enforcement/RSS, larger-tier runs, authorized inference, refinement/task-success comparisons, host acceptance and full redistribution provenance remain open. Conditions 4–5 in ADR 0006 have not run. |

### Evidence that must remain distinguishable

- The original eighteen-case pilot and twelve-case Graphify comparison are
  separate frozen studies, not interchangeable baselines. Neither was retuned.
  In the latter, both backends scored TP=8/FP=0/FN=8, precision=1 and recall=.5,
  but authored selected mixed Rust/Python and the Graphify adapter Python only.
  Pinned producer source and historical raw graphs support an adapter-contract
  gap, not a claim that Graphify cannot extract Rust. Current full raw graphs
  were not retained. See [ADR 0010](../decisions/0010-graphify-retrieval-comparison.md).
- The initial native Segmenter failure, subsequent standalone-not-ready failure
  and fixed-loopback Bun SIGTRAP are retained failed attempts. The crash cause
  remains unknown. Passing compiler discovery under a separately declared 2 GiB
  bound does not erase the earlier 1 GiB OOM or certify host readiness.
- Runtime provenance/notice gaps for `@npmcli/agent@4.0.2`,
  `eastasianwidth@0.2.0` and three AWS packages are not waived by Rust cargo-deny
  or SDK declaration review. Installed-version observation is not redistribution
  approval. See [native dependency/compiler evidence](phase-1-opencode-native.md).
- Local tests, exact-head PR CI, qualified merge and post-merge main CI are
  separate gates. None proves a daemon deployment, useful refinement or certified
  host. No production/binary deployment has been performed by these units.

### Decisions needed for the remaining live paths

1. **Product inference:** explicit provider/profile/model, permitted data scope,
   endpoint/locality and a bounded cost/egress/retention/cancellation plan. Current
   inference/network/spend budget remains zero under
   [ADR 0006](../decisions/0006-phase-1-evaluation-protocol.md). Coding-agent login
   tokens and a statement that inference capacity exists do not supply this API
   authorization. Request any necessary secret only through the secure harness.
2. **Native-host continuation:** retain the launch pause. A supported diagnosis
   or an explicitly approved isolated environment and exact bounded test plan
   must precede another launch. No VM/account/runtime installation or broader
   filesystem/network/Seatbelt allowance is implied; do not retry the crash.
3. **T3 draft path:** an exposed draft-placement capability and an authorized
   disposable destination with existing-draft preservation, cancellation and
   observable acknowledgment. Copy preparation is a useful fallback experiment,
   not a silent substitute for the agreed draft handoff acceptance.

These are genuine capability/authority gates, not requests to relax safety or
reduce the product scope. Independent engineering remains possible: focused
packaging/provenance investigation, a separately reviewed cross-language
extraction contract, and prospective resource validation. None can stand in for
the live MVP paths above. Do not generate more demo wrappers solely to keep work
moving, alter a frozen study to manufacture success, or start Phase 2 on unproven
host/inference assumptions. A scoped next unit must identify which open gate it
actually advances.

### Latest integrated revision and verification boundary

[PR #37](https://github.com/suhaasbadada/threadmark/pull/37) merged as
`eeb55b4598ce754ff5cc623a1e02f3cce5f92aba` after independent review and five
successful checks on source head `6f65d2b0a746a82f283c382b87ecca838aefbe37`.
Post-merge [CI 43429901955](https://github.com/suhaasbadada/threadmark/actions/runs/43429901955)
and [integrated 43429901952](https://github.com/suhaasbadada/threadmark/actions/runs/43429901952)
both passed on that exact merge. Its reviewed tree passed 743 Python/100 Node
offline tests plus foundation/dependency/security checks; those results do not
constitute checks for this subsequent documentation update.

This refresh changes only evidence navigation/status, not runtime, experiments,
budgets, source/query/oracle bytes, site, permissions or acceptance criteria.
Its own review, tested SHA and exact-head CI are recorded separately before
handoff. The seven inherited unstaged progress appends remain untouched.

Local checks for this three-file refresh passed: full `python3 scripts/check.py`
(foundation format/build/Clippy/tests/docs/finite smoke and deliberate failure
probe), `cargo deny --locked check`, staged `python3 scripts/secrets.py`, and
staged whitespace. No extraction, inference, native-host or repeated full offline
experiment suite was needed or run for these document-only changes.
Joffrey independently reviewed the consolidation with no substantive findings;
he verified the original ledger body byte-for-byte, bounded claims against local
specifications/evidence, three-file scope, links and whitespace. Remote outcomes
were primary-verified, not independently fetched by that reviewer.

## Historical snapshot — 2026-11-12

2026-11-12 UTC. **Phase 1 OPEN; Phase 2 not authorized by this report.**
TM-02, TM-04–TM-08, TM-10; P1-A1–P1-A5 remain partial/unverified as detailed
below. Phase 0 is the offline foundation, not a functioning companion. Foundation
and the separate public landing page were merged with explicit owner approval;
that authorization does not extend to the experimental PRs below.

**Later integration update:** the owner subsequently explicitly instructed
continued work and merging. PRs #3–#13 are now merged; see the exact source/merge
SHAs and combined-tree verification in [the integration record](phase-1-integration.md).
Earlier approval limits and open/unmerged descriptions below are historical
snapshots. Phase 1 acceptance remains open; merging is not certification.

This is a documentation-only consolidation and prospective protocol, not an
integration of unmerged experimental code. The exact assigned primary worktree
and branch are retained; its clean foundation branch was fast-forwarded to main
`7b3f8ad4dabdfe1f675601864c42a61977b1048d` without switching branches.
Experiment source records were read in their retained task worktrees. Links below
bind evidence to immutable commits rather than assuming files exist on main.

## Evidence ledger

At this ledger's original snapshot all listed PRs were **open/unmerged**; they
have since merged as recorded above. Every listed check was successful at the
full head recorded here, not automatically at a later head. CI validates the
named experiment, not real-host capability or the full Phase 1 exit.

| Unit and full head | Experiment evidence | Foundation / experiment CI run IDs |
| --- | --- | --- |
| [PR #3](https://github.com/suhaasbadada/threadmark/pull/3), `9a45e749a4dcb971660ef3efe528f2fa3267abbf` | [Extraction](https://github.com/suhaasbadada/threadmark/blob/9a45e749a4dcb971660ef3efe528f2fa3267abbf/docs/progress/phase-1-extraction.md) | [43184045171](https://github.com/suhaasbadada/threadmark/actions/runs/43184045171) / [43184045231](https://github.com/suhaasbadada/threadmark/actions/runs/43184045231) |
| [PR #4](https://github.com/suhaasbadada/threadmark/pull/4), `6b43f39d11bd672f352e23a76ce7b1fa432f0acc` | [OpenCode mock](https://github.com/suhaasbadada/threadmark/blob/6b43f39d11bd672f352e23a76ce7b1fa432f0acc/docs/progress/phase-1-opencode.md) | [43186234709](https://github.com/suhaasbadada/threadmark/actions/runs/43186234709) / [43186234929](https://github.com/suhaasbadada/threadmark/actions/runs/43186234929) |
| [PR #5](https://github.com/suhaasbadada/threadmark/pull/5), `55a1c81bf25fc46e569ae48be3eff111b9f0c098` | [Containment / bootstrap](https://github.com/suhaasbadada/threadmark/blob/55a1c81bf25fc46e569ae48be3eff111b9f0c098/docs/progress/phase-1-host-isolation.md) | [43202346089](https://github.com/suhaasbadada/threadmark/actions/runs/43202346089) / [43202346193](https://github.com/suhaasbadada/threadmark/actions/runs/43202346193) |
| [PR #6](https://github.com/suhaasbadada/threadmark/pull/6), `e2a3e24948c0bb0e692c74a6b24c3bd083bb039b` | [T3 source/copy preparation](https://github.com/suhaasbadada/threadmark/blob/e2a3e24948c0bb0e692c74a6b24c3bd083bb039b/docs/progress/phase-1-t3.md) | [43195693944](https://github.com/suhaasbadada/threadmark/actions/runs/43195693944) / [43195694042](https://github.com/suhaasbadada/threadmark/actions/runs/43195694042) |
| [PR #7](https://github.com/suhaasbadada/threadmark/pull/7), `5c6d433433a98a23711f16f6637967f45bf1c4a1` | [Disposable UX](https://github.com/suhaasbadada/threadmark/blob/5c6d433433a98a23711f16f6637967f45bf1c4a1/docs/progress/phase-1-ux.md) | [43198497454](https://github.com/suhaasbadada/threadmark/actions/runs/43198497454) / [43198497628](https://github.com/suhaasbadada/threadmark/actions/runs/43198497628) |

Some pinned progress documents retain earlier delegate snapshots saying CI is
pending. The exact-head check records above supersede only those CI statements,
not their capability limits. PR #5's full head and CI were verified in the prior
notification turn; #3/#4/#6/#7 were freshly read while preparing this ledger.

## Acceptance and decision ledger

| Gate | Established evidence | Remaining blocker / next permitted boundary |
| --- | --- | --- |
| P1-A1 extraction | Tiny synthetic Rust/Python direct-call/provenance facts, explicit failure/recovery and lexical/symbol comparisons | IDs collide across roots; malformed source can claim complete coverage; no representative quality, full packaging audit or real inference labeling. Production Graphify adoption deferred; not a replacement decision. |
| P1-A2 OpenCode | 48 offline contract tests; Joffrey review; synthetic containment checks; local version-only bootstrap on 2.2.5 | No pinned SDK/type/plugin runtime verification, native consent/admission or serialization-safe context ownership. Version output does not certify a running service. Broader host experiment needs a bounded plan, negative controls and review. |
| P1-A3 T3 | 18 offline tests and source-pinned prompt-link semantics; exact copy preparation | No actual clipboard/paste/destination/composer acknowledgment. Copy-only output is not a completed draft handoff. Prompt URLs remain unsupported; no native UI action authorized by this report. |
| P1-A4 UX | Six synthetic mechanical browser journeys; 14 final controller tests; primary source review and focused outage repair | No normal-host comparison, user study, keyboard-only project-selection proof or assistive-technology validation. Marking reviewed cannot validate arbitrary text semantics. |
| P1-A5 capability/evaluation | Versioned bounded records and existing experiment ADRs; prospective [ADR 0006](../decisions/0006-phase-1-evaluation-protocol.md) | Corpus/generator/oracle, declared evaluation hardware, representative measurements and independent outcome scoring absent. Provider consent/inference tests absent. Protocol is not an executed evaluation. |

No gate is promoted to complete merely because its test workflow is green.
Joffrey reviewed extraction cancellation and the OpenCode offline contract, and
identified containment supervisor defects repaired as recorded in PR #5. T3/UX
received primary source review, not a claimed additional delegated review.
This consolidation has primary evidence reconciliation only; no new independent
review has occurred. Earlier safety findings are not waived by this report.

### Subsequent independent protocol review

Joffrey independently reviewed full head
`d3a7ad601316bec82856aa60ea7b4fb99e0df188`. No must-fix blocker to the documents
or preparing a small offline corpus. Two medium execution-gate gaps were found:
retrieval arms/scoring units were underspecified before comparative pilots, and
descendant ownership/termination/output bounds needed explicit runner acceptance
criteria before launch. The primary added both gates to ADR 0006: frozen lexical,
symbol and candidate arm/scoring manifests; actual bounded aggregate-output and
owned-descendant cleanup/failure/recovery tests. No worker or corpus was launched.

The earlier primary-only review statements describe the initial consolidation;
this paragraph records the subsequent real independent review. Joffrey did not
review the follow-up wording, a runner implementation or runtime behavior. Full
study blinding/adjudication and condition budgets remain pre-study requirements;
corpus preparation alone does not resolve comparative or host acceptance gates.

## Safe continuation and authority boundaries

1. Independently review the prospective evaluation protocol; implement its
   synthetic corpus/manifest and bounded offline runner as a separate unit.
   Do not change budgets retroactively or call synthetic scale representative
   of real repositories without validation.
2. Before installed-host work beyond `--version`, specify exact executable/SDK,
   contained state/configuration/network/process boundaries, consent/review and
   cleanup controls. Review the plan and demonstrate negative controls first.
   The diagnostic page-size and literal ICU reads are not committed permissions
   or permission for a service. Do not test against the user's shared service.
3. Inference remains blocked pending explicit provider/profile authorization and
   a bounded cost/egress/cancellation plan. No credential request is necessary for
   this docs-only unit; coding-tool logins are not reusable authorization.
4. Keep native T3 composer/clipboard/link testing blocked until a declared
   disposable destination, preservation/cancellation controls and privacy plan
   are reviewed. No prompt-bearing URI, occupied real draft or send.
5. Merging PRs #3–#7 requires fresh owner authority and exact-head merge gates.
   This report does not request or perform a merge, deployment or phase closure.

## Verification record for this documentation unit

Only this ledger and ADR 0006 are new. No runtime, site, dependencies, lockfile,
workflow, host state, provider or corpus changed. No new worker, PR watch or
schedule was needed for evidence reconciliation. Local checks and committed
code/evidence SHA are recorded below before handoff; remote CI for this new unit
must target its own final head, not any run in the historical table.

Local results: `python3 scripts/check.py` passed format/build/Clippy, tests,
rustdoc, finite diagnostics, local links and the intentional failing assertion
probe. `cargo deny --locked check` passed advisories/bans/licenses/sources;
`python3 scripts/secrets.py` passed after staging both new files and rejected
the synthetic sentinel; `git diff --cached --check` passed. Remote link content
is not checked by the local link test. No representative corpus or benchmark
was run, and none is required to validate this explicitly prospective document.

Full committed documentation revision tested again with `scripts/check.py`:
`caeb871d8d627c19abb47c47edfbfe06652864e9`, passed. This subsequent evidence-only
addition does not change the protocol. The final PR head needs its own CI; its
exact run/head record will be attached to the PR without rewriting historical
experiment evidence. Review remains primary-only; protocol acceptance and
independent review before a future runner remain pending.

Subsequent exact-head verification: PR #8 at
`d3a7ad601316bec82856aa60ea7b4fb99e0df188` passed all three checks in
[CI run 43206956344](https://github.com/suhaasbadada/threadmark/actions/runs/43206956344).
That is the independently reviewed head, before the focused protocol repairs
recorded above. It remains unmerged. Those repairs need their own CI head;
neither the old green run nor review certifies the follow-up or a future runner.

Focused follow-up local verification: `scripts/check.py`, `cargo deny --locked
check`, staged `scripts/secrets.py` and staged whitespace checks all passed.
Only ADR 0006 and this progress record changed; no corpus, worker or other
experiment ran. The follow-up's exact committed head/run is recorded on PR #8.
