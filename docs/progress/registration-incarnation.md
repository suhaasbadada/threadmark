# Registration-incarnation safety

Requirements: TM-01–TM-04, TM-07, TM-10; partial P2-A1/P2-A3/P2-A5 and
P3-A3/P3-A4. Exact tested integration:
`71d2bc6eeaec3fb0b2c5158443612fb0f6582f35`, based on PR #46 merge
`17a482b05dee1e7c80ec6f8c1b1313c8ae66377b`. Ancestry integration changed no
reviewed tree content. Bob implemented; the coordinator owns publication.

## Root cause and approved contract

During native Forget design, Joffrey found a high-severity stale-approval gap:
removing/re-registering the same directory can repeat root identity, file policy,
snapshot and human revision 1. A cached prompt bound only to those values could
delete different newly registered history. Native Forget was therefore deferred,
not shipped with that unsafe binding. The coordinator instead specified stable
registration incarnations and independently reviewed the
[migration contract](../contracts/registration-incarnation-v1.md) before coding.

Schema v3 adds exactly one non-content 32-hex token per live registration, maintained
by canonical insert/delete triggers and strict one-to-one validation. Ordinary
source/context changes preserve it; explicit re-registration gets a new value.
Incarnation-aware captured mutations and index publication recheck it inside their
transactions. Native cached removal/automatic refresh pass the exact token through
CLI/core before deletion/source access. Same-root reuse cannot redirect approval.
Legacy projects have null tokens; native cached actions require explicit upgrade
guidance rather than fabricated authority or silent migration. Export v1 is unchanged.

New stores initialize v3; existing v1/v2 stores remain supported without implicit
upgrades. Explicit v3 upgrade requires both schema confirmation and
`--confirm-legacy-workers-stopped`. The latter is **operator attestation**, not
machine-verified quiescence: already-running older binaries cannot be fenced by
these tokens. Stop/pause those companions and finish owned workers first. Legacy
insert/delete tests prove token maintenance only. The default v1→v2 upgrade remains
available; a v3 store never downgrades. No real user migration was performed.

## Implementation review and repair

Joffrey reviewed the implementation's migration, captured-operation checks and
native bindings. He found malformed tokens could pass SQL admission because
SQLite text length/GLOB treat embedded NUL specially and GLOB can admit BLOBs.
The coordinator added TEXT-type, exact byte-length and explicit NUL rejection.
The first recheck correctly remained open for exact-32-byte NUL cases; both boundary
cases were then added alongside overlength and BLOB fixtures. Each proves rejected
validation/reopen with database bytes unchanged. Joffrey cleared the final repair,
ran all 65 core tests plus a doctest, rebuilt the CLI and passed all 55 strict Swift
tests including live-core journeys. No finding was waived.

## Integrated verification and open gates

The coordinator's full check pipeline passed on the exact integration: 114 Rust
tests plus two doctests, formatting, strict lint, documentation, smoke, links and
negative gate. All 55 strict Swift tests passed against the rebuilt actual core.
Synthetic coverage includes multi-project migration/backfill, v1/v2 preservation,
idempotence, cancel/disk-full/killed-child rollback, forward-header byte preservation,
legacy token maintenance, malformed shape/cardinality/tokens, same-root reuse,
captured mutation rejection and actual native-bound removal/refresh preservation.
Bob's bundle/plist passed; dependency policy, staged secrets and whitespace passed.

Remote exact-head CI/PR outcome remains subsequent. No dependency or generated
lock changed. Native Forget, source-derived Forget, GUI/accessibility runtime,
event watching, live providers/hosts and phase closure remain open. All inherited
progress appends, user work, worktrees and orchestration reminders were preserved.

## Publication outcome

PR [#47](https://github.com/suhaasbadada/threadmark/pull/47) passed all five
checks on `8a4f3729066213a1cc26ea3df00ab8ea5fcfa508`: CI
[43532659164](https://github.com/suhaasbadada/threadmark/actions/runs/43532659164)
and integrated [43532659189](https://github.com/suhaasbadada/threadmark/actions/runs/43532659189).
Fresh exact-head/main/discussion/rules checks found no blocker; independent review
and repaired malformed-token acceptance above applied. It merged at
`2026-11-14T00:17:44Z` as `ddaaac5ad17db063ab133f2ac3258746c1b1eda8`;
the PR watch was removed. Post-merge CI
[43533220054](https://github.com/suhaasbadada/threadmark/actions/runs/43533220054)
and integrated [43533220108](https://github.com/suhaasbadada/threadmark/actions/runs/43533220108)
both passed on that exact merge. No real user v3 upgrade was performed.
