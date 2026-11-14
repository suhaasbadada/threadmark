# Unit Q — bounded native textual review comparison

**TM-04–TM-07, TM-10; partial P4-A1/A3.** Implements the original/diff surface
in [Phase 4 preparation step 6](../spec/phase-4-refinement.md), on the
[mounted retained workflow](unit-o-mounted-retained-review.md). This is a textual
comparison, not semantic fidelity, intent preservation, GUI/AX or host certification.

## Base and owned handoff

- Initially clean prepared head: `661bdb3e11118efe979cc7adf06c39db723bf133`.
- Authorized normal `git merge --no-edit` of required local base
  `9b900717337c03e84281587c9fa8e54bcc131ea9` produced merge-only head
  **`6e09a14a60470f2c46f48da650c5bb8e9aa0bc2c`**. Its parents are exactly
  those two full SHAs, in that order. Separate prepared contract/site history is
  preserved. No reset, branch switch or new worktree occurred.
- Implementation remains **uncommitted**. Tested identity is the full merge head
  plus the five runtime/test files below. SHA-256 of `git diff HEAD --` over just
  those five paths (in listed order):
  **`3a5716d8fbdec7ff0690435aa7a852b02a38192636b9f335d6eca6e1527a61cb`**.
  Git emits file diffs in its normal path order. This document is excluded from
  that runtime fingerprint.
- Coordinator integrates **only the owned diff**, not base/site merges. No
  implementation commit, push, PR, release, deployment, GUI launch, permission
  change, credential use, dependency, lockfile, schema or global configuration
  change. No subagents, polling, reminders or watchers.

Owned inventory:

| Path | Change |
| --- | --- |
| `apps/companion/Sources/CompanionKit/ReviewTextDiff.swift` | New internal pure byte-exact line model, declared budgets and explicit fallback. |
| `apps/companion/Sources/CompanionKit/ReviewTextDiffView.swift` | New internal selectable verbatim full texts, expanded textual comparison, line-ending labels and inspectable changed-line bytes. |
| `apps/companion/Sources/CompanionKit/RefinementPreviewView.swift` | Narrow retained mounting; approved comparison uses actual engine value; unsaved editor disclosure. |
| `apps/companion/Tests/CompanionKitTests/ReviewTextDiffTests.swift` | Five presentation/model fixture tests, including exact reconstruction and adversarial boundaries. |
| `apps/companion/Tests/CompanionKitTests/ReviewTextDiffModelTests.swift` | One actual-model lifecycle test with ready/questions branches and an owned synthetic loopback peer. |
| `docs/progress/unit-q-bounded-textual-diff.md` | This evidence, limitations and handoff identity. |

No common model, consent DTO, `RetainedReview*.swift`, ProcessService, Rust,
provider or CLI implementation changes. Unit P's retrieval-mode work is separate.

## Presentation and bounds

Full unchanged original and full proposed text stay visible and manually
selectable. The comparison defaults expanded and can be collapsed with a standard
SwiftUI DisclosureGroup. Labels say Context, Removed or Added independently of
color, with old/new line numbers. LF, CRLF and absent final newline are explicit;
empty lines/text have presentation markers. Changed rows offer selectable exact
UTF-8 hexadecimal bytes, including ending bytes, so invisible whitespace and
canonically equivalent Unicode differences are inspectable. Prose uses only
verbatim Text; Markdown, HTML, URLs and directive-like strings are inert text.

The algorithm scans bytes and compares shared leading/trailing whole lines.
The middle is shown conservatively as all Removed then all Added; it does not
claim exact/minimal middle alignment. Runtime and storage are linear in bounded
input bytes, not quadratic in line count. Limits: 4096 original bytes, 8192
proposed bytes, 512 combined logical lines. Exceeding either budget produces an
explicit reason and **no aligned rows**, with both full strings still visible.
No normalization, trimming, automatic clipboard operation or silent truncation.
Empty text is zero lines; a terminal LF belongs to the preceding line. Lone CR
remains literal content and is inspectable in the byte disclosure.

