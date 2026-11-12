# Evaluation-only static direct-call prerequisite

**TM-02/04/07/10; P1-A1/P1-A5 PARTIAL. Phase 1 OPEN.** This is a conservative
authored resolver for the frozen candidate arm, **pending independent policy and
observed-coverage review, NOT ARMED**. It is not Graphify adoption, a production
graph replacement, daemon, index, worker integration or comparative study.
The full [product](../../docs/product.md), [Phase 1](../../docs/spec/phase-1-feasibility.md)
and proposed [ADR 0006](../../docs/decisions/0006-phase-1-evaluation-protocol.md)
remain unchanged. No context/refinement/hosts/inference/UX/safety scope is waived.

Run with Python 3.10+ stdlib, from the repository root:

```sh
python3 -B -m unittest discover -s experiments/evaluation-directcall -v
```

## API, inputs and frozen selection

`extract(sources, scope)` returns a frozen `Extraction` containing immutable
`declarations`, `resolvedcalls`, `observedcoverage`, and `policyversion`.
`retrieve(sources, task)` returns a tuple of frozen six-field `Anchor` values:
project/worktree/revision/path/line/text. Both close with a generic `ValueError`
without parser-content diagnostics, partial results, fallback, cache or mutation.
There is no cancellation callback, process, timeout or resource-containment API.

Inputs use exactly the existing symbol boundary: tuple of `(str path, bytes)`
pairs, strictly increasing UTF-8 paths including the selected project root;
`.rs`, `.py`, `.md` only; no traversal, empty/dot components, backslashes,
absolute paths, controls, duplicates, mutable data or mixed roots. Maximum 2048
sources, 32 MiB aggregate, 65536 bytes/file. Scope has exactly project/worktree/
revision, each ASCII `[A-Za-z0-9_-]{1,128}`. Labels and hashes are consistency
values, **not credentials, authorization, verified Git facts or freshness**.
The caller must independently establish the complete authorized source set.
This API cannot detect an omitted file or stale bytes relabeled current.

Task fields are exactly schema/scope/family/query/instructions; schema
`evaluation-scoring/1`; only the two symbol relevance families are supported.
Nonempty query/instructions have a combined canonical-object limit of 4096 UTF-8
bytes. Original instructions are not rewritten or used as identifiers. No oracle,
fixture, answer hash, fact kind or private coverage is an extraction input.

All bytes validate and **all bindings and calls extract before selection**, even
for an empty match. A late invalid irrelevant file closes the entire operation.
LF splitting removes one trailing CR/line, omits only the final empty split
segment, retains blank lines, and rejects remaining CR. Byte coordinates are in
that normalized snapshot (including omission of its terminal LF), not raw CRLF.
Whole normalized source lines alone are anchors.

Frozen ranking, unchanged from the [scorer](../evaluation-scoring/README.md):

1. Exact whole declaration names match maximal ASCII regex identifiers from the
   **original query**, case-sensitive, unique first-occurrence order. No semantic
   expansion, kind filtering, oracle narrowing or lowercasing.
2. Include only resolved direct calls targeting those declarations, **one hop**.
   An unrelated caller's name matching a query does not create its callees.
3. Rank all declarations before all calls, then earliest target identifier index,
   UTF-8 path bytes, numeric line. Shared coordinates retain their best rank.
4. Select top eight whole anchors. Reject the entire result if their complete
   canonical JSON **list** exceeds 8192 UTF-8 bytes. Never choose cheaper losers.

Canonical JSON uses sorted keys, compact separators, raw UTF-8, no NaN/newline.
All caps are postallocation arithmetic, not CPU/RSS/hostile transport containment.
Unlike the cropped symbol retriever this extractor retains every internal call;
more than eight matched declarations intentionally crop all call anchors.

## Identity and boundary checks

Declaration identity is an immutable tuple:

```text
(project, worktree, revision, path, language,
 ((lexical_owner_kind, owner_start_byte, owner_end_byte), ...),
 declaration_keyword_start_byte, kind, raw_ASCII_name)
```

Call identity contains its own lexical-owner chain and **callee span start/end**
instead of a declaration suffix. Separate calls between the same endpoints,
including two calls on one line, remain distinct extraction records. Retrieval
alone deduplicates source coordinates. `target` is the complete declaration ID,
not a basename or hash. `callable` denotes structural eligibility; uniqueness and
masks are checked separately. IDs are deterministic for an identical supplied
snapshot and do not depend on traversal order. Owners include spans: changes to the
snapshot can change IDs, even without renaming. Different roots/revisions,
renames and nested owners are distinct; no cross-revision lineage is claimed.

Declarations anchor the declaration keyword line (Python async anchors async).
Calls anchor the callee-expression start line, not the argument/closing-paren
line. Python AST byte columns are used directly; tokenizer character columns
are converted to UTF-8 before matching declarations. Raw Unicode/NFKC names
cannot become ASCII-prefix targets. Rust spans are attached to the **pinned
baseline lexer** tokens by reconstructing trivia/opaque-literal extents, not by
regex-searching call text. Whole tokens, not substrings, resolve.

