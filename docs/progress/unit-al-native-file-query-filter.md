# Unit AL — native Query-only file filter

## Primary integration and independent review

Child owned implementation committed as `88bf853`; primary applied only its diff
as `99ccfff3daff6a0d2b697ac96be60400bad4e47a` on AJ merge
`bed1d5d43442b94a581b6f694c37eeadf806b736`. Shared conflicts were resolved by
retaining both batch and filtered-query cancellation/preservation hooks, command/
decode/budget arms, fixture variables/builds and API gates. No baseline/site merge
was replayed; nine inherited progress edits remain untouched.

Exact integrated tested runtime **`b00912a71cdc6c8a8021591bf449e945f7e44a4d`**
adds integration-only batch tests: inert filter edits revoke old review without
I/O/draft/base/conflict loss, and a filtered-query successor joins a cancellation-
ignoring preclaim batch while preserving its unknown outcome and retained intent.
Payload fingerprint (lexical changed non-progress paths versus AJ merge, path/NUL/
bytes/NUL): **`a150aec7c9c0e791831ea83c03cfbacb6b4db8ce42998670284c2387860980e6`**.
This intentionally differs from the isolated child due to AJ conflict unions and
the new cross-feature tests; no claim of byte-identical integration is made.

Joffrey independently reviewed isolated AL **CLEAR**, verified its original
fingerprint and reran full strict Debug **284 tests/45 suites**, all fixtures,
new API gate and whitespace. A separate fresh integration review was **CLEAR**;
it checked the exact conflict unions and new tests, independently reran targeted
Debug/Release **20 tests each**, and inspected full integrated logs. Its targeted
run skipped two actual-CLI cases without environment; primary's full runs enabled
the actual CLI and all seven C-fixture families.

Primary full offline workspace **387 Rust tests + two doctests PASS**; strict
serial full Debug and Release each **296 Swift tests/47 suites PASS**, all eight
API gates, offline locked deny, secrets/whitespace and bundle/plist **PASS**.
An initial new-test compile error from a combined actor-isolated assertion was
fixed by separate awaited assertions before these passing gates. Two inherited
deadline fixtures remain ignored. Publication-head CI is separate and pending.
No GUI/AX, live provider, host delivery or phase closure claim.

AJ #86 exact post-merge runs `43598044374` and `43598044381` both completed
**PASS** at `bed1d5d43442b94a581b6f694c37eeadf806b736`, independently of PR-head CI.

Requirements TM-01–TM-04, TM-07, TM-10; partial P2-A1–A6 and P3-A3/A4/A5/A6.
Phase 2/3 remain open. Reviewed AK v1 is unchanged. Acceptance IDs frozen before
tests: **AL-A1** mounted inert registered-policy choices/default/empty guard;
**AL-A2** exact full-bound two-list transport/strict whole closed frame and independent
adoption; **AL-A3** registry cancel/join and frozen generation/config/scope/mode/subset;
**AL-A4** genuine selected row Inspect with full policy, no forged/old-row authority;
**AL-A5** full-policy freshness/Forget/replacement rejection and human preservation;
**AL-A6** unchanged separate full-scope Context/Refine consent/no automatic provider;
**AL-A7** strict native/full offline checks/API boundaries/CI fixture wiring.

Prepared clean HEAD `661bdb3e11118efe979cc7adf06c39db723bf133`; authorized normal
merge of required local `927aac48a0625be7d41bac38bd7846e13d511832` produced full
baseline **`a834ad378beb3dfd3405ccb6167af1515798b916`** (parents in that order).
Only baseline merge committed; implementation uncommitted. No reset/switch/new
worktree. Primary must integrate only AL-owned diff, not baseline/site history.

## Owned inventory / integration

Twelve payload files plus this document; all other baseline files untouched:

1. `.github/workflows/ci.yml` — build/enable new synthetic C fixture and seventh
   ordinary-import API gate; retain all six existing gates.