The preview comparison uses the retained captured original and latest engine
proposal. Explicit Edit updates that proposal; unsaved fields are explicitly not
represented as an engine preview and cannot enable prepared approval. Once
approved, the comparison uses only `approvedValue.text`, including an unchanged
original when explicitly selected, rather than mislabeling the remaining proposal
as approved. Existing material questions, challenge-bound actions and disable
rules are unchanged. Comparison is pure presentation; no inference, approval,
delivery, host draft mutation, persistence or content-bearing artifact is added.

## Acceptance evidence

| Stable acceptance | Evidence |
| --- | --- |
| P4-A1 (textual subset only) | Exact old/new reconstruction across Unicode combining forms, emoji, CRLF/LF, lone CR, tabs/spaces, empty/trailing lines, identifiers, negations/exclusions and directive-like prose. Canonical equivalents are Removed/Added with different hex bytes. This does not prove preserved meaning. |
| P4-A3 | New actual-CLI/model test invokes only public model actions: preview → Edit → stale challenge rejection → fresh prepared approval; questions survive Edit and block prepared approval, then explicit original produces the unchanged approved comparison. Original draft remains byte-exact; one provider request, no reinference from diff/Edit. |
| P4-A3 bounded output | At/over byte and line limits, multibyte limits, 4096/8192-byte single lines, thousands of all-newline/many-line inputs, identity and conservative middle alignment; no truncation or invented alignment. |
| Lifecycle regression | Full native suite includes existing mounted-model cancellation, dependency/provider failure, stale binding, source changes, child reaping and no persistence tests. New tests never directly start/synchronize/edit the internal controller. Pure view fixtures do not manufacture controller state. |

Synthetic data only. The new loopback peer uses bounded nonblocking I/O,
accepts one request, closes its accepted socket, and is stopped/joined before its
listener closes. Actual CLI tests use private temporary fixture roots/stores,
removed by existing fixture cleanup. No real provider or external egress, Docker,
host capture, execution or permission request.

## Verification and exclusions

Actual CLI and all ten hostile C fixture modes rebuilt from this checkout with
the commands and command-local SDK isolation in
[adapter reproduction](native-retained-review-adapter.md). All Swift commands
used `sh apps/companion/scripts/swift.sh`, strict complete concurrency and source
warnings-as-errors, with actual CLI/C fixture environment variables set. No plain
Swift or global SDK/header changes. Existing SwiftPM native-backend deprecation
and Testing deployment-target linker warnings remain.

| Gate | Result |
| --- | --- |
| `cargo build --offline --locked -p threadmark-cli` | PASS. |
| Isolated C11 `-Wall -Wextra -Werror` fixture build and ten mode copies | PASS. |
| Final strict full native debug `--no-parallel` | PASS: 163 tests / 22 suites. |
| Final strict full native release `--no-parallel` | PASS: 163 tests / 22 suites. |
| `CARGO_NET_OFFLINE=true python3 scripts/check.py` | PASS: Rust format/build/Clippy/tests/rustdoc, diagnostics, links and intentional failing-test rejection. |
| `cargo deny --offline --locked check` | PASS: advisories/bans/licenses/sources. |
| `python3 scripts/secrets.py` after staging owned new files | PASS; rerun with this evidence staged. |
| Unstaged and staged `git diff --check` | PASS. |
| GUI/AX, keyboard/assistive technology runtime, semantic/live-model quality, host delivery, independent review, exact integrated-head CI | NOT RUN; coordinator/external gates. |

An initial debug compile exposed the same SDK State macro-name collision already
avoided in the existing editor. A local generic State typealias, matching that
pattern, resolved it. An initial full release invocation exceeded the harness's
120-second command timeout after building/starting tests; it is not claimed as a
pass. The bounded 240-second rerun and final exact-diff runs passed. Final process
inspection found no retained test/CLI children. No failures were waived.

Ignored local logs are `target/unit-q-{cli,check,deny,secrets,full-debug,full-release,full-release-rerun,final-debug,final-release}.log`.
Ignored compiled artifacts and the worktree remain intact. No content is saved by
the new feature. **Remote CI run/head: none for this diff; independent review:
not performed by this implementation lane.** Prior published heads do not certify
this diff. Primary owns integration, independent review, exact CI and any authorized
merge. Local tests do not close Phase 4 or certify accessibility.

Plum lookup returned `thread_not_found`; no coordination or external response is
pending, and no follow-up was scheduled.
