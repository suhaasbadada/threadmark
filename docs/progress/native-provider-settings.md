# Lane D — Native Connections provider settings

## Revision and ownership

- Assigned branch `t3/native-connections-profile-settings`; assigned worktree retained.
- Reviewed main merged: `530fe81c396d6984637fd00bb980bfa034e02478`.
  Local merge commit: `4117146803f1f5e16128839b5d63fd52325a7c7a`.
- Required unpublished A/B bases applied in order:
  `8b9809ed3a62a164efd9e9e01867f5e30b93678c` → `81f8731`;
  `665439e1c8ebfc18af67ab9a8e4d4c84a149322f` → `57b7c98`;
  `22e43b4d79d1e137a10ebc3351d6c9f1612e7f93` → `7922c7f`;
  `e0aad600378551cb0878f50fd1136efe9d80f50e` → `983d82c`.
- Combined dependency base: `983d82c69acc06124919765a67448867e57c1acc`.
  The two Lane A conflicts were stopped/reported, then resolved only with the
  coordinator's explicit approval: keep HEAD's incarnation/source-refresh safety
  guards and add incoming Search/context-save accessibility identifiers.
- **Own implementation / tested runtime SHA:**
  `dc4be973c713a1a8d96fda1b054d20a9bfd601c9`.
  This new evidence record is a subsequent documentation-only commit. Coordinator
  should cherry-pick only Lane D's implementation and evidence after A/B bases,
  not the dependency merge/cherry-picks again.
- Exact remote CI run/head: **none / not run**. Independent review: **not run**.
  No push, PR, merge-to-main, deployment, host launch, remote inference or spend.

## Delivered product scope

Requirements **TM-04–TM-07, TM-10**, partial **P3-A2/P3-A6, P4-A3/P4-A4**;
the mounted Connections surface also contributes to the **P3-A1** setup journey.
Specifications: [Phase 3](../spec/phase-3-background-experience.md),
[Phase 4](../spec/phase-4-refinement.md),
[local contract](../contracts/client-v1.md). None of these phases is closed.

The actual native app owns one `CompanionProviderSession` for its lifetime.
Connections mounts the existing `ProviderConfigurationView` with that session's
production `Binding<ProviderSettings>`, rather than a preview/hardcoded value.
The selected model/endpoint/locality is visible; editing an existing profile into
the form is a deliberate action. Session selection changes reset enablement.
Profile changes/enable/disable/load invalidate the current derived preview through
the app's existing `dismissPreview` cancellation boundary, preserving original
request and note editor state. This conservative existing boundary also cancels
owned operations and disables automatic lexical refresh; the UI explicitly
discloses that refresh needs renewed approval. No new shared model API was added.

Save/Load are explicit native file panels. Cancel passes nil and changes neither
settings nor status or draft state. Save changes no session settings, enablement,
preview or draft; the on-disk value is always disabled. Load validates the whole
file before any adoption, always disables inference, invalidates the old preview,
and visibly reports errors without partial adoption. No launch-time auto-load,
default profile path, user-global preferences, host settings or credential lookup
exists. Explicitly chosen files are companion app data, not external host config.

### Private file rules

- At most **65,536 bytes** before decoding, with bounded reads and full-value
  rejection; no truncation. Only profile IDs/model/endpoint/locality, selection and
  disabled configuration are written. No request, source, editor text, consent,
  key field or credential storage was invented.
- This version accepts only its own **canonical sorted-key JSON encoding**.
  Decode/re-encode equality rejects duplicate keys (including escaped aliases),
  unknown fields, extra whitespace and other ambiguous/noncanonical encodings.
  This is intentionally not a general JSON import/editor format. All profiles
  validate, IDs are unique, at most 16 profiles exist and selected IDs must resolve.
- Exact existing parent must be owner-owned **0700**, no extended ACL. Every
  directory component is opened descriptor-relatively with `O_NOFOLLOW`; no
  symlink parent or silent alias resolution. Foundation may shorten the system
  temporary-root spelling; fixtures use `realpath` explicitly, not weaker product
  traversal. Users must select a path without symlink ancestors.
- Loads require an owner-owned single-link **regular 0600 file**, no extended ACL;
  read-only 0400 files are visibly rejected by this strict policy. Symlinks,
  hardlinks, FIFOs, directories, unsafe modes and oversize files reject. Descriptor
  identity, length and change timestamps are checked before/after reading, plus
  the named file identity before adoption. ACL inspection errors reject, except
  macOS's absent-ACL `ENOENT` on an otherwise valid opened descriptor.
- Save uses a random exclusive **0600** temporary file in that opened directory,
  checks inherited permissions/ACL, writes fully, fsyncs, and publishes with
  `renameatx_np(RENAME_EXCL)`, then fsyncs the directory. **NEW filename only**:
  existing files/symlinks and competing writers are never overwritten, including
  after a native Save panel replace prompt. Temporary files are removed on failure.
  A post-publication durability error is reported as uncertain; published user data
  is never removed to manufacture rollback. No chmod/ACL repair of chosen data,
  directory creation or profile overwrite occurs.

Swift endpoint validation now follows Rust's exact case-sensitive scheme,
authority/port/path subset and canonical IPv4 exclusions (including multicast),
rather than Foundation URL normalization. Model/profile byte bounds remain equal.
The UI discloses **numeric-loopback HTTP transport only**. Remote HTTPS profiles
can be saved but are never called or labeled remote-inference-ready. Configuration
enablement is not request/content/budget consent. No fake Refine button or hidden
send was added; coordinator owns CLI/process/preparation/consent mapping separately.

