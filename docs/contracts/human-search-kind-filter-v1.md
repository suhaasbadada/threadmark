# Human search kind filter v1

Requirements TM-01–TM-04, TM-07, TM-10; partial P2-A1/A3/A4/A5/A6,
P3-A4/A6. Additive opt-in human-only lexical search, not source evidence,
authorization, semantic search, automatic resolution or phase completion.

## Closed request and response

`Store::search_context_kinds_bound` requires validated `HumanSearchKinds` and
`ContextReadBinding`; no unbound filtered API or fallback.

```text
threadmark --data-dir EXISTING context search PROJECT QUERY --kinds KIND... --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN
```

Exactly one `--kinds` precedes exact ordered binding flags. Require one to five
unique known kinds: constraint, correction, decision, note, pitfall. Input order
is immaterial; captured/output order is ASCII ascending. Unknown/duplicate/empty/
oversized/partial/extra flags reject before store open or stdin. No stdin, implicit
migration, store creation, source/FS/Git/provider read or SQL identifier interpolation.
Old routes and JSON remain unchanged. The new closed response is the old search
envelope plus exactly `version="human-search-kind-filter-v1"` and canonical
`selected_kinds`. Existing human-only labels remain. Entire encoded envelope
including final LF is at most 8192 bytes.

## Admission and selection

Reuse [human read binding v1](human-context-read-binding-v1.md): exact UTF-8
root/identity/incarnation before first human SQL in one coherent snapshot, fresh
publication checking. Local scope is not authentication; no source binding.
Shared pipeline retains 4096 scoped revision limit, suppression and validation
of every nonsuppressed latest row (including unselected/retired). Then filter
active latest kinds before Unicode-lowercase literal matching (no normalization),
occurrence ranking, max 8 and whole-entry byte omission. Counts/truncation describe
only filtered matches; descending occurrence count / ascending ID ties unchanged.

## Native lifetime

Default all-kinds retains old bound route. Opt-in/checkbox choices perform zero
service I/O, clear old search/ticket eligibility and advance search generation.
Only explicit Search captures immutable query/kinds/binding/generation/config.
Cancel/join predecessor before service/spawn; strict duplicate-rejecting closed
frame validates captured filter, result kinds and bindings at adapter and model.
No fallback. Late A cannot appear as B. Failure/cancel/filter edits preserve human
history/editor/base/original/CAS conflict; namespace replacement clearing unchanged.
No query/compare/source/export/refine/retained behavior changes.

## Stable acceptance IDs — defined before implementation

- **AE-01:** filter before ranking/caps; score/ties/counts/escaping/whole-entry
  omission/LF budget, all-kinds equivalence and old-byte compatibility.
- **AE-02:** kind-only/latest/retire/reactivate/Forget/no resurrection; invalid
  unselected latest rows and scoped overflow fail closed.
- **AE-03:** exact pre-human-SQL binding; cancellation/WAL/replacement publication;
  source-policy/missing-root independence.
- **AE-04:** actual CLI closed grammar/prestdin/prestorage/missing-store zero
  creation/legacy no migration/canonical order/old forms.
- **AE-05:** native zero-I/O choice, immutable generations/cancel/join/config/
  selection/Quit fencing, actual CLI replacement zero B/fallback.
- **AE-06:** wrong-filter/kind/duplicate/partial/extra/overflow rejection; mounted
  accessible text controls, preserved history/editor/CAS.
- **AE-07:** Rust/security/strict Swift/C/API/bundle evidence; independent review,
  integrated exact CI and GUI/AX remain separate gates.
