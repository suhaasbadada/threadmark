# Cached native source reads — Lane K

Requirements: **TM-01–TM-04, TM-07, TM-10**. Partial acceptance evidence for
**P2-A1/P2-A6, P3-A4, P4-A2**; no phase closure.

## Reviewed bases and tested revision

- Assigned isolated branch: `t3/native-bound-source-reads`; original checkout was
  old foundation history. Merged fetched `origin/main`
  `2b9abb810d5661259badb5d751d6e30af7e584f0` (contains required
  `8b04317dc21e748d7bcd75cf931138b8c56f2e47`), then exact reviewed local primary
  base `218100e96046cca6321185a480994626d65ed91c` without replaying old lanes.
- Implementation and full tested source SHA:
  **`2819007c9aef3403259d2cc9baf6a812d678d91c`**.
- Local-only implementation/evidence commits. No push or new PR; no remote CI
  run/head for this change, and no independent Lane K review claimed. Primary
  owns integration, publication, exact-head CI and independent review gates.

## Boundary and compatibility

Cached native source reads now carry the complete captured `Project` into
`Store::query_bound`: project ID, canonical root, filesystem root identity,
non-null valid registration incarnation, exact source list, and nullable stored
SQL snapshot. Core compares the current registration before source traversal and
uses that same captured authorized project for traversal. A preliminary model
inspection is not the enforcement boundary and cannot be followed by an unbound
ID reload into replacement sources.

New daemon `QueryBound`/`PrepareContextBound` and Context `context_bound` reuse
this core path. Both initial Context selection and the engine authority's later
selection use the same expected project. Existing retained Refine capture and
actual provider-call implementation are not rewritten.

CLI forms retain literal query behavior and existing explicit unbound operator
commands. Bound query and Context accept this complete suffix:

```text
--expected-root ROOT --expected-root-identity IDENTITY
--expected-incarnation TOKEN --expected-snapshot HASH|none
--expected-sources [FILE ...]
```

All flags are required together, in that order. The exact source list is last,
may be empty, and permits at most 64 relative paths without delimiter ambiguity.
Malformed metadata, nonce, hash, path, partial/unknown flag, or oversized query
fails before opening existing storage. Expected paths never authorize filesystem
opening; only the current registration does. Query is at most 256 UTF-8 bytes.
Original text remains stdin-only and bounded to 4096 bytes. An absent snapshot
is encoded `none`, not an invented indexed hash. Empty/unindexed Context remains
honest `needs-input`, without a provider call. The suffix parser is independent
of retrieval-mode selection for later optional terms-mode integration; no ranked
or terms implementation is included here.

Native `queryBound(Project, text)` and `prepareContextBound(Project, query,
original)` map exact argv and retain the 8192-byte response cap, bounded stdin,
clean environment, owned-PID cancellation/reaping and teardown behavior. Manual
evidence Query, Context, pre-Refine consent selection and confirm-selection all
use these forms. Legacy cached scopes fail closed with Refresh/explicit-upgrade
guidance, without inventing a nonce or falling back to unbound reads.

Model checks bracket reads and classify errors: actual root/incarnation
replacement clears namespace editors; same-namespace policy/snapshot conflict
requires Refresh and blocks unadopted derived work while preserving original
text, unsaved human editor identity and loaded history. Ordinary source edits
without SQL metadata changes return `stale-or-unindexed`/no results rather than
a fabricated root mismatch. Manual Build's existing index route is retained;
its actual post-Build metadata is loaded and namespace/policy checked so the next
read does not carry a pre-Build SQL snapshot.

Automatic refresh keeps existing root/incarnation/files consent and bound index
ownership. After indexing, it checks cancellation, loads actual fresh metadata,
verifies fixed namespace/policy, and only then binds that SQL snapshot into its
metadata/currentness query. Cancellation cannot start that subsequent query.
Timer/watch early-enabled checks, debounce/coalescing, stop and join ownership
remain intact. Driver startup also rejects malformed consent metadata before
authority inspection or watch installation.

## Acceptance evidence

| Acceptance | Synthetic evidence |
| --- | --- |
| P2-A1/P2-A6 | Existing private `bound_query_tests` source-boundary callback tests rerun: a peer replaces A with B at the same or different root after precheck, and strict `ScopeMismatch` occurs before the callback/source traversal. Added malformed metadata, absent-snapshot and root-identity boundary cases. No unreadable-file-only proof. |
| P2-A1/P4-A2 | New actual CLI/SQLite tests cover bound Query/Context, empty stdout on replacement/policy conflict, partial and malformed pre-open rejection, exact 64-file argv, absent snapshot, empty sources and ordinary source edits. |
| P2-A1/P3-A4/P4-A2 | New native actual-CLI peer fixture replaces scope or changes policy/snapshot after the model precheck but before the bound operation. Query, Context and pre-Refine selection all reject at the real CLI; no B content is adopted and no provider operation is dispatched. Same-namespace drafts/history survive; actual replacement clears namespace editor state. |
| P2-A6/P4-A2 | New automatic-refresh actual-CLI fixture verifies the query captures a snapshot different from pre-index metadata, then rejects a peer replacement/policy/snapshot change before selection. Automatic work stops, no index report is adopted, and owned teardown is joined. Existing production timer/file-event actual-core suites also pass. |
| P3-A4/P4-A2 | New native legacy/no-fallback cases, actual unindexed Context and source-edit stale cases; retained HTTP-preview tests verify namespace replacement clears only replaced drafts, while SQL snapshot conflicts retain originals and require Refresh, with zero provider connections. |

## Verification

On the implementation SHA above:

- `python3 scripts/check.py`: **PASS**, 177 Rust tests + 2 doctests; formatting,
  warnings-as-errors lint, documentation build/link checks and intentional
  failing-test gate passed. CLI rebuilt before native tests.
- `cargo deny --locked --offline check`: **PASS** (advisories, bans, licenses,
  sources). Offline explicitly prevents advisory/index egress; advisory freshness
  is limited to the existing local cache.
- Strict complete-concurrency native wrapper, with actual rebuilt CLI:

  ```sh
  THREADMARK_CORE_TEST_BINARY="$PWD/target/debug/threadmark" \
    sh apps/companion/scripts/swift.sh test \
    -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
  ```

  **PASS: 139 tests in 17 suites**, including existing owned-child timeout/cancel,
  HTTP-fixture teardown, real timer/watch and actual SQLite/core journeys. No
  plain Swift invocation or replacement fake production CLI was used.
- `python3 scripts/secrets.py`, after explicitly staging only owned changes:
  **PASS**, tracked-file/history scan and synthetic rejection sentinel.
- `git diff --cached --check`: **PASS** before implementation commit.

Initial local iterations exposed stale fake-service dispatch/call-count
expectations and the old retained-original expectation on actual registration
replacement; focused assertions were updated to the required behavior. Timed-out
development test helpers were explicitly stopped by their exact owned PID before
rerunning. The final complete wrapper passed without a hung worker.

## Exclusions and remaining gates

No listener, authentication framework, credential claim, schema, dependencies,
lockfile, global configuration, provider settings/private files, human-search
API/mutations, Refine preview parser/ReviewEngine, privacy UI or host delivery
changes. No subdelegation, Docker, real user data, remote inference, secrets,
installation, deployment, desktop capture or paused-host manipulation.

All fixtures are synthetic. Native GUI/accessibility walkthroughs, certified
host integration, live authorized inference, publication, exact-head remote CI,
independent review and all remaining phase gates are **not performed/closed** by
this local implementation unit. Local CLI/SQLite and synthetic loopback HTTP
tests are not evidence of production deployment or host admission.
