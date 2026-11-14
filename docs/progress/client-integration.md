# Native client and preparation integration

Requirements: TM-01–TM-07, TM-10. This partial slice contributes to P3-A1–P3-A6
and P4-A1–P4-A4; neither phase is closed and P4-A5 remains open.

Exact tested integration: `8f1486a96624edd5c69bf8bbe0eeaa2508a9fdef`.
Published core baseline: `51b48f1693f956750825dc266605c13d96d94219`.
Baseline tree equals reviewed source `425d1bc087a86cb1706573ee68e7802fbe80b69e`;
the ancestry merge changed no integrated tree content. Inherited Phase 1 appends
and the local Phase 2 publication ledger were deliberately excluded.

Local `python3 scripts/check.py` passed on the exact integration head: formatting,
strict lint, Rust tests, documentation, smoke, links and negative assertion gate.
Dependency policy and staged secret checks passed. The unchanged runtime tree
passed 27 strict Swift tests against the actual built Rust CLI, release bundle
build and plist validation. Joffrey independently cleared engine, core bridge and
repaired shell; both subprocess PID ownership and mutation-ordering findings are
closed. See [shell evidence](phase-3-shell.md) and
[preparation evidence](phase-4-refinement.md) for acceptance details.

Remote CI has not yet run for this integration; PR/head/run identities will be
recorded after publication. No earlier core CI run is evidence for this client
integration. No GUI/accessibility runtime, live inference, provider credentials,
host draft placement, delivery, deployment or quality evaluation was performed.
Source selection remains explicit/manual lexical indexing. Context previews do
not approve, persist or send originals. Existing paused live-host launches remain
paused; their gates do not block unrelated product implementation.

## PR #40 macOS compiler compatibility repair

Publication head `da1025e4c06aca0759bb060b2376c9c325442105` ran CI
[43507486584](https://github.com/suhaasbadada/threadmark/actions/runs/43507486584).
Its macOS job [132168819171](https://github.com/suhaasbadada/threadmark/actions/runs/43507486584/job/132168819171)
failed compiling `ProcessService.swift:208`: `'OwnedChild' initializer is
inaccessible due to 'private' protection level`. The compiler synthesized a
private memberwise initializer from the private lifecycle fields, unlike the
newer local compiler. This was not a test failure or a waived/retried job.

Repair supplies an explicit internal PID-only initializer. Private lifecycle
state remains private and starts fresh; wait/reap/signal behavior is unchanged.
Local strict Swift tests passed all 27 tests/four suites against the real core,
including sole-reaper and cancellation-ordering regressions. Release bundle build
passed. The CI toolchain itself remains a remote verification gate; a new run on
the repaired head is required, not inferred from the local result.

### Concurrent fixture isolation repair

CI [43508134006](https://github.com/suhaasbadada/threadmark/actions/runs/43508134006)
on `43ebd0d` failed earlier in Rust tests, job
[132171038798](https://github.com/suhaasbadada/threadmark/actions/runs/43508134006/job/132171038798).
`knowledge.rs:18` reported `AlreadyExists` creating a fixture directory. Both CLI
tests run in one process and timestamp-only names can coincide at the clock's
actual resolution. This run did not reach the Swift compilation gate.

Fixture names now also include a process-local atomic sequence. A regression
creates 16 concurrent fixtures with a deliberately identical timestamp, keeps
all roots alive, and verifies distinct directories and source files. Creation
still fails rather than reusing an existing directory; cleanup remains confined
to each successfully created fixture. No runtime source policy changed.
The complete local Rust check pipeline passed, including all three CLI knowledge
tests. This failure was diagnosed and repaired, not retried or waived.

## Publication and merge outcome

PR [#40](https://github.com/suhaasbadada/threadmark/pull/40) passed all five
checks on `5b27d06d6981e87a6ee5ac63ada4850ef17e8ab9`: CI
[43508743472](https://github.com/suhaasbadada/threadmark/actions/runs/43508743472)
and integrated [43508743597](https://github.com/suhaasbadada/threadmark/actions/runs/43508743597).
The macOS job successfully ran Swift tests, actual-core adapter and bundle/plist
validation on the CI compiler. Fresh exact-head/main/discussion/rules checks
found no remaining blocker; the independently reviewed implementation and the
two narrow compiler/fixture repairs merged at `2026-11-13T21:16:27Z` as
`bdc7e1e714f674d856f09a4c48ad45d62d6538a2`. PR watch was removed after merge.

Post-merge CI [43509204977](https://github.com/suhaasbadada/threadmark/actions/runs/43509204977)
and integrated [43509204983](https://github.com/suhaasbadada/threadmark/actions/runs/43509204983)
both completed successfully on that exact merge. This is not GUI/runtime or live
provider/host acceptance and does not close Phase 3 or Phase 4.
