# Lane B — Explicit provider profiles and refinement transport

## Scope and gates

Requirements **TM-04–TM-07, TM-10**; partial acceptance **P3-A2, P4-A1–A4**.
Phase 2 source authorization/currentness remains core-owned (**P2-A1/A6**).
This is configuration and a real existing-engine provider path, not a replacement
composer, autonomous sender, working remote inference integration or phase closure.
All requests in tests are synthetic numeric-loopback traffic; no real key, remote
provider call, credential reuse, expenditure, Docker or host launch was used.

The assigned old branch was merged with reviewed `origin/main`
`86dba4cd1e442c5e704e55f38fef4e7c69b5683e` before edits. PR 51/source Forget work
was neither copied nor redone. The coordinator owns newer shared integration.
Exact tested implementation SHA and final checks are recorded below after commit.
Remote CI/run/head: **not run** in this lane; no push/PR/merge/watch/deploy/release.
Independent review: **not run**; primary coordinator owns integrated-head review.

## Implemented

- Rust `ProviderSettings` defaults off; explicit profile selection resolves exact
  profile, model, endpoint and disclosed locality. Missing/duplicate/oversized
  profile sets fail closed. Configuration does no I/O and is not content consent.
- `Endpoint` rejects userinfo, query, fragment, percent/control characters, missing
  paths, invalid ports and locality mismatches. Supported subset is numeric local
  loopback HTTP (`127.0.0.1`, `[::1]`) or remote HTTPS. Local DNS aliases are not
  resolved. Locality describes the connection, not a guarantee that an independently
  operated local server does not forward data elsewhere.
- `ConfiguredProvider` implements the **existing** Rust `Provider` trait. Engine
  consent still binds the exact request, selected evidence, identity/locality,
  call/output budgets and monotonic deadline. It never invents authority or consent.
- OpenAI-compatible nonstreaming chat-completions JSON codec sends the explicitly
  selected model, original, constraints, selected evidence/provenance and attachment
  **references/metadata only**. No whole-project or attachment-byte upload exists.
  System instructions distinguish untrusted selected data from policy/permission.
- The codec requests JSON-object output and at most 1024 generated tokens. Response
  must have exactly one assistant choice with `finish_reason: stop`, no tool calls,
  and string content containing exactly four fields: nonempty `objective` and
  `output_expectations`, plus `unknowns` and `questions` arrays (up to sixteen
  nonempty strings each). Missing/extra/wrong-shaped fields reject. This deliberately
  narrow first codec does not generate risk/decision/source-quote records; the
  engine's conservative seed retains original bytes, constraints, evidence IDs and
  mandatory limitations. Generated prose is still unverified; human review remains
  necessary. Material questions block prepared approval.
- Bounds: escaped provider input 32 KiB, raw response 16 KiB, headers 4 KiB, full
  engine output envelope at most 8 KiB (stricter request/consent budgets apply).
  Bodies are bounded **before** JSON parsing. Overflow rejects whole output, never
  truncates original/constraints/metadata/warnings. No automatic retry/fallback.
- `LoopbackHttp` is a concrete safe-Rust standard-library HTTP transport, no proxy,
  DNS, cookie, credential or environment lookup. It POSTs the exact numeric-loopback
  endpoint, accepts only status 200 + JSON content type + one positive bounded
  Content-Length, rejects redirects, content/transfer encoding, malformed/truncated
  bodies and all other statuses including 401/403. It does not parse error bodies
  into logs. This restricted transport does not support chunked or compressed
  responses and does not claim compatibility with every OpenAI-compatible server.
- Connect timeout at most 100 ms; blocking read/write checkpoints at 25 ms socket
  timeout intervals; operation deadline at most 30 s and no later than consent/
  engine deadline. Cancellation/supersession drops the socket; no worker is left
  running and no late result can be adopted. Scheduling/OS latency is not a hard
  real-time guarantee. Injected transports remain cooperative like existing
  engine providers; they must enforce allocation/timeout/redirect/auth policy too.
- `JsonTransport` is an explicit injection seam, not automatic remote discovery.
  The supplied transport rejects remote profiles before any DNS/network attempt.
  **Remote TLS and authorized secure credential entry are deferred**, not faked.
  No plaintext secret setting/CLI flag/env fallback/keychain substitute was added.