The new app-specific session/file helper lives in CompanionKit so the existing
native test target can exercise the same binding and file code without a package
or shared contract change. No Rust/core/refinement/daemon/CLI, CompanionModel,
ProcessService, generated lockfile, dependency, other lane or inherited progress
file was modified by Lane D's own implementation.

## Local runnable evidence

All data synthetic; no Docker, credentials, network egress, real user stores,
installers, permission changes to GUI automation or paused-host launches.

| Gate | Result |
| --- | --- |
| `python3 scripts/check.py` | PASS; workspace format/build/strict Clippy/tests/rustdoc, bounded CLI/daemon smoke, docs links, intentional failing-test rejection; rebuilds actual core |
| `cargo deny --locked check` | PASS; advisories/bans/licenses/sources |
| `sh apps/companion/scripts/swift.sh build -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors` | PASS; native executable built |
| `THREADMARK_CORE_TEST_BINARY="$PWD/target/debug/threadmark" sh apps/companion/scripts/swift.sh test --disable-xctest --enable-swift-testing -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors` | PASS; **117 tests in 12 suites**, actual rebuilt CLI/SQLite enabled, none skipped |
| `python3 scripts/secrets.py`, after staging only owned new files | PASS; tracked-file scan and synthetic secret rejection |
| `git diff --check`, `git diff --cached --check` | PASS |

Eight new Swift tests cover canonical/duplicate/ambiguous/malformed/oversize values,
Rust endpoint boundaries, all-profile validation, new-file save/load-off,
permissions/readonly/ACL/symlink/hardlink/FIFO boundaries, eight simultaneous atomic
savers with exactly one winner and no leftover temporary files, canceled selections,
visible errors/no partial adoption, production mounted-binding update/enable/
selection invalidation and exact selected model use. Native AppKit/SwiftUI mounts
are compiled; constructing the form and exercising its actual binding callbacks
is **not** a GUI click/accessibility walkthrough.

The new actual-core regression builds only an approved synthetic source, writes a
human note, prepares a real Context preview, then proves that Save/cancel/failed
Load retain that preview while profile update and successful Load invalidate it.
Original request bytes and persisted human-note history remain intact. No provider
operation is available from these settings paths. Initial fixture failures exposed
Foundation's shortened temporary-root spelling and macOS's absent-ACL return; those
fixtures/inspection handling were corrected, not symlink/permission checks waived.

The wrapper's native-build-system deprecation and Testing-framework macOS-14 versus
package macOS-13 linker warning remain tooling limitations, not macOS-13 runtime
certification. Plain Swift was not substituted for the documented SDK wrapper.

## Remaining gates / exclusions

- Actual GUI Save/Load/button/focus/VoiceOver/light-dark journeys remain **blocked /
  unverified** by the already recorded `osascript` assistive-access error **-1728**.
  No broad automation retry, screenshot, permission change or GUI claim was made.
- Coordinator must integrate with its runtime process/CLI/provider preparation and
  consent owner, rerun exact-integrated-head checks, obtain independent review and
  exact-head CI. Its runtime owner must consume this session's selected settings
  and invalidate any future provider consent/late responses as well; settings alone
  neither create consent nor make inference ready.
- Remote TLS/authentication, secure key entry/storage, host capture/handoff, held-out
  semantic quality evaluation (**P4-A5**), real-user migration/retention policy,
  background inference, daemon listener, installation and phase closure excluded.
- No native app or paused OpenCode host was launched; local callback/real-core tests
  and native build are separate from GUI acceptance and deployment readiness.

## Coordinator integration and review repair

The primary integrated the reviewed PR51-safe onboarding commit `81f8731` and
Lane D's own commits onto PR #53 merge `b65e3515949ae6b89e04660fe419f34bb4fe2223`.
Exact tested runtime: `2d67d8a75daee6a523f8175891f18a15df5d8d0e`.
PR51 incarnation/source-refresh guards remain intact; no old weak guard was adopted.

Joffrey independently reviewed launch, onboarding, mounted state and private file
admission/publication. A medium finding exposed enabled-profile deselection:
validation rejected enabled-plus-None before the selection change could disable
inference. The primary now normalizes profile/selection changes to off before
validation. The production binding regression covers None with and without profile
deletion, and proves one invalidation plus no duplicate Picker-follow-up callback.
Invalid candidates still preserve previous settings. Joffrey independently closed
the finding and passed nine targeted tests, including actual-core invalidation.

Primary verification passed: full workspace gate (153 Rust tests/two doctests),
118 strict-concurrency Swift tests using rebuilt core, seven actual-app launch
validation cases, dependency policy, tracked secrets and whitespace checks.
The launch driver initially lacked its required executable argument; invoking the
documented command passed, without a product change. No GUI permission was granted
or desktop captured, and no live endpoint/host was called. Native GUI/AX remains
blocked/unverified; exact remote head/CI and process-consent integration are later
gates. Nine inherited progress-file appends remain excluded and untouched.

## PR #54 publication outcome

PR [#54](https://github.com/suhaasbadada/threadmark/pull/54) passed all five checks
on `592b145ab970f785d48c93b73b3846a058192318`: CI
[43552360767](https://github.com/suhaasbadada/threadmark/actions/runs/43552360767)
and integrated [43552361101](https://github.com/suhaasbadada/threadmark/actions/runs/43552361101).
Fresh exact-head/main/rules/discussions checks found no blocker; the recorded
review/recheck and local acceptance applied. It merged at `2026-11-14T03:53:32Z`
as `9daf74e9823e8037963b3ba46e28af2ff406584f`; the watch was removed. Separate
exact post-merge CI [43553914092](https://github.com/suhaasbadada/threadmark/actions/runs/43553914092)
and integrated [43553913999](https://github.com/suhaasbadada/threadmark/actions/runs/43553913999)
both passed. This does not certify GUI/AX, live inference or host delivery.
