# ADR 0005 — T3 source-contract experiment remains copy-only

Status: provisional Phase 1 experiment; TM-05/TM-08/TM-10, P1-A3 partial,
P1-A5 partial. Phase 1 remains open.

## Decision and pre-test budgets

Inspect T3 at `3a30b011c3867884d7e5180be77886de65e12ac9` without running its
code. Implement only an in-memory destination parser and exact-review copy
preparation under `experiments/t3-handoff/`. No transport, clipboard, app launch,
send, persistence, automatic retry, or host-state simulation.

Budgets declared before test execution: one process/one preparation at a time;
synthetic small/medium/large text fixtures of 32, 8,000, and 65,536 UTF-16 units;
hard input caps 65,536 text units and 4,096 destination units. Oversized relative
to T3's pinned 8,000-unit prompt-link limit is copy-only without truncation; exceeding the experiment
cap is rejected without returning text. Suite target <=5 seconds and peak process
RSS <=128 MiB on local macOS; CI timeout 2 minutes per Linux/macOS job. Zero
inference calls, network calls during tests, installs, or monetary cost. These are
provisional correctness-fixture budgets, not representative repository retrieval,
host latency, UX, or product-performance measurements.

## Rationale and consequences

Pinned source supplies a desktop route codec, not installed-runtime certification
or proof of local-only content handling/log privacy. Prefer explicit copy-only
output (caller must separately choose to copy/paste), never a private prompt in
hosted HTTPS. Treat local URI transport as unsupported in this experiment. Source
normalization can invalidate exact review; report needs-review, never silently
sanitize approved text. Preserve copy text exactly, including oversize text.

Accept only a bare copied hosted thread URL on the pinned default origin. Reject
all query parameters, including duplicates, fragments, userinfo and new-thread
routes. Internal `t3-thread` display links are not OS protocols or authorized
destinations here. IDs identify a destination, not authority to access it.

Alternatives deferred: live composer APIs (not verified), desktop URI launching
(requires separate authorization and runtime/privacy evidence), thread-send APIs
(not composer control), UI scraping/application databases (not acceptable).
