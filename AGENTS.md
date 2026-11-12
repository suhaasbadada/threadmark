# Threadmark implementation rules

- Read the relevant `docs/spec/phase-*.md` before editing. Tie each task/PR to TM
  requirements and stable acceptance IDs; record exclusions and evidence.
- Current implementation is Phase 0 offline foundation, not a working companion.
  Do not advertise a daemon listener, storage, inference or certified host support.
- Core owns knowledge semantics; daemon owns bounded orchestration; adapters own
  capture/handoff; existing hosts own chat, permissions and execution. No HandsFree.
- Safe Rust only; workspace lints forbid unsafe. Keep third-party dependencies
  minimal, reviewed, locked and license-compatible. Never edit generated lockfiles.
- Run `python3 scripts/check.py`, `cargo deny --locked check`, and
  `python3 scripts/secrets.py` (after staging new files) for relevant changes.
  Report missing tooling or failed checks honestly. All examples/fixtures synthetic.
- Test mismatch, cancellation, dependency failure and recovery at relevant boundaries.
  Local IDs are not authenticated credentials; do not expose a listener before its
  authorization and containment contract passes Phase 1.
- No implicit network egress, host modification, telemetry, login startup or credential
  reuse. Never log content, tokens or private filesystem paths in public evidence.
- Use isolated task branches and PRs. No force push, user-work cleanup, automatic
  merge, production deployment or release without explicit authorization. Keep
  runtime, docs and site scope separate. Landing page changes require a separate PR.
- Before handoff, record full tested SHA, exact CI run/head, review, acceptance
  results and limitations in `docs/progress/`. Do not close a phase on local tests.
