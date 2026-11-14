# Source-derived Forget v1 — schema v4

Scope: TM-01–TM-04, TM-07, TM-10; partial P2-A1/P2-A3/P2-A5/P3-A4.
Forget one previously approved relative file, never delete its repository file.
Human context is independent and is not automatically erased by this operation.

## Schema and compatibility

V4 retains exact supported v3 objects and adds canonical DDL:

```sql
CREATE TABLE forgotten_sources(project TEXT NOT NULL, path TEXT NOT NULL, PRIMARY KEY(project,path));
CREATE TRIGGER threadmark_source_policy_guard BEFORE UPDATE OF sources ON projects
WHEN EXISTS(SELECT 1 FROM forgotten_sources f JOIN json_each(NEW.sources) s ON s.value=f.path WHERE f.project=NEW.id)
BEGIN SELECT RAISE(ABORT,'threadmark forgotten source'); END;
CREATE TRIGGER threadmark_source_evidence_guard BEFORE INSERT ON evidence
WHEN EXISTS(SELECT 1 FROM forgotten_sources WHERE project=NEW.project AND path=NEW.path)
BEGIN SELECT RAISE(ABORT,'threadmark forgotten source'); END;
CREATE TRIGGER threadmark_source_project_delete_guard BEFORE DELETE ON projects
WHEN EXISTS(SELECT 1 FROM forgotten_sources WHERE project=OLD.id)
BEGIN SELECT RAISE(ABORT,'threadmark source markers remain'); END;
```

Markers contain only bounded project IDs and validated relative paths, never file
contents, hashes of forgotten content, prompts or absolute paths. At most 64
source markers per project, consistent with the approved-file budget; duplicates
consume no capacity. Validate types, byte lengths/NULs, full relative-path syntax,
project association and exact canonical objects, not just names. Existing human
Forget guards and registration incarnations remain intact. New removal deletes
source markers before project deletion; a legacy remover cannot leave orphaned
markers on re-registration. Triggers prevent old source-policy writers/evidence
inserts from restoring marked paths; they are not universal old-worker fencing.

New stores initialize v4. Known v1/v2/v3 stores remain usable without implicit
upgrade on reads/export/index. Source Forget requires v4. Explicit existing-store
`store upgrade --to-version 4 --confirm-local-schema-upgrade
--confirm-legacy-workers-stopped` atomically installs all needed prior objects,
backfill and v4 version. Both confirmations precede opening/creation; the second
is operator attestation, not machine-enforced quiescence. Stop old companions and
finish owned workers first. Cancel/SQL/disk-full/process interruption before commit
preserves the complete old schema/content. Already-v4 is idempotent. Unknown
forward v5/foreign headers fail before writable recovery; no repair/downgrade.
Older explicit/default upgrade targets on v4 report actual unchanged v4. The v4
compatibility receipt string is `"Older binaries cannot open schema v4; no automatic downgrade."`.

## Operation and suppression

`source forget PROJECT PATH --confirm-forget-source` selects exactly one currently
approved relative file. Missing confirmation or invalid binding/path fails before
opening/creating a store; the operation requires an existing private v4 store and
registered project. It never opens, reads, chmods, renames or removes a source file;
missing/unreadable files can still have their local derivatives forgotten.

One immediate transaction rechecks captured root/root identity/incarnation, removes
the path from approved sources, installs its marker, deletes the project's coherent
source-evidence snapshot and clears snapshot/manifest. Remaining approved sources
need an explicit or already-consented bounded rebuild. All human history and other
projects remain unchanged. Marker-capacity failure changes nothing. Unmarked paths
not currently approved fail; already marked paths are idempotent. Cancellation at
policy/marker/evidence/final precommit stages rolls back every change.

An optional native-safe variant requires all of `--expected-root ROOT
--expected-root-identity IDENTITY --expected-incarnation TOKEN
--expected-sources FILE ...` together and checks the exact displayed policy in the
transaction before revocation. No root-only fallback for native cached approval.
Bound calls with changed policy, absent/already marked targets or reused IDs fail
without mutation; explicit unbound CLI idempotence remains available.

Policy updates reject any marked path transactionally. Indexing/retrieval/preparation
and export cannot read/recreate/expose marked derivatives. Already captured index
work cannot publish after policy revocation. Marked content in a corrupt overlap
fails or is suppressed, never exported as trusted facts. Ordinary source edits do
not remove markers; there is no unforget. Explicit whole-project removal clears all
markers; re-registration is new authorization and never restores stored old content.

`source forgotten PROJECT` lists lexically ordered relative path markers as
`{"project":"...","forgotten":[{"path":"..."}]}`, whole JSON plus newline
at most 1 MiB, no prefix truncation. Order is relative path, not discovery order.
Forget receipt keys are exactly `project`, `path`, `forgotten=true`,
`source_authorization="revoked"`, `snapshot="invalidated"` on initial revocation
or `snapshot="unchanged"` on an idempotent repeat that preserves later rebuilds,
`human_context="unchanged"`, and `retention_limits` with the fixed value:
`"Active source-derivative removal and same-scope suppression only; not forensic erasure. Source files and human context are untouched. SQLite free pages, journals, backups, earlier exports and displayed copies may retain bytes."`.

Export v1 wire format stays unchanged; it is not a restore capability and does not
purport to preserve suppression markers. Existing read transactions serialize with
Forget so one archive cannot mix pre/post state. Earlier delivered/displayed copies
cannot be recalled. No VACUUM, global cleanup, private-source egress or automatic
forgetting of human declarations mentioning the file is implied.

## Acceptance

Synthetic v1/v2/v3 upgrades, no implicit migration, idempotence, cancel/disk-full/
killed-child rollback, malformed schemas/markers and forward-header byte preservation.
Two-project/source preservation, human-history preservation, restart/rebuild/query/
prepare/export suppression, held-index policy races, capacity/duplicate markers,
missing/unreadable source forgetting and strict pre-open CLI confirmation/bindings.
Legacy open policy/evidence/removal SQL guards and same-root incarnation rejection;
new removal/re-registration cleans markers without old content. No real user store
is upgraded or forgotten during tests. Native source Forget UI and whole-phase
closure remain subsequent work; independent implementation review/CI are required.
