# Compiler-only candidate plan — inert, execution CLOSED

TM-04/TM-05/TM-08/TM-10; supporting P1-A2/P1-A5 prerequisite only. Neither
acceptance ID nor Phase 1 is completed. This is a macOS-first **plan candidate**,
not a sandbox, launcher, certified compiler check or native OpenCode bridge.
Linux execution is unsupported until a separately reviewed actual policy exists.

`compiler_plan.build_descriptor` validates already-owned bytes and returns plain
data. There is no CLI, process start, Node probe, SDK import, config write, install,
acquisition, dynamic evaluation or network operation. Its only filesystem effects
are reads. Existing native `test_*.py` discovery includes the pure synthetic tests;
there is no new dependency or workflow. No actual SDK selection is approved.

## Authority and byte bindings

The caller supplies exact manifest bytes **and a separately operator-approved
SHA-256**. Supplying a document's own hash is not review; the API cannot authenticate
an operator. A future consumer must obtain the approved digest from the trusted
parent/review channel, not the artifact, filenames, copied ledger or archive.
`reviewId` identifies that external decision, not a credential/signature. Unknown
manifest keys and duplicate JSON keys reject; flags/options are not pass-through.

The reviewed manifest explicitly binds:

- Exact lock bytes and the existing projection plan's canonical hash. Projection
  archives are rehashed and re-inspected by `prepare_files`. All selected source
  files and **complete package.json** are compared to authentic selected archive
  bytes. Exact reconstructed ledger bytes/hash, `prepared_not_compiled`, no
  `INCOMPLETE`, and no extra files or directories are required. Old metadata's
  claimed closure cannot approve a plan. Known missing types, unresolved requested
  requirements and missing notices fail closed, even with a new manifest digest.
  The descriptor exposes the verified per-read-file hashes (including generated
  config bytes) and ledger hash for review and future launch-time comparison.
- An explicit source-file inventory/hash and unique canonical TypeScript roots.
  Owned sources must be strictly decoded UTF-8 (optional UTF-8 BOM), without NUL;
  UTF-16 and malformed encodings reject rather than bypass directive checks.
  No JS roots or owned-source `@ts-ignore`, `@ts-nocheck`, `@ts-expect-error`.
  Selected upstream source is not rewritten or executed. Its own directives and
  semantic effects still require consumed-file review, not synthetic proof.
- TypeScript **6.0.3**, `lib/tsc.js`, required `lib/_tsc.js`, reviewed helper/lib
  files, complete metadata, `LICENSE.txt` and `ThirdPartyNoticeText.txt` hashes,
  Apache-2.0, and the exact separately verified archive identity:
  `sha512-y2TvuxSZPDyQakkFRPZHKFm+KKVqIisdg9/CZwm9ftvKXLP8NRWj38/ODjNbr43SsoXqNuAisEf1GdCxqWcdBw==`.
  **External inventory review must attest that every inventory hash was derived
  from that verified archive**, including all needed helpers/default libraries
  and actual legal notices. `archiveVerified: true` is that review's attestation,
  not archive verification performed by this builder. No real compiler archive
  is projected here. Synthetic tests use inert invented inventory bytes with
  this identity pin; they do not prove the real archive's contents or notices.
- Node's exact absolute path, version, SHA-256 and reviewed inventory identity.
  No `which`, PATH search, version probe, download or caller version assertion
  substitutes for external inventory review binding that version to that hash.
  The builder proves actual byte/hash equality, regular single-link identity and
  owner-executable/non-group/world-writable mode, **not version semantics from
  bytes**. No actual machine Node inventory is approved by these tests.

Every supplied root and ancestor must be canonical, not a link. All inventoried
files must be single-link regular files; compiler files are nonexecutable. Extra
libraries/runtime files, links, FIFOs, case/NFC aliases, relative/traversal/control
paths and ambiguous duplicate roots reject. Parent directories and the reviewing
caller are trusted against concurrent same-UID mutation: this is not a hostile
container boundary. Observations are snapshots; any future launcher must recheck
all approved bytes/config/modes immediately before launch, with descriptor-based
access and a reviewed immutability strategy. The candidate is not a bearer token.

## Layout, config and environment

Authentic projection files retain `projection/node_modules/...` paths. Separately
approved owned fixtures live only in `projection/__compiler_roots/...`, so official
ancestor-based module resolution can find projected packages without invented
aliases. These extra fixtures are individually hashed and included in the exact
combined inventory. Compiler and workspace roots are separate/nonoverlapping;
Node is outside them. No whole home/private/repository read allowance is emitted.

An empty private owned workspace is required. The builder returns owned config
**data and its hash**, not a written config. The future launcher must exclusively
create the private state directories, empty typeRoots and exactly these config
bytes, revalidate, and never discover ambient config. Only fixed candidate argv:
absolute reviewed Node, `--max-old-space-size=1024`, exact compiler entrypoint,
`--project`, owned config. No arbitrary CLI/shell string or extra Node flags.

Owned config fixes `noEmit: true`, `strict: true`, `skipLibCheck: false`,
`skipDefaultLibCheck: false`, `types: []`, an explicit empty owned `typeRoots`,
`module: ESNext`, `moduleResolution: Bundler`, `target: ESNext`, explicit root
`files`, empty `include`/`exclude`. Optional JSX is only `preserve` (mandatory for
TSX roots). No extends, plugins, aliases/paths, custom resolver, allowJs/checkJs,
watch/build/incremental/composite/noResolve, emit artifacts, suppressions or
library skips. Normal official library/module resolution is intentional; known
missing requirements reject beforehand, but **unknown module/type graph problems
cannot be diagnosed without the future official compiler**. An externally reviewed
inventory may be a discovery candidate, never a claim of complete type closure.

