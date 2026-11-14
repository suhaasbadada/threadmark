# Lane I — Explicit ranked Context and Refine preparation

Requirements **TM-04–TM-07, TM-10**; partial **P2-A1/A4/A6, P4-A2**.
This is bounded lexical source selection for actual preparation, not semantic/AST
retrieval, an inference-quality result, automatic context promotion, host approval,
a listener or a completed Phase 2/4. All fixtures are synthetic.

## Explicit opt-in, unchanged defaults

```text
threadmark --data-dir EXISTING_STORE query-terms PROJECT QUERY
threadmark --data-dir EXISTING_STORE context prepare PROJECT QUERY --terms < ORIGINAL_UTF8_FILE
threadmark --data-dir EXISTING_STORE refine preview PROJECT QUERY --terms --profile PROFILE --model MODEL --endpoint http://127.0.0.1:PORT/v1/chat/completions --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-snapshot SNAPSHOT --confirm-local-inference < ORIGINAL_UTF8_FILE
```

Inspect the exact project policy, ranked query selection, snapshot and provider
identity before confirming Refine, as in the [local preview protocol](local-refinement-preview.md).
`--terms` changes only retrieval; **all** existing inference confirmation, binding,
endpoint, data and call-budget requirements remain. A local server may itself
forward elsewhere; numeric-loopback HTTP is not network isolation. Only owned fake
servers were exercised, not a real provider or arbitrary running local service.

Without `--terms`, existing literal `query`, Context and Refine output shapes and
selection behavior remain unchanged. Ranked-only response fields are
`retrieval_mode`, selected `evidence` with actual project/path/line/hash/producer/
kind/currentness, and explicit selection/coverage limitations (Refine already had
coverage). The existing literal/native DTO is not extended. Human note/history
retrieval, permissions, source policy, schema and dependencies are unchanged.
Context never invokes a provider. Refine preview still reports
`approval: not-requested`, `delivery: not-attempted`; no approval, handoff, host
draft, copy or send is performed. Original UTF-8 comes only from bounded stdin;
negations, Unicode, CRLF and exact original bytes are not rewritten.

## Selection and immutable authority

