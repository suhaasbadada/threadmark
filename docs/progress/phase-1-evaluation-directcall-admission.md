# Phase 1 — Trusted candidate direct-call admission integration

2026-11-12. **TM-02/04/07/10; P1-A1/P1-A5 PARTIAL; Phase 1 OPEN.** Full product
context/refinement/hosts/inference/UX/safety scope is unchanged. No reduced MVP,
Graphify adoption, production graph decision, comparative study or phase closure.

## Assigned checkout and authority boundary

- Branch: `t3/phase1-directcall-admission-integration`; assigned T3 worktree
  basename `t3-b08123b2-96a8d48ccad5e800`. Only that checkout was edited.
- Initially clean inherited HEAD `c10e9ee5ec31569c908dab9d2a556b3c0c99a6d7`;
  fetched origin/main and **fast-forward-only** updated this branch to
  **`45ceb932bad8dea1213f2633173d422c968c88cb`** before implementation. No reset,
  branch switch, second checkout/worktree or user-work cleanup.
- PR19 source `c0049fa` / tree-identical merged base and previously reviewed
  `9ee47048cc31fa4edcb96a26b6884d0e9af28b58` are supplied parent evidence.
  Standalone Joffrey review (79 tests + 16 probes, no substantive findings) applied
  only to **NOT_ARMED** standalone code, not this new integration.
- Deliverable is **staged UNCOMMITTED**. Full tested committed implementation SHA:
  **PENDING parent commit/rerun**. Independent integration review: **PENDING**.
  Exact-head CI run/head: **NOT RUN by child; parent-owned**. No PR created.
- **Actual candidate-arm `worker.py`: NOT RUN by child**. No new positive worker
  test is added. Parent owns fresh independent review before that launch, then
  committed source pins, worker conformance, CI and any authorized merge.
- No commit/push/PR/merge/deploy/subdelegate/watch/scheduler by child.

Exact staged file inventory (13):

```text
.github/workflows/experiments.yml
docs/progress/phase-1-evaluation-directcall-admission.md
experiments/evaluation-candidate/README.md
experiments/evaluation-candidate/_trusted.py
experiments/evaluation-candidate/candidate.py
experiments/evaluation-candidate/test_candidate.py
experiments/evaluation-candidate/test_directcall_admission.py
experiments/evaluation-directcall/README.md
experiments/evaluation-directcall/directcall.py
experiments/evaluation-runner/README.md
experiments/evaluation-runner/runner.py
experiments/evaluation-runner/test_candidate_admission.py
experiments/evaluation-runner/worker.py
```

## Implementation and acceptance

| Requirement | Evidence in this unit | Limitation / next gate |
| --- | --- | --- |
| TM-02 / P1-A1 partial | Shared private trusted normalization binds exact all-file observations, scope/snapshot, policy and complete original limited source map in candidate and runner | Same reviewed extractor consistency, not independent semantic oracle, runtime truth or complete Rust/Python coverage |
| TM-04 | Exact `candidate` arm alongside unchanged lexical default/symbol; original query/instructions; declaration-first one-hop ranking unchanged; whole8192 UTF-8 metadata/duplicate admission | SMALL eight declarations do not prove resolver usefulness; no comparative metrics |
| TM-07 | Authored source/dependency and grammar policy pins; missing/extra/order/status/gaps/count/endpoint/span observations reject; wrong-arm class, source/task mutations and generic dependency failure close whole output | Same-interpreter Python code is trusted; scope/hash is not authorization or authenticated revision |
| TM-10 | Immutable expectation before retrieval callback; checkpoints return zero candidates on cancellation; no fallback/cache/retry/cheaper anchors; independent runner reconstruction without retrieval | Pure synchronous checkpoints do not abort work; existing cooperative worker ownership limits unchanged |
| P1-A5 partial | Predeclared supplemental policy/coverage commitments, tests in existing discovery commands, native CI version/grammar record | Fresh integration review, committed SHA/pins, exact-head CI, actual candidate-worker test and representative evaluation remain parent gates |

