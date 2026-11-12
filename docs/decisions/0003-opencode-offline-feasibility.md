# ADR 0003 — Bound the OpenCode feasibility model

Status: provisional experiment decision, not adapter approval.
Traceability: TM-05/TM-08/TM-10; P1-A2 partial, P1-A5 non-extraction partial.

Before executing tests, choose an offline synthetic command/review model rather
than installing a plugin. Use Node built-ins only. No host admission, provider,
network, credentials, storage or UI is exercised by the test program.

Provisional limits: JSON input 4,096 UTF-8 bytes; daemon candidate 8,192 bytes;
four URI/MIME attachment descriptors; context evidence 1,024 bytes. Preparation,
review and admission each have a 100 ms deadline (300 ms total stage budgets).
One preparation and one admission attempt per invocation object; zero inference
calls/tokens/cost, zero retained content history. CI is bounded to three minutes
per OS. These tiny fixture budgets are not product latency targets or measured
performance. Timer deadlines depend on event-loop scheduling, not hard real time.

Reject unsupported attachment mentions instead of guessing offset remapping.
Refinement must change text only; all other fixture fields remain exact. Review
approval carries the exact candidate; close/disconnect/timeout is not approval.
Errors never fall back to submitting the original. Unknown admission remains
unknown and is not retried. An in-memory latch is not durable host idempotency.

Do not implement review inside the prompt hook: V2 documentation says its edits
are canonical persisted input and it is not an exactly-once side-effect boundary.
Model transient context separately on each outgoing model-call snapshot, including
tool continuations. The prototype tracks only its own object identities; actual
SDK snapshot ownership/serialization must be verified before an adapter exists.

Safe mode for now: offline experiments only. A future copy/manual-host-send path
may be evaluated separately; native command send and automatic context are no-go
until an isolated host/provider fixture, trusted review lifecycle, scope capture,
attachment/mention fidelity and admission reconciliation are demonstrated.
