# ADR 0008 — Prospective bounded declaration/caller selection

Status: **initial feasibility prototype, not product or Phase 2 adoption**.
TM-02/04/07/10; P1-A1/P1-A5 partial; Phase 1 OPEN.

## Decision (declared before demonstrations)

Decline adopting the old candidate arm as default or claiming graph benefit from
the [frozen pilot](../progress/phase-1-retrieval-pilot.md). Its eight declaration
slots exclude every caller, matching symbol despite additional relationship
extraction. Lexical's caller evidence is a concrete counterexample to a generic
candidate advantage. Do not rewrite or rescore that study.

Propose [evidence-selection/1](../../experiments/evidence-selection/README.md)
only for explicitly bounded `definition_directcall` tasks. Preserve the exact
original query/instructions and scope. Extract all selected sources through the
existing reviewed public directcall API, then interleave ordered declaration and
resolved one-hop call line groups, declarations first. Within each group use
original query identifier order, UTF-8 path, numeric line; skip previously selected
coordinates and spill when a group exhausts. At most eight whole unique lines;
one line may represent both facts. Reject the whole canonical envelope above
8192 bytes; reject original query/instructions object above 4096 bytes. No cheaper
fallback, semantic guessing, rewritten terms or dynamic caller loading.

Report requested/available/selected categories, source-bound scope, exact line
text, and unchanged extractor observations/gaps. Selection is partial, never a
complete graph. Scope labels are caller assertions, not authentication or proof
of actual Git provenance/freshness. Core-owned extraction supplies fact semantics;
this selector does not invent adapter relationships or permission claims.

## Prospective conformance and exclusions

Before the two fixed SMALL synthetic CLI demonstrations, run independent-name
holdouts for Python/Rust, crowded/sparse/shared-line groups, ordering, recursion,
dynamic gaps, scope/invalid source closure, original negations and both budgets.
The CLI uses actual extraction/selection, public corpus bytes and original task,
never gold/oracle/scorer input. No evaluation worker or comparative study runs.
These demonstrations test runnable draft feasibility, not retrieval quality,
task success, performance or user value. Future comparisons require fresh
preregistration, independent review and the unchanged ADR 0006 worker gates.
This envelope is **not** the old candidate/scorer format or ranking contract.

Other tasks and existing lexical/symbol choices remain separate; the general
baseline decision is unresolved. No final scope cut, abandonment of Graphify's
evaluation requirement, new parser, production graph decision, inference,
refinement completion, clipboard, send, service, host launch or phase closure.
Native P1-A2 remains blocked and its launch pause authoritative.
