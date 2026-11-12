"""In-memory declaration baseline. Rust is a constrained lexer, not a compiler."""
import ast
from dataclasses import asdict, dataclass
import io
import json
import re
import tokenize


SCOPE = ("project", "worktree", "revision")
FAMILIES = ("definition_directcall", "conflictingrules_stale_wrongrevision")
IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
RAW_STRING = re.compile(r'(?:br|cr|r)(#*)"')
KINDS = {"fn", "struct", "enum", "trait", "type", "const", "static", "mod"}
RESERVED = set(("as async await break const continue crate dyn else enum extern false fn "
                "for if impl in let loop match mod move mut pub ref return self Self "
                "static struct super trait true type unsafe use where while abstract "
                 "become box do final macro override priv typeof unsized virtual yield try").split())
# These became keywords after edition 2015, where they can name macros.
LEGACY_MACRO_NAMES = {"async", "await", "dyn", "try"}


@dataclass(frozen=True)
class Anchor:
    project: str
    worktree: str
    revision: str
    path: str
    line: int
    text: str


def _require(condition):
    if not condition:
        raise ValueError("invalid or unsupported symbol input")


def _canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=False, allow_nan=False).encode("utf-8")


def _fields(value, names):
    _require(type(value) is dict and set(value) == set(names))


def _lines(data):
    lines = data.decode("utf-8").split("\n")
    if lines[-1] == "":
        lines.pop()
    lines = tuple(line[:-1] if line.endswith("\r") else line for line in lines)
    _require(all("\r" not in line for line in lines))
    return lines


def _validate(sources, task):
    _fields(task, ("schema", "scope", "family", "query", "instructions"))
    _require(type(task["schema"]) is str and task["schema"] == "evaluation-scoring/1")
    _require(type(task["family"]) is str and task["family"] in FAMILIES)
    _fields(task["scope"], SCOPE)
    scope = tuple(task["scope"][key] for key in SCOPE)
    for label in scope:
        _require(type(label) is str and re.fullmatch(r"[A-Za-z0-9_-]{1,128}", label))
    for key in ("query", "instructions"):
        _require(type(task[key]) is str and bool(task[key]))
        task[key].encode("utf-8")
    _require(len(_canonical({k: task[k] for k in ("query", "instructions")})) <= 4096)
    _require(type(sources) is tuple and len(sources) <= 2048)
    previous, total = b"", 0
    for pair in sources:
        _require(type(pair) is tuple and len(pair) == 2)
        path, data = pair
        _require(type(path) is str and bool(path))
        encoded = path.encode("utf-8")
        parts = path.split("/")
        _require(not path.startswith("/") and "\\" not in path
                 and not any(ord(c) < 32 or ord(c) == 127 for c in path)
                 and not any(p in ("", ".", "..") for p in parts)
                 and len(parts) >= 2 and parts[0] == scope[0]
                 and path.endswith((".rs", ".py", ".md")) and encoded > previous)
        previous = encoded
        _require(type(data) is bytes and len(data) <= 65536)
        total += len(data)
        _require(total <= 32 * 1024 * 1024)
        _lines(data)
    return scope


def _python(text, lines):
    # Parse the ENTIRE file before emitting anything. Never import/execute it.
    tree = ast.parse(text)
    tokens = list(tokenize.generate_tokens(io.StringIO(text).readline))
    positions = {(t.start[0], len(lines[t.start[0] - 1][:t.start[1]].encode("utf-8"))): i
                 for i, t in enumerate(tokens) if t.type == tokenize.NAME}
    for node in ast.walk(tree):
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            continue
        index = positions[(node.lineno, node.col_offset)]
        keyword = tokens[index]
        if isinstance(node, ast.AsyncFunctionDef):
            index += 1
        # Explicit continuations have no intervening token, but row must agree.
        name = tokens[index + 1]
        suffix = lines[name.end[0] - 1][name.end[1]:]
        if (name.type == tokenize.NAME and IDENT.fullmatch(name.string)
                and name.string == node.name
                and (not suffix or not _id_part(suffix[0]))
                and tokens[index].start[0] == name.start[0] == keyword.start[0]):
            yield name.string, keyword.start[0]


