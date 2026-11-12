# OpenCode V2 offline feasibility experiment

This is a disposable behavioral model, **not a plugin, adapter, daemon, inference
engine or runtime certification**. It has no package manifest, SDK dependency,
listener, network calls, persistence or installation/configuration instructions.
It must not be put in an auto-loaded plugin directory.

Run with an existing Node supporting `node:test` and `structuredClone`:

```sh
node --test experiments/opencode/contract.test.mjs
```

`contract.mjs` separates fake command registration, scoped preparation, exact
review approval, one deliberate admission attempt, and outgoing context snapshots.
The injected `daemon.prepare`, `review.open`, `host.admit`, `capture`, `trustedScope`,
`currentScope` and `currentTurn` contracts are **experiment ports**, not documented
OpenCode methods/fields. The registration's `command.transform`/`editor.add` and
executor `{sessionID, prompt, delivery}` shape come from V2 documentation. Nothing
imports or calls an installed host SDK. The proposed host bridge to
`ctx.session.prompt` is intentionally absent.

Synthetic URI/MIME descriptors are opaque and never dereferenced. This deliberately
closed fixture schema excludes attachment mentions, binary attachments, actual
skill/agent resolution, host metadata and unknown prompt fields. It preserves
all accepted non-text fields, rather than pretending to implement host fidelity.
Review receives both original and candidate; there is no rendered UI/diff test.
IDs and injected scope equality are not authentication or authorization.

All fixture content remains in process memory. Receipts expose only status and
attempt count; the flow drops preparation references at settlement. Tests keep
synthetic call logs solely for assertions. JavaScript GC is not secure erasure;
injected dependencies may retain their inputs or ignore abort. There is no
durable journal, recovery protocol, automatic fallback or retry. A settled
invocation cannot be reused; a new invocation is a new deliberate action and
must not be used to retry an unknown admission.

Context evidence is opt-in and scoped to a supplied synthetic turn. Each fresh
tool-continuation snapshot gets one part; repeated calls on the same owned
objects replace only Threadmark-owned parts. Identical foreign text is preserved.
Ownership is a WeakSet, **not a text delimiter or invented host metadata field**.
Serialization/cloning loses ownership, intentionally exposed by a negative
boundary test. No stable host turn identity or snapshot ownership was verified.
The model never receives persisted prompt/permission mutation methods.

See the [budgets ADR](../../docs/decisions/0003-opencode-offline-feasibility.md)
and [capability record](../../docs/progress/phase-1-opencode.md) for evidence,
limits and remaining blockers. Tests do not depend on the extraction experiment.
