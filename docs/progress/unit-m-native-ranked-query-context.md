# Unit M — explicit native ranked lexical Query / Context

## Scope and base

- TM-01–TM-04, TM-07, TM-10; bounded evidence toward P2-A1/P2-A6,
  P3-A4 and P4-A2, not phase closure.
- Assigned branch: `t3/native-ranked-query-context-mode`. Original clean head:
  `661bdb3e11118efe979cc7adf06c39db723bf133`.
- Coordinator authorized normal base integration after the fast-forward failed.
  Merge-only baseline: `1dfaee562572f53ee60b1900fc7a5cf0bba6c4da`, merging
  `cdeb277264b0690911c0d60f40bd31e53c344cd6` and preserving the unique contract
  freeze / landing redesign commits. No merge conflicts. No implementation commit,
  push, PR, CI, merge-to-target or deployment was performed.
- Tested tree is the uncommitted Unit M diff against that full baseline SHA;
  there is no committed implementation SHA or CI run/head to claim. Coordinator
  owns integration, review, commit and CI. Independent review has not run here.

## Behavior and evidence

- Explicit native picker in source Query and Context, literal by default;
  session-memory-only ranked lexical opt-in. Refine remains literal. No semantic
  completeness, provider invocation, approval or delivery from Query/Context.
- Exact cached Project reaches new bound-ranked CLI/daemon variants and the
  existing core `query_terms_bound` / Context bound-retrieval APIs before source
  traversal, including every Context engine revalidation. Complete registration,
  source policy and snapshot required; no metadata preflight then unbound reload.
- Mode changes cancel/invalidate results, Context/refinement previews and consent.
  Existing generation/cancellation/join gate rejects late results; original draft
  retained. Human note mutation/history semantics are not changed.
- P2-A1/A6 and P4-A2: live native tests replace same-root/different-root
  registration, source policy and SQL snapshot after the shell precheck but before
  the real bound-ranked CLI call. All eight ranked Query/Context cases reject;
  no evidence/preview/provider call is adopted. Existing core tests prove the
  pre-traversal boundary for every binding field.
- P3-A4: these same tests preserve unsaved original and human history for
  source-only policy/snapshot changes; namespace replacements clear old drafts
  rather than adopting replacement data. No new human-edit behavior is claimed.
- Live adapter journey proves literal multiword no-match remains unchanged,
  opt-in ranking finds dispersed terms, Context preserves exact original UTF-8,
  mode changes discard already displayed output, returning to literal restores
  the same Query result, and Refine preflight still selects literal evidence.
- Deterministic cancellation-ignoring service tests cover Query/Context × mode
  change/Cancel, asserting no late result adoption and no original replacement.
- Actual CLI/SQLite tests exercise valid complete bindings, each wrong
  root/identity/incarnation/snapshot/source value, partial/repeated flags and
  revoked policy, without fallback or content output on rejection.

## Changed implementation / test files

- `apps/companion/Sources/CompanionKit/Contract.swift`
- `apps/companion/Sources/CompanionKit/ProcessService.swift`
- `apps/companion/Sources/CompanionKit/CompanionModel.swift`
- `apps/companion/Sources/ThreadmarkCompanion/main.swift`
- `apps/companion/Tests/CompanionKitTests/BoundSourceReadTests.swift`
- `apps/companion/Tests/CompanionKitTests/CompanionTests.swift`
- `apps/companion/Tests/CompanionKitTests/RankedSourceTests.swift`
- `crates/cli/src/main.rs`
- `crates/cli/tests/ranked_query.rs`
- `crates/daemon/src/knowledge.rs`
- `apps/companion/README.md` and this evidence file.

## Actual checks

- PASS: `cargo build --workspace --locked` (rebuilt actual CLI).
- PASS: `python3 scripts/check.py`: fmt, locked workspace build, clippy with
  warnings denied, all workspace tests and doctests, docs warnings denied,
  finite diagnostics, documentation links and intentional failure-gate probe.
- PASS: `cargo deny --locked check`: advisories, bans, licenses, sources.
- PASS: documented Swift wrapper with rebuilt `THREADMARK_CORE_TEST_BINARY`,
  `test --disable-xctest --enable-swift-testing -Xswiftc -strict-concurrency=complete
  -Xswiftc -warnings-as-errors`: 142 tests / 18 suites, including live-core tests.
  Initial compile identified the exhaustive fake-service switch; fixed explicitly
  without pretending the fake supports ranked retrieval. Wrapper emits its known
  SwiftPM native-backend deprecation notice; no compile warnings passed as errors.
- PASS: `python3 scripts/secrets.py` after staging both new files: tracked/history
  scan passed and synthetic sentinel rejected. No inherited implementation edits
  were staged or attributed to this unit.
- PASS: `python3 scripts/check.py docs` and `git diff HEAD --check` after the
  README/evidence additions. Diff is 12 scoped files against the merge baseline;
  no site/contract-base history is included in this implementation diff.

## Exclusions / limitations

No site changes relative to baseline, dependencies/lock edits, retained native
controller/protocol/provider-consent/host UI changes, automatic inference or
delivery. No GUI launch, permission prompts, host launches, production listener,
Docker or deployment. Existing full-suite synthetic loopback provider tests ran;
they are not production network egress or new product provider calls.
No GUI walkthrough, VoiceOver/native accessibility certification, semantic quality
evaluation, complete resource acceptance, independent review or remote CI was run.
P2/P3/P4 stay open. Coordinator must compose this isolated diff with lane L's
retained-controller mounts; this unit does not modify retained files.
