"""Evaluation-only static bindings. Never execute supplied source or discover files."""
import ast
from dataclasses import asdict, dataclass
import hashlib
from importlib import import_module
import io
import sys
import tokenize


VERSION = "evaluation-directcall/1"
SYMBOL_SHA256 = "d09e22d3a7d3f077673d672920bbeeff983de778407684ec6dc5c9e53ba63a60"
_symbol = import_module("experiments.evaluation-symbol.symbol")
# Fixed authored CODE dependency only, at import. No supplied-source IO in either API.
_dependency_sha = hashlib.sha256(
    _symbol.__loader__.get_source(_symbol.__name__).encode("utf-8")).hexdigest()


def _dependency():
    if _dependency_sha != SYMBOL_SHA256:
        raise ValueError("internal dependency mismatch")
    return _symbol


@dataclass(frozen=True)
class Anchor:
    project: str
    worktree: str
    revision: str
    path: str
    line: int
    text: str


@dataclass(frozen=True)
class Declaration:
    id: tuple
    name: str
    rawname: str
    kind: str
    path: str
    line: int
    span: tuple
    callable: bool


@dataclass(frozen=True)
class Call:
    id: tuple
    target: tuple
    path: str
    line: int
    span: tuple


@dataclass(frozen=True)
class Unresolved:
    span: tuple
    reason: str


@dataclass(frozen=True)
class Coverage:
    path: str
    language: str
    parse: str
    bytes: int
    lines: int
    declaration_count: int
    call_count: int
    unresolved: tuple
    gaps: tuple


@dataclass(frozen=True)
class Extraction:
    declarations: tuple
    resolvedcalls: tuple
    observedcoverage: tuple
    policyversion: str


def policy_manifest():
    """Supplemental policy bytes, NOT a replacement scoring/corpus manifest."""
    manifest = {
        "policy": VERSION, "review": "PENDING_INDEPENDENT_REVIEW_NOT_ARMED",
        "python_ast_grammar": list(sys.version_info[:2]),
        "internal_dependency": {"experiments/evaluation-symbol/symbol.py": SYMBOL_SHA256},
        "preserved_pins": {
            "scoring_contract": "2aea61ef91963863acbbe45bfe2cda1bfcf81960408bc6df219876946b2ae4ac",
            "small_corpus": "c497a577eb9699d15da30b02a215784df36bafeafcb643c83c983ba540e6c9e8",
            "scoring.py": "78d023fcb47e3a85908f0cd87ca9d3ae0126b70b330eba465c887281b6919181",
            "corpus.py": "87f884b5820060e6939e05612699fd86be193d4b36fa14ddf0cfd4f16cc09dff"},
        "bindings": "static lexical unique unconditional undecorated functions; no runtime certainty",
        "rust": "standalone file; parsed item boundaries; multiline item masks independent of evidence; casts, expression angles and unknown bindings poison scope; no grammar certification",
        "python": "AST plus raw tokens; whole-scope and annotation masks; class-private keys, implicit class cells and compiler-created class bindings including conservative __firstlineno__; class not method closure; local function and class binding initialization required",
        "identity": "scope,path,language,lexical owner byte spans,declaration keyword byte,kind,raw name; calls own byte span",
        "coordinates": "normalized LF UTF-8 bytes; decl keyword line; call callee-expression start line; whole lines",
        "failure": "whole closed ValueError; all files before selection; no cache or prefix",
        "ranking": "declarations then one-hop resolved calls; original query identifier order,UTF-8 path,numeric line; coordinate best rank; top8 then whole8192 list",
        "admission": "NOT_INTEGRATED; independently reconstruct policy/observations and budget whole envelope including metadata",
    }
    manifest["digest"] = hashlib.sha256(_symbol._canonical(manifest)).hexdigest()
    return _symbol._canonical(manifest)


