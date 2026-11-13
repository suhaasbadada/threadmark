# Fixed compiler-only containment — measured standalone smoke

The independently reviewed owned-cwd-read candidate
`aea72b77d1cacbcd2daf30aa5b555f6b52b94e8e7c336d3970b8235702039caf`
passed one primary-authorized actual invocation: version 6.0.3, positive semantic
success, intended negative TS2322/exit 2, exact 93-library-plus-fixture reported
program closure, all pre/post validations and verified cleanup. Earlier failures
below remain retained; this is standalone compiler evidence, NOT SDK compatibility.
Success receipt binds provisional record SHA-256
`e969a38afdb040eac3919f2da44c0ef10d2afa12db7810586eb87a4ba909f5eb`
and that exact review digest. No further execution is automatically authorized.

The preceding exact path-fix candidate was independently reviewed and received
one primary-authorized real invocation: version **6.0.3 PASS**, positive **BLOCKED**,
negative **NOT_RUN**, cleanup reported verified-or-not-launched, reported program
closure **NOT established**. Raw output and precise rejection reason were discarded;
the positive failure's root cause is unknown. This retention repair is a NEW inert
candidate, not a retry or inherited execution authorization. Subsequent reviewed
literal owned-cwd read repaired the observed failure, as recorded above.

Persisted `result.json` success is explicitly provisional:
`compiler-checks-passed-unconfirmed` / `awaiting-successful-return`. It cannot
certify its own final fsync/close. Only a successful `run_guard` return provides
`successReceipt` binding the approved review SHA-256 and provisional record hash.
A record without that successful-call receipt is never terminal success. This is
an integrity/audit binding, not authentication against a malicious same-UID owner.

TM-04/TM-05/TM-08/TM-10; P1-A2/P1-A5 prerequisite **PARTIAL** only. No SDK,
native bridge, complete type/runtime closure, host certification or Phase 1 close.
This supersedes neither the blocked SDK graph nor the inert descriptor's contract
in [COMPILER-PLAN.md](COMPILER-PLAN.md). The latter still never launches anything.

`compiler_containment.py` adds separate fixed preparation/review/measurement APIs.
There is no CLI, import-time I/O, acquisition, installation, arbitrary executable,
argv, flags, source, config, profile or compiler-descriptor execution API. Actual
compiler execution remains CLOSED until independent exact code/policy/inventory
review **and new explicit primary authorization**. No new CI measurement exists.

## Inert preparation and review

`prepare_review` accepts only already-owned archive bytes, the exact approved
Node-review bytes/digest and a fresh owned materialization destination immediately
under this machine's approved private experiment parent. It does not run Node,
the compiler, SDK, sandbox, package scripts or static inspection tools.

Compressed SHA-256 and SHA-512 must match the exact TypeScript 6.0.3 pins **before**
`project_types.inspect` performs full bounded archive preflight. No tar extraction
API is used. This is a separate compiler-specific selector, not a relaxation of
the declaration projector: precisely `lib/tsc.js`, `lib/_tsc.js`, complete
`package.json`, actual `LICENSE.txt`/`ThirdPartyNoticeText.txt` and all 107 authentic
`lib/lib.*.d.ts` files are copied unchanged. Metadata must declare typescript,
6.0.3 and Apache-2.0. No bin/native/build-script file is selected. JS remains
0400 nonexecutable data. Complete metadata may describe scripts; none execute.

All preflight precedes fresh 0700 destination creation. Exclusive nofollow dirfd
writes, copy hashes, an incomplete marker and atomically finalized ledger prevent
overwrite or silently accepted partial preparation. Failures preserve owned
artifacts. The final exact tree rejects extra/missing directories/files, links,
hardlinks, executable files, case/NFC/file-ancestor collisions and invalid roles,
metadata, notice/helper hashes or sizes. Private authentic bytes are not vendored,
uploaded or distributed. Archive inputs are never modified.

