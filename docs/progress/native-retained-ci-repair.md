# Native retained-review macOS CI repair

TM-04–TM-07/TM-10; partial P4-A3/A4 and P3-A5. No phase closure.

## Failed exact run

PR [#61](https://github.com/suhaasbadada/threadmark/pull/61), head
`5571e99c944f8f91740698480fa6e3fc2c3b07b5`, required CI
[43565183148](https://github.com/suhaasbadada/threadmark/actions/runs/43565183148),
macOS job [132357424042](https://github.com/suhaasbadada/threadmark/actions/runs/43565183148/job/132357424042)
**FAILED**. The retained 400-ms deadline test read `ownedPID` only after waiting
for HTTP readiness; the controller had already cleared its completed process.
Two five-second file-event waits and one ten-second HTTP fixture also expired in
the same concurrent 147-test run. This is not a pending job or waived failure.

The PID assumption is invalid independently of runner speed: a correct deadline
may finish before HTTP or the main actor resumes. Concurrent subprocess/socket
fixture pressure is the working diagnosis for the other readiness expirations;
the trace alone does not prove every scheduling mechanism.

## Correction and evidence

Exact tested primary correction:
`6410b10f5d06c5a6b68a8e9116ca8cbc9438edab`, on the combined native-ranked base.

- A default-off internal Sendable spawn observer records the actual worker PID in
  a locked test receipt before its deadline. It neither signals nor reaps and is
  not part of the public controller API. The worker remains the sole reaper.
- Timeout awaits completion independently of HTTP readiness and explicitly
  requires `lastError == .timedOut`, positive PID, `waitpid == -1/ECHILD`, cleared
  preview/challenge, at most one provider connection and joined server. If a
  request was observed, socket EOF remains required. Cancel/rebind still require
  exactly one captured request. Premature exit/protocol failure cannot satisfy
  the timeout assertion.
- CI runs the complete strict native suite serially on shared runners to bound
  subprocess/socket pressure. No acceptance case is disabled. Explicit races
  inside tests still run concurrently. Existing event/provider budgets are not
  increased; the short 400-ms deadline remains unchanged.
- CI now explicitly compiles and enables all hostile retained C fixtures instead
  of relying on an absent optional environment variable.

Primary full serial strict actual-CLI/C-fixture suite: **PASS**, 149 tests/19
suites. Full concurrent suite also passed before the final explicit timeout-code
assertion; final full serial suite and workspace gate passed after it. Relevant
Rust tests, formatting/lint/docs/negative gate, dependency policy, staged secrets,
whitespace, release bundle build and plist lint **PASS**. No app launch/GUI claim.

Joffrey independently reviewed the repair and passed seven retained tests. He
requested the explicit timedOut assertion so another failure could not masquerade
as a timeout; primary added it and reran the full serial suite successfully.

Only the four-file correction and this evidence are applied onto PR #61's exact
head. Native-ranked PR #62 changes are excluded from that push. New remote
exact-head CI remains a separate required gate; no retry or merge before it.
Nine inherited progress edits and all worktrees remain intact. Unit N completed
separately and awaits review/integration; Unit O remains independently owned.
