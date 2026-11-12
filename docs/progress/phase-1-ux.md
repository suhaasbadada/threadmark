# Phase 1 — disposable UX walkthrough

## Status and scope

2026-11-12. **P1-A4 PARTIAL, primary source review completed; CI pending. P1-A5 UX portion
PARTIAL.** This is a disposable feasibility artifact, not Phase 3 shell/indexing
or Phase 4 inference implementation. The Phase 0 runtime remains unchanged.
No installation, publication, provider, real source selection or host integration.
No claim of user-value validation, certified support or phase completion.

Implementation branch: `t3/ux-walkthrough-prototype`; assigned T3 worktree only.
Tested base SHA: `984703bfd73d5178a1748898bd95c97619d50438`, plus staged
uncommitted files listed below. There is no tested commit SHA for these edits yet.
Parent owns integration with newer main, independent review, final commit, exact
head CI and PR; no remote CI run/head or PR exists for this unit at handoff.
Independent extraction/OpenCode/guard/T3-copy units are not dependencies.

### Parent review and focused repair

Primary independently inspected the fixture controller, safe DOM bindings,
semantic HTML, unit tests and browser evidence. No host/delivery/storage APIs are
present. Found and repaired a misleading availability transition: selecting a
project used to reset the simulated shared daemon outage. The outage now remains
visible until explicitly restored; a regression checks project switch, blocked
review and explicit recovery without restoring approval. The unit now has 14
tests. CI uses pinned Linux/macOS runner labels and main-only push triggers to
avoid duplicate branch/PR work. No extra delegated review is claimed for this
disposable, effect-free model/UI.

The recorded browser artifact describes the delegate's earlier controller and
its 13-test version. The focused availability repair is unit-verified, not a
repeat of all browser observations. Main integration, final full tested SHA and
exact-head CI remain pending; no end-user or runtime certification follows.

Committed code after current-main integration:
`b357e398113d9bf8e4ba9899f3492560a6f22f33`. Primary reran all 14 Node tests
and the full foundation script successfully on that exact revision. cargo-deny,
staged/history secret scans and whitespace checks also passed for this unit.
This follow-up changes only the evidence record; final PR-head CI remains
required. No merge, publication or real host action is authorized by these checks.

## Pre-test protocol and bounds

Declared in the implementation turn before test execution: six scripted journeys;
390/1280 CSS-pixel widths, light/dark, keyboard checks and invalidation/failure
checks. Two fixed synthetic projects, one evidence excerpt each; candidate text
limited to 2,000 characters. No real corpus or small/medium/large retrieval study.
Browser server bound only to `127.0.0.1:41837`, five allowlisted static paths,
no content logging, no cache, maximum lifetime 900 seconds and explicit cleanup.
CI: two OS jobs, five-minute timeout each, runner-provided Node 22+, read-only
contents permission and SHA-pinned checkout without persisted credentials.
No latency/RSS thresholds or optimization claims; these are interaction/resource
bounds, not future product performance budgets. No consequential architecture
decision: no ADR 0006 needed; ADRs 0002–0005 remain untouched.

## Artifacts and requirements

- [Experiment instructions](../../experiments/ux-walkthrough/README.md)
- [Interactive page](../../experiments/ux-walkthrough/index.html),
  [controller](../../experiments/ux-walkthrough/model.mjs),
  [DOM binding](../../experiments/ux-walkthrough/app.mjs),
  [styles](../../experiments/ux-walkthrough/style.css)
- [Offline tests](../../experiments/ux-walkthrough/model.test.mjs)
- [Actual browser observations](../../experiments/ux-walkthrough/browser-results.json)
- [Bounded CI definition](../../.github/workflows/ux-walkthrough.yml)

| Requirement / acceptance | Bounded evidence | Exclusion |
| --- | --- | --- |
| TM-01 | Similar Cedar/Cedar Lab names, conflicting rules; project switch clears candidate, choice and review | No project discovery or source access |
| TM-02 | Explicit fixture-only anchors, one-excerpt coverage and exclusions | No extraction or indexed facts |
| TM-05 | Original negations retained beside canned example; differences explained; edited candidate invalidates review | No model or semantic intent validator |
| TM-07 | Decision vs implementation unknowns; unresolved permissions; stale/mismatch blockers | No real freshness verification |
| TM-08 | Explicit unavailable-daemon simulation and return without enrichment | No supported host/version/mode capability |
| TM-10 | Explicit simulated review; cancel retains original; nothing copied/sent; no automatic approval | No actual handoff, admission or execution |
| P1-A4 | Six interactive walkthroughs, cancellation/dependency failure and friction recorded | Partial until independent review; not an end-user study |
| P1-A5 | Versioned browser observation, fixture corpus and bounded protocol | UX portion only; host/inference/extraction records and future budgets remain separate |

## Steps and observed outcomes

Initial wide/light run used T3 `preview_act` native selects, clicks and text input.
Tab/Enter activated the review control with a solid focus outline. The four-way
matrix repeated actual page-controller interactions via DOM change/input events
and button clicks, with DOM assertions; not all four runs were keyboard-only.
Browser reported T3CodeBeta 0.1.9 / Electron 44.10.1 / Chromium 152.0.7977.169.