class _Scope:
    def __init__(self, parent, kind, span, class_name=None):
        self.parent, self.kind, self.span = parent, kind, span
        self.bindings, self.poison = {}, False
        self.class_name = class_name if kind == "python_class" else (parent.class_name if parent else None)
        if kind == "python_class":
            self.bind("__module__")
            self.bind("__qualname__")
            # Python 3.13+ initializes this class-local integer. Conservatively
            # mask it on older grammars too rather than fabricate a global edge.
            self.bind("__firstlineno__")
        if (self.class_name is not None
                and kind in ("python_function", "python_lambda", "python_comprehension")):
            # Class-associated code scopes can receive the implicit class cell.
            # Constructors/implicit cell targets are not verified free functions.
            self.bind("__class__")

    def key(self, name):
        if (self.class_name is not None and name.startswith("__")
                and not name.endswith("__") and "." not in name):
            prefix = self.class_name.lstrip("_")
            if prefix:
                return "_" + prefix + name
        return name

    def bind(self, name, declaration=None):
        self.bindings.setdefault(self.key(name), []).append(declaration)

    def resolve(self, name, position):
        name = self.key(name)
        scope = self
        while scope:
            if scope.poison:
                return None, "scope_poisoned"
            if name in scope.bindings:
                values = scope.bindings[name]
                if len(values) != 1 or values[0] is None or not values[0].callable:
                    return None, "masked_or_ambiguous_binding"
                target = values[0]
                if (scope.kind in ("python_function", "python_class")
                        and target.span[1] > position):
                    return None, ("class_binding_not_initialized" if scope.kind == "python_class"
                                  else "local_function_not_initialized")
                return target, None
            if scope.kind == "rust_mod":
                return None, "module_requires_explicit_path_or_import"
            scope = scope.parent
            # Class dictionaries do not form a lexical closure for methods.
            while scope and scope.kind == "python_class":
                scope = scope.parent
        return None, "no_static_binding"


class _File:
    def __init__(self, path, data, scope):
        self.path, self.scope = path, scope
        self.lines = _symbol._lines(data)
        self.text = "\n".join(self.lines)
        self.data = self.text.encode("utf-8")
        self.starts = [0]
        for line in self.lines:
            self.starts.append(self.starts[-1] + len(line.encode("utf-8")) + 1)
        self.language = "python" if path.endswith(".py") else "rust" if path.endswith(".rs") else "markdown"
        self.declarations, self.pending, self.calls, self.unresolved = [], [], [], []
        self.gaps = set()

    def offset(self, row, byte_column):
        return self.starts[row - 1] + byte_column

    def owners(self, scope):
        result = []
        while scope:
            result.append((scope.kind, *scope.span))
            scope = scope.parent
        return tuple(reversed(result))

    def declaration(self, name, kind, line, span, owner, eligible, rawname=None):
        rawname = name if rawname is None else rawname
        identity = (*self.scope, self.path, self.language, self.owners(owner), span[0], kind, rawname)
        declaration = Declaration(identity, name, rawname, kind, self.path, line, span, eligible)
        self.declarations.append(declaration)
        return declaration

    def finish(self):
        for owner, name, span, line, reason in self.pending:
            target = None
            if reason is None:
                target, reason = owner.resolve(name, span[0])
            if target is None:
                self.unresolved.append(Unresolved(span, reason))
            else:
                identity = (*self.scope, self.path, self.language, self.owners(owner), *span)
                self.calls.append(Call(identity, target.id, self.path, line, span))


