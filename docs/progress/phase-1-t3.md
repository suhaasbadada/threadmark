# Phase 1 — T3 source-contract handoff feasibility

Status: **OPEN; source-contract/offline only, not runtime-certified**.
Requirements TM-05/TM-08/TM-10; acceptance P1-A3 partial and P1-A5 partial.
No Phase 5 adapter or installed-host support is claimed.

## Parent review and finalization

Primary independently inspected the codec and the pinned upstream normalization
source; verified its full SHA-256 matches the recorded `429c76e9…` value. The
source-derived detector now retains the full upstream T3 Tools Inc. MIT notice
in the experiment. Primary tightened names to **prompt-link** limits and
normalization, not general composer/paste behavior; manual paste may follow a
different path and is untested. Added content-free rejection for malformed
top-level inputs. All **18 tests pass** after these changes. Branch push CI is
limited to main to avoid duplicate branch/PR runs. This pure, effect-free unit
received primary source review, not another delegated Joffrey review.

No native composer, clipboard, app link, session or host configuration was
touched. Main integration, committed-revision verification and exact-head CI
are still required. Historical delegate verification below refers to its then
uncommitted 17-test version, not the final code revision.

## Evidence provenance

Public read-only GitHub tree API and raw files inspected at T3 commit
`3a30b011c3867884d7e5180be77886de65e12ac9`; no clone, dependency installation,
third-party execution, app launch, composer read/write, clipboard operation,
thread-management/send API, or user data. Source tests were **read, not run**.
Source pin proves implementation semantics only, not the installed T3 build.

All links below are pinned source anchors. SHA-256 values refer to complete raw
file bytes fetched, not snippets. Prefixes in the following table are paths in
the upstream T3 repository, not local experiment files.

