# ADR 0007 — SDK resource discovery after a failed 1 GiB experiment

Status: bounded experiment selected; execution requires independent exact-candidate
review and a separate primary decision. TM-04/TM-05/TM-08/TM-10; P1-A2/P1-A5
remain partial. [Phase 1](../spec/phase-1-feasibility.md) stays open.

## Evidence and decision

The first authentic SDK compiler discovery at 1,024 MiB V8 old-space failed with
heap OOM/SIGABRT. Version passed; positive produced no stdout/file list; negative
did not run. The failed result and private capture/source snapshot are preserved.
Static investigation found exactly three intended roots, no accidental declaration
glob or duplicate package trees, and no justified source fix. The underlying
type-instantiation hotspot versus ordinary declaration workload remains unknown.

Select one separately identified `fixed-sdk-compiler-resource-discovery-2048`
candidate with 2,048 MiB old-space. This is resource/semantic **discovery**, not
compliance with the failed 1 GiB gate or adoption of a product memory budget.
The historical inert plan retains its 1,024 MiB intention. New kind/bounds and
source bindings prevent inheriting its execution decision. Predeclare this limit
before measurement; no automatic escalation or retry follows another failure.

Keep compiler/runtime/SDK bytes, all fixture surfaces, strict/noEmit/full library
checking, literal policy, 120 s total envelope, 16 MiB aggregate output and 2 s
retained-owner cleanup unchanged. Old-space is **not total RSS containment**;
no broader host memory-isolation guarantee is claimed. No tracing, heap snapshots,
extra writes, SDK runtime imports or host execution are introduced.

## Alternatives and acceptance

Do not trim SDK surfaces, stub declarations, cast away types, suppress diagnostics
or skip libraries to fit the original limit. No static evidence warrants those
changes. Unbounded heap escalation/traces would obscure the failed gate and risk
unbounded resource/output use; reject them.

The follow-up may expose diagnostics, consumption or another resource failure.
Report each independently with before/after validation and cleanup evidence.
Even semantic success does not establish a product budget, native compatibility,
runtime provenance, certified integration or Phase 1 completion. A production
resource strategy and representative budgets remain separate design gates.

## Node26 diagnostic and separate authentic typings alignment

The single reviewed 2 GiB Node26 experiment returned version PASS, positive exit 2
with one TS2416 diagnostic at OpenTUI InternalKeyHandler.emit (zero stderr),
negative NOT_RUN, before/after validation and cleanup PASS. This does not repair
the 1 GiB failure or meet SDK semantic acceptance.

Primary selected authentic Node typings 24.12.2, matching the actual pinned
OpenCode plugin's exact development pin (Solid uses ^24.0.0), with undici-types
7.16.0 matching Node24's ~7.16.0 dependency. No declarations/fixtures are patched,
cast, stubbed, suppressed or scoped away. Actual EventEmitter signatures differ;
alignment is a testable hypothesis, not an observed TS2416 fix.

After the mandated stop on unexpected npm lock drift, primary accepted only the
already-generated exact transition following Joffrey's independent read-only
review: root pins, two complete typings replacements, six Redis6.3.1 peer records,
Emscripten dev -> devOptional and TypeScript dev removal, no other changes. This
expands a future ordinary installation graph; it does not authorize Redis source
acquisition, installation, distribution, runtime or waive the existing TypeScript
^5 peer conflict. No lock regeneration or further network followed that decision.

The new aligned outer candidate retains `fixed-sdk-compiler-resource-discovery-2048`
and every predeclared bound/policy. It has new lock/selection/plan/source hashes
and cannot reuse either Node26 execution approval. Historical preparation intent
and failed candidates remain immutable. Independent exact-byte review and another
primary decision are required before any actual compiler sequence. Node runtime
24.10.0 versus OpenTUI >=26.4 remains a separate blocked engine gate.
