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
