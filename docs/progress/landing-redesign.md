# Landing redesign — product clarity, separate site scope

Base: `d2a1fdace6b1125bf4d41bda7b821ec9011cc27d`. Requirements TM-01,
TM-04, TM-08 and TM-10; communication/UX evidence relevant to P1-A4/P1-A5,
not completion of either acceptance or Phase 1. User explicitly prioritized a
full landing redesign over the safely paused compiler experiment.

## Acceptance and evidence

- Replaced numbered architectural notes with compact navigation, product intent,
  one rough-request-to-brief example, background-only ownership and current status.
- Neutral light/dark palette, one purple accent, system typography, responsive
  two-column example stacking below 650px. No gradients, feature-card grid, fake
  metrics, scripts, tracking, external assets or dependencies.
- Synthetic example visibly labeled; citations navigate to synthetic evidence;
  proposed checks and unresolved decisions remain distinct from source facts.
- Current offline foundations/experiments are distinguished from storage,
  inference, native validation and the future companion. Installer status appears
  once. Claims checked against core/daemon contracts and merged progress.
- Primary inspected actual `html_preview` images at 1440px/light and 390px/dark:
  desktop request/brief alignment, mobile stacking, readable evidence/status,
  no visible clipping; no console messages. These are rendered source previews,
  not evidence of deployment or a running product integration.
- Interactive preview loaded the actual HTML bytes via a local file input into
  an owned blank document (no server/network). Tab exposed the skip link at top
  12px with solid outline; Enter focused `main`. Subsequent Tab focus reached
  repository CTA, example CTA and source citation, all with solid outlines. Enter
  on citation navigated to `#source-key` and exposed its evidence.
- DOM measurements: 320px and 390px had matching viewport/scroll widths and no
  right-overflow elements; settled 1440px viewport/scroll widths matched with
  two-column tracks of 402.398px/603.602px. Rapid resize initially returned stale
  intermediate widths, so no 768px measurement is claimed.
- Saved interactive screenshot artifact `browser-screenshot-site-mwe9t7km-b912fd5f.png`
  captures the evidence/status viewport. Full light desktop/dark mobile images
  were returned inline by the preview tool and inspected by primary.
- `python3 scripts/site_check.py`: PASS, ten negative fixtures reject broken
  skip/citation links, unknown external links, headings, active HTML/CSS,
  inaccurate status labels and missing navigation name. Byte-identical build and
  unchanged exact-owner-merge Pages deployment contract pass.
- `python3 scripts/check.py` and `cargo deny --locked check`: PASS.
- Joffrey independently reviewed site/checker against the base; no substantive
  or blocking issues. Source review only; browser inspection belongs to primary.

## Gates and exclusions

Tested commit SHA, PR and exact remote CI are recorded in the PR/handoff after
commit; not yet available at this source checkpoint. Staged secrets and whitespace
checks follow staging. No remote CI, merge or Pages deployment is claimed here.
No runtime/compiler files, Pages permissions or deployment triggers changed.
Compiler work remains preserved in its separate assigned worktree; no compiler
execution, product release, binary deployment or phase closure is authorized by
this website work. No full screen-reader or cross-browser certification claimed.
