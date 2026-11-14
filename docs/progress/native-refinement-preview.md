# Lane H — Native local refinement consent and preview

Scope: **TM-04–TM-07, TM-10**, partial **P3-A2, P4-A1–A4**. This unit
connects the actual companion to F's finite local refinement CLI. It does not
implement Send, host admission, clipboard, persistent engine approval or a
generic executor. Context-only preparation remains provider-free.

## Dependency integration evidence

The assigned branch was clean before integration. Reviewed `origin/main`
`b65e3515949ae6b89e04660fe419f34bb4fe2223` and exact local native base
`592b145` were merged in place. Human-search dependencies
`1c49e1ab41f75d8a72c35639bd437f74f6ef9e0d`,
`5d5b36bbc80c98e5cccf1ceee5ae3b83ca1cead4`,
`136429b26abf06893b41924c97b18570a22e45dd`, and
`cddde8373653067fe6749db5a85011f04a63df1a` were merged in place.
The resulting pre-F HEAD is
`472030ae87412d780d82980c995344fea834fa60` (not tested).

Merging F `db953f0a28ac64cb08768957c4464520cf001743` initially stopped with
four dependency conflicts:

- `apps/companion/Sources/CompanionKit/ProviderSettings.swift`: reviewed
  strict endpoint parsing versus older URLComponents parsing, including
  different remote-address rejection rules.
- `apps/companion/Sources/CompanionKit/ProviderConfigurationView.swift`:
  selected-profile editing and transport disclosure present only on HEAD.
- `crates/daemon/tests/review_session.rs`: independently added loopback review
  test versus F bound-capture and preview-overflow tests at the same insertion.
- `docs/progress/provider-profiles.md`: HEAD-only evidence additions.

The primary explicitly authorized their exact resolution. Reviewed HEAD provider
files and provider evidence were retained byte-for-byte (compared against HEAD
before staging). Both Rust test groups and the macOS accepted-stream blocking
regression were preserved. The staged merge delta had exactly F's nine expected
CLI/daemon/test/documentation files, no provider-file changes. Full workspace
check passed before completing merge `3fb7fea`. CLI dispatch merged automatically
and retains both human search and refinement branches. F evidence commit
`4d152de2540cd5ea185890f679fd3e08d91eb03d` was then merged. Primary-reviewed
backend race repair `48bd8f4940f43ed11a8684ee6da4cf705b2f35c5` was applied as
dependency commit `0aee2f3`; no alternative backend fix was implemented here.
These dependency commits are not lane H implementation work.

## Native interaction and boundaries

The actual Context navigation mounts both the distinct human-text search view and
the local refinement consent/preview view. Refinement uses the current
`CompanionProviderSession.settings`, not a hardcoded endpoint or production fake.
Its existing settings-change callback immediately cancels/discards consent and
preview; confirmation also compares the entire immutable settings value.

Inspect first performs actual project/query/project reads, checks namespace,
policy, currentness and snapshot, then displays an immutable request/selection.
The sheet shows exact original, query, project/root/identity/incarnation/snapshot,
selected evidence and provenance/coverage, nonsecret profile/model/endpoint and
locality. It discloses one call, 1024 tokens, 8192 output bytes and 30 seconds,
no attachments/whole-project upload, and that a local server may forward elsewhere:
numeric loopback is not a sandbox guarantee. **Cancel is the default action.**
Missing/disabled profiles and saved remote profiles reject before CLI/network.
Only the explicit confirmation action requests F's `--confirm-local-inference`.
Original UTF-8 bytes go exclusively to bounded stdin; nonsecret flags carry F's
exact usage. Revalidation checks current project, exact query selection and project
again before invocation; F's reviewed bound capture owns authoritative source
selection/rechecks. Native preflight reads are separate operations, not an atomic
external revocation lease. Followup checks the exact project after the CLI exits.

ProcessService reuses its sole-reaper bounded child lifecycle: <=30-second child,
<=8192-byte stdout, cancellation kill/escalation/reap, no inherited credentials or
proxy environment. Replacement work joins all old operations. Original/query edits,
project/configuration/source-policy changes, settings changes and cancellation
invalidate consent and reject late callbacks. Preparation failure/cancel/dismiss
preserve original bytes and human editor revision/history; no fallback or adoption
of unknown reply types occurs.

Preview admission validates closed schema (including nested provider keys), duplicate
members/escaped aliases, bounds, exact original bytes, scope/snapshot/query, provider
identity, fixed budgets, mode/state/material questions and not-requested/not-attempted
authority labels. Empty evidence remains needs-input without invented expertise.
UI shows original/proposed/questions; generated prose remains unverified. F exits
after PREVIEW, so no Apply/Send/Copy or reusable engine approval is represented.

## Runnable acceptance evidence

`RefinementTests.swift` exercises strict receipt mutation/unknown fields, missing
fields, escaped duplicate keys, provider identity/budgets, canonical-equivalent but
byte-different originals, material questions and output bounds. Native state tests
exercise immutable consent invalidation, cancellation-ignoring late callbacks,
unknown replies, failures, no draft replacement, and human history/editor retention.

`LiveRefinementTests.swift` uses actual rebuilt CLI/SQLite and test-owned bounded
numeric-loopback HTTP peers, not a live model or production fake. It registers a
synthetic source, builds, saves human context, selects settings, inspects, cancels,
re-inspects, confirms and reviews previews with/without material questions. Wire
assertions check exact negation/Unicode/CRLF original, model/token limit and selected
source count, without human-note mixing. Malformed/duplicate provider JSON and HTTP
error reject. Missing/remote/stale/profile/namespace/snapshot cases and Context-only
preparation have zero accepted HTTP connections. Actual slow peers exercise child
timeout, cancellation and mounted session profile-change invalidation, then join
owned workers; fixture shutdown joins/closes owned sockets. No HTTP retry/fallback.

