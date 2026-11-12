"""Pure, offline compiler candidate validation. No launcher or execution approval.

The review SHA is supplied out-of-band by an operator, never taken from inputs.
Inventory review attests compiler archive provenance and Node version identity;
hash matching alone cannot establish either. See COMPILER-PLAN.md.
"""

import json
import os
from pathlib import Path
import re
import stat

from project_types import check_paths, prepare_files, safe_path, sha256, with_directories

COMPILER_INTEGRITY = (
    "sha512-y2TvuxSZPDyQakkFRPZHKFm+KKVqIisdg9/CZwm9ftvKXLP8NRWj38/"
    "ODjNbr43SsoXqNuAisEf1GdCxqWcdBw=="
)
BOUNDS = {"wallSeconds": 120, "outputBytes": 16 * 1024 * 1024,
          "heapMiB": 1024, "cleanupSeconds": 2}
FILE_LIMIT = 1024 * 1024 * 1024


def encoded(value):
    return (json.dumps(value, sort_keys=True, indent=2) + "\n").encode()


def keys(value, expected):
    if not isinstance(value, dict) or set(value) != set(expected):
        raise ValueError("unexpected/missing schema keys")


def digest(value):
    if not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{64}", value):
        raise ValueError("invalid digest")
    return value


def regular(path):
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or info.st_size > FILE_LIMIT:
        raise ValueError("nonregular/linked/oversized file")
    # Parent directories are trusted against concurrent same-UID mutation.
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, "rb") as source:
        opened = os.fstat(source.fileno())
        if (opened.st_dev, opened.st_ino, opened.st_mode, opened.st_nlink) != (
                info.st_dev, info.st_ino, info.st_mode, 1):
            raise ValueError("file identity changed")
        data = source.read(FILE_LIMIT + 1)
    if len(data) > FILE_LIMIT:
        raise ValueError("file bound")
    return data


def absolute(value, directory=False):
    if not isinstance(value, str) or not value.startswith("/") or value == "/":
        raise ValueError("absolute non-root path required")
    safe_path(value[1:])
    path = Path(value)
    # No canonicalization that silently accepts symlink/traversal aliases.
    for ancestor in reversed(path.parents):
        if not stat.S_ISDIR(ancestor.lstat().st_mode):
            raise ValueError("non-directory/symlink ancestor")
    if directory and not stat.S_ISDIR(path.lstat().st_mode):
        raise ValueError("non-directory/symlink root")
    return path


def inventory(value):
    if not isinstance(value, dict) or not value:
        raise ValueError("empty inventory")
    for name, expected in value.items():
        safe_path(name)
        digest(expected)
    check_paths(with_directories({name: False for name in value}))
    return value


def tree(root, expected):
    """Compare every actual file AND directory against an exact reviewed inventory."""
    inventory(expected)
    actual = {}
    for parent, directories, files in os.walk(root, followlinks=False):
        for name in directories + files:
            child = Path(parent) / name
            relative = child.relative_to(root).as_posix()
            info = child.lstat()
            if stat.S_ISDIR(info.st_mode):
                actual[relative] = True
            elif stat.S_ISREG(info.st_mode):
                actual[relative] = False
                if relative not in expected or sha256(regular(child)) != expected[relative]:
                    raise ValueError("unapproved or mismatching file")
            else:
                raise ValueError("nonregular tree member")
    if actual != with_directories({name: False for name in expected}):
        raise ValueError("missing/extra inventory member")
    check_paths(actual)