The shared private helper is
[`_trusted.py`](../../experiments/evaluation-candidate/_trusted.py). Its expectation
captures canonical immutable policy and full extraction bytes **before** any
retriever callback. Observation commitment covers selected scope, every selected
source path/length/SHA-256, declarations/IDs/spans/callability, resolved-call IDs/
targets/spans and every file's parse status, lengths/counts/unresolved reasons/gaps.
No unsupported or irrelevant file is dropped. All selected public sources and
scope only reach extraction; retrieval additionally receives the unchanged task,
never fixture/oracle/fact-kind/hash/coverage. The actual adapter and scorer remain
the only source-map/schema/anchor/admission implementations, not copied algorithms.

Exactly two compact coverage strings append to **both** trusted Fixture and full
candidate envelope. Original adapter coverage/map/hash/gaps stay byte-identical.
Detailed observations stay internal bytes; no unbounded candidate payload. All
original metadata, both commitments, item duplicates and raw UTF-8 count toward
the exact inclusive 8192-byte full-envelope limit. A fitting list is not proof;
overflow blocks the whole candidate without cheaper selection, metadata omission,
query rewriting, gold filtering, truncation or fallback.

Before preparation/launch, policy/source pins check; relevant code, policy,
observations and task bindings recheck before admission/final return. Runner fixed
bindings include directcall and the helper; capture, immediate prelaunch,
post-cleanup/admission and final resource-restoration checks close stale code.
Runner independently builds the actual SMALL adapter case and uses the **same
private normalization contract**, never worker-result metadata as its authority;
no retrieve/ranking occurs in `_admit`. Less-relevant current anchors can still
admit if the frozen scorer allows them; exact source/policy/observation binding
does not independently certify ranking or usefulness.

Directcall now owns a frozen six-field `Anchor`, rather than aliasing symbol.
Serialized values and resolver/ranking behavior are unchanged; selected-class
guards can now reject genuine wrong-arm anchors. Existing lexical/symbol classes,
corpus/schema/scorer CONTRACT/algorithm pins and historical NOT_IMPLEMENTED /
NOT_RUN / pending standalone policy strings are unchanged. No old digest was
overwritten to fake approval.

## Authored pins and observed commitments

- Directcall source (six-field class integration):
  `b9210ec286093a257ca6e814dd0c31047f78b93ed554d09e6778b447b66e0221`.
- Symbol dependency source:
  `d09e22d3a7d3f077673d672920bbeeff983de778407684ec6dc5c9e53ba63a60`.
- Unchanged scorer source:
  `78d023fcb47e3a85908f0cd87ca9d3ae0126b70b330eba465c887281b6919181`.
- Unchanged corpus source:
  `87f884b5820060e6939e05612699fd86be193d4b36fa14ddf0cfd4f16cc09dff`.
- Unchanged adapter source:
  `5e71fb9e5c63dc0794944d62b981c19be831df12cd635ac24e92609d5e66dab2`.
- Frozen SMALL corpus:
  `c497a577eb9699d15da30b02a215784df36bafeafcb643c83c983ba540e6c9e8`.
- Historical standalone Python 3.12 policy (still PENDING/NOT_ARMED value):
  `7e126aabcfca4db0b01568139cd711cd22391bcd2eb979c3b78083fc588ed622`.
- New `evaluation-directcall-admission/1` supplemental Python 3.12 policy:
  `0626c354146799f549fbc6664d540a5947a3d67d644ece199eb92c7f00f7eb57`.
- SMALL `harbor` observation commitment:
  `532ba5edd35a1644ee1ad0a598ba3f798c1b287b7302fa812429331e1b124839`.
- SMALL `harbour` observation commitment:
  `578fcc6bf9e9868bb55abe51521d33b5a3cdde750de926e7055b7bc196623a28`.

The authored grammar→standalone-digest table is fixed in the helper for 3.10–3.14;
these are explicit manifest/protocol states, **not certification of all runtimes**.
Unknown grammar/version or a freshly self-hashed altered policy rejects. Only
Python **3.12.6**, Darwin/arm64 was locally exercised. The existing native CI
runtime-check line now prints its actual version/AST grammar; native CI itself
was not run by this child. Helper source is captured/rechecked as a fixed runner
binding; it is not self-hashed recursively into its own authored policy.

## Local verification and counterexamples

Final local integrated run: **364 tests PASS** (**343 existing + 21 new**;
284 Python + 80 Node), zero failures/skips. Exact existing workflow commands:

| Suite | Passed |
| --- | ---: |
| extraction harness | 8 |
| host isolation | 25 |
| corpus | 10 |
| scorer | 24 |
| adapter | 18 |
| lexical | 21 |
| candidate (24 existing + 15 new) | 39 |
| symbol | 37 |
| directcall | 79 |
| runner (17 existing + 6 new pure cases) | 23 |
| Node OpenCode/T3/UX | 80 |

- Actual synthetic macOS guard: **synthetic-only-pass**, `host_launched=false`.
- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **PASS** after final code/docs:
  format/build/clippy, 10 Rust tests + one doctest, docs/local links, finite
  diagnostics and intentional failing-assertion rejection.
- `cargo deny --offline --locked check`: **PASS**, advisories/bans/licenses/sources;
  cached advisory data only, freshness **not verified**, no network refresh.
- After staging all 13 task files, `python3 scripts/secrets.py`: **PASS** tracked
  scan and intentional synthetic-secret rejection; `git diff --cached --check`
  and `git diff --check`: **PASS**. All task changes staged; no unrelated edits.

The first focused run caught an obsolete invalid-method test listing `candidate`,
an incorrectly authored SMALL expected declaration list, a placeholder tiny pin,
and a test that removed a trusted pin rather than simulating stale bytes. Tests
were corrected to the new contract and independent literal coordinates/fixed pins;
resolver ranking and corpus answers were not changed to make those tests pass.

New tests remain **pure in-memory**: public SMALL candidate builds in both roots,
literal Rust and Python call anchors through separately fixed private test pins,
exact class guards, original/query/scope preservation, all-file extraction spies,
callback-time observation/policy corruption, status/path/order/gap/count/endpoint/
span/unknown-version/dependency failures, whole-envelope 8192/8193 UTF-8 and
duplicate-metadata rejection, every cancellation checkpoint and fresh recovery.
Runner tests exercise `_admit` with actual public build bytes, no retrieval,
policy/coverage/scope/source-binding mutations and prelaunch-no-spawn gates.
Existing 79 directcall tests (including all prior 77 false-edge regressions) stay.

Actual SMALL definition outputs have eight declarations, **not call-resolution
proof**; ready candidate envelopes were 2472 / 2507 bytes for harbor / harbour.
The actual decision-family result has an **empty** list. Neither is a quality win.
Tiny fewer-declaration fixtures independently assert actual call lines after
normalization without a caller pin/oracle injection interface in public build.

The integrated commands retain the previously reviewed lexical/symbol actual
SMALL-worker regression (four arm/root cases) and authored lifecycle fixtures;
they do **not** launch the new candidate worker. Corpus regression tests still
build their existing inert larger-tier bytes; no medium/large retrieval/study.
Memory enforcement remains unavailable and runner preflight blocks scaling.

## Exclusions and remaining parent gates

No full study/comparison/scoring publication, source execution/compilation,
Graphify execution/adoption, provider/network/inference/spend, host/product
runtime/site, dependency/lock, Docker, permissions/containment/privacy policy,
listener/storage/telemetry/login or deployment change. Fixed authored code reads
for integrity are not source discovery/export. No new test folder, command or
workflow; existing discovery commands cover the new tests.

Parent must independently review this exact integration, commit and bind the full
tested SHA, run the first reviewed actual candidate-worker conformance/add its
positive test, obtain exact-head native CI, and own any authorized merge. Local
conformance is not phase exit, installed-host certification or product readiness.

## Parent pre-review final-binding cancellation repair

Primary reproduced a finalization regression introduced by the new source-binding
recheck: cancellation was checked before that final IO, so an Event set during
binding reads after temporary-state removal still returned a constructed ready
receipt. The actual authored lifecycle fixture and mocked admission receipt
reproduced `ready` with candidate bytes; no candidate-arm worker was launched.

The final cancellation check now follows final binding IO, while cleanup-unverified
and quarantine retain precedence. A fixture-only regression sets the Event during
the final binding reads and requires verified cleanup plus `canceled`, with both
candidate and original bytes absent. Primary focused verification: **24 runner
tests + 39 candidate tests PASS**. Child 23/364 counts above are historical;
current full inventory is 365 pending the parent integrated rerun. Independent
integration review remains required before any actual candidate-worker launch.