Outer review bytes bind archive identity, every selected hash/size/explicit role,
materialized root, exact nested approved Node-review bytes/digest, both fixed
fixture hashes, and launcher/config/policy generator/projection-validator source
identities. Node's existing manifest also binds all runtime aliases, source and
system fingerprints. `read_review` requires an externally approved SHA-256, not a
JSON approval boolean, copied ledger or self-generated hash. The API cannot
authenticate caller authority. Preparation's self-readback is validation only.

The 18-file/24-alias measured Node inventory and all its existing fingerprints
remain unchanged. Same-UID parent trust and no concurrent Homebrew updates remain
explicit assumptions, not universal TOCTOU or hostile same-UID containment proof.

## Fixed future attempts

Only these three attempts, once each, in order:

1. Authentic compiler `--version`: exact `Version 6.0.3` and zero exit/stderr.
2. Fixed positive strict program: ordinary typed function/result, independent
   `Assert`/`IsAny` checks for non-any types, zero diagnostics and exit zero.
3. Fixed negative program: `const bad: number = 'synthetic'`; exactly the controlled
   TS2322 diagnostic, exit **2**, and no other diagnostics/stderr.

Node argv fixes 1024 MiB V8 old-space, owned comment-only `--openssl-config`,
authentic `lib/tsc.js`, and either `--version` or `--project` plus the exact owned
config. No `listFilesOnly`: it would skip semantic checking. Config fixes strict,
noEmit, both library skips false, types empty, empty owned typeRoots, ESNext target
and module, Bundler resolution, explicit files, empty include/exclude, listFiles
true and pretty false. No ambient config, extends/plugins/paths/custom resolver,
watch/build/allowJs/noResolve/suppression or pass-through option exists. Owned
sources strictly decode UTF-8, reject NUL and all three `@ts-*` suppression forms.

Output parsing rejects partial, malformed, duplicate, outside, unknown or missing
program files, arbitrary source echoes and extra diagnostics. Every reported path
must exactly match an approved authentic library or the one owned root. A separate
inert literal-reference oracle traverses `lib.esnext.full.d.ts`'s fixed default-lib
references: all expected libraries plus exactly the selected fixture must appear.
This deliberately narrow oracle is not a general TypeScript resolver or SDK proof.
Any unexpected real compiler behavior fails closed; no automatic retry or policy
relaxation follows. Public evidence contains only version, diagnostic codes,
approved relative identities/roles and hashes, never output, source or private paths.

## Containment and lifecycle

Policy reuses the measured Node deny-default literal runtime/alias read/map rules,
public-system discovery baseline and seven named page-size/uname metrics. Those
are not minimum system closure; hostname-read capability is still process-wide.
Only exact approved compiler/library/metadata/notices/fixture/config data reads and
literal ancestor metadata are added. JS gains no file-map-executable permission.
Unused Node probe/read-canary rules are removed, without changing the Node policy
generator itself. No recursive compiler/SDK/private/Homebrew read, target fork,
network, Mach-service or new OS permission is added. The shared SBPL serializer's
escaping and independent emitted-policy semantic oracle are reused.

Environment is replaced by the measured clean environment/cache-disable control,
not inherited NODE_ENV, NODE_OPTIONS, NODE_PATH, coverage, DYLD, ICU or SSL state.
Only the six fresh owned state directories are writable; noEmit is mandatory.

The retained process owner remains responsible for independent target status and
2-second cleanup proof, never output EOF. Preflight, initialization and I/O count
toward a 110-second launch/final-validation deadline within the 120-second envelope,
reserving 10 seconds for cleanup. Combined stdout/stderr is **16 MiB aggregate**,
not per attempt. V8 old-space is **not** total RSS/native-memory containment.
The reserve is not a universal filesystem-latency guarantee; actual timings and
owned artifact removal still need observation on the reviewed fixed candidate.

Compiler-only run artifacts use a local context under the approved private parent,
not the measured C/Node artifact prefix: its literal POSIX backslash is normalized
to a separator by authentic TypeScript. The local prefix retains quote/injection-
shaped punctuation but no backslash. Shared C/Node sources, fingerprints and their
full adversarial quoting tests remain unchanged. Both materialized compiler roots
and run roots reject backslashes, dot/empty/traversal components, control characters
and non-ASCII policy paths before preparation/launch, without silently normalizing
them. Parent validation precedes fresh directory creation. The small local context
shares the existing quarantine/retained-artifact registry, cleanup-unknown handling
and signal-masked owned-directory removal; it does not introduce another process
owner or general lifecycle framework. Directories stay 0700 and protected files
0400; the late-preparation INCOMPLETE marker spans final validation as before.