| Pinned source anchor | Raw file SHA-256 | Finding |
| --- | --- | --- |
| [docs/user/prompt-links.md L6–64](https://github.com/pingdotgg/t3code/blob/3a30b011c3867884d7e5180be77886de65e12ac9/docs/user/prompt-links.md#L6-L64) | `fee4023f5080bb2201f6f12a34d85c181cdb8edf1f837b189decbf610556e45f` | Draft not Send; 8,000 characters; encodeURIComponent; repo/PR may select/clone/create worktree; occupied draft confirmation; hidden stripping. |
| [packages/shared/src/promptLinks.ts L3–67](https://github.com/pingdotgg/t3code/blob/3a30b011c3867884d7e5180be77886de65e12ac9/packages/shared/src/promptLinks.ts#L3-L67) | `429c76e919c56353b620a2b91e5fe5d7be8e8084a61fc8a9ed3246718d5ea922` | Constant, hidden ranges, conditional ZWJ and normalization. Same file L104–121 checks raw JS string.length before sanitizing; L156–158 reads existing-thread prompt; L184–214 maps hosted and desktop links. |
| [packages/shared/src/promptLinks.test.ts L15–141](https://github.com/pingdotgg/t3code/blob/3a30b011c3867884d7e5180be77886de65e12ac9/packages/shared/src/promptLinks.test.ts#L15-L141) | `3ea1ebe2366cc77d57cc517c1c78a435bf81b33b12266fb5d360650272d2b758` | Hidden/emoji tests; plus decoding; >8,000 ASCII rejection; copied route -> desktop path. Upstream tests do not themselves establish astral UTF-16 boundary coverage. |
| [packages/shared/src/threadLinks.ts L7–72](https://github.com/pingdotgg/t3code/blob/3a30b011c3867884d7e5180be77886de65e12ac9/packages/shared/src/threadLinks.ts#L7-L72) | `1164a0232ad9bac00d6c041324a8054eb29b553bb9923cb7bc4d6611a7040ce9` | Bare hosted copied route, strict encoded segments, decode once; internal t3-thread IDs instead taken verbatim. |
| [packages/shared/src/threadLinks.test.ts L205–225](https://github.com/pingdotgg/t3code/blob/3a30b011c3867884d7e5180be77886de65e12ac9/packages/shared/src/threadLinks.test.ts#L205-L225) | `d360906af34273f65becd9a9f8e63f22bd809963b3a3b3a11074e9717c4c1d0e` | Copied hosted ID roundtrip and rejection of query-bearing/extra-path/wrong-origin links. |
| [packages/shared/src/connectAuth.ts L10](https://github.com/pingdotgg/t3code/blob/3a30b011c3867884d7e5180be77886de65e12ac9/packages/shared/src/connectAuth.ts#L10) | `287baca5ab6ca54e9dac18fb357e66a41d5031f795d925fa0033a35f4be985a6` | Default hosted origin app.t3.codes. No auth flow used. |
| [apps/desktop/src/electron/ElectronProtocol.ts L15–29](https://github.com/pingdotgg/t3code/blob/3a30b011c3867884d7e5180be77886de65e12ac9/apps/desktop/src/electron/ElectronProtocol.ts#L15-L29) | `0def478275c116bed1b36bd20180d49b073ad3dd03910798630bb288807c5060` | t3code/t3code-dev renderer origins; Electron asset/proxy protocol is not alone proof of OS-link registration or privacy. |
| [apps/desktop/src/app/DesktopClerk.ts L125–140](https://github.com/pingdotgg/t3code/blob/3a30b011c3867884d7e5180be77886de65e12ac9/apps/desktop/src/app/DesktopClerk.ts#L125-L140) | `75f70787005a60feeb4c474920e96b47a2a462539dfe5fa752890457895d45c1` | Buffers open-url and second-instance; L217–256 forwards parsed app links to renderer via DesktopWebLinks. Not an acknowledgment of composer placement. |
| [apps/desktop/src/app/DesktopLinuxUrlHandler.ts L79–96](https://github.com/pingdotgg/t3code/blob/3a30b011c3867884d7e5180be77886de65e12ac9/apps/desktop/src/app/DesktopLinuxUrlHandler.ts#L79-L96) | `25b4756aa51c822d367706b0b06118269b80af10f6545c7309bf34b9fa8799c8` | Source generates x-scheme-handler desktop entry; L124 chooses actual scheme; L255–275 sets MIME handler. None executed. |
| [apps/desktop/src/app/DesktopWebLinks.ts L26–82](https://github.com/pingdotgg/t3code/blob/3a30b011c3867884d7e5180be77886de65e12ac9/apps/desktop/src/app/DesktopWebLinks.ts#L26-L82) | `5ecf7a13c500ceae1815953229539826ac97a5ef2a6f22437c94e186f3393eff` | In-memory pending links, renderer readiness and IPC forwarding; no composer or Send receipt. |
| [apps/web/src/components/promptLinks/ThreadLinkPrompt.tsx L23–47](https://github.com/pingdotgg/t3code/blob/3a30b011c3867884d7e5180be77886de65e12ac9/apps/web/src/components/promptLinks/ThreadLinkPrompt.tsx#L23-L47) | `f100cef027655edb6956d4b30e8b088dfb323d060cd3b12d34c04564902cda6f` | Route guard, once-per-location handling and query removal; stripping URL later does not undo OS/history/log exposure. |
| [apps/web/src/components/promptLinks/linkedPrompt.ts L7–49](https://github.com/pingdotgg/t3code/blob/3a30b011c3867884d7e5180be77886de65e12ac9/apps/web/src/components/promptLinks/linkedPrompt.ts#L7-L49) | `d081e9b3dd3a93c2b4a746ed3bc0f3504bdd79b138eea5d8470bae0519d49158` | Warning; setPrompt; replace confirmation only when existing.trim() nonempty and existing differs from incoming. Empty/whitespace-only or identical prompt places directly. |
| [apps/web/src/threadRoutes.ts L68–79](https://github.com/pingdotgg/t3code/blob/3a30b011c3867884d7e5180be77886de65e12ac9/apps/web/src/threadRoutes.ts#L68-L79) | `0bd9e657f113dfe45a85f6de21302dee4f6cc81ce5e10bc4a0bc62a5d8062d8e` | Route compares both IDs decoded once. |

### Documentation versus source

Docs use the older two-segment web draft route; copied thread links use the
`/threads/<environment>/<thread>` share route. Source distinguishes these: the
two-segment web route is considered a link only with a prompt; the share route
also works bare. Desktop mapping uses scheme `t3code`, host `threads`, and two
encoded ID segments, **not** `t3-thread` (internal Markdown display links).
No prompt-bearing URI is constructed by this experiment.

The source accepts more schemes/parameters than our policy. We accept only bare
copied default-hosted routes, no query at all, no userinfo/port/fragment, no implicit
environment resolution. Malformed percent escapes/UTF-8 are rejected rather than
replaced. IDs decode once and preserve literal percent sequences, case and Unicode;
encoded slash inside an ID is preserved as ID text, not another route segment.
Additional blank/control/dot-ID rejection is a conservative experiment restriction,
not a claim about the complete upstream ID schema. IDs are not credentials.

Prompt-link size means **raw decoded JS UTF-16 string.length <=8,000**, not bytes, code points,
or encoded URI length. The linked-prompt parser then normalizes CR/CRLF and U+2028/U+2029 to LF, strips
the enumerated hidden ranges, keeps U+200D only between source-defined emoji
parts, and trims JS edge whitespace. No NFC/NFKC normalization was found in this
path. Plain ZWJ identifiers change, emoji sequences can survive. Any such change
invalidates our exact review: needs-review, no silently substituted payload.
`encodeURIComponent` encodes space as `%20` and literal plus as `%2B`, preserving
`!'()~*`; URLSearchParams uses form encoding (space `+`, different punctuation).
Offline tests exercise both decoders without building a public prompt URL.

## Versioned capability record

| Capability | Evidence level / result |
| --- | --- |
| Product/version | T3 source commit above; installed product/version **UNTESTED** |
| OS/execution | Offline Node built-ins on local macOS; dedicated Linux/macOS CI defined, not run remotely yet |
| Integration/configuration | Disposable in-memory copy preparation; zero host configuration changes; no installation |
| Destination selection | Source-verified bare copied hosted route; offline parser rejects unknown origin/params/routes; explicit exact raw destination in fixture review |
| Capture/attachments | Synthetic string input only; no host draft capture, files, attachments or real content |
| Permission/trust | Local IDs are not authenticated authority; host owns login, connectivity, permissions, Send, execution and destination access |
| Prompt-link size limits | Source-verified UTF-16 semantics; offline 8,000 boundary/astral/byte-difference and unchanged oversized copy tests; general composer/paste limit untested |
| Exact review | Offline-prototyped exact text+destination+copy decision; not proof of native consent |
| Normalization | Source-verified rules; offline needs-review on changes, accepted text exact |
| Local URI | Mapping exists in source; **unsupported transport here**, no installed handler, local-only/privacy or native confirmation proof |
| Hosted prompt URL | Unsupported by policy; no generated URLs, no network/launch in component |
| Copy | Ephemeral exact output for explicit user copy only; clipboard/paste not implemented or tested |
| Occupied/closed/missing destination | Runtime **UNTESTED/UNSUPPORTED**; source confirmation logic only, including empty/identical exceptions |
| Cancellation | Offline cancellation returns no payload and reads no destination/content/review; native occupied-composer cancel **UNTESTED** |
| Acknowledgment | Every runtime-gate input unsupported with retry=false; no draft-received or sent claim; actual destination acknowledgment **UNTESTED** |
| Privacy/logs | Component has no logging/I/O/persistence; output text stays ephemeral. Host/OS/browser/clipboard log privacy **UNTESTED**, not guaranteed by source or URL removal |

## Experiment and acceptance

[Component and synthetic tests](../../experiments/t3-handoff/README.md),
[pre-test ADR/budgets](../decisions/0005-t3-source-contract-copy-only.md), and
[path-specific CI](../../.github/workflows/t3-handoff.yml).

- **P1-A3 partial:** codec/copy-only preparation, exact review, size handling,
  cancellation without output and unsupported acknowledgment tested offline. No
  native draft handoff, occupied composer preservation, cancel behavior or
  destination receipt verified. Those remain blocking before advertising draft mode.
- **P1-A5 partial:** source-pinned capability record, synthetic corpus, provisional
  budgets and ADR provided. No runtime certification, representative repository
  evaluation, end-user UX or Phase 1 closure.
- Exclusions: PRs 3/4/5 experiments, inference, daemon/listener/storage, extraction,
  OpenCode integration, site, Rust runtime, live T3, hosted prompt transport,
  native clipboard, commits, publication and merge. Independent work does not
  depend on the other experimental PRs.

## Verification and handoff

Worktree branch `t3/t3-source-contract-handoff`; inherited tested base HEAD
`984703bfd73d5178a1748898bd95c97619d50438` (uncommitted additions are not represented
by that SHA). Parent owns integration of current main
`7b3f8ad4dabdfe1f675601864c42a61977b1048d`, independent review, final commit,
full tested commit SHA, PR and exact-head CI. No remote CI run/head or native
review evidence exists for this unit yet. Phase 1 remains open.

Local macOS arm64, Node v24.10.0, Python 3.12.6:

- Final offline tests (including percent-encoded Unicode destination IDs): 17/17
  passed; measured complete command 0.12 seconds wall, maximum RSS 59,244,544
  bytes (~56.5 MiB), within provisional budgets.
- Initial test run: 16/17 passed; the static effect-API check falsely classified
  `RegExp.exec` as process execution. Narrowed it to actual effect APIs; no
  transport or preparation behavior was relaxed. Second run 17/17 passed.
- `CARGO_NET_OFFLINE=true python3 scripts/check.py`: passed format, locked build,
  clippy, workspace tests, rustdoc, CLI/daemon finite smoke, local doc links and
  intentional-failing-test gate. No Rust/site/lockfile changes.
- `CARGO_NET_OFFLINE=true cargo deny --locked check`: passed advisories, bans,
  licenses, sources using available local data (not proof of advisory freshness).
- `python3 scripts/secrets.py` after staging all seven changed files: passed
  tracked-file/history scans and intentional synthetic-secret rejection gate.
- `git diff --cached --check` and final local documentation-link check: passed.
  Seven assigned files staged, uncommitted; no unrelated changes present.
- Native runtime, Linux execution, remote CI, independent review and installed
  host/privacy/permissions acceptance: **not run**. No commit/push performed.
