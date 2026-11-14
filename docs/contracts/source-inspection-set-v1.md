# Coherent source inspection set v1 (AQ)

TM-01–TM-04, TM-07, TM-10; partial P2-A1/A3/A4/A6 and P4-A2.
Contract and stable AQ IDs defined before runtime edits. No phase closure.

`SourceInspectionSet::new(Project, radius, Vec<SourceInspectionAnchor>)` purely
admits and privately freezes the complete captured Project: exact root bytes,
identity, non-null incarnation, FULL ordered source policy and NONNULL snapshot.
Explicit radius 0..3; 2..8 distinct indexed coordinates (exact approved path,
line 1..4096, lowercase SHA-256 source_hash). Duplicate coordinates fail even with
different hashes. Canonical order is full-policy position then line. No unbound
form, ID reload, reduced policy, latest substitute or implicit indexing.

Typed daemon `InspectSourceSet(plan)` uses existing-only read-only v3/v4 DELETE
storage via `open_existing_for_inspection`, including pre-SQLite header rejection.
No schema/migration/dependency/lock/source/human/evidence/marker writes.

Closed CLI; all flags required once in this exact order:

```text
source inspect-set PROJECT --radius RADIUS --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-snapshot HASH --expected-sources FILE ...
```

Validate flags/full binding/radius BEFORE stdin. Radius is canonical decimal 0..3,
no sign/leading zero/NUL. Only stdin carries one closed JSON document:

```json
{"version":"source-inspection-set-v1","anchors":[{"path":"code.rs","line":1,"source_hash":"0000000000000000000000000000000000000000000000000000000000000000"},{"path":"code.rs","line":2,"source_hash":"0000000000000000000000000000000000000000000000000000000000000000"}]}
```

Strict UTF-8, <=65536 bytes including newline, no NUL, duplicate/unknown fields,
extra frames or scalar coercion. Line is a JSON unsigned integer, not bool,
fraction or exponent. No root/original/text/credentials in stdin. Complete plan
admission/canonicalization precedes store open. Exact nonempty path bytes must
already be approved; no normalization. All 64 full-policy paths fit the global
argument cap without widening unrelated grammars.

ONE read transaction validates ALL indexed membership/producer/text/hash and full
manifest binding BEFORE first source authorization/traversal. Not sequential
public single-anchor reads. Existing containment and full approved manifest reads
remain, including unselected sources. Each center matches indexed/current exact
text/hash. Windows use freshly observed text and unchanged `str::lines()` semantics.
Complete binding, health, cancellation, full manifest/publication freshness and
DELETE reader-lock fencing span the set. Any failure rejects ALL output; no
omission/retry/fallback. No reduced authority/I/O, performance or atomic filesystem
lease claim; later filesystem changes remain possible.

Closed output: `format=threadmark-source-inspection-set`, `version=1`, `project`,
`root_identity`, `incarnation`, `snapshot`, `radius`,
`currentness=current-at-read`, `inspections`. Each canonical record has exactly
`path`, `source_hash`, `producer`, `anchor_line`, `lines`, reusing single-anchor
window/provenance construction. Lines have `line`, `text`, `is_anchor`,
`kind=indexed-anchor|observed-source-text`. Exactly one center per record; producer
describes center extraction only. Neighbors are not indexed claims. Outer binding
applies to every record. No absolute root/human notes. At most 56 whole lines;
natural file edges only. Complete escaped JSON plus LF <=8192 bytes or whole-call
failure, never prefix/truncation/radius change. Explicit local stdout only.
Existing single inspection/all other wire/default contracts unchanged.
No provider/approval/delivery/export/native integration/new source authority.

## Stable acceptance IDs

- **AQ-A1:** immutable full-plan admission, canonical order/count/distinctness,
  binding/path/hash/line/radius bounds before store/source authority.
- **AQ-A2:** actual Query→capture 2..8 anchors→core/daemon/CLI set; truthful
  same/different-file windows/provenance/blank/CRLF/Unicode/escaping.
- **AQ-A3:** one SQL snapshot/all membership before first source; full-policy
  freshness, cancellation/dependency/containment/race refusal and DELETE fencing.
- **AQ-A4:** whole escaped 8192-byte/LF bounds, no partial output; preservation,
  recovery, Forget/new-capture/rebuild non-resurrection.
- **AQ-A5:** closed bounded duplicate-rejecting stdin/flags, held-open stdin
  rejection, existing-only/v2/WAL nonmutation and 64-source policy support.
- **AQ-A6:** unchanged single/Query/Context/Refine/export/human-search regressions,
  full offline checks, owned inventory/fingerprint and honest exclusions.
