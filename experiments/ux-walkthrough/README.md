# Disposable UX walkthrough

Phase 1 feasibility only; not an installed app, indexer, inference system or host
integration. No dependencies or build step. Two hand-authored fixtures; all inputs
stay in memory. Do not enter real source, credentials or user data.

Run `node --test experiments/ux-walkthrough/model.test.mjs` (Node 22+).
Serve this directory on loopback with a bounded-lifetime static server, then open
`index.html`. Stop the server and close its tab afterward. Do not publish it or
change Pages/site configuration. Reload resets the experiment.

Select Cedar, inspect scope/exclusions and fixture provenance; switch to Cedar Lab
to see a conflicting isolated decision. Simulate stale source, alternate worktree
or revision to block review. Choose a proposed permission (or leave unresolved),
load the explicitly canned example, compare/edit it, then mark reviewed in
simulation. Edit or switch scope to invalidate. Simulate unavailable daemon and
return/cancel; the original fixture request remains visible and nothing is sent.

No real files, provider, daemon, clipboard, storage or host are touched. Marking
reviewed does not validate arbitrary edits, grant permission or deliver anything.
The small controller is a throwaway UX aid, not the future Rust semantics/API.
See [protocol and actual findings](../../docs/progress/phase-1-ux.md).
