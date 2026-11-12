# Phase 1 — Evaluation-only Rust/Python static direct-call prerequisite

2026-11-12. **Phase 1 OPEN; TM-02/04/07/10; P1-A1/P1-A5 PARTIAL ONLY.**
The complete context/refinement/hosts/inference/UX/safety product remains required.
This is not a reduced MVP, Graphify adoption/replacement, production graph,
daemon, integration, comparative pilot, quality study or phase closure.

## Exact handoff and scope

- Assigned branch `t3/directcall-static-binding-extraction` (T3 renamed the initial
  `t3/0d012021` label during startup; no branch switch/rename by this child);
  assigned T3 worktree basename
  `t3-0d012021-c61746d5f484e3d1`. No other checkout or task work modified.
- Initial clean inherited HEAD `c10e9ee5ec31569c908dab9d2a556b3c0c99a6d7`.
  Fetched origin/main and fast-forwarded this exact branch to merged main
  **`d00b94e225233595d026481c4e241187bfa0b657`**. No reset, branch switch,
  extra checkout or worktree creation.
- Deliverable: staged, **UNCOMMITTED** changes in the four requested experiment/
  progress files plus one command in the existing experiments workflow. No
  duplicate workflow; no other arm/runner/worker/adapter/scorer/corpus edits.
- Exact tested committed implementation SHA: **PENDING parent commit and rerun**;
  the base SHA above plus staged edits is the local verification tree, not a
  committed implementation. Independent policy/coverage review: **PENDING**.
  Exact CI run/head: **NOT RUN by child; parent-owned**. No PR created or assumed.
- No commit/push/PR/merge/deploy/subdelegate/watch/scheduler or Graphify execution.

## Acceptance and remaining gates

| Requirement / acceptance | Evidence in this unit | Remaining limitation |
| --- | --- | --- |
| TM-02 / P1-A1 partial | Both languages' whole-input binding collection, source-byte identity, distinct call spans and per-file observed coverage | Static subset assumptions, not runtime/type truth or language completeness |
| TM-04 | Frozen one-hop declaration-first query/path/line ranking, coordinate dedup, top-eight then whole8192-list reject | Full candidate envelope with independently reconstructed observations not integrated |
| TM-07 | Explicit unresolved reasons, poisoned affected scopes, late-failure rejection, generic content-free errors, dependency pin | Same-interpreter code is trusted; no authorization, missing-source detection or runtime certainty |
| TM-10 | Pure immutable in-memory APIs, no source execution/discovery, network/provider, fallback/cache or new worker | No cancellation/containment interface offered by this synchronous prerequisite |
| P1-A5 partial | Supplemental version/dependency/policy manifest and independent literal tests in existing workflow | Policy/coverage review, committed SHA/exact-head CI and separate admission review required before arming/comparisons |

The [README](../../experiments/evaluation-directcall/README.md) records precise
predeclared Python grammar/binding contexts, Rust subset/masks, IDs/coordinates,
coverage semantics, failures, limits and counterexamples. Module functions are
static binding assumptions, not monkeypatch-proof object identities. Python
definition-time execution calls are unsupported with gaps and binding masks;
Rust unsupported binding constructs poison affected scopes. Rust syntax/type
certification and all cross-file/type/alias/qualified/macro/cfg resolution remain
unavailable. No arbitrary Rust grammar claim is made.

The existing scorer CONTRACT/digest, corpus/schema/algorithm pins and historical
NOT_IMPLEMENTED/NOT_RUN strings are unchanged. The supplemental manifest explicitly
pins the reviewed symbol internal source dependency rather than copying its
lexer or calling its cropped retrieve output. Graphify 0.9.101 is neither run
nor wrapped; earlier ID/completion/inference/location/edge-collapse limitations
remain evidence against assuming that a wrapper meets this contract.

## Local verification

Host: Darwin 27.0.0 / arm64, Python 3.12.6. No other interpreter/platform was
locally certified. Supplemental Python 3.12 policy digest:
`c66d5404f17a8cc596bad68e718b287e6c2e96b25d88f78fdb3aac3fe374612e`.
Grammar-version-specific digests are deliberate, not source/corpus schema changes.

Initial new-suite run exposed three incorrectly hand-counted test offsets (not resolver
edge failures); expected literals were independently recounted and corrected.
Subsequent inspection added definition-time named-expression masks, module lexical
isolation, opaque Rust type contexts and extern/generic binding poison regressions.
No negative result was converted to completeness or a production claim.

The initial complete integrated run passed **264 existing tests + 63 new tests**,
all actual workflow commands, plus actual synthetic macOS guard. Follow-up code
inspection added opaque local-type/turbofish contexts, exact noncallable ownership,
same-line macro exclusion, inclusive source counts and unknown-parameter-pattern
regressions. Final results are recorded below after rerunning those changes.

Important distinction: the unchanged existing runner suite includes its previously
reviewed lexical/symbol actual-SMALL transport conformance test (four fixed arm/root
cases). That existing regression ran as part of the requested **all 264 existing**
commands; there was no additional/manual worker launch, no directcall worker,
no directcall admission and no new arm/candidate/runner integration. Existing
corpus/adapter tests build inert larger-tier fixture bytes; no medium/large
retrieval was run. All new directcall fixtures remain small, independently authored
in-memory examples; the 32-MiB Markdown arithmetic boundary is not a study.

Second complete integrated run: **332 tests PASS (264 existing + 68 new;
252 Python + 80 Node)**, zero failures/skips. Actual synthetic macOS guard:
**synthetic-only-pass**, `host_launched=false`. After this run a final identity
inspection retained Rust raw-identifier spelling (`r#name`) separately from query
names and added explicit expensive-top-eight/cheap-ninth rejection; the final
focused **69-test directcall suite passed again**, including raw-name retrieval.
Final unique test inventory verified: **333 PASS (264 existing + 69 new;
253 Python + 80 Node)**. Existing arm/runner source and pins were not modified.

- Offline foundation `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **PASS**:
  formatting/build/clippy, 10 Rust tests + one doctest, docs, finite diagnostics,
  local Markdown links and intentional-failure rejection.
- `cargo deny --offline --locked check`: **PASS** advisories/bans/licenses/sources;
  cached advisory data only, freshness not verified, no network refresh.
- `python3 scripts/secrets.py` after staging all five files: **PASS**, tracked-file
  scan and intentional synthetic-secret rejection. `git diff --cached --check`:
  **PASS**. No unrelated files staged or unstaged; exact final status rechecked.

Parent must independently review policy and observed coverage before integration,
then bind eventual committed SHA and exact CI run/head. No local check closes
Phase 1 or establishes quality/performance, host certification or a product decision.