- Reuse [G's ranked contract](ranked-lexical-query.md): whitespace split, Unicode
  lowercase, first-occurrence deduplication, 1–8 terms, <=64 UTF-8 bytes per lowered
  term, <=256 query bytes, no controls. Match any literal term; order by distinct
  matched terms, then per-term nonoverlapping occurrences, then path/line. No
  stemming, normalization, semantic expansion or relevance-quality guarantee.
- `Store::query_terms_bound(&Project, query, cancel)` shares the primary's bound
  project validation with literal query. It checks root/identity/incarnation,
  exact source policy and stored SQL snapshot against the **same captured Project
  passed to source traversal**, before reading files. There is no early metadata
  preflight followed by an unbound project-ID reload. Postchecks do not substitute
  for this pre-read guard. Ranked freshness/policy checks also run after selection.
- Existing `ReviewSession::capture` and `capture_bound` remain literal wrappers;
  explicit `*_with_retrieval` variants freeze `RetrievalMode::RankedTerms` in the
  session, its authority and private immutable `Request` metadata. `RequestData`
  remains unchanged. Consent equality includes mode even for identical or empty
  selected evidence; approvals include that exact request and authority. No mutable
  mode setter exists. A new mode/selection requires new capture and matching consent
  and review, not reuse of earlier approval.
- The provider receives exactly the authorized selected excerpts, original and
  existing bounded metadata; ranked-only provider metadata labels lexical mode.
  Existing literal provider payload fields are unchanged. No whole-source/history
  upload, credential/environment reuse, automatic retry, fallback or inference.
- At most eight complete anchors; core query's entire JSON line including newline
  is <=8192 bytes. Omissions are disclosed in preparation coverage. Preparation's
  own request/rendered/output envelopes can be larger: reject whole rather than
  silently shorten, drop warnings/provenance or return an original fallback.
  Ranked Context and Refine JSON lines include their newline in the 8192-byte cap.
- Source edits, replacement, policy/snapshot changes and cancellation reject stale
  preparation/provider results. Current-at-read is not a filesystem lock or an
  atomic external-revocation lease. Existing cooperative cancellation checkpoints
  remain; this lane does not add mid-query preemption or a hard-time guarantee.
- Ranked Context requires an existing incarnation-bearing store. Explicit legacy
  literal operator Context remains supported; cached review sessions and ranked
  reads do not gain a legacy-ID-only authorization fallback.

## Acceptance evidence

New tests use actual SQLite, real CLI subprocesses and owned ephemeral fake HTTP.
They are in the new `ranked_query/tests/bound.rs`,
`cli/tests/local_refinement/ranked_preparation.rs` and
`daemon/tests/review_session/ranked_preparation.rs` modules.

| Partial acceptance | Evidence |
| --- | --- |
| P2-A1/A6 | Peer SQLite same-root/different-root replacement after earlier capture never reaches ranked source traversal. Root, identity, missing incarnation, source policy, SQL snapshot and cancellation checks run before the source boundary. Real CLI wrong namespace/snapshot, stale source and replaced registration connect to zero providers. |
| P2-A4 / P4-A2 | Multiword literal query has no hits while `--terms` Context contains current ranked source anchors with exact provenance; unapproved source and human history never enter selection. Real Refine HTTP payload equals the inspected ranked result order/path/line/text/hash/producer/kind/coverage and snapshot. |
| P2-A6 | Invalid/repeated/unknown mode flags and malformed terms reject before store open. Existing confirmation remains mandatory. Actual CLI enforces complete-anchor omission, eight-anchor bound, escaped whole-envelope rejection and no partial stdout. Core G tests retain the full query/row/byte-bound coverage. |
| P4-A2 (plus regression P4-A1/A3/A4) | Original Unicode/negations/CRLF round-trip unchanged. Source change during HTTP rejects; cancellation during provider call rejects late preview. Consent cannot cross modes with identical data, even empty selection; review cannot cross changed mode/selection with the same Control/original. No host approval is fabricated. |

The inherited literal/default, recovery, provider failure/strict parser, human
history and source-Forget suites remain part of the full gate. No native UI work,
Swift invocation, live model, host interaction or held-out quality evaluation was
performed. Native H and common integration/review/PR54 monitoring remain primary
owned, not passed gates claimed by this implementation child.

## Bases and verification

- Assigned checkout started at `661bdb3`; current reviewed main (including required
  `b65e3515949ae6b89e04660fe419f34bb4fe2223`) merged in place as
  `c0e729a2d29e9b4d591144645555e2c4e62961ae`.
- Exact required reviewed local primary base
  `5bfca96bbb9a6e5cc70303d7f66931de68c65857` merged as
  `7ce1f8922881ac0bd51e7332a3c3784ceff2e1c6`, retaining primary bound-query repair
  `48bd8f4940f43ed11a8684ee6da4cf705b2f35c5`.
- G implementation `9d52ba20100eeb186bb6732e7857fd07ed6b6de5` cherry-picked as
  `4d09399c1892fce3299f5edb4c6607073467264e`; G evidence
  `1c8883e2427b3a47bfe268f61a6b1d0d557396be` as
  `b64a83b3cad7df2768920ee5808d57895b285b68`. G's initial merge was not picked.
  The small freshness-helper conflict retained the primary's complete bound
  checks and G's helper/ranked implementation, not a wholesale side selection.
- Full tested implementation SHA and final checks are recorded below after the
  implementation commit. Evidence-only follow-up does not change runtime/tests.
- Remote CI/run/head: **not run** for this unpushed lane. Independent review:
  **not run by this child**; primary-owned gate. No previous main/PR54 CI is claimed
  as evidence for this exact implementation head.

No branch switching, manual worktree creation, reset/discard, subdelegation,
Docker, installs, user data, global config, secrets, external provider, spending,
deployment, push, PR creation or merge-to-main. Only the requested Git fetch was
remote. The checkout and local commits remain intact for primary integration;
cherry-pick only the new Lane I commits, not the merges or G/base prerequisites.