| Journey | Reproduction | Actual outcome |
| --- | --- | --- |
| UX-01 First project | Empty page → select Cedar → inspect scope, exclusions and provenance | PASS: empty state blocked; exact ID/worktree/revision and one fixture decision shown, excluded source explanation visible; no scan action |
| UX-02 Second project | Review Cedar → choose Cedar Lab | PASS: opposite rule, separate worktree/revision; candidate and permission choice cleared, no applicable prior review |
| UX-03 Stale context | Review example → toggle stale source; restore; separately switch worktree/revision | PASS: stale/mismatch blocked; review invalidated; no quiet freshness update; restoration did not restore approval |
| UX-04 Rough request | Choose proposed owners policy → load canned example → compare original/differences → Tab to review, Enter → edit candidate | PASS: explicit no-model example, original “Do not send email or deploy” preserved; simulated outcome says nothing copied/sent; edit invalidated review |
| UX-05 Ambiguity | Load with unresolved permissions; attempt review; choose proposed policy | PASS: unresolved stays blocked; no invented policy. Policy change discards the old permission-bearing candidate, requiring reload/manual review |
| UX-06 Dependency failure | Toggle unavailable daemon → return without enrichment; cancel | PASS: preparation/review disabled; original remains exact; candidate cleared and nothing copied/sent |

Four matrix configurations (1280×800 light/dark, 390×800 light/dark) each passed
15 DOM checks including all six journeys, both identity mismatches, invalidation,
no horizontal overflow and sticky banner at scroll end. Explicit appearance
select also changed backgrounds to the expected light/dark values. Narrow/dark
Tab/Enter review then cancel passed. After moving full identity into the sticky
banner, all four 15-check runs passed again and identity remained visible at
scroll end; narrow keyboard review/cancel passed again (focused review top
~759px, banner bottom ~132px). These are mechanical observations, not visual
usability validation.

The initial accessibility tree returned named native controls, headings, regions
and status without timing out. DOM verified all select/textarea/checkbox controls
have labels and the status has polite live semantics. Focus styles and
reduced-motion override were source checked. No motion is authored in ordinary
styles; reduced-motion preference was not emulated. No screen-reader session or
accessibility certification is claimed; contrast and assistive technology remain
review work. No screenshots are offered as proof.

## Friction, counterexamples and hypotheses

- **Observed:** automated ArrowDown/Enter on the project selector did not commit a
  choice. Native select automation worked. Tab order and Enter buttons worked;
  full keyboard-only selection is not proven by this run.
- **Observed/design review:** choosing a different proposed permission could
  leave old permission text visible. Controller now discards that candidate;
  unit and browser regression checks passed. This adds a reload/re-review step.
- **Counterexample:** arbitrary edited text can contradict the retained original
  yet be marked reviewed manually. The UI discloses no semantic validation and
  no safety certification. This is deliberately not a production approval gate.
- **Friction:** identity/provenance and safety explanations make a long narrow
  page; users scroll between project scope and review. Repeated full identity at
  review helps, but sticky banner reduces viewport space. No timed effort study.
- **Hypothesis:** routine host use should stay in the host; occasional context
  inspection and material ambiguity justify leaving it. This run never opened a
  real host, so normal host usage was not compared. Comparative/user study is
  planned, not observed; no claims of reduced friction or task quality.
- **Limit:** returning/canceling has only local page effects, not host composer
  behavior. Stale restoration reselects declared fixture evidence, not a refresh.
  Source/API denylist tests are limited regression guards, not containment proof.

## Verification and handoff gates

Local commands/results are recorded below after execution. Linux/macOS CI is a
definition only until parent pushes the exact final head. No Docker is needed.
Parent independent review, integration with current main, tested full final SHA,
exact remote CI run/head and acceptance signoff are still pending. Do not close
Phase 1 from this walkthrough.

Executed locally on macOS 27.0.1, Node v24.10.0:

- `node --test experiments/ux-walkthrough/model.test.mjs`: PASS, 13/13 tests,
  including mismatch, ambiguity, cancellation, dependency failure, recovery and
  invalidation. Static surface regression checks also pass.
- `node --check` for `app.mjs`, `model.mjs`, `model.test.mjs`: PASS.
- `python3 scripts/check.py`: PASS (format/build/clippy/tests/docs, finite CLI
  and daemon diagnostics, local documentation links, intentional test failure
  correctly rejected).
- `cargo deny --locked check`: PASS, advisories/bans/licenses/sources.
- Browser checks: PASS for stated mechanical assertions; keyboard selector
  limitation and untested assistive technology/reduced-motion emulation above.
- `python3 scripts/secrets.py` after staging: PASS, tracked-file scan and synthetic
  sentinel rejection. `git diff --cached --check`: PASS.
- Cleanup: both own preview tabs closed; loopback static-server PIDs 99450 and
  9667 terminated gracefully and background completions confirmed. Final browser
  recheck server used the tighter 300-second lifetime. No other resources touched.
  No content was logged by either server.