Runtime/compiler/source/fixture/config/policy bytes, aliases, exact immutable
artifact tree and protected directory identities are checked before and after
**every** attempted launch, including errors/cancel/timeout. Interrupted or failed
postchecks quarantine reuse and retain artifacts even on zero exit. Unknown owner
cleanup or removal likewise retains; no automatic retry/reset exists. Known target
failure with independently verified cleanup removes only fresh owned run artifacts.

Reported **program-file closure**, literal sandbox **read containment**, and
Node/compiler **loader inventories** are distinct claims. listFiles is not a trace
of all metadata/system reads; static helper selection is not formal dynamic helper
closure. The previously measured Node controls are not new compiler observations.

## Private diagnostic retention (new candidate, NOT EXECUTED)

Before creating launch artifacts, the guard prepares a fresh fixed-prefix 0700
evidence directory immediately under the approved private parent. It is a sibling,
not a child of any sandbox-readable compiler root or readable/writable run root.
The policy is unchanged and grants no read/write access to evidence files. Failure
to prepare/fsync the sink prevents launch. Its implementation is in the already
hash-bound `compiler_containment.py`; shared measured Node/C/owner sources are
unchanged. Same-UID trusted-parent assumptions remain, not filesystem immutability
against a malicious owner.

Fixed per-attempt stdout/stderr files retain returned bytes privately, including
failure and success output, never in public evidence, exceptions, logs or source.
The aggregate retained output cannot exceed the existing **16 MiB** output budget;
an owner-returned oversize result is truncated privately and fails closed. No
generic logger, output-derived filename or pass-through policy is introduced.
Files use exclusive dirfd/nofollow 0400 pending writes, fsync, exclusive final-name
reservation and atomic rename, then directory fsync. Existing names cannot be
replaced. Interrupted/failed pending writes and all earlier evidence are retained,
never deleted or retried. A pending file, empty reserved final file or absent final
`result.json` is incomplete evidence, **never a pass or verified cleanup**.

Private metadata binds the exact review digest, returned exit codes, byte counts,
truncation, before/after validation, safe stages, recognized failure codes and
final cleanup outcome. The operator can discover the private sink via the private
module registry/fixed prefix; no private path is placed in returned public evidence.
Public errors retain a fixed message and closed-vocabulary metadata, never arbitrary
exception text/repr or compiler diagnostics. The strict `observe` contract is
unchanged; unexpected real diagnostics still reject rather than being waived.

The measured owner's existing API returns bounded outputs on normal return but
does **not** expose partial bytes or exit status when it raises. Those cases record
`unavailable-owner-raised`/null exit status and safe owner failure code; this repair
does not claim to recover unavailable bytes or alter the measured shared helper.
Postvalidation still runs on owner failure/cancellation. Capture/after-record
retention failure or incomplete postvalidation quarantines/retains run artifacts;
unknown owner cleanup likewise quarantines. Known semantic failure with verified
owner cleanup may remove run artifacts, but NEVER the separate evidence directory.
Final metadata retention failure blocks a pass. Uncatchable termination can leave
only partial private records, with cleanup unknown, not fabricated completion.

## Verification boundaries

`test_compiler_containment.py` uses invented inert archive/inventory bytes and a
mocked process boundary. It never executes a compiler or new Node program. Hash
pin patches are test-only; mocked orchestration is not compiler/containment proof.
Existing native discovery finds these tests without workflow changes. Actual owned
compiler preparation is a separate private, inert operation, not live CI acquisition.

Still blocked: independently reviewed first actual compiler decision/measurement,
publisher provenance, minimum system/dynamic helper closure, DNS/IPC/JIT and total
memory containment, authentic Emscripten/SDK/type/notice graph, native TUI capture,
review/admission fidelity, and full product/Phase 1 acceptance.
