# Compiler work checkpoint — landing-page priority

The user's landing-page redesign is prioritized at this safe checkpoint. The
compiler-only unit remains in its assigned branch `t3/004628d1`, based on full
HEAD `29e62348dfa531dcbae2cb8d63d0d276361a629e`, with staged work and primary fixes
preserved. No reset, stash, branch switch, cleanup, push, PR or compiler execution
was performed to make room for site work. No worker or PR watch is running for
this uncommitted unit.

Bob's unit prepared 112 authentic TypeScript 6.0.3 files / 107 default libraries
and reported 529 offline tests. Joffrey independently verified the actual archive,
all selected bytes/notices, Node/runtime bindings, policy and 27 pure tests. His
low incomplete-marker finding was repaired by the primary: validation now occurs
with the marker present, followed by final marker removal. The new regression
rejects the pre-fix implementation; all 28 compiler-only pure tests pass.

Fresh inert candidate digest (UNAPPROVED):
`5504e2c9d671bfc797c3f1cddea4ceb7c0baa2ce132a7e6b514e6b165dd29bad`.
No TypeScript, new Node guard, SDK or host has run. First execution still needs
the regenerated exact candidate's independent review and explicit authorization.

Before that review, primary discovered a path-representability issue to repair:
the shared synthetic artifact prefix contains a literal POSIX backslash, while
authentic `_tsc.js:5452–5453` replaces backslashes with directory separators and
`normalizePath` applies that normalization at lines 5568–5569. Compiler config/root
paths must use a compiler-specific representable owned prefix without weakening
SBPL quoting tests or shared Node/C guard fingerprints. No speculative policy or
runtime change was made for that issue yet. Preserve all private artifacts and
the earlier candidate/failure evidence; do not run the known problematic path.

The landing-page redesign uses the primary's separate, clean T3-assigned worktree
and a site-only PR. Return to this checkpoint afterward. P1-A2/P1-A5 and Phase 1
remain open; this is preservation evidence, not a phase or compiler completion.

## Resumed compiler-only repair (after separate landing work)

The path-representability repair is now implemented without modifying measured
C/Node/shared helper sources. Compiler-local artifact naming retains the shared
owner/quarantine/removal lifecycle; raw compilerRoot/run paths reject normalization
hazards before preparation or launch. Primary's late-marker fix is preserved.
Fresh inert candidate SHA-256 **UNAPPROVED**:
`7fb64794f4dd856ddcec40afda792538be67742beba411ca49d6ebd70f3da2b8`.
See [the appended native progress record](phase-1-opencode-native.md) for exact
source/inventory bindings and verification boundaries. No Node, TypeScript,
sandbox target, SDK or host ran during this resumed unit. The preceding checkpoint
and all prior private candidates/evidence remain preserved. Independent review
and a new explicit execution decision are still required; no phase is closed.

## Private retention repair after the single authorized attempt

The path-fix candidate subsequently received Joffrey review and one primary-
authorized real guard invocation: version 6.0.3 PASS, positive BLOCKED, negative
NOT_RUN, cleanup reported verified-or-not-launched, program closure NOT established.
Its raw output/reason was discarded, so the positive root cause remains unknown.
No retry followed. The new private evidence-retention repair is inert and awaits
independent exact review plus new explicit authorization. Final candidate SHA-256:
`a8a01b0d9b9c1d6ac601ec32b634694e19987a51cb027fd354f80e6ada2bcbc3`.
See the appended native progress record for source bindings, private retention
contract and 469 Python offline tests. Shared measured Node/C/owner fingerprints
remain unchanged. All primary records and prior private artifacts are preserved;
this checkpoint does not authorize execution or close any acceptance gate.
