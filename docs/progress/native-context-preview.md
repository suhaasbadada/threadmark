# Native Context-only preview

Requirements: TM-04–TM-07, TM-10. Partial P4-A1–P4-A3 and P3-A3/P3-A5
evidence; no Phase 3/4 closure. Bob implemented the native slice; the coordinator
owns integration/publication. Exact locally tested integration:
`3c5a94789790c13b0ae713826422a23b24530ea6`, based on published PR #40 merge
`bdc7e1e714f674d856f09a4c48ad45d62d6538a2`. The ancestry merge changed no
reviewed tree content.

The Context management view now takes an explicit evidence query and original
request, runs the actual core's `context prepare` through the bounded local
adapter, and displays unchanged original plus proposed plain text. Source quotes
are labeled untrusted. No Markdown interpretation, provider, approval, copy,
save, send or host draft mutation is implemented. Missing/stale evidence remains
needs-input; a snapshot is current only at the core preparation read, not forever.

The adapter sends original text only on stdin, validates byte-exact original
preservation, exact project/mode/state and non-delivery claims, and caps the full
response at 8 KiB. Invalid responses fail with content-free errors. Model edits
immediately invalidate previews and pending preparation; cancel/failure keeps the
original draft in memory, while project/configuration changes clear scoped drafts.
Serialized operation teardown and late-result rejection remain in force.

Local strict Swift tests passed: **34 tests/four suites**, including the real Rust
CLI and private synthetic SQLite store. Parameterized tests cover ten invalidation
events and eleven malformed response variants; byte-distinct Unicode, original
stdin mapping, bounded input/output, current/stale evidence and no persisted
preview are covered. Joffrey independently reviewed all eight changed app files
with no substantive findings and reran all 34 tests against the actual core.
The coordinator reran the same tests on the integrated revision. Bob's release
bundle/plist passed. Full Rust check pipeline, dependency policy, staged secrets
and whitespace checks passed. No third-party dependency or generated lock changed.

Remote CI/PR identity is a subsequent gate, not inferred from local verification.
Native GUI launch, keyboard/assistive-technology runtime, external provider consent,
host delivery and controlled refinement-quality evaluation remain unrun/open.
Paused coding-host launches stay paused. Existing unrelated progress appends were
preserved and excluded. No deployment or product inference was performed.
