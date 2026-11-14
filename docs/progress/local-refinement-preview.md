# Lane F — Explicit local refinement preview

Requirements **TM-04–TM-07, TM-10**; partial **P2-A1/A2/A6, P4-A1–A4**.
This unit is a finite CLI preview over actual SQLite, retained `ReviewSession`,
`ConfiguredProvider` and `LoopbackHttp`, not a generic harness, listener, daemon
launcher, interactive session server, native review bridge or automatic sender.
It does not close Phase 2/4, establish inference quality or certify any host.

## Operator protocol and exact usage

First explicitly register/index approved synthetic or operator-owned sources using
the existing core commands. Inspect the current policy and query selection:

```text
threadmark --data-dir EXISTING_STORE project show PROJECT
threadmark --data-dir EXISTING_STORE query PROJECT QUERY
```

Review the exact registered root, root identity, incarnation, current snapshot,
query, selected evidence and coverage. Independently inspect the exact nonsecret
profile/model/numeric-loopback endpoint and its operator. Then invoke:

```text
threadmark --data-dir EXISTING_STORE refine preview PROJECT QUERY --profile PROFILE --model MODEL --endpoint http://127.0.0.1:PORT/v1/chat/completions --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-snapshot SNAPSHOT --confirm-local-inference < ORIGINAL_UTF8_FILE
```

The original comes **only** from bounded UTF-8 stdin (1–4096 bytes), never a content
argument, environment variable, credential or existing host draft. Query remains
the explicit existing core lexical selector, not a substitute for original stdin.
The confirmation flag authorizes this **one local CLI operator invocation** with
that exact profile/model/endpoint/locality, project/root/identity/incarnation,
snapshot and query-selected evidence. Enabling a profile is not per-request
consent. This flag does not grant an agent permission to call arbitrary servers.
The operator must inspect the selection before confirmation; changed/replaced or
stale source state fails rather than silently consenting to another snapshot.
IDs and binding values are not authenticated credentials.

Only numeric-loopback HTTP (`127.0.0.1`, `[::1]`) is admitted. Remote endpoints,
DNS aliases, userinfo, auth/credentials, TLS and environment/proxy reuse are not
supported. A local server may forward content elsewhere; this is **not network
isolation**, and no live endpoint was authorized or exercised by this unit.

Maximum one provider call, no retry/fallback, <=30-second monotonic preparation/
provider deadline after stdin capture, 1024 generated tokens and existing codec
bounds. Source-query cancellation remains cooperative at operation checkpoints,
not arbitrary mid-query interruption or a hard real-time guarantee. Stdin waits
for EOF; a parent may terminate the CLI. There is no signal handler or detached
worker. A parent kill ends the process, not a claim of cooperative acknowledgment
or cancellation of work independently performed by a local server.

## Result and authority

The entire escaped JSON preview **including its newline** must fit 8192 bytes.
Overflow rejects the whole result without truncating the original, proposal,
questions or metadata. Success includes original/proposed/changed, material
questions, state, core coverage, exact nonsecret provider identity/locality and
limits, project/snapshot and registration binding. Questions remain `needs-input`;
`ready-for-review` is not approval, semantic fidelity or downstream success.
Errors are content-free with no preview on stdout and no silent original fallback.
Content-bearing stdout is deliberately sensitive and should not be put in logs.

`approval: not-requested` and `delivery: not-attempted` are closed values. This path
never calls `approve` or `handoff`, copies, sends, creates a host draft or edits the
original. Humans inspect the output outside the CLI. The actual review session is
retained through preparation and preview validation, then ends with the process;
no approval is retained or reusable across invocations. True interactive/native
review, edit/apply/use-original controls and host delivery remain future gates.

Flags, endpoint, binding and original shape validate before `Store::open_existing`;
preparation cannot create a store. The small approved `capture_bound` hook reuses
the private namespace capture/check: it validates expected project/root/identity/
incarnation/snapshot **before** actual source selection and after. Actual core
source freshness must then produce that exact snapshot. The existing authority
rechecks registration/source policy and selected evidence before/after inference
and before publishing preview. Expected roots never become source authority.
Existing unbound capture and Context behavior remain available and provider-free
respectively. Core, not the CLI DTO, owns source authorization and health.

## Acceptance evidence

All fixtures are owned synthetic SQLite directories and owned ephemeral loopback
servers, explicitly restored to blocking accepted sockets on macOS. No user store,
global config, secrets, installer, Docker, external server, native app, desktop
capture, spending, push, PR, merge, scheduler or deployment is used.