def _id_start(c):
    return c == "_" or c.isalpha() or (ord(c) > 127 and c.isidentifier())


def _id_part(c):
    return c.isalnum() or c == "_" or (ord(c) > 127 and ("a" + c).isidentifier())


def _rust_tokens(text):
    """(spelling, physical LF line, kind); opaque literals never join identifiers."""
    tokens, i, line = [], 0, 1
    size = len(text)
    while i < size:
        start, row, c = i, line, text[i]
        if c.isspace():
            line += c == "\n"
            i += 1
            continue
        if text.startswith("//", i):
            end = text.find("\n", i)
            i = size if end < 0 else end
            continue
        if text.startswith("/*", i):
            depth, i = 1, i + 2
            while i < size and depth:
                if text.startswith("/*", i):
                    depth, i = depth + 1, i + 2
                elif text.startswith("*/", i):
                    depth, i = depth - 1, i + 2
                else:
                    line += text[i] == "\n"
                    i += 1
            _require(depth == 0)
            continue
        raw = RAW_STRING.match(text, i)
        if raw:
            closing = '"' + raw[1]
            end = text.find(closing, raw.end())
            _require(end >= 0)
            i = end + len(closing)
            line += text[start:i].count("\n")
            tokens.append(("", row, "literal"))
            continue
        prefix = 1 if c in "bc" and text[i + 1:i + 2] == '"' else 0
        if c == '"' or prefix:
            i += prefix + 1
            while i < size and text[i] != '"':
                if text[i] == "\\":
                    i += 1
                    _require(i < size)
                i += 1
            _require(i < size)
            i += 1
            line += text[start:i].count("\n")
            tokens.append(("", row, "literal"))
            continue
        byte_char = text.startswith("b'", i)
        if c == "'" or byte_char:
            i += 2 if byte_char else 1
            _require(i < size)
            # Identifier without closing quote is a lifetime, not a char.
            if not byte_char and _id_start(text[i]):
                end = i + 1
                while end < size and _id_part(text[end]):
                    end += 1
                if text[end:end + 1] != "'":
                    tokens.append((text[start:end], row, "lifetime"))
                    i = end
                    continue
            if text[i] == "\\":
                i += 1
                _require(i < size)
                if text.startswith("u{", i):
                    end = text.find("}", i + 2)
                    _require(end >= 0 and re.fullmatch(r"[0-9a-fA-F_]+", text[i + 2:end]))
                    i = end + 1
                elif text[i] == "x":
                    _require(re.fullmatch(r"[0-9a-fA-F]{2}", text[i + 1:i + 3]))
                    i += 3
                else:
                    _require(text[i] in "nrt0\\'\"")
                    i += 1
            else:
                _require(text[i] not in "\n\r\t'")
                i += 1
            _require(text[i:i + 1] == "'")
            i += 1
            tokens.append(("", row, "literal"))
            continue
        raw_id = text.startswith("r#", i) and i + 2 < size and _id_start(text[i + 2])
        if raw_id or _id_start(c):
            if raw_id:
                i += 2
            begin = i
            i += 1
            while i < size and _id_part(text[i]):
                i += 1
            tokens.append((text[begin:i], row, "raw" if raw_id else "id"))
            continue
        tokens.append((c, row, "punct"))
        i += 1
    return tokens