- Swift `ProviderSettings`/`ProviderProfile` are Codable nonsecret host-owned values,
  default off, bounded/validated, with replacement resetting enablement. No file or
  global preferences are touched. `ProviderConfigurationView` is an embeddable
  Connections form for profile/endpoint/model/locality, save-off, explicit selection,
  enable/disable, locality/data-flow explanation and deferred-secret disclosure.
  It cannot call inference, submit/copy a draft or launch a host.

Only already workspace-locked `serde_json =1.0.154` was reused, with explicit
coordinator approval. Cargo generated the lock graph update: **only** the refinement
package's serde_json dependency edge changed; existing packages/checksums/features
were unchanged. The lockfile was not hand-edited.

## Smallest shared integration hook (coordinator-owned)

No edits were made to `CompanionModel.swift`, `Contract.swift`, `ProcessService.swift`,
`ThreadmarkCompanion/main.swift`, daemon/core/CLI or common public contracts.

1. Mount `ProviderConfigurationView(settings: Binding<ProviderSettings>)` in the
   host's Connections section. Host owns persistence/mapping and must not treat
   loading/enabling nonsecret settings as per-request data or spending consent.
2. Core-backed capture freezes the real authorized source selection and original
   draft into an existing Rust `Request` in Refine mode. No echo authority adapter.
3. Select settings and construct `ConfiguredProvider::new(&settings, &transport)`.
   Show exact identity/locality, selected data, call/token/output/time limits.
   Only after explicit user consent construct existing `ProviderConsent`.
4. Retain the actual `Engine` (coordinator's planned `preparation::ReviewSession`)
   and pass `Some(ProviderAccess { provider, consent })` to `prepare`. Surface
   ready/needs-input/failure/canceled, original/proposed and questions honestly.
5. Edit via existing engine validation; explicit UsePrepared/UseOriginal obtains
   `Approval`; revalidated `handoff` returns only `Delivery::NotAttempted`. No send.
   Supersede/cancel prior control before new scope. Failed providers never silently
   substitute or submit the original.

Coordinator is separately adding a post-provider actual-core authority recheck
before Ready. That shared race repair is **not duplicated in this lane**. UI mounting,
shared process/persistence contracts and end-to-end native/core consent/approval
flow are integration gates, not a claim made from isolated helpers passing tests.

## Acceptance evidence and limitations

| Acceptance | Synthetic runnable evidence |
| --- | --- |
| P3-A2 | Default off, missing/duplicate profile, exact selection/model/endpoint, locality-mismatched consent no-call, remote execution refusal, timeout/cancel. Native consent UX integration remains open. |
| P4-A1 | Real-engine HTTP success preserves Unicode/CRLF original bytes, negation constraints and attachments. Narrow generated fields cannot replace immutable capture fields. No semantic quality guarantee. |
| P4-A2 | Existing engine authority/provenance tests still run. New tests use an independent fixed fixture authority, not real core; coordinator owns actual SQLite integration/recheck. |
| P4-A3 | Fake HTTP success/malformed JSON/status/401/403/redirect/bounds/framing, questions/oversized proposal, socket timeout/cancel, injected oversize/superseded return. Failure retains original; only explicit original review can recover. |
| P4-A4 | Existing approval binding tests plus actual-HTTP preview/edit invalidates prior approval; delivery remains not-attempted. |
| P4-A5 | Open. No held-out quality evaluation, live provider/host certification, secure secret storage, remote TLS/auth or native accessibility walkthrough. |

Verification commands (all local; no remote provider needed):

```text
cargo test --offline --locked -p threadmark-refinement
cargo clippy --offline --locked -p threadmark-refinement --all-targets -- -D warnings
sh apps/companion/scripts/swift.sh test --disable-xctest --enable-swift-testing -Xswiftc -warnings-as-errors
python3 scripts/check.py
cargo deny --offline --locked check
python3 scripts/secrets.py
git diff --check
```

Swift uses the documented wrapper, never plain `swift`. Initial checks exposed the
installed SDK's State macro and absent XCTest; implementation now follows existing
explicit State-wrapper alias and Swift Testing patterns. Wrapper invocation requires
`sh` because the tracked script is not executable. Native-build-system deprecation
and Testing-framework macOS-version linker warnings are tooling limitations, not
proof of macOS 13 runtime coverage. No sensitive desktop was launched or captured.