| Acceptance | Runnable evidence |
| --- | --- |
| P2-A1/A6 | Bound-capture test gives a mismatched namespace plus an invalid query: mismatch wins before core selection. Real CLI root/identity/incarnation/project/snapshot mismatches accept zero HTTP connections. |
| P2-A2 / P4-A2 | Stale file, replaced directory, same-root re-registration, invalidated snapshot and source change during HTTP fail closed. Actual core supplies selected evidence/provenance and lexical coverage. |
| P4-A1 | CLI sends only bounded original/selection to the existing codec; UTF-8, CRLF, quotes, backslashes and negation original bytes round-trip unchanged alongside a different proposed preview. Generated prose remains unverified. |
| P4-A3 | Missing confirmation/profile/model/flags, duplicates, malformed bindings/endpoints, remote/DNS aliases and invalid stdin fail without creating a store. HTTP malformed/duplicate response, 401/403/redirect/server errors and bounds fail with empty stdout and no retry. Whole-JSON overflow is separately tested beyond the existing engine envelope. Parent kill during HTTP produces no preview or late delivery. |
| P4-A4 | No approval/handoff call is reachable from this preview path. Success including material questions reports not-requested/not-attempted. Existing retained-session edit/scope/approval regressions remain in the full gate; CLI does not implement approval. |
| P4-A5 | Open: no held-out quality evaluation, real model, native bridge, secure remote TLS/auth, live host or interaction certification. |

Dedicated tests: `crates/cli/tests/local_refinement.rs` (six real-process tests,
multiple cases each) and two new tests in `crates/daemon/tests/review_session.rs`.
Inherited provider tests cover socket deadline/cooperative cancellation, framing,
late/superseded responses and recursive duplicate JSON admission; they are reused,
not copied or altered. Full existing Context/unbound review regressions also run.

## Base, verification and handoff

The assigned checkout began at `661bdb3`; reviewed main
`8e46da24ecf14422c580a4c3ef93219d5d8a8bf9` was merged in place without switching
branches. Provider bases were not ancestors and were cherry-picked once:
`22e43b4d79d1e137a10ebc3351d6c9f1612e7f93`,
`e0aad600378551cb0878f50fd1136efe9d80f50e`,
`0ba2d22b9f2686afe2725883c0e8275e5c7cf746`.
No provider/native/human-search implementation, dependency or lock was edited in
this lane. The primary owns PR53, integrated-head review, publication and CI.

Exact tested implementation SHA:
`db953f0a28ac64cb08768957c4464520cf001743`. The evidence-only follow-up changes no
runtime or test code; its final head is separately identified at handoff.

Repeated against that clean implementation commit:

- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: **PASS**, workspace format,
  build, strict all-target Clippy, **160 Rust tests + two doctests**, rustdoc,
  finite diagnostics, documentation links and intentional failing-test gate.
- `cargo deny --offline --locked check`: **PASS**, advisories/bans/licenses/sources.
- `python3 scripts/secrets.py`: **PASS**, after staging only the four owned new
  files, and again after the implementation commit. Synthetic secret rejected.
- `git diff --check`: **PASS**; tested implementation commit status **clean**.
- The six dedicated real-CLI tests and eight retained-session tests pass; the
  latter include two new bound-capture/outer-envelope regressions. The envelope
  fixture separately proves the engine preview fits while even minimal JSON
  repeating original/proposed exceeds 8192 bytes, then the CLI rejects it whole.

Local logs are ignored `target/local-refinement-check.log` and
`target/local-refinement-tested-head.log`, not public evidence artifacts. No Swift
or native code changed; native/UI tests were not run in this lane.

For integration, cherry-pick only the owned implementation commit and evidence
follow-up, **not** this branch's merge/base cherry-picks. The primary already owns
the original provider commits. Locally the inherited provider bases are
`efb69b876743c4afbf2b9cf7f77eb5fe7bb7794d`,
`af718a0f93f77cc824522fce1f210810059cf217`,
`ac07b7e8f8425e2d2fb22159776ff24fa9be7a7e`; main was merged by
`89979ad08aac5f6495d352a5a2187f0436e7b486`.

Remote CI/run/head: **not run for this lane**. Independent review: **not run by
this child**. These are explicit remaining integration gates, not inferred from
previous main/provider CI. Linked Plum coordination was unavailable (environment
reported unreachable); no agent messages or scheduled follow-ups were sent.

## Primary integration and preselection binding repair

Primary integrated only the owned F commits, preserving its independent
SQLite/actual-transport review test. Joffrey independently found a medium
preselection race: an earlier metadata check admitted A, but unbound core query
could reload replacement B and read its approved files before later checks rejected
publication/provider disclosure. A postcheck is not a pre-read scope guard.

The primary's `48bd8f4940f43ed11a8684ee6da4cf705b2f35c5` adds a bound core query:
expected root/identity/incarnation/policy/stored snapshot are validated against the
same captured `Project` passed to source traversal, with no ID reload. Initial
session capture and all retained authority reads use it. Existing explicit literal
operator query stays unchanged; namespace stores the SQL snapshot separately from
an unavailable/stale selected snapshot so Context needs-input remains possible.
This is not an atomic external-revocation lease or authentication scheme.

Two deterministic core tests pass the earlier A precheck, replace the registration
at another or identical root through a peer connection, then prove the source
traversal boundary is never reached. Additional policy/snapshot/legacy/cancel and
stale-file checks pass. Joffrey independently closed the finding and passed core,
daemon and actual CLI tests. Primary full verification passed 163 Rust tests/two
doctests, 118 strict Swift tests against rebuilt core, dependency policy, staged
secrets and whitespace. Native refinement remains a separate ongoing lane; exact
integrated-head publication/CI and GUI/live-model/host gates remain open.