Early native verification found a missing exhaustive test-service case, then an
empty-evidence fixture exposed the legitimate needs-input-without-questions state.
Both were repaired rather than waived: empty selection admission now matches F,
and live evidence tests explicitly create matching synthetic source. Query selection
truncation metadata is retained so F's bounded-selection coverage matches exactly.
The first launch-validation invocation omitted its required executable argument;
the documented validation mode was rerun with the actual rebuilt companion and
all seven cases passed, without opening a window or creating a store.

## Exact tested implementation and local gate

Full tested implementation SHA:
`b013ea80a76f3ef5aaf54bdf4b1f843c162ed921`.
This is lane H's own implementation commit (ten native/test/progress files);
dependency merges and primary-authored `0aee2f3` are excluded from its own work.
The followup evidence commit changes only this progress document.

Passed against that implementation:

- `python3 scripts/check.py`: workspace build, fmt, Clippy, **172 Rust tests plus
  two doctests**, rustdoc, finite smokes, local documentation links and intentional
  negative assertion gate.
- `cargo deny --locked --offline check`: advisories, bans, licenses and sources.
  Offline was explicit to honor the no-egress restriction; advisory data was
  already cached, not freshly fetched.
- `python3 scripts/secrets.py` after staging only owned new files: tracked-file
  scan and synthetic-secret negative control.
- `THREADMARK_CORE_TEST_BINARY="$PWD/target/debug/threadmark" sh
  apps/companion/scripts/swift.sh test --disable-xctest --enable-swift-testing
  -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete`: **133 tests
  in 16 suites**, including all six new refinement tests. Actual core was rebuilt
  after applying the primary's bound-query repair. The strict wrapper also built
  the actual companion target. No plain Swift invocation was used.
- `python3 apps/companion/scripts/test-launch-configuration.py
  apps/companion/.build/debug/ThreadmarkCompanion`: seven validation cases, no
  GUI/core invocation or storage creation.
- Whitespace check and conflict-marker inspection passed. All owned HTTP workers
  joined and sockets closed through asserted fixture teardown; no Docker resources.

SwiftPM still reports its inherited native-build-system deprecation warning and
the test linker reports the existing Testing framework deployment-target warning;
neither is represented as GUI/platform certification. Exact remote CI run/head:
**not run by this child**. Independent review: **not run by this child**. Primary
owns publication, integrated-head review and CI. No push, PR, merge-to-main or
deployment was performed by this lane.

## Explicit exclusions

Remote CI/run/head and independent review are owned by the primary, not executed
by this child. GUI/AX remains blocked by the previously reported osascript -1728;
no GUI launch/capture or permission workaround was attempted. Actual rendered sheet,
keyboard/AX walkthrough and unsaved view-local text retention remain GUI acceptance
gates (model history/editor revision retention is tested, not fake GUI evidence).
Remote inference/TLS/auth, real-model quality, persistent native engine approval,
host draft/delivery, clipboard and live-host certification remain open. No private
real data, global configuration, credentials, installs, Docker, external server,
new dependency or generated lockfile edit was introduced. P3-A2 and P4-A1–A4 remain
partial; no phase is closed by these local tests.

## Primary integration, review and repairs

The primary integrated E's actual human-search transport/model/view and H's
mounted consent/Refine preview into its implementation worktree. Joffrey reviewed
the combined native loop and found two P2 issues: default Swift slash escaping
inflated valid Rust envelopes beyond the native limit, and two inherited
Connections/Privacy statements incorrectly denied the now implemented explicitly
confirmed local provider flow. Both were repaired in exact tested runtime
`218100e96046cca6321185a480994626d65ed91c` and independently re-reviewed closed.

Consent/preview re-encoding now uses `withoutEscapingSlashes` with the newline
inside the 8192-byte bound. Actual raw transport bounds, duplicate/schema gates,
identity binding and original-byte checks remain intact. One regression uses
actual SQLite/CLI selection from eight 1000-byte slash-heavy synthetic lines;
consent succeeds with zero provider connections, then cancellation retains the
original. A 6000-slash valid preview also passes while raw oversized input still
fails. Connections/Privacy now accurately distinguish provider-free Context,
settings and automatic lexical work from explicitly confirmed local Refine
transmission, possible local-server forwarding and unavailable remote inference.

Primary checks passed 172 Rust tests plus two doctests, 135 strict-concurrency
Swift tests using rebuilt actual core, dependency policy, staged secrets and
whitespace. Joffrey independently passed eight targeted regression/rejection/
cancellation tests. Final integration `fc3ca56d42449b4a6e240d6d4ebc8c509fcdddc6`
incorporates PR #56's merge without a runtime tree change. Release bundle build,
source/bundled plist validation and all seven launch-validation cases passed.
No GUI window was launched or private desktop captured for these checks.

Exact remote native head/CI remains required. Preliminary cached native source
reads and Context use existing namespace pre/postchecks; moving those bindings
into the core read itself is a separate active hardening lane, not a claim made
from the F inference-call binding repair. Persistent pipe review, optional ranked
preparation, GUI/AX, real-model quality, remote TLS/auth and actual host delivery
remain separate gates. Nine inherited progress appends remain untouched/excluded.
