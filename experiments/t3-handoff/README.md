# T3 source-contract copy preparation (disposable)

TM-05/TM-08/TM-10; P1-A3 **partial**, P1-A5 **partial**. No production adapter,
composer mutation, clipboard write, URL construction, transport or native host
test. Phase 1 remains open. All tests use synthetic data.

Run with runner-provided Node built-ins (no installation):

```sh
node --test experiments/t3-handoff/prepare.test.mjs
```

`parseDestination` accepts only a bare copied default-hosted thread URL, returns
IDs decoded once, and deliberately rejects all parameters, fragments and other
origins/routes. This is parsing only: it neither opens the hosted page nor
authenticates a destination. Encoded slash and literal percent sequences in IDs
remain exact. Internal display links and local URIs are not accepted inputs.

`prepareCopy` requires a fixture review containing `decision: 'copy'` and the exact
raw destination and exact text. It returns an ephemeral `copyText` payload only
for copy-only results. This is not a consent UI or authenticated authorization.
Do not serialize/log the result or put text in command arguments. The caller must
separately choose to copy, select and verify a destination, paste, inspect, and
send in T3. No such operation is implemented here.

Text changed by pinned prompt-link normalization returns `needs-review` with no payload; the experiment never
substitutes sanitized text. A fresh exact review of changed text would be required.
8,001–65,536 UTF-16-unit text is offered unchanged for explicit copy; larger input
is rejected. There are no attachments, retries, receipts or retained state.
`runtimeGate` always reports unsupported, even for an alleged successful ack.
The 8,000-unit rule belongs to the pinned prompt-link parser, not a demonstrated
general composer/paste limit. No claim is made that manual paste follows the
same normalization path; the change detector is a conservative experiment policy.

The source-derived normalization detector retains T3 Tools Inc.'s MIT notice in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Threadmark's own license is unchanged.

Evidence, capability boundaries and verification are in
[the Phase 1 record](../../docs/progress/phase-1-t3.md); pre-test budgets are in
[ADR 0005](../../docs/decisions/0005-t3-source-contract-copy-only.md).
