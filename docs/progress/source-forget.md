# Source-derived Forget and explicit v4 upgrade

Requirements: TM-01–TM-04, TM-07, TM-10; partial P2-A1/P2-A3/P2-A5/P3-A4.
Exact tested integration: `74652f1e23ff99b9e68740a8be0467bffaa75698`, based on
PR #49 merge `13a867c9b492c811d7177e8f18884ffa8cbece01`. Ancestry integration
changed no reviewed tree content. Bob implemented; the coordinator owns publication.

[Source Forget v1](../contracts/source-forget-v1.md) was independently reviewed
before coding. Canonical v4 objects add relative-path suppression and policy,
evidence and removal guards, retaining existing human Forget and incarnations.
New stores initialize v4; existing v1/v2/v3 stores never silently migrate. Explicit
upgrade requires schema confirmation and legacy-worker-stop attestation. The latter
is operator responsibility, not machine-verified quiescence or universal old-worker
fencing. No real user migration was performed.

Confirmed CLI source Forget never opens, reads, changes or deletes the source file.
One transaction revokes its approved path, installs its non-content marker and
invalidates the project's coherent source snapshot. Human history and other
projects are preserved. Rebuilds, query, preparation, export and source-policy
updates cannot restore/read marked derivatives. Captured index publication fails
after revocation; corrupt marker/policy/evidence overlap is rejected before source
filesystem access. Bound approval checks exact root/identity/incarnation/policy;
unbound repeats are idempotent. Project removal clears markers; re-registration
is new authority and never restores stored old content.

Marker listing is deterministic and bounded; capacity is 64 source markers/project.
Whole failures preserve policy, markers and facts. Missing/unreadable approved
files can be forgotten without accessing them. This is active derivative removal
and suppression, **not forensic erasure** or automatic deletion of human declarations
mentioning a file. Backups, journals, earlier exports and displayed copies may
retain bytes. No unforget, VACUUM, source deletion or external delivery follows.

Joffrey independently reviewed all implementation files with no substantive
findings and passed 81 core and 18 CLI knowledge tests using existing builds.
Bundled SQLite validates canonical `json_each` guards with `trusted_schema=OFF`,
including allowed updates, marked-policy rejection and transactional rollback.
The coordinator additionally corrected repeat receipts: initial revocation reports
snapshot invalidated, while an idempotent repeat reports unchanged and preserves
a later remaining-source rebuild. The full check caught an old CLI equality
assertion, which was corrected before the complete pipeline passed.

The coordinator rebuilt and verified the integrated source: 133 Rust tests plus
two doctests, full formatting/lint/docs/smoke/links/negative gate, and all 82 strict
Swift tests against the rebuilt core. Dependency policy, staged secrets and
whitespace checks passed. Synthetic fixtures cover all supported upgrade sources,
no implicit migration, idempotence, cancel/SQL/disk-full/killed-child rollback,
forward-header byte preservation, corruption/NUL/path validation, zero source
access, legacy guards, held-index/same-root races, capacity and cleanup/re-registration.

Remote exact-head CI/PR outcome remains subsequent. No dependency/generated lock
or native UI changed. Native source Forget, native upgrade UI, GUI/accessibility
and additional platform fixtures, live providers/hosts and full phase closure
remain open. No private user Forget or source scan ran; inherited appends, user
work, worktrees and orchestration reminders remain preserved.
