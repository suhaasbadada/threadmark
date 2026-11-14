# Native source Forget and namespace-safe mutations

Requirements: TM-01–TM-04, TM-07, TM-10; partial P2-A1/P2-A3/P2-A5 and
P3-A3/P3-A4/P3-A5. Exact tested integration:
`011b73d413e4154cf205a1588712aa8b27f30d30`, based on PR #50 merge
`86dba4cd1e442c5e704e55f38fef4e7c69b5683e`. Ancestry integration changed no
reviewed tree content. Bob implemented; the coordinator owns publication.

## Native source lifecycle

Explicit v4 marker inspection enables the selected registration's source Forget
controls. Confirmation is immutable, Cancel-default and bound to exact root,
filesystem identity, registration incarnation and displayed file policy. It uses
only the already-reviewed bound CLI/core variant, never operator-only idempotence.
Warnings distinguish source-derivative loss/suppression from repository-file or
human-history deletion and from forensic erasure. No automatic upgrade follows;
legacy stores receive explicit v4/worker-stop guidance without a false capability
claim. Fresh project checks before/after marker reads verify the exact remaining
policy and incarnation before success. Receipt/marker validation is strict and
bounded; uncertain/canceled outcomes block further source actions until Refresh.

Confirm stops/joins automatic metadata/index work and clears derived previews,
not unrelated human drafts/history or the original request. Namespace changes and
human Forget still clear the appropriate editor state; same-namespace source-policy
changes preserve unsaved human text. No native source-file removal or content
archive is implemented. Source marker inspection is non-content, not an unforget
or restore action.

## Review finding and namespace repair

Joffrey found a medium issue in the surrounding policy-Apply path: checking only
returned ID/sources could adopt a peer-replaced registration while retaining the
old namespace's human editor/original/context list. Merely checking after a write
would also be too late to protect replacement policy. Bob added bound policy
replacement plus native human write/retire bindings, with root/incarnation checks
before mutation and inside transactions. Policy replacement additionally requires
the exact captured old file policy. Native cached mutations have no unbound fallback.

Replacement metadata is never adopted with old drafts. Detected replacement clears
namespace state and requires Refresh; uncertain failures preserve unadopted drafts
while blocking mutation. Context/history publication is bracketed by namespace
checks. Deterministic other-root/same-root reuse and policy-conflict tests prove
replacement policy/history/evidence remain unchanged. Joffrey independently closed
the finding and passed targeted model/live-core/core/parser tests. An ignored build
symlink disturbed by a plain Swift test invocation was restored through the normal
wrapper; source/user work was not changed by that attempt.

## Integrated verification and open gates

The coordinator rebuilt the exact integrated tree and passed 136 Rust tests plus
two doctests through the full formatting/lint/docs/smoke/links/negative gate, and
all 105 strict Swift tests across nine suites using the rebuilt actual CLI. A
synthetic CLI acceptance driver also verified export/rebuild suppression,
idempotent-repeat receipts and source/human/other-project preservation; its fixture
was removed. Bob's release bundle/plist passed. Dependency policy, staged secrets
and whitespace checks passed. No schema/dependency/generated lock changed.

Remote exact-head CI/PR outcome remains subsequent. GUI/accessibility and platform
fixtures, native upgrade UI, further cached-read hardening, live providers/hosts
and phase closure remain open. No real user source was forgotten or store migrated.
All inherited appends, user work, worktrees and orchestration reminders remain.