def _python(file):
    tree = ast.parse(file.text)
    tokens = list(tokenize.generate_tokens(io.StringIO(file.text).readline))
    positions = {(t.start[0], len(file.lines[t.start[0] - 1][:t.start[1]].encode("utf-8"))): i
                 for i, t in enumerate(tokens) if t.type == tokenize.NAME}
    root = _Scope(None, "python_module", (0, len(file.data)))

    def span(node):
        return (file.offset(node.lineno, node.col_offset),
                file.offset(node.end_lineno, node.end_col_offset))

    def mask_target(node, owner):
        for child in ast.walk(node):
            if isinstance(child, ast.Name) and isinstance(child.ctx, (ast.Store, ast.Del)):
                owner.bind(child.id)

    def expression(node, owner):
        if node is None:
            return
        known_expressions = (ast.BoolOp, ast.NamedExpr, ast.BinOp, ast.UnaryOp,
            ast.Lambda, ast.IfExp, ast.Dict, ast.Set, ast.ListComp, ast.SetComp,
            ast.DictComp, ast.GeneratorExp, ast.Await, ast.Yield, ast.YieldFrom,
            ast.Compare, ast.Call, ast.FormattedValue, ast.JoinedStr, ast.Constant,
            ast.Attribute, ast.Subscript, ast.Starred, ast.Name, ast.List, ast.Tuple, ast.Slice)
        if isinstance(node, ast.expr) and type(node) not in known_expressions:
            owner.poison = True
            file.gaps.add("unknown_expression_scope_poisoned")
            return
        if isinstance(node, ast.Lambda):
            file.gaps.add("lambda_and_default_execution_not_resolved")
            # Defaults run outside lambda, body has its own parameter bindings.
            for value in (*node.args.defaults, *node.args.kw_defaults):
                expression(value, owner)
            inner = _Scope(owner, "python_lambda", span(node))
            parameters(node.args, inner)
            expression(node.body, inner)
            return
        if isinstance(node, (ast.ListComp, ast.SetComp, ast.DictComp, ast.GeneratorExp)):
            file.gaps.add("comprehension_scope_static_only")
            inner = _Scope(owner, "python_comprehension", span(node))
            # First iterable runs in outer scope; all targets mask the inner scope.
            for generator in node.generators:
                mask_target(generator.target, inner)
            for i, generator in enumerate(node.generators):
                expression(generator.iter, owner if i == 0 else inner)
                for condition in generator.ifs:
                    expression(condition, inner)
            for field in ("elt", "key", "value"):
                expression(getattr(node, field, None), inner)
            # Walrus binds an enclosing scope, not the implicit comprehension.
            for child in ast.walk(node):
                if isinstance(child, ast.NamedExpr):
                    enclosing = owner
                    while enclosing.kind == "python_comprehension":
                        enclosing = enclosing.parent
                    mask_target(child.target, enclosing)
            return
        if isinstance(node, ast.NamedExpr):
            mask_target(node.target, owner)
        if isinstance(node, ast.Call):
            callee = node.func
            name = callee.id if isinstance(callee, ast.Name) else ""
            raw = file.data[slice(*span(callee))].decode("utf-8")
            reason = None if name and _symbol.IDENT.fullmatch(raw) and raw == name else "non_bare_or_non_ascii_callee"
            file.pending.append((owner, name, span(callee), callee.lineno, reason))
        for child in ast.iter_child_nodes(node):
            expression(child, owner)

    def parameters(args, owner):
        for arg in (*args.posonlyargs, *args.args, *args.kwonlyargs,
                    *((args.vararg,) if args.vararg else ()),
                    *((args.kwarg,) if args.kwarg else ())):
            owner.bind(arg.arg)

    def statements(body, owner, conditional=False):
        for node in body:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                is_function = not isinstance(node, ast.ClassDef)
                eligible = is_function and not conditional and not node.decorator_list
                index = positions[(node.lineno, node.col_offset)]
                keyword = tokens[index]
                if isinstance(node, ast.AsyncFunctionDef):
                    index += 1
                name_token = tokens[index + 1]
                suffix = file.lines[name_token.end[0] - 1][name_token.end[1]:]
                ascii_name = (_symbol.IDENT.fullmatch(name_token.string)
                              and name_token.string == node.name
                              and (not suffix or not _symbol._id_part(suffix[0]))
                              and tokens[index].start[0] == name_token.start[0] == keyword.start[0])
                declaration = None
                if ascii_name:
                    declaration = file.declaration(node.name,
                        "async_def" if isinstance(node, ast.AsyncFunctionDef) else "def" if is_function else "class",
                        keyword.start[0], span(node), owner, eligible)
                owner.bind(node.name, declaration if eligible else None)
                # Unsupported definition-time expressions can still bind names.
                # Collect their masks without pretending their calls execute in
                # the lexical function body. Overmask nested lambdas conservatively.
                contexts = list(node.decorator_list)
                if is_function:
                    contexts.extend(v for v in (*node.args.defaults, *node.args.kw_defaults,
                        getattr(node, "returns", None)) if v is not None)
                    contexts.extend(a.annotation for a in (*node.args.posonlyargs, *node.args.args,
                        *node.args.kwonlyargs, *((node.args.vararg,) if node.args.vararg else ()),
                        *((node.args.kwarg,) if node.args.kwarg else ())) if a.annotation)
                else:
                    contexts.extend(node.bases)
                    contexts.extend(keyword.value for keyword in node.keywords)
                for context in contexts:
                    for child in ast.walk(context):
                        if isinstance(child, ast.NamedExpr):
                            mask_target(child.target, owner)
                # Do not AST-walk these using the function's lexical body context.
                if (node.decorator_list or getattr(node, "returns", None)
                        or getattr(node, "type_params", ()) or not is_function
                        or (is_function and (node.args.defaults or node.args.kw_defaults
                            or any(a.annotation for a in (*node.args.posonlyargs, *node.args.args, *node.args.kwonlyargs))
                            or (node.args.vararg and node.args.vararg.annotation)
                            or (node.args.kwarg and node.args.kwarg.annotation)))):
                    file.gaps.add("definition_defaults_annotations_decorators_bases_not_resolved")
                inner = _Scope(owner, "python_function" if is_function else "python_class", span(node),
                               class_name=node.name if not is_function else None)
                if getattr(node, "type_params", ()):
                    inner.poison = True
                if is_function:
                    parameters(node.args, inner)
                elif ast.get_docstring(node, clean=False) is not None:
                    inner.bind("__doc__")
                statements(node.body, inner)
            elif isinstance(node, (ast.Global, ast.Nonlocal)):
                file.gaps.add("global_nonlocal_affected_names_poisoned")
                for name in node.names:
                    current = owner
                    while current:
                        current.bind(owner.key(name))
                        current = current.parent
            elif isinstance(node, (ast.Import, ast.ImportFrom)):
                file.gaps.add("imports_and_aliases_not_resolved")
                for alias in node.names:
                    if alias.name == "*":
                        owner.poison = True
                    else:
                        owner.bind(alias.asname or alias.name.split(".")[0])
            elif isinstance(node, (ast.Assign, ast.AnnAssign, ast.AugAssign, ast.Delete)):
                targets = getattr(node, "targets", None) or [node.target]
                for target in targets:
                    mask_target(target, owner)
                    expression(target, owner)
                # Annotations are explicitly unsupported execution contexts.
                if isinstance(node, ast.AnnAssign):
                    file.gaps.add("annotation_execution_not_resolved")
                    if owner.kind == "python_class":
                        owner.bind("__annotations__")
                    # Unsupported execution context is not permission to ignore
                    # its binding effects (annotations can contain walrus stores).
                    for child in ast.walk(node.annotation):
                        if isinstance(child, ast.NamedExpr):
                            mask_target(child.target, owner)
                expression(getattr(node, "value", None), owner)
            elif isinstance(node, (ast.For, ast.AsyncFor, ast.With, ast.AsyncWith, ast.If, ast.While, ast.Try,
                                   getattr(ast, "TryStar", ast.Try), ast.Match)):
                file.gaps.add("conditional_bindings_not_verified")
                if isinstance(node, (ast.For, ast.AsyncFor)):
                    mask_target(node.target, owner)
                    expression(node.iter, owner)
                elif isinstance(node, (ast.With, ast.AsyncWith)):
                    for item in node.items:
                        expression(item.context_expr, owner)
                        if item.optional_vars:
                            mask_target(item.optional_vars, owner)
                elif isinstance(node, ast.Match):
                    expression(node.subject, owner)
                    for case in node.cases:
                        for pattern in ast.walk(case.pattern):
                            for field in ("name", "rest"):
                                name = getattr(pattern, field, None)
                                if isinstance(name, str):
                                    owner.bind(name)
                        expression(case.guard, owner)
                        statements(case.body, owner, True)
                else:
                    expression(getattr(node, "test", None), owner)
                for field in ("body", "orelse", "finalbody"):
                    statements(getattr(node, field, ()), owner, True)
                for handler in getattr(node, "handlers", ()):
                    if handler.name:
                        owner.bind(handler.name)
                    expression(handler.type, owner)
                    statements(handler.body, owner, True)
            elif isinstance(node, (ast.Expr, ast.Return, ast.Raise, ast.Assert)):
                for child in ast.iter_child_nodes(node):
                    expression(child, owner)
            elif isinstance(node, (ast.Pass, ast.Break, ast.Continue)):
                pass
            else:
                owner.poison = True
                file.gaps.add("unknown_statement_scope_poisoned")
    statements(tree.body, root)
    file.gaps.add("static_not_runtime_binding_truth")
    file.finish()