2. `apps/companion/Sources/CompanionKit/QueryFilter.swift` — immutable complete
   bound request, canonical selected paths, distinct closed duplicate-rejecting
   whole-frame decoder and independent retained-frame/projection validation.
3. `apps/companion/Sources/CompanionKit/QueryFilterView.swift` — inert Query-only
   registered-file choices, empty-selection guidance and full-policy disclosure.
4. `apps/companion/Sources/CompanionKit/CompanionModel.swift` — Query-only action
   capture/adoption and narrow existing lifecycle/inspection-preservation hooks.
5. `apps/companion/Sources/CompanionKit/Contract.swift` — additive operation/reply.
6. `apps/companion/Sources/CompanionKit/ProcessService.swift` — AK argv/EOF,
   complete 8192-byte cap and distinct decode arm; no metadata diagnostic.
7. `apps/companion/Sources/ThreadmarkCompanion/main.swift` — mount actual Query
   filter controls and disabled empty/invalid Query action; existing rows/Inspect.
8. `apps/companion/Tests/CompanionKitTests/CompanionTests.swift` — one exhaustive
   rejecting fake arm; no inherited expectations changed.
9. `apps/companion/Tests/CompanionKitTests/QueryFilterTests.swift` — strict frame,
   fake-service explicitness/lifecycle, preservation and separate-consent tests.
10. `apps/companion/Tests/CompanionKitTests/LiveQueryFilterTests.swift` — actual
    CLI two-list/full-policy/Inspect/stale/Forget/dispatch-race and hostile-process tests.
11. `apps/companion/Tests/QueryFilterFixtures/query-filter.c` — exact 145 arguments
    excluding executable (argc 146), canonical 64+64 lists, both modes and EOF.
12. `apps/companion/Tests/QueryFilterFixtures/check-api.sh` — ordinary-import
    positive model/full-bound read and negative lifecycle/publication/construction probes.

New files are staged **only** so the tracked-file secrets scanner includes them;
existing owned modifications remain unstaged. Primary must use `git diff HEAD`,
not only index or unstaged diff. No implementation commit, push, PR, CI run/head,
independent review or integration SHA exists in this implementation child.

## Product and authority boundary

Default is ALL approved files through the unchanged old bound Query route. An
explicit opt-in selects 1..64 distinct paths from **current registered Project.sources**,
not the editable source-policy draft, a file picker or discovery. Empty selection
disables Query and explains why; neither invalid nor failed filtered Query falls
back to all files. Selection is copied into captured full-policy order. Choices,
appearance and radius changes never call AK; only explicit Query dispatch does.

The mounted disclosure is: **“Query results only; Context/Refine use separate
settings and full approved scope”**. File choices never alter the existing
Source Query/Context matching setting or Refine's independent retrieval mode.
Context and Refine retain their reviewed full-scope operations and their existing
consent gates; a filtered Query neither invokes them nor authorizes transmission.
Even an empty Query filter does not shrink or disable explicit Context preparation.
Changing file choices revokes old pending consent through existing cancellation;
it does not manufacture replacement consent. No prepared-engine wire mode added.

The private action freezes full Project root bytes/identity/incarnation/ordered
FULL policy/nullable snapshot, raw query bytes, mode, canonical subset, model owner,
generation, configuration generation and scope revision. The existing registry
cancels and joins predecessors before successor metadata/service/spawn. Filter
edits immediately remove old Query display/inspection eligibility without changing
loaded human history, editor revision, edit base, original or CAS-conflict state.
Policy staging while filtering retains those human values too. Existing explicit
project-selection/configuration and authoritative namespace-replacement clearing
remain unchanged; they are not late-reply adoption or migration to a new binding.

Query-text/mode/filter/settings/policy/Build/Forget/selection/configuration/Cancel/
Quit invalidation drops late replies. Inspection continues to use AB membership,
generation tickets and the **full captured Project**, never a reduced Project
derived from selected results. Forged/unselected/old coordinates/text/producers
cannot acquire inspection eligibility from a filtered display. No public action
owner, registry, lifecycle state, publisher, decoder or frame constructor.