def build_descriptor(review_bytes, reviewed_sha256, *, lock_bytes, projection_plan,
                     archives):
    """Return INERT JSON-compatible data; never write config or start a process.

    review_bytes and its externally approved hash are distinct trust inputs.
    Archives are already-owned bytes, not download URLs. Source bytes are read,
    never imported. All filesystem observations are preparation-time snapshots.
    """
    if sha256(review_bytes) != digest(reviewed_sha256):
        raise ValueError("operator-reviewed manifest mismatch")

    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("duplicate JSON key")
            result[key] = value
        return result

    review = json.loads(review_bytes, object_pairs_hook=unique)
    keys(review, {"schema", "reviewId", "platform", "lockSha256", "projectionPlanSha256",
                  "projection", "ledgerSha256", "sources", "roots", "compiler", "node",
                  "workspace", "jsx", "knownMissing"})
    if (review["schema"] != 1 or review["platform"] != "macos"
            or not isinstance(review["reviewId"], str)
            or not re.fullmatch(r"[A-Za-z0-9_-]{1,80}", review["reviewId"])):
        raise ValueError("unsupported review/platform")
    if review["knownMissing"] != []:
        raise ValueError("known missing requirements")
    if (review["lockSha256"] != sha256(lock_bytes)
            or review["projectionPlanSha256"] != sha256(json.dumps(projection_plan, sort_keys=True).encode())):
        raise ValueError("lock/projection plan mismatch")
    # Reconstruct authentic selected bytes from the hash-verified owned archives,
    # not from a copied ledger or historical audit's closure assertions.
    selected, ledger = prepare_files(lock_bytes, projection_plan, archives)
    projection = absolute(review["projection"], directory=True)
    expected_ledger = encoded(ledger)
    if (review["ledgerSha256"] != sha256(expected_ledger)
            or regular(projection / "ledger.json") != expected_ledger
            or ledger["state"] != "prepared_not_compiled"):
        raise ValueError("prepared ledger mismatch")
    selected_hashes = {name: sha256(content) for name, content in selected.items()}

    source = review["sources"]
    keys(source, {"directory", "files"})
    sources = absolute(source["directory"], directory=True)
    if sources != projection / "__compiler_roots":
        raise ValueError("owned roots must share official node_modules ancestry")
    inventory(source["files"])
    if any(not name.endswith((".ts", ".tsx", ".mts", ".cts")) for name in source["files"]):
        raise ValueError("non-TypeScript source")
    tree(sources, source["files"])
    tree(projection, {**selected_hashes, "ledger.json": sha256(expected_ledger),
                      **{"__compiler_roots/" + name: value for name, value in source["files"].items()}})
    roots = review["roots"]
    if (not isinstance(roots, list) or not roots or any(not isinstance(r, str) for r in roots)
            or len(set(roots)) != len(roots) or set(roots) != set(source["files"])):
        raise ValueError("explicit unique source roots required")
    # Owned test roots cannot suppress errors. Selected upstream bytes remain
    # untouched; their directives require separate consumed-file review later.
    for name in roots:
        try:
            content = regular(sources / name).decode("utf-8-sig", errors="strict")
        except UnicodeDecodeError:
            raise ValueError("owned sources must be UTF-8") from None
        if "\x00" in content:
            raise ValueError("owned sources must not contain NUL")
        if any(token in content for token in ("@ts-ignore", "@ts-nocheck", "@ts-expect-error")):
            raise ValueError("owned-source suppression")

    compiler = review["compiler"]
    keys(compiler, {"directory", "name", "version", "archiveIntegrity", "archiveVerified",
                    "license", "entrypoint", "files", "roles", "noticeHashes"})
    if (compiler["name"] != "typescript" or compiler["version"] != "6.0.3"
            or compiler["archiveIntegrity"] != COMPILER_INTEGRITY
            or compiler["archiveVerified"] is not True or compiler["license"] != "Apache-2.0"
            or compiler["entrypoint"] != "lib/tsc.js"):
        raise ValueError("compiler identity/provenance mismatch")
    compiler_root = absolute(compiler["directory"], directory=True)
    inventory(compiler["files"])
    keys(compiler["roles"], {"entrypoint", "helpers", "libraries", "metadata", "notices"})
    roles = compiler["roles"]
    all_roles = []
    for role in roles.values():
        if not isinstance(role, list) or any(not isinstance(name, str) for name in role):
            raise ValueError("invalid compiler role")
        all_roles.extend(role)
    if (roles["entrypoint"] != ["lib/tsc.js"] or roles["metadata"] != ["package.json"]
            or "lib/_tsc.js" not in roles["helpers"] or not roles["libraries"]
            or not {"LICENSE.txt", "ThirdPartyNoticeText.txt"}.issubset(roles["notices"])):
        raise ValueError("incomplete compiler roles")
    if len(set(all_roles)) != len(all_roles) or set(all_roles) != set(compiler["files"]):
        raise ValueError("compiler inventory/roles mismatch")
    if (any(not name.startswith("lib/") or not name.endswith(".js") for name in roles["helpers"])
            or any(not re.fullmatch(r"lib/lib\.[a-z0-9.]+\.d\.ts", name) for name in roles["libraries"])
            or compiler["noticeHashes"] != {name: compiler["files"][name] for name in roles["notices"]}):
        raise ValueError("compiler helper/library/notice mismatch")
    tree(compiler_root, compiler["files"])
    if any((compiler_root / name).lstat().st_mode & 0o111 for name in compiler["files"]):
        raise ValueError("compiler inventory must be inert nonexecutable files")
    metadata = json.loads(regular(compiler_root / "package.json"))
    if (metadata.get("name"), metadata.get("version"), metadata.get("license")) != (
            "typescript", "6.0.3", "Apache-2.0"):
        raise ValueError("actual compiler metadata mismatch")

    node = review["node"]
    keys(node, {"path", "version", "sha256", "inventoryId"})
    if (not isinstance(node["version"], str) or not re.fullmatch(r"\d+\.\d+\.\d+", node["version"])
            or not isinstance(node["inventoryId"], str)
            or not re.fullmatch(r"[A-Za-z0-9_-]{1,80}", node["inventoryId"])):
        raise ValueError("reviewed Node identity required")
    node_path = absolute(node["path"])
    if sha256(regular(node_path)) != digest(node["sha256"]):
        raise ValueError("Node inventory hash mismatch")
    if not node_path.lstat().st_mode & stat.S_IXUSR or node_path.lstat().st_mode & 0o022:
        raise ValueError("Node inventory mode mismatch")

    workspace = absolute(review["workspace"], directory=True)
    spaces = [projection, compiler_root, workspace]
    if any(a == b or a in b.parents or b in a.parents for i, a in enumerate(spaces) for b in spaces[i + 1:]):
        raise ValueError("overlapping roots")
    if any(node_path == p or p in node_path.parents for p in spaces):
        raise ValueError("Node overlaps owned roots")
    if list(workspace.iterdir()):
        raise ValueError("fresh empty owned workspace required")
    if workspace.lstat().st_uid != os.getuid() or workspace.lstat().st_mode & 0o077:
        raise ValueError("workspace must be private and owned")
    if review["jsx"] not in (None, "preserve"):
        raise ValueError("unsupported JSX policy")
    if any(name.endswith(".tsx") for name in roots) and review["jsx"] != "preserve":
        raise ValueError("explicit JSX required")
    options = {"noEmit": True, "strict": True, "skipLibCheck": False,
               "skipDefaultLibCheck": False, "types": [],
               "typeRoots": [str(workspace / "typeRoots")],
               "module": "ESNext", "moduleResolution": "Bundler", "target": "ESNext"}
    if review["jsx"] is not None:
        options["jsx"] = review["jsx"]
    config = {"compilerOptions": options, "files": [str(sources / name) for name in roots],
              "include": [], "exclude": []}
    config_path = workspace / "tsconfig.json"
    environment = {"HOME": str(workspace / "home"), "TMPDIR": str(workspace / "tmp"),
                   "XDG_CONFIG_HOME": str(workspace / "config"),
                   "XDG_CACHE_HOME": str(workspace / "cache"),
                   "XDG_DATA_HOME": str(workspace / "data"),
                   "XDG_STATE_HOME": str(workspace / "state"),
                   "LANG": "C", "LC_ALL": "C", "PATH": "/usr/bin:/bin"}
    read_files = ([str(projection / name) for name in selected_hashes]
                  + [str(sources / name) for name in roots]
                  + [str(compiler_root / name) for name in compiler["files"]]
                  + [str(node_path), str(config_path)])
    check_paths(with_directories({name[1:]: False for name in read_files}))
    read_hashes = {str(projection / name): value for name, value in selected_hashes.items()}
    read_hashes.update({str(sources / name): value for name, value in source["files"].items()})
    read_hashes.update({str(compiler_root / name): value for name, value in compiler["files"].items()})
    read_hashes.update({str(node_path): node["sha256"], str(config_path): sha256(encoded(config))})
    return {"kind": "inert-compiler-candidate", "reviewId": review["reviewId"],
            "reviewSha256": reviewed_sha256, "executionApproved": False,
            "containmentVerified": False, "typeGraphClosure": "NOT established",
            "runtimeDependencyClosure": "NOT established", "preparationOnly": True,
            "argvCandidate": [str(node_path), "--max-old-space-size=1024",
                              str(compiler_root / "lib/tsc.js"), "--project", str(config_path)],
            "config": config, "configPath": str(config_path), "configSha256": sha256(encoded(config)),
            "environment": environment, "inheritEnvironment": False, "cwd": str(workspace),
            "rootHashes": dict(source["files"]), "readFileHashes": read_hashes,
            "projectionLedgerSha256": sha256(expected_ledger), "bounds": dict(BOUNDS),
            "policy": {"name": "threadmark-compiler-macos-deny-default-v1",
                       "status": "PENDING negative controls and system inventory",
                       "default": "deny", "network": "deny", "childSpawn": "deny",
                       "readFiles": read_files, "recursiveReadRoots": [],
                       "writeDirectories": list(environment[k] for k in (
                           "HOME", "TMPDIR", "XDG_CONFIG_HOME", "XDG_CACHE_HOME",
                           "XDG_DATA_HOME", "XDG_STATE_HOME")),
                       "systemReadFiles": [], "linux": "unsupported"},
            "cleanup": {"owner": "retained process owner + private status/control pipes",
                        "unknown": "quarantine; no reuse or success"},
            "requiredGates": ["independent plan review", "explicit parent execution authorization",
                              "reviewed system/dyld and sandbox owner inventory",
                              "measured containment negative controls", "launch-time byte revalidation",
                              "official compiler diagnostics and consumed-file closure"]}