Environment is replaced, never inherited: owned HOME, TMPDIR, XDG config/cache/
data/state, C locale, fixed `/usr/bin:/bin` PATH. No NODE_OPTIONS, NODE_PATH,
TS_NODE variables, auth, credentials, user npm configuration or provider state.
The fixed candidate also sets `NODE_DISABLE_COMPILE_CACHE=1`: authentic pinned
`tsc.js` attempts `enableCompileCache()` unconditionally. This documented Node
control was subsequently measured by the separate fixed Node-only guard;
absence of NODE_ENV avoids the development-only
source-map-support branch. The separate fixed Node-only guard must observe
`getCompileCacheDir() === undefined` and the named `compileCacheStatus.DISABLED`
result before any later compiler authorization. Both observations passed for the
exact reviewed local runtime; no numeric enum is assumed or generic runtime claimed.
The first contained Node-only CommonJS attempt exposed denied ambient OpenSSL
configuration loading. A separate candidate now supplies a fixed owned config
through documented `--openssl-config`, never host settings. That fixed Node-only
candidate's complete measurement passed after separately reviewed named page-size/
uname reads. This inert compiler descriptor does not yet
model that configuration and is not executable authorization.
The fixed PATH is not spawn permission. Read/write names are typed JSON strings
and argv arrays, not interpolated shell or SBPL. Quotes are preserved as data;
controls reject. A later policy serializer must use reviewed SBPL string escaping
and prove injection negative controls; this unit deliberately emits no SBPL.

## Containment candidate and cleanup obligations — NOT verified

Named policy: `threadmark-compiler-macos-deny-default-v1`. Typed intentions are
deny-default, deny network, deny target child spawn, individual approved read
files only, writes only into exact newly owned state directories. No recursive
read roots or guessed system/dyld allowances exist. Config and approved file
lookups will need explicitly reviewed metadata traversal rules as well as byte
reads. Minimum Node/dyld/system files, pinned sandbox-exec/trusted process owner,
their bootstrap execution exceptions and exact macOS policy remain **PENDING**;
do not turn a missing runtime inventory into `/`, `/Users`, repo or home access.
Compiler libraries/helpers not in the approved inventory cannot be read. This
candidate is deliberately not runnable and does not broaden host-isolation policy.

A future reviewed launcher must use retained process-owner semantics from
`../../host-isolation/process_supervisor.py`: owner retains the group identity,
private status pipe proves target status independently of output EOF, control-pipe
EOF handles parent death, and target does not inherit ownership channels. Review
bootstrap/owner exceptions separately from the target's no-spawn policy. Do not
copy the older EPERM-as-cleaned bug: permission errors, unknown status, missing
owner/status proof, unreaped members or incomplete kill are **unknown cleanup**,
never success. Quarantine owned artifacts, stop reuse and report the failure.

Independent budgets are **120 s wall**, **16 MiB combined stdout/stderr**,
**1 GiB V8 old-space heap**, **2 s cleanup proof**, including cancellation and
failure paths. V8 old-space is not a total RSS/native-memory limit; a future
launcher needs a reviewed actual OS/resource strategy and measurements before
claiming broader memory containment. No process framework is implemented here.

### Future measured negative-control matrix (none run by this unit)

| Boundary | Required observed result before execution approval |
| --- | --- |
| Private canary / home / repo / config ancestors | Forbidden bytes unreadable, no disclosure in logs; minimum allowed lookup still works |
| Network / DNS / localhost | Denied, no listening or egress, including dynamic imports |
| Writes / cache / emitted artifacts | Only owned state writable; no compiler emit or ambient cache/config mutation |
| Config / typeRoots / package discovery | Ambient extends, user/global types and ancestor config cannot inject code/types |
| Plugins / resolver / Node options / SBPL injection | No plugin or custom loader execution; malformed path/options reject |
| Child escape / descendant | Spawn/exec escape denied; descendants covered by retained owner and independently proven cleanup |
| Wall / output flood / heap | Threshold aborts bounded; combined output counted; no output-content evidence leakage |
| Cancel / timeout / dependency failure | No inferred success; owner/status and all group cleanup proven within 2 s |
| Parent death / output EOF / permission failure | Control EOF kills group; EOF alone not exit proof; EPERM/unknown quarantines |
| Recovery / stale candidate / changed bytes | No reuse after unknown cleanup; new approval/revalidation on drift |

The descriptor always returns `executionApproved: false`, `containmentVerified:
false`, `typeGraphClosure: NOT established`, and runtime closure unestablished.
Independent plan review, exact runtime inventories, measured negative controls
and **new explicit parent execution authorization** are separate mandatory gates.
Actual compiler diagnostics must then prove non-any positive and intended-error
negative assertions and trace every consumed file to approved bytes/notices.
Tests here cannot mock those gates into passing. Full runtime dependency closure
is a different, still-blocked gate; a future separately authorized compiler-only
path does not require executing that runtime, nor waive its missing type/notice
requirements. A historically approved filename/audit is not such authorization.

Full native SDK/TUI capture and immutable attachment/mention fidelity, exclusive
review leases, revision/scope revalidation, real admission acknowledgment,
context ownership and refinement remain open. No currentTurn guess, synthetic
SDK type, ambient stub, `any` escape or reduced product scope is introduced.
