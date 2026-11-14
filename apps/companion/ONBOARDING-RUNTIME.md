# Native onboarding and isolated launch (Lane A)

Scope: TM-01–TM-04, TM-07, TM-10; partial P3-A1/P3-A6 and P4-A1–P4-A3.
This is the local lexical/Context journey, not AI refinement or a certified host.

Build with the command-scoped SDK wrapper:

```sh
sh apps/companion/scripts/swift.sh build -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
cargo build --locked -p threadmark-cli
```

Launch the built `ThreadmarkCompanion` directly, or the packaged app's executable,
with paired **absolute** `--core-binary` and `--data-dir` paths. Select your trusted
`target/debug/threadmark` core and an explicitly isolated synthetic store. No
environment lookup, remembered configuration, default store, scan or core command
runs at launch. The store can be an existing core store or a new child of an
existing folder; core, not the app, validates/creates storage on explicit actions.
No login item or global setting is written. Do not use real project/store data for
acceptance testing.

`--validate-launch-config` checks arguments and filesystem selection without
starting AppKit or invoking core. It does not certify the binary or validate a
store schema. Unknown/duplicate/unpaired arguments and unavailable selections exit
2 with content-free diagnostics. A successful validation exits 0 and creates no
store. Paths are not printed in validation output.

With no launch configuration, Manage opens at Connections. With explicit paired
configuration, it opens at Projects with an untested/configured status. This is
not a readiness claim: Refresh projects, registration or another explicit core
operation must succeed. The footer offers numbered navigation between setup,
Projects/Build and Notes/Context. Close keeps the menu-bar app alive; Quit cancels
owned operations. Automatic refresh remains off without separate consent.

## Synthetic manual walkthrough

1. Configure the trusted core/private store in Connections, or launch explicitly.
2. In Projects enter a synthetic ID, choose/type an existing absolute synthetic
   root, and inspect the displayed canonical **Root used for approval**. Approve
   exact relative file paths only. No content scan occurs on registration.
3. Open Notes/Context, add a human note with an explicit ID, and verify its history.
4. Return to Projects and Build. Inspect file/anchor counts and lexical coverage.
   Search a source token; an omitted file must never appear as evidence.
5. In Context enter an evidence query and an original request, then Prepare.
   Review the unchanged original and core-produced `ready-for-review` preview.
   Empty/stale evidence must instead show `needs-input`, not invented expertise.
6. Cancel/dismiss the preview: no send/inference/copy occurs and the original
   stays in memory. Cancellation does not clear the human text editor either;
   project changes and confirmed Forget have separate clearing semantics.
7. Make an approved synthetic file unavailable, Build, inspect the visible failure,
   restore it and retry. Human history must survive. Close/reopen Manage and Quit
   are separate lifecycle checks, not equivalents of cancellation.

Stable accessibility identifiers identify registration ID/root/approval, Build,
evidence search, human ID/draft/save and Context prepare/dismiss. Native labels
remain descriptive. These identifiers enable focused app-only AX inspection;
they are not proof of accessibility acceptance. No desktop-wide capture or OS
privacy changes are required or authorized by these instructions.

## Runnable checks

```sh
python3 apps/companion/scripts/test-launch-configuration.py apps/companion/.build/debug/ThreadmarkCompanion
THREADMARK_CORE_TEST_BINARY="$PWD/target/debug/threadmark" sh apps/companion/scripts/swift.sh test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
```

The new `OnboardingJourneyTests` drives the production model and real bounded
subprocess/core/SQLite operations on synthetic files, including rejected traversal,
unapproved-file exclusion, note persistence, preview/draft cancellation, dependency
failure and recovery. It does **not** drive the native controls or establish AX,
keyboard, VoiceOver, visual appearance or native window-close acceptance.