The internal completion boundary validates exact returned records against the
per-file observations, coverage path/counts, endpoint identity and callable
eligibility, byte boundaries/UTF-8, source line, scope/path/language and duplicate
IDs. Missing coverage, changed endpoint/span or internal dependency failure closes
the whole result. This is a corruption/error boundary, not protection from
same-interpreter monkeypatching or an independent semantic verifier.

## Predeclared Python static binding policy

The running interpreter's **whole-file** `ast.parse` plus `tokenize` is used;
grammar major/minor is recorded in the policy manifest. No import, compile,
evaluation or execution of supplied examples occurs. AST parsing is not compiler
context checking, name/type checking or proof that a program can execute.

- Keep whole-ASCII, same-physical-line `def`, `async def`, `class` declarations,
  including nested, decorated and conditional ones. Only unique, unconditional,
  undecorated def/async-def bindings are eligible callable targets. Classes are
  declaration evidence, not verified constructor targets.
- Collect **all** scope bindings before resolving: arguments (all forms), local
  assignments/annotations/augmented assignments/deletions, imports/aliases,
  loop/with/exception targets, assignment expressions, match captures/rest names,
  function/class names and conditional definitions. Any duplicate or mask means
  no edge; no first/last wins. Whole-function masks apply even before assignment.
  Module bindings are also collected statically, not evaluated in source order.
- Bare Name calls in assignments, returns, nested arguments and keyword arguments
  resolve by lexical ownership. Module-function-body references to a unique module
  function use a **declared static assumption**, not runtime object identity.
  Nested local functions and class-local callable bindings additionally must end
  before the call's source position; forward class-local references are left
  unresolved rather than targeting a method not yet initialized.
  uninitialized/recursive forward locals are unresolved. This deliberately
  under-resolves some valid recursion and later initialization paths.
- Class bodies are not lexical closures for methods/nested scopes. A method's
  bare name can reach a module function, never a sibling method through the class
  dictionary. Constructor/member/self/subscript/dynamic-global calls are unresolved,
  never basename-resolved. Aliases/imports do not transfer callable identity.
- Class-private binding and lookup keys follow the lexical class name-mangling
  rule, including leading-underscore class names and nested class contexts;
  declarations/IDs retain their raw source names. Class-associated function,
  lambda and comprehension scopes mask the implicit `__class__` cell so it cannot
  fabricate an edge to a same-spelling module function. This conservatively
  under-resolves explicit rebindings of that cell.
- Class dictionaries mask compiler-created `__module__` / `__qualname__`,
  `__doc__` when a class docstring exists, and `__annotations__` when an annotated
  assignment is present. These whole-scope masks may under-resolve explicit later
  rebinding; methods still skip the dictionary and can reach ordinary module
  functions with those names.
- Comprehensions have a separate masked target scope; the first iterable uses the
  enclosing context. Walrus targets mask the enclosing non-comprehension scope.
  Lambda arguments mask its own body. These are static observations, not flow or
  execution-order proofs. Global/nonlocal names conservatively mask **all**
  ancestor scopes, potentially losing unrelated edges rather than guessing.
- Calls in defaults, annotations, decorators, class bases/keywords are explicitly
  **unsupported execution contexts**, not walked in the function-body scope.
  Named-expression bindings inside them still mask the enclosing scope
  (conservatively also in nested lambdas). Variable annotation expressions are
  likewise unsupported call contexts but their named-expression stores still
  mask affected module/class/function bindings. Decorated targets remain declarations
  but are not callable bindings. Unknown statement/binding constructs poison the
  affected scope; e.g. Python 3.12 type aliases. New grammar unsupported by the
  running interpreter rejects the entire input. Type-parameter function bodies
  are poisoned. No monkeypatch, dynamic exec/globals or runtime-replacement proof.

## Predeclared Rust subset and masks

Each file is a standalone unit; **no crate graph or cross-file basename merge**.
The reviewed symbol `_rust_tokens`, identifier rules, delimiter/opaque-token
behavior and textual noncallable declaration coverage are reused through an
explicit internal source hash, **without changing/copying the other arm**.

- Build file/module/block/function/impl/trait ownership and all masks before
  recognizing calls. Parse fn item boundaries, modifiers, name, recognized generic
  angles, parameter group and body/semicolon. Named fn outside an item boundary
  rejects (`let fn target() {}` is never a verified target).
- Unique visible free fn items in file/module/block scopes are eligible; item
  visibility precedes textual declaration order. Bare calls in let initializers,
  tail expressions, returns and arguments are supported. Nested fn items shadow
  outer items. Simple name:type parameters and simple let bindings mask the entire
  affected block/function, conservatively even before a Rust let declaration.
- Nonfunction item bindings mask independently of same-line evidence eligibility:
  multiline tuple structs, constants and statics cannot expose an outer function
  merely because their declarations are excluded from emitted anchors.