def _rust_positions(text, tokens):
    """Attach exact byte spans to the pinned lexer's already validated tokens.

    Only trivia and opaque-literal extent are reconstructed, not token recognition.
    """
    result, i = [], 0
    byte_offsets, rows = [0], [1]
    for char in text:
        byte_offsets.append(byte_offsets[-1] + len(char.encode("utf-8")))
        rows.append(rows[-1] + (char == "\n"))
    for word, line, kind in tokens:
        while i < len(text):
            if text[i].isspace():
                i += 1
            elif text.startswith("//", i):
                end = text.find("\n", i)
                i = len(text) if end < 0 else end
            elif text.startswith("/*", i):
                depth, i = 1, i + 2
                while depth:
                    if text.startswith("/*", i):
                        depth, i = depth + 1, i + 2
                    elif text.startswith("*/", i):
                        depth, i = depth - 1, i + 2
                    else:
                        i += 1
            else:
                break
        start = i
        if kind == "literal":
            raw = _symbol.RAW_STRING.match(text, i)
            if raw:
                end = text.index('"' + raw[1], raw.end())
                i = end + 1 + len(raw[1])
            else:
                if text[i] in "bc":
                    i += 1
                quote = text[i]
                i += 1
                while text[i] != quote:
                    if text[i] == "\\":
                        i += 1
                    i += 1
                i += 1
        else:
            spelling = "r#" + word if kind == "raw" else word
            _symbol._require(text.startswith(spelling, i))
            i += len(spelling)
        _symbol._require(rows[start] == line)
        result.append((byte_offsets[start], byte_offsets[i]))
    return result