AK owns full binding comparison before source authority and its existing complete
freshness/publication checks. AL dispatches that complete bound request directly:
no project-show precheck, unbound ID reload, replacement metadata adoption, path
normalization, diagnostic writable probe, automatic retry or wide fallback. The
closed response has AK's actual incarnation/root-identity/snapshot fields; root
path bytes are captured in the request, not invented as an echoed wire field.

Whole stdout including LF is <=8192, with complete JSON, exact closed keys at
each level, decoded duplicate-key rejection, exact selected-path order/mode/scope,
integer type/range/count/truncation consistency, selected+approved paths, bounded
anchor/text/hash/producer/currentness/coverage, exact literal ASCII matching or
ranked terms/scores/order. Stale responses cannot carry results. The original
frame is retained, decoded again and compared byte-exactly with the typed display
projection at adoption; a forged typed projection cannot bypass its original frame.

This is an OUTPUT CANDIDATE filter, not permissions or filesystem scope. ALL
approved files are still freshness-read; changed/unsafe unselected files may make
the whole snapshot stale. No source-I/O avoidance, privacy lease, filesystem lock,
WAL strengthening, CPU/AST/semantic/performance gain or complete comprehension claim.

## Verification evidence

All fixtures synthetic; local Swift **6.4**, not proof of Swift 6.1.2 CI portability.

| Acceptance | Actual evidence |
| --- | --- |
| AL-A1 | Fake service counts prove default old route, zero calls for filter/radius choices, canonical current-policy selection, rejected unknown paths, disabled empty Query and no all-files fallback. Actual mounted SwiftUI controls compile with labeled native toggles and Query action; no GUI/AX run claimed. |
| AL-A2 | Actual CLI and C fixture accept both 64-approved/64-selected lists in both modes. C checks every ordered argv element, mode, full binding and stdin EOF. Exact raw literal/ranked query bytes retained. Decoder tests reject wrong paths/filter/order/mode/provenance, malformed types/numbers/counts/scores/truncation, extra/duplicate/escaped duplicate keys, duplicate coordinates, partial/extra frames, nonselected entries and >8192 bytes including LF. Exactly 8192 including LF accepted. Fake forged typed projection rejected again at model adoption. |
| AL-A3 | Continuation-owned cancellation-ignoring A tests: subset/query/mode/settings/policy/selection/config/Build/Forget/source-Forget/Cancel/Quit/invalid successor input. No successor service call overtakes A teardown; no canceled A display or A reply becomes B. Selection to beta adopts only intentional successor metadata after join. |
| AL-A4 | Actual filtered z.rs row survives 63 earlier stronger unselected matches, then existing explicit Inspect succeeds with full 64-source policy. Fake membership rejects nonselected old anchors; filter edit clears display/window/eligibility. Existing AB forged text/producer/coordinate and full-bound inspection regressions remain unchanged and pass. |
| AL-A5 | Actual unselected edit and symlink stale the entire snapshot with no results. Actual source Forget invalidates old capture; fresh capture rejects forgotten selected path; rebuild cannot resurrect it; source bytes and independent human note remain. Actual peer root/identity/incarnation/policy/snapshot changes between capture and dispatch reject with no B response. Existing AK private-before-source/WAL publication fences also pass unchanged in full Rust gate. Same-namespace errors/timeouts/cancellation preserve human history/editor/original/edit base/CAS conflict; authoritative namespace error follows existing clearing. |
| AL-A6 | Explicit separate Context and Refine preflight tests in both existing modes use complete approved policy even after filtered Query and empty file selection. No automatic preview/consent/provider call; filter edits revoke stale consent. Existing prepared/ranked/retained/Refine regression suites pass unchanged; no live provider invoked. |
| AL-A7 | Full checks below; original six API gates retained plus new seventh, C fixture built/enabled in CI. |

Final local gates:

- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **PASS**, **387 Rust tests +
  two doctests**, formatting/build/all-target clippy/rustdoc, finite diagnostics,
  local doc links and failing-test rejection sentinel. Existing 300/30-second
  deadline fixtures stay ignored and were **not** rerun.
- `cargo deny --locked --offline check`: **PASS** (local cached advisory freshness).
- Documented SDK-isolated Swift wrapper, strict concurrency/warnings-as-errors,
  serial full Debug: **284 tests / 45 suites PASS**; same full Release: **284 tests /
  45 suites PASS**. Actual CLI and all six C fixtures enabled in both.
- All seven ordinary-import API gates: **PASS**. Original retained, inspection,
  comparison, human-kind-filter, coverage and incremental gates unchanged.
- Staged-new-file `python3 scripts/secrets.py`, unstaged/staged whitespace:
  **PASS**, including secrets rejection sentinel.
- Release bundle and `plutil -lint .../Contents/Info.plist`: **PASS**; not launched.

The first full Release invocation hit the harness's 120-second command timeout
after compiling and entering tests; it was **not** counted as a pass. After
confirming no Swift test/compiler remained, a bounded 600-second invocation of the
same final source completed successfully. Its test run took 59.187 seconds.
The wrapper is a SwiftPM command wrapper, not a `--version` wrapper; a version
probe through it rejected `--package-path`, then `xcrun swift --version` supplied
the actual 6.4 toolchain above. Neither issue was a product/test failure waiver.

Ignored local evidence logs: `target/unit-al-check.log`, `unit-al-deny.log`,
`unit-al-api.log`, `unit-al-full-debug.log`, `unit-al-full-release.log` (interrupted),
`unit-al-full-release-complete.log`, `unit-al-secrets.log`, `unit-al-bundle.log`.
These may contain local paths and are not public artifacts or tracked payload.

## Reproduction / tested identity

Full tested baseline HEAD **`a834ad378beb3dfd3405ccb6167af1515798b916`** plus the
uncommitted owned payload. Payload SHA-256:
**`3377fc6988ae09a0d1210832c0c69f593d66cecdb7e8f2a36c2736f32b4e7a40`**.
Hash the twelve inventory paths above in lexical relative-path order, concatenating
each UTF-8 relative path + NUL + exact bytes + NUL. Exclude this document to avoid
self-reference. New files are staged; use all working-tree bytes for the hash.

Reproduce Rust/deny/secrets/whitespace with the commands above. Build every C
fixture using the SDK-isolated clang commands in `.github/workflows/ci.yml`,
including retained fixture mode copies; set **all seven** `THREADMARK_*` environment
variables in that native step to this checkout's absolute target paths. Then run:

```sh
sh apps/companion/scripts/swift.sh test --no-parallel --disable-xctest --enable-swift-testing -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
sh apps/companion/scripts/swift.sh test -c release --no-parallel --disable-xctest --enable-swift-testing -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
sh apps/companion/scripts/check-retained-api.sh
sh apps/companion/Tests/SourceInspectionFixtures/check-api.sh
sh apps/companion/Tests/ComparisonAPIFixtures/check-api.sh
sh apps/companion/Tests/HumanSearchFilterAPIFixtures/check-api.sh
sh apps/companion/Tests/CoverageFixtures/check-api.sh
sh apps/companion/Tests/IncrementalBuildFixtures/check-api.sh
sh apps/companion/Tests/QueryFilterFixtures/check-api.sh
sh apps/companion/scripts/bundle.sh
plutil -lint apps/companion/dist/Threadmark.app/Contents/Info.plist
```

No Rust/backend, AJ Batch/staged-plan/Context editor methods or mutation-authority,
Context engine, Refine consent, schema/dependency/lock/site/provider/retained/export/
marker semantics changed. No subagents, implementation commit, push/PR/remote CI,
credentials/egress/spend/deploy/Docker/GUI/AX/host launch. Primary owns independent
review, integration, exact published SHA and exact-head CI; no phase closure.