- Modules do **not** implicitly import their parent's unqualified names. Local
  module paths and super/crate paths are currently unresolved; no guessed path
  resolution. Impl/trait methods remain declarations, never another method's bare
  lexical binding. A method can reach an unmasked file free fn. Raw ASCII names
  (`r#name`) retain raw byte coordinates and resolve as whole names.
  IDs retain the exact `r#name` spelling in `rawname`; query matching uses `name`.
- Generic function bodies and generic impl/trait scopes are conservatively
  poisoned. Generic headers/type bounds/function pointer types are not call text.
  Type/const/static item initializers are explicitly unsupported call contexts;
  their textual declarations are retained but never callable targets.
- use/import aliases/globs, extern binding contexts, destructuring/unknown
  parameter or let patterns, for/if/while/match constructs, expression casts and
  expression-level angle brackets (including qualified type paths, whose type
  spans must not fabricate calls, and conservatively ordinary comparisons), closures, macro
  invocations that could introduce bindings, and attributes/cfg poison their
  **affected scope**. This can suppress valid neighbors, but not unrelated files
  or sibling function scopes. Macro token trees are opaque; no generated targets.
- Receiver/member/trait/Self/Type/qualified dispatch and generic callee expressions
  are unresolved with explicit reasons, never basename edges. There is no
  expansion, cfg evaluation, external resolution, function-pointer/alias tracing
  or type inference. Comments, strings (including raw hash/byte/C), chars,
  lifetimes and macro trees do not fabricate calls.

Lexical, delimiter and recognized-subset structural failures reject everything.
**Balanced unsupported grammar is NOT Rust syntax certification**: the subset
cannot certify arbitrary expressions, item/type grammar, escape values, editions,
Unicode XID or lifetime-versus-malformed-character intent. A structurally
recognized `fn` is eligible only under the declared subset/static assumptions,
not evidence that rustc accepts the file. No Rust compiler runs on examples.

## Observed coverage, dependencies and admission gate

Every supplied file, including empty Markdown, has an immutable observation:
path/language, `ast_parsed` / `lexed_subset` / `not_code`, normalized bytes/physical
lines, declaration/resolved-call counts, unresolved callee spans/reasons and
sorted gap labels. Unsupported execution contexts have gap labels, not invented
calls/zero-gap claims. There is deliberately **no `complete=true`**.

The existing adapter's authored source-map envelope is a different fact from
observed parsing/resolution and from language coverage. None can authorize the
others. Future candidate **and** runner admission must independently reconstruct
this policy and observations from the same trusted sources, reject missing/
partial/mismatched data, validate exact anchors and count **all metadata** inside
the full 8192-byte envelope. Retriever self-reported coverage is not authorization.
This integration is intentionally absent; current runner/candidate do not select
this arm, and no comparative run is permitted by these tests.

`policy_manifest()` returns immutable supplemental canonical bytes with version,
Python grammar, explicit symbol internal-dependency SHA-256, preserved scorer
contract/source and corpus/source pins, policy descriptions, pending-review state
and a digest (excluding its own field). It does not rewrite the frozen scorer
CONTRACT, schema, corpus recipe, algorithm pins, digest, historical
`NOT_IMPLEMENTED` / `NOT_RUN` strings or runner binding list. The source of the
fixed repository-owned symbol module is checked once at import through its loader;
the pure extraction/retrieval calls perform **no input filesystem IO**. Missing/
changed import dependencies fail rather than choosing another parser. Pins are
value consistency, not credential/security protection against Python code in the
same interpreter. No third-party dependency, installation, network or lock change.

Graphify 0.9.101 is **not executed or adopted**: prior reviewed evidence reports
cross-root ID collisions, malformed-source completion, inference/location gaps
and endpoint-pair edge deduplication discarding separate call lines. Wrapping that
output cannot establish this prerequisite. An authored resolver is an evaluation
policy choice pending review, not a production replacement decision.

## Evidence and exclusions

Tests use independent literal expected anchors, edges and target IDs for both
languages. Separate few-declaration fixtures prove real call resolution. The
frozen SMALL corpus has eight `resolve` declarations, so a declaration-only
top-eight result there would **not** prove calls work; this suite does not use
SMALL as a call-resolution oracle. Tests cover ambiguity/masks/poison, ownership,
UTF-8/CRLF/blank/multiline coordinates, identity/revision/rename/delete/fresh
recovery, late invalid input, dependency/coverage/endpoint/span rejection and
exact inclusive canonical budgets. No medium/large retrieval, metrics or study.

No new actual runner worker, candidate/runner integration, daemon, storage, source
discovery/export, listener, credential/provider/config/clipboard/telemetry/login,
site/runtime/dependency/lockfile/Docker or deployment capability is added.
Review, committed implementation SHA and exact-head CI remain parent-owned.
See the [staged handoff record](../../docs/progress/phase-1-evaluation-directcall.md).