def _rust(file):
    tokens = _symbol._rust_tokens(file.text)
    spans = _rust_positions(file.text, tokens)
    pairs, stack = {}, []
    for i, (word, _, kind) in enumerate(tokens):
        if kind != "punct":
            continue
        if word in "([{":
            stack.append(i)
        elif word in ")]}":
            _symbol._require(stack and tokens[stack[-1]][0] == {")": "(", "]": "[", "}": "{"}[word])
            pairs[stack.pop()] = i
    _symbol._require(not stack)
    root = _Scope(None, "rust_file", (0, len(file.data)))
    ownership, excluded, declaration_tokens = {}, set(), set()

    def value(i):
        return tokens[i][0] if 0 <= i < len(tokens) else ""

    def identifier(i):
        return (i < len(tokens) and tokens[i][2] in ("id", "raw")
                and (tokens[i][2] == "raw" or value(i) not in _symbol.RESERVED))

    def angles(i, end):
        if value(i) != "<":
            return i
        depth = 1
        i += 1
        while i < end and depth:
            if i in pairs:
                i = pairs[i] + 1
                continue
            depth += (value(i) == "<") - (value(i) == ">" and value(i - 1) != "-")
            i += 1
        _symbol._require(depth == 0)
        return i

    def region(begin, end, owner):
        i, boundary = begin, True
        while i < end:
            ownership[i] = owner
            word, _, kind = tokens[i]
            if word == "#" and kind == "punct":
                j = i + 1 + (value(i + 1) == "!")
                _symbol._require(value(j) == "[" and j in pairs)
                owner.poison = True
                file.gaps.add("attributes_cfg_not_evaluated_scope_poisoned")
                excluded.update(range(i, pairs[j] + 1))
                i = pairs[j] + 1
                continue
            if ((identifier(i) or word in _symbol.LEGACY_MACRO_NAMES)
                    and value(i + 1) == "!" and value(i + 2) != "="):
                j = i + 2
                if word == "macro_rules":
                    _symbol._require(identifier(j))
                    j += 1
                _symbol._require(j in pairs)
                owner.poison = True
                file.gaps.add("macro_may_introduce_bindings_scope_poisoned")
                excluded.update(range(i, pairs[j] + 1))
                i = pairs[j] + 1
                boundary = True
                continue
            j = i
            if boundary:
                while (j < end and tokens[j][2] == "id"
                       and value(j) in ("pub", "async", "unsafe", "const", "extern", "default")):
                    modifier = value(j)
                    j += 1
                    if modifier == "pub" and value(j) == "(":
                        j = pairs[j] + 1
                    if modifier == "extern" and j < end and tokens[j][2] == "literal":
                        j += 1
                if value(j) == "fn" and tokens[j][2] == "id":
                    _symbol._require(identifier(j + 1))
                    name_index = j + 1
                    k = angles(j + 2, end)
                    generic = k != j + 2
                    _symbol._require(value(k) == "(" and k in pairs)
                    parameter_start, parameter_end = k, pairs[k]
                    k = parameter_end + 1
                    while k < end and value(k) not in ("{", ";"):
                        _symbol._require(value(k) not in ("=", "fn", "let"))
                        if k in pairs:
                            k = pairs[k] + 1
                        else:
                            k += 1
                    _symbol._require(k < end)
                    has_body = value(k) == "{"
                    eligible = has_body and owner.kind not in ("rust_impl", "rust_trait")
                    declaration = None
                    if (tokens[j][1] == tokens[name_index][1]
                            and _symbol.IDENT.fullmatch(value(name_index))):
                        declaration = file.declaration(value(name_index), "fn", tokens[j][1],
                            (spans[j][0], spans[pairs[k]][1] if has_body else spans[k][1]), owner, eligible,
                            file.data[slice(*spans[name_index])].decode("utf-8"))
                    if owner.kind not in ("rust_impl", "rust_trait"):
                        owner.bind(value(name_index), declaration if eligible else None)
                    excluded.update(range(i, k + 1))
                    if has_body:
                        inner = _Scope(owner, "rust_function", (spans[k][0], spans[pairs[k]][1]))
                        if generic:
                            inner.poison = True
                            file.gaps.add("generic_function_binding_context_not_resolved")
                        # Only simple name:type parameters (or receiver); patterns poison.
                        p = parameter_start + 1
                        while p < parameter_end:
                            q = p
                            while q < parameter_end and value(q) != ",":
                                if q in pairs:
                                    q = pairs[q] + 1
                                else:
                                    q += 1
                            r = p + (value(p) == "mut")
                            if identifier(r) and value(r + 1) == ":":
                                inner.bind(value(r))
                            elif ([value(x) for x in range(p, q)] in
                                  (["self"], ["mut", "self"], ["&", "self"], ["&", "mut", "self"])
                                  or (value(p) == "self" and value(p + 1) == ":")
                                  or (value(p) == "&" and p + 1 < q and tokens[p + 1][2] == "lifetime"
                                      and [value(x) for x in range(p + 2, q)] in (["self"], ["mut", "self"]))):
                                inner.bind("self")
                            else:
                                inner.poison = True
                                file.gaps.add("parameter_pattern_scope_poisoned")
                            p = q + 1
                        region(k + 1, pairs[k], inner)
                        i = pairs[k] + 1
                    else:
                        i = k + 1
                    boundary = True
                    continue
            if word == "fn" and kind == "id" and identifier(i + 1):
                # A named function where an item cannot start is not a target.
                raise ValueError("malformed function item boundary")
            header = j if boundary else i
            item_word = value(header)
            if (boundary and tokens[header][2] == "id"
                    and item_word in ("mod", "impl", "trait", "struct", "enum", "union")):
                k = header + 1
                while k < end and value(k) not in ("{", ";"):
                    if value(k) == "<":
                        k = angles(k, end)
                    elif k in pairs:
                        k = pairs[k] + 1
                    else:
                        k += 1
                _symbol._require(k < end)
                excluded.update(range(i, k + 1))
                ownership.update((x, owner) for x in range(i, k + 1))
                declaration_tokens.add(header)
                # Binding effects do not depend on same-line evidence eligibility.
                # A multiline tuple struct can shadow a file function even though
                # its declaration cannot be emitted by the frozen anchor policy.
                if item_word != "impl" and identifier(header + 1):
                    owner.bind(value(header + 1))
                if value(k) == "{":
                    inner = _Scope(owner, "rust_" + item_word, (spans[k][0], spans[pairs[k]][1]))
                    if item_word in ("impl", "trait"):
                        file.gaps.add("methods_trait_receiver_type_dispatch_not_resolved")
                        if any(value(x) == "<" for x in range(header, k)):
                            inner.poison = True
                            file.gaps.add("generic_impl_trait_scope_poisoned")
                    if item_word in ("struct", "enum", "union"):
                        excluded.update(range(k, pairs[k] + 1))
                    else:
                        region(k + 1, pairs[k], inner)
                    i = pairs[k] + 1
                else:
                    i = k + 1
                boundary = True
                continue
            nonfunction = next((x for x in range(i, min(j + 1, end))
                                if tokens[x][2] == "id" and value(x) in ("type", "const", "static")), None)
            if boundary and nonfunction is not None:
                # Type syntax is not expression syntax. Initializers deliberately
                # remain unsupported rather than inventing calls in Fn() bounds.
                name_index = nonfunction + 1 + (value(nonfunction) == "static"
                                               and value(nonfunction + 1) == "mut")
                if identifier(name_index):
                    owner.bind(value(name_index))
                else:
                    owner.poison = True
                    file.gaps.add("unknown_item_binding_scope_poisoned")
                k = i + 1
                while k < end and value(k) != ";":
                    if k in pairs:
                        k = pairs[k] + 1
                    else:
                        k += 1
                _symbol._require(k < end)
                excluded.update(range(i, k + 1))
                ownership.update((x, owner) for x in range(i, k + 1))
                declaration_tokens.add(nonfunction)
                file.gaps.add("type_static_const_initializer_calls_not_resolved")
                i, boundary = k + 1, True
                continue
            if ((kind == "id" and word in ("use", "macro", "for", "match", "if", "while", "move", "extern", "as"))
                    or word in ("|", "<")):
                owner.poison = True
                file.gaps.add("unsupported_binding_or_control_construct_scope_poisoned")
            if word == "let" and kind == "id":
                k = i + 1 + (value(i + 1) == "mut")
                if identifier(k) and value(k + 1) in ("=", ":", ";"):
                    owner.bind(value(k))
                    if value(k + 1) == ":":
                        type_end = k + 2
                        while type_end < end and value(type_end) not in ("=", ";"):
                            if type_end in pairs:
                                type_end = pairs[type_end] + 1
                            elif value(type_end) == "<":
                                type_end = angles(type_end, end)
                            else:
                                type_end += 1
                        _symbol._require(type_end < end)
                        excluded.update(range(k + 1, type_end))
                else:
                    owner.poison = True
                    file.gaps.add("local_pattern_scope_poisoned")
            if (identifier(i) and value(i + 1) == ":" and value(i + 2) == ":"
                    and value(i + 3) == "<"):
                k = angles(i + 3, end)
                file.unresolved.append(Unresolved(spans[i], "generic_callee_not_resolved"))
                excluded.update(range(i, k))
                i, boundary = k, False
                continue
            if word == "{" and kind == "punct":
                inner = _Scope(owner, "rust_block", (spans[i][0], spans[pairs[i]][1]))
                region(i + 1, pairs[i], inner)
                i = pairs[i] + 1
                boundary = True
                continue
            boundary = word == ";"
            i += 1

    region(0, len(tokens), root)
    # Preserve textual declaration coverage of the baseline; only parsed functions
    # above can be callable bindings. Never promote textual matches to targets.
    textual = set(_symbol._rust(file.text))
    for i, (word, row, kind) in enumerate(tokens):
        if kind != "id" or word not in _symbol.KINDS or i not in declaration_tokens:
            continue
        j = i + 1 + (word == "static" and value(i + 1) == "mut")
        if j < len(tokens) and (value(j), row) in textual:
            owner = ownership.get(i, root)
            file.declaration(value(j), word, row, (spans[i][0], spans[j][1]), owner, False,
                             file.data[slice(*spans[j])].decode("utf-8"))
            if word != "fn":
                owner.bind(value(j))
    for i, (word, line, kind) in enumerate(tokens):
        if (i not in excluded and i in ownership and identifier(i)
                and value(i + 1) == ":" and value(i + 2) == ":" and value(i + 3) == "<"):
            file.unresolved.append(Unresolved(spans[i], "generic_callee_not_resolved"))
        if (i in excluded or not identifier(i) or value(i + 1) != "("
                or i not in ownership):
            continue
        reason = None
        if value(i - 1) in (".", ":"):
            reason = "member_or_qualified_dispatch_not_resolved"
        file.pending.append((ownership[i], word, spans[i], line, reason))
    file.gaps.update(("standalone_file_no_crate_graph", "balanced_subset_not_rust_syntax_certification",
                      "aliases_macros_cfg_generics_types_dynamic_dispatch_not_resolved"))
    file.finish()


