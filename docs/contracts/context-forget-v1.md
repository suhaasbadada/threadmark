# Human-context Forget v1 and explicit store upgrade

Scope: TM-01–TM-04, TM-07, TM-10; partial P2-A3/P2-A5 and P3-A4.
This slice forgets human context, not source-derived facts. No live integration,
new dependency, import/restore, login startup or source-file modification.

## Storage and upgrade contract

SQLite application ID and 4096-byte pages stay unchanged. Schema v2 retains all
v1 tables and adds exactly:

```sql
CREATE TABLE forgotten_context (
  project TEXT NOT NULL,
  id TEXT NOT NULL,
PRIMARY KEY(project,id)
);
```

V2 installs this canonical guard DDL in the same atomic upgrade transaction:

```sql
CREATE TRIGGER threadmark_context_insert_guard BEFORE INSERT ON context
WHEN EXISTS(SELECT 1 FROM forgotten_context WHERE project=NEW.project AND id=NEW.id)
BEGIN SELECT RAISE(ABORT,'threadmark forgotten context'); END;
CREATE TRIGGER threadmark_context_update_guard BEFORE UPDATE ON context
WHEN EXISTS(SELECT 1 FROM forgotten_context WHERE project=NEW.project AND id=NEW.id)
BEGIN SELECT RAISE(ABORT,'threadmark forgotten context'); END;
CREATE TRIGGER threadmark_project_delete_guard BEFORE DELETE ON projects
WHEN EXISTS(SELECT 1 FROM forgotten_context WHERE project=OLD.id)
BEGIN SELECT RAISE(ABORT,'threadmark forget markers remain'); END;
```

These guards cover an already-open older writer/remover that cannot be forced to
recheck user_version. New removal deletes markers before deleting registration;
an older removal while markers exist fails atomically instead of leaving orphaned
suppression in a later registration. No other triggers/views are admitted by v2
shape validation. Validate exact canonical definitions, allowing only SQLite's
trailing-semicolon/whitespace normalization, not merely matching trigger names.

Markers contain only bounded local project/context IDs, never note text, hashes
of note text, source excerpts, original requests or private paths. At most 4096
markers per project; duplicates do not consume additional capacity.

New stores initialize v2. Existing recognized v1 stores remain usable for their
existing commands and do **not** migrate on open, export or reads. Forget on v1
fails before changing logical records. `store upgrade --confirm-local-schema-upgrade`
requires an existing recognized private store; missing confirmation does not open
or create it. A transaction validates the supported v1 shape, adds the marker
table and sets user_version=2 atomically. Cancellation, SQL failure or interruption
before commit preserves v1 schema, evidence and human history. Already-v2 upgrade
is an idempotent metadata-only success, not a rebuild or repair.

Foreign application IDs, unknown/forward versions, malformed schemas, insecure
roots/sidecars or replaced DB identities fail closed. Reject unsupported headers
before SQLite can perform writable hot-journal recovery, as existing behavior
requires. V2 shape includes the marker table; do not guess/repair missing objects.
Older binaries reject v2 before writable recovery; there is no automatic downgrade.
The explicit upgrade confirmation acknowledges this compatibility change. Never
run an upgrade on real user data as part of implementation tests.
Upgrade receipt: `schema_version=2`, boolean `upgraded`, and
`compatibility="Older binaries cannot open schema v2; no automatic downgrade."`.

## Forget operation

`context forget PROJECT ID --confirm-forget-local-history` requires exact
confirmation before store opening. It requires an existing v2 store/project and
valid context ID. One immediate transaction rechecks captured root/root identity,
creates the marker and deletes every revision for that target. Sources, project
registration, source evidence and other context/projects remain unchanged.
Unknown unmarked targets fail without creating a marker. An already marked target
is idempotent; the marker remains authoritative even if stale/corrupt content is
present. Capacity failure rejects the whole operation without deleting history.

Cancellation checks before staging and just before commit; staged cancel/SQL
failure rolls back both marker and deletion. The committed result is authoritative;
do not claim cancellation rolled back an operation after commit. Receipt fields:
`project` string, `id` string, `forgotten=true`, `removed_revisions` integer 0–32,
`retention_limits` bounded fixed explanatory string. No text/path/credential output.
The exact string is `"Active human-history removal and same-scope suppression only; not forensic erasure. SQLite free pages, journals, backups, earlier exports and displayed copies may retain bytes. Source files are untouched."`.

`write_context` (add/update), retirement, history inspection and normal context
listing respect markers inside their coherent operation/transaction. Same-ID
creation is rejected; no implicit restore/unforget exists. Rebuild/source-policy
changes cannot remove markers or restore text. Previously captured old-root
mutations still fail exact-root revalidation. In-flight reads that completed before
Forget cannot be recalled; a subsequent read/export cannot return forgotten text.

`context forgotten PROJECT` lists deterministic ID-ordered non-content markers:
`project` string and `forgotten` array of `{id: string}`. Whole output is bounded
at 1 MiB including newline, no prefix truncation. This is inspectable suppression,
not a retained content history. Malformed markers fail rather than grant access.

Project removal deletes its markers together with all project-local records.
Explicit re-registration is a new authorization scope and may reuse IDs; it never
restores old text. Removing/re-registering is not an automatic bypass or unforget.
Export v1 wire format stays unchanged and never includes forgotten text; export
and Forget serialize so one archive cannot mix pre/post-Forget state. Export has
no restore capability and does not purport to preserve suppression markers.

## Privacy and acceptance

Forget is active-data removal and same-scope suppression, **not forensic erasure**.
SQLite free pages, rollback journals, backups, earlier exports and already displayed
copies may retain bytes. No VACUUM/global cleanup or source deletion is implied.
No automatic recreation of forgotten entries; deliberate new context needs a new
ID, or explicit project removal/re-registration with its separate loss warning.

Synthetic tests must cover v1 fixtures, no implicit upgrade, idempotent upgrade,
unknown/forward-header byte preservation, migration cancel/SQL/interruption
rollback, full-history forgetting across reopen/rebuild, marker capacity/isolation,
post-Forget add/update/retire/show/list/export suppression, SQL/cancel rollback,
writer/removal/root-replacement boundaries, source preservation and CLI exact
confirmation/no-store-creation/content-free failures. Independent implementation
review and exact-head CI remain separate gates; no full Phase 2/3 closure follows.
Include an older connection opened before upgrade: stale writes cannot recreate
forgotten content, and stale removal cannot leave markers in a new registration.