def _rust(text):
    tokens = _rust_tokens(text)
    # Validate delimiter nesting everywhere, including excluded macro bodies.
    pairs, stack = {}, []
    for i, (word, _, kind) in enumerate(tokens):
        if kind != "punct":
            continue
        if word in ("(", "[", "{"):
            stack.append(i)
        elif word in (")", "]", "}"):
            _require(stack and tokens[stack[-1]][0] == {")": "(", "]": "[", "}": "{"}[word])
            pairs[stack.pop()] = i
    _require(not stack)
    i = 0
    while i < len(tokens):
        word, row, kind = tokens[i]
        # Attribute token trees and macro invocations are not declaration sources.
        if word == "#":
            j = i + 1
            if j < len(tokens) and tokens[j][0] == "!":
                j += 1
            if j < len(tokens) and tokens[j][0] == "[":
                i = pairs[j] + 1
                continue
        if (kind in ("id", "raw")
                and (kind == "raw" or word not in RESERVED or word in LEGACY_MACRO_NAMES)
                and i + 1 < len(tokens) and tokens[i + 1][0] == "!"
                and (i + 2 == len(tokens) or tokens[i + 2][0] != "=")):
            j = i + 2
            if word == "macro_rules" and kind == "id":
                _require(j < len(tokens) and tokens[j][2] in ("id", "raw"))
                j += 1
            _require(j in pairs)
            i = pairs[j] + 1
            continue
        _require(not (word == "macro" and kind == "id"))  # macro 2.0 unsupported
        if kind == "id" and word in KINDS:
            j = i + 1
            if (word == "static" and j < len(tokens)
                    and tokens[j][0] == "mut" and tokens[j][2] == "id"):
                j += 1
            if j < len(tokens):
                name, name_row, name_kind = tokens[j]
                if (name_kind in ("id", "raw") and IDENT.fullmatch(name)
                        and (name_kind == "raw" or name not in RESERVED) and name_row == row):
                    yield name, row
        # Skip declaration/impl/for generic parameter lists, including const
        # parameters. Not a general expression/angle-bracket grammar.
        generic = None
        if kind == "id" and word in {"impl", "for"}:
            generic = i + 1
        elif kind == "id" and word in {"fn", "struct", "enum", "trait", "type", "union"}:
            if i + 1 < len(tokens) and tokens[i + 1][2] in ("id", "raw"):
                generic = i + 2
        if generic is not None and generic < len(tokens) and tokens[generic][0] == "<":
            depth, j = 1, generic + 1
            while j < len(tokens) and depth:
                value = tokens[j][0]
                if j in pairs:
                    j = pairs[j] + 1
                    continue
                # The '>' in a function type's return arrow is not an angle.
                arrow = value == ">" and tokens[j - 1][0] == "-"
                depth += (value == "<") - (value == ">" and not arrow)
                j += 1
            _require(depth == 0)
            i = j
        else:
            i += 1


def retrieve(sources, task):
    """Immutable top-eight six-field anchors or closed ValueError; no IO/state.

    Only approved synthetic in-memory bytes. Scope labels are not authorization.
    Bounds are postallocation, not CPU/RSS or hostile transport containment.
    """
    try:
        scope = _validate(sources, task)
        query = {word: i for i, word in enumerate(dict.fromkeys(IDENT.findall(task["query"])))}
        ranked = []
        for path, data in sources:
            lines = _lines(data)
            text = "\n".join(lines)
            declarations = (_python(text, lines) if path.endswith(".py") else
                            _rust(text) if path.endswith(".rs") else ())
            for name, number in declarations:
                if name not in query:
                    continue
                key = (query[name], path.encode("utf-8"), number)
                old = next((r for r in ranked if r[1:3] == key[1:3]), None)
                if old is not None:
                    if old[:3] <= key:
                        continue
                    ranked.remove(old)
                ranked.append((*key, Anchor(*scope, path, number, lines[number - 1])))
                ranked.sort(key=lambda r: r[:3])
                del ranked[8:]
        anchors = tuple(row[3] for row in ranked)
        _require(len(_canonical([asdict(a) for a in anchors])) <= 8192)
        return anchors
    except (ValueError, TypeError, UnicodeError, SyntaxError, tokenize.TokenError,
            RecursionError, OverflowError, KeyError, IndexError):
        # Do not attach parser diagnostics containing source content.
        raise ValueError("invalid or unsupported symbol input") from None