def _extract(sources, scope):
    dependency = _dependency()
    task = {"schema": "evaluation-scoring/1", "scope": scope,
            "family": "definition_directcall", "query": "validation", "instructions": "validation"}
    labels = dependency._validate(sources, task)
    files = []
    for path, data in sources:
        file = _File(path, data, labels)
        if file.language == "python":
            _python(file)
        elif file.language == "rust":
            _rust(file)
        else:
            file.gaps.add("markdown_validated_no_symbols")
        files.append(file)
    extraction = Extraction(
        tuple(d for f in files for d in f.declarations),
        tuple(c for f in files for c in f.calls),
        tuple(Coverage(f.path, f.language,
                      "ast_parsed" if f.language == "python" else "lexed_subset" if f.language == "rust" else "not_code",
                      len(f.data), len(f.lines), len(f.declarations), len(f.calls),
                      tuple(f.unresolved), tuple(sorted(f.gaps))) for f in files), VERSION)
    _validate_extraction(extraction, files, labels)
    return extraction


def _validate_extraction(extraction, files, labels):
    """Closed internal boundary. Not a public plugin/admission API."""
    _symbol._require(type(extraction) is Extraction and extraction.policyversion == VERSION)
    _symbol._require(type(extraction.declarations) is tuple and type(extraction.resolvedcalls) is tuple
                     and type(extraction.observedcoverage) is tuple)
    _symbol._require(extraction.declarations == tuple(d for f in files for d in f.declarations)
                     and extraction.resolvedcalls == tuple(c for f in files for c in f.calls))
    _symbol._require(tuple(c.path for c in extraction.observedcoverage) == tuple(f.path for f in files))
    declarations = {d.id: d for d in extraction.declarations}
    _symbol._require(len(declarations) == len(extraction.declarations))
    mapping = {f.path: f for f in files}
    for item in (*extraction.declarations, *extraction.resolvedcalls):
        file = mapping[item.path]
        _symbol._require(type(item) in (Declaration, Call) and item.id[:3] == labels
                         and item.id[3:5] == (file.path, file.language)
                         and type(item.span) is tuple and len(item.span) == 2
                         and all(type(n) is int for n in item.span)
                         and 0 <= item.span[0] < item.span[1] <= len(file.data)
                         and type(item.line) is int
                         and file.data[:item.span[0]].count(b"\n") + 1 == item.line)
        file.data[:item.span[0]].decode("utf-8")
        file.data[:item.span[1]].decode("utf-8")
        if type(item) is Call:
            target = declarations[item.target]
            _symbol._require(target.callable and target.path == item.path
                             and item.id[-2:] == item.span)
        else:
            _symbol._require(item.id[-3:] == (item.span[0], item.kind, item.rawname))
    _symbol._require(len({c.id for c in extraction.resolvedcalls}) == len(extraction.resolvedcalls))
    for coverage, file in zip(extraction.observedcoverage, files):
        _symbol._require(type(coverage) is Coverage and coverage.language == file.language
                         and coverage.bytes == len(file.data) and coverage.lines == len(file.lines)
                         and coverage.declaration_count == sum(d.path == file.path for d in extraction.declarations)
                         and coverage.call_count == sum(c.path == file.path for c in extraction.resolvedcalls)
                         and coverage.unresolved == tuple(file.unresolved)
                         and coverage.gaps == tuple(sorted(file.gaps)))


