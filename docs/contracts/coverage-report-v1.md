# Bound metadata-only coverage report v1

Unit AD; TM-01–TM-04, TM-07, TM-10; partial P2-A1/A2/A3/A4/A6.
This is lexical inventory/currentness, not semantic completeness or Ready.

## Request (frozen before implementation)

`Store::coverage_report(&Project, cancel)`; daemon `CoverageReport(Project)`.
No unbound form. CLI:

```text
threadmark --data-dir EXISTING_STORE project coverage PROJECT --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-snapshot HASH|none --expected-sources [FILE ...]
```

Closed grammar, exactly once in that order, complete ordered policy (0..64), no
stdin or prompt. Validate shape before opening the existing-only READ_ONLY
inspection store. Reject WAL in the database header before SQLite opens it; never
normalize journals, create storage, migrate, index, discover, recurse or infer.
Bindings are stale-approval metadata, not authenticated transport. Only captured
registration authorizes source access. Match root bytes/identity/incarnation,
ordered policy and snapshot (including explicit none) before first source access.

Validate the complete stored manifest hash, schema, identities, path ordering and
bounded evidence membership/hash/coordinates before filesystem access. A missing
baseline requires null manifest and zero evidence. No database path grants access.
Use the same captured Project for both bounded scans and publication validation,
within a DELETE read transaction that fences peer commits. Any observed change
between scans fails the whole request. Recheck store dependency, binding and cancel
before publication. Kernel I/O is cooperatively bounded, not a hard deadline or
external authorization lease. Unavailable observations remain unknown.

## Response

`format=threadmark-coverage-report`, `version=1`, project, root_identity,
incarnation, historical `baseline_snapshot` (null if absent), `coverage=lexical-only`,
`semantic_completeness=not-assessed`, `review_scope=explicit-approved-files-only`,
ordered `files`, and `summary`. No absolute paths, source/human text, OS errors or
private filesystem details. Each file has relative path, `baseline_exists`,
`stored_anchor_record_count` (records, not semantic proof), nullable
`current_metadata` (byte/line count and current hash), `baseline_matches`, and status:

- `current`: full stored file identity and hash match, readable nonempty file;
- `readable-empty`: zero-byte readable file, with baseline_matches separately stated;
- `changed`: stored identity matches but hash differs;
- `replaced`: stored identity differs, even with identical content;
- `unindexed`: readable file with no baseline (except readable-empty);
- `unavailable-or-unsafe`: opaque file-specific read refusal; never missing versus
  permissions/unsafe speculation, never a stored hash relabeled as current.

Summary counts approved/readable/unavailable/matching files and stored anchor
records. `project_snapshot_current` requires a baseline and every approved file
readable and fully matching. Empty policy never implies semantic completion.
`needs_build` is true for an absent or observed mismatching baseline, null when
only unavailable files prevent deciding, otherwise false; `needs_readability_review`
means unavailable sources. Neither triggers Build. Restoring bytes/identity can
recover diagnostics without Build; explicit Build alone replaces the baseline.

Source-local failures do not suppress other approved files. Registration/policy,
store/schema/dependency, corruption, cancellation and byte/line/row/output budget
failures fail the whole operation without partial JSON. Existing descriptor
NOFOLLOW/root identity/device/hardlink/FIFO/nested-repo containment applies. Each
scan: 64 KiB/file, 1 MiB aggregate including failed partial reads, 4096 lines/file;
at most 64 files and 16384 stored records. Entire escaped JSON plus CLI newline
<=65536 bytes, fail rather than truncate. No persistent or source mutations.

## Stable acceptance IDs

- **AD-A1 (P2-A1/A6):** complete binding, ordered policy/Unicode byte shape,
  explicit none, mismatch before first source access, closed pre-open CLI.
- **AD-A2 (P2-A2/A4):** actual core/daemon/CLI register/index/report journey,
  full policy, empty/unindexed/zero-anchor, mixed currentness and recovery.
- **AD-A3 (P2-A3/A6):** source containment and failed-read aggregate accounting,
  cancellation and row/line/escaped-output budgets, no partial publication.
- **AD-A4 (P2-A1/A3):** publication source changes, peer revocation/replacement,
  dependency/manifest/evidence corruption, WAL existing-only read-only refusal.
- **AD-A5 (P2-A3/A4):** exact source/store/history preservation, Forget/rebuild
  omissions and explicit recovery without automatic Build.

No native UI/provider/refinement/export/marker/schema/dependency changes, listener,
phase closure or semantic percentages. Progress records actual evidence and gaps;
primary independent review and exact integrated-head CI remain separate gates.
