# Registration incarnation v1 — schema v3

Scope: TM-01–TM-04, TM-07, TM-10; partial P2-A1/P2-A3/P2-A5 and P3-A3/P3-A4.
Root/filesystem identity and a note revision can repeat after explicit project
removal/re-registration. Neither is an authorization-scope incarnation token.
This contract closes that cached-approval gap without treating local IDs as secrets.

## Canonical schema addition

Schema v3 retains exact supported v2 objects and adds:

```sql
CREATE TABLE project_incarnations(project TEXT PRIMARY KEY, incarnation TEXT NOT NULL UNIQUE);
CREATE TRIGGER threadmark_project_incarnation_insert AFTER INSERT ON projects
BEGIN INSERT INTO project_incarnations(project,incarnation) VALUES(NEW.id,lower(hex(randomblob(16)))); END;
CREATE TRIGGER threadmark_project_incarnation_delete AFTER DELETE ON projects
BEGIN DELETE FROM project_incarnations WHERE project=OLD.id; END;
```

Every live project has exactly one distinct lowercase 32-hex incarnation; no orphan
or missing rows are admitted. Backfill existing projects with the same SQLite
randomblob expression inside the upgrade transaction. Random-collision/SQL failure
aborts, never silently reuses a token. Exact canonical object validation and known
implicit indexes extend existing strict shape checks. The insert/delete triggers
also cover already-open older connections, so same-directory re-registration gets
a new token even when an older writer registers it. Existing Forget guards remain.

New stores initialize v3. Existing recognized v1/v2 stores remain supported without
implicit upgrades. `store upgrade --to-version 3 --confirm-local-schema-upgrade
--confirm-legacy-workers-stopped`
is existing-store-only and atomically installs any required v2 objects, v3 objects,
backfill and version. Cancellation, SQL failure, disk-full or killed process before
commit preserves the complete prior schema/data. Already-v3 is idempotent. Unknown
headers/objects/forward v4 fail before writable recovery; no guessed repair or
downgrade. The existing upgrade command without `--to-version` retains its v1→v2
behavior; on a v3 store it reports unchanged v3, never downgrades. Receipts identify
actual `schema_version`, `upgraded` boolean and exact compatibility string
`"Older binaries cannot open schema v3; no automatic downgrade."` for v3 results.
No real user migration runs during implementation tests.

V3 upgrade requires the caller's explicit attestation that older in-flight core
operations/automatic workers have finished or stopped. The extra confirmation is
not machine-verifiable evidence of quiescence and does not stop another process.
Guards maintain tokens for legacy inserts/deletes but cannot fence an old binary's
already-captured index/context mutation. The stale-operation guarantees below
apply to incarnation-aware binaries; do not claim safe concurrent legacy-worker
operation. Stop/pause older companions and let owned workers terminate before the
upgrade. No upgrade UI or automatic worker resurrection is introduced here.

## Identity and approval behavior

Project inspection/listing adds `incarnation`: a validated 32-hex string on v3,
`null` on v1/v2. Export v1 wire format is unchanged and is not an authorization or
restore capability. The token is non-content metadata, not authentication, a
credential or permission to read another root.

Incarnation-aware captured-project transaction checks bind incarnation as well as root/root identity
for mutations and index publication. A migration between preflight and transaction
must fail stale work rather than infer the new token. Same-directory/same-policy/
same-content re-registration must invalidate captured operations.

Native cached removal, automatic-refresh, policy replacement and human write/
retirement approvals require a non-null incarnation
and pass `--expected-incarnation TOKEN` through CLI/core before source access or
persistent mutation, then revalidate transactionally. Root-only explicit legacy CLI variants
remain available but must not be used as incarnation-bound native approvals.
Malformed token/binding shape fails before opening or creating storage. V1/v2
native clients show truthful explicit-upgrade guidance; they neither invent a token
nor migrate automatically. Project/config/policy changes still clear approvals.
Policy replacement additionally compares the captured old source policy inside
the transaction. Replacement metadata is not adopted with old human drafts; reads
used for context/history publication are bracketed by incarnation checks. Source-
only changes in the same namespace preserve unsaved human text.
Native human Forget additionally binds the latest human revision, as specified
in [Human-context Forget](context-forget-v1.md). Source Forget and native upgrade
execution remain unavailable.

## Acceptance and limits

Synthetic tests cover fresh v3, v1/v2 no implicit migration, explicit upgrade from
both versions, idempotence, cancel/disk-full/killed-child rollback, malformed schema/
token/cardinality and forward-header preservation. Test already-open legacy insert/
delete token maintenance (not fencing of legacy pending operations), and same-root/
same-file/same-note-revision re-registration. All incarnation-aware captured
mutations and native removal/refresh reject old incarnation without touching new
history/evidence or widening sources; ordinary source edits preserve incarnation.
Core enforcement is required, not only model checks. Retain existing Forget guards,
export format, source preservation and resource limits. No dependency, network,
credential, source-file modification, GUI launch or phase-closure claim follows.