def extract(sources, scope):
    """All bindings/calls/observations from immutable in-memory selected sources."""
    try:
        return _extract(sources, scope)
    except Exception:
        raise ValueError("invalid or unsupported directcall input") from None


def retrieve(sources, task):
    """One hop to matched declarations; complete extraction before top-eight crop."""
    try:
        dependency = _dependency()
        labels = dependency._validate(sources, task)
        extraction = extract(sources, task["scope"])
        identifiers = {word: i for i, word in enumerate(dict.fromkeys(dependency.IDENT.findall(task["query"])))}
        matches = {d.id: identifiers[d.name] for d in extraction.declarations if d.name in identifiers}
        ranked = []
        for declaration in extraction.declarations:
            if declaration.id in matches:
                ranked.append((0, matches[declaration.id], declaration.path.encode("utf-8"), declaration.line))
        for call in extraction.resolvedcalls:
            if call.target in matches:
                ranked.append((1, matches[call.target], call.path.encode("utf-8"), call.line))
        coordinates, chosen = set(), []
        lines = {path: dependency._lines(data) for path, data in sources}
        for _, _, encoded, line in sorted(ranked):
            path = encoded.decode("utf-8")
            if (path, line) not in coordinates:
                coordinates.add((path, line))
                chosen.append(Anchor(*labels, path, line, lines[path][line - 1]))
        anchors = tuple(chosen[:8])
        dependency._require(len(dependency._canonical([asdict(a) for a in anchors])) <= 8192)
        return anchors
    except Exception:
        raise ValueError("invalid or unsupported directcall input") from None
