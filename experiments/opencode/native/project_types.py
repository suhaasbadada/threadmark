"""Offline declaration preparation, NOT resolution/installation/compilation.

Inputs must be operator-reviewed, never archive-derived approval. No actual SDK
selection is approved. Private output must not be uploaded. Trusted same-process
parent directories required: this is not hostile same-UID process containment.
Directory descriptors/nofollow protect created children; failed outputs remain
incomplete. No package scripts, JS runtime or compiler are executed.
"""

import base64
import gzip
import hashlib
import io
import json
import os
import re
import stat
import tarfile
import unicodedata
from pathlib import Path

MIB = 1024 * 1024
ARCHIVE_LIMIT = 32 * MIB
COMPRESSED_LIMIT = 256 * MIB
EXPANDED_LIMIT = 1024 * MIB
DESTINATION_LIMIT = 1024 * MIB
MEMBER_LIMIT = 100000
DIR_FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def safe_path(value):
    if (not isinstance(value, str) or not value or "\\" in value
            or any(unicodedata.category(c).startswith("C") for c in value)
            or any(p in ("", ".", "..") for p in value.split("/"))):
        raise ValueError("unsafe path")
    return value


def collision_key(path):
    return unicodedata.normalize("NFC", path).casefold()


def check_paths(paths):
    canonical = {}
    for path in paths:
        safe_path(path)
        key = collision_key(path)
        if key in canonical and canonical[key] != path:
            raise ValueError("case/Unicode collision")
        canonical[key] = path
    for path in paths:
        for index in range(1, len(path.split("/"))):
            ancestor = "/".join(path.split("/")[:index])
            other = canonical.get(collision_key(ancestor))
            if other is not None and other != ancestor:
                raise ValueError("case/Unicode ancestor collision")
            if ancestor in paths and not paths[ancestor]:
                raise ValueError("file ancestor conflict")


def with_directories(paths):
    full = dict(paths)
    for path in paths:
        for index in range(1, len(path.split("/"))):
            full.setdefault("/".join(path.split("/")[:index]), True)
    return full


def inspect(data, integrity):
    if len(data) > ARCHIVE_LIMIT:
        raise ValueError("compressed bound")
    actual = "sha512-" + base64.b64encode(hashlib.sha512(data).digest()).decode()
    if actual != integrity:
        raise ValueError("archive integrity mismatch")
    with gzip.GzipFile(fileobj=io.BytesIO(data)) as source:
        expanded = source.read(EXPANDED_LIMIT + 1)
    if len(expanded) > EXPANDED_LIMIT:
        raise ValueError("expanded bound")
    files, paths = {}, {}
    total = count = 0
    with tarfile.open(fileobj=io.BytesIO(expanded), mode="r:") as archive:
        for member in archive:
            count += 1
            if count > MEMBER_LIMIT:
                raise ValueError("member bound")
            name = safe_path(member.name)
            if (member.type not in (tarfile.REGTYPE, tarfile.AREGTYPE, tarfile.DIRTYPE)
                    or member.sparse is not None
                    or any("sparse" in key.lower() for key in member.pax_headers)):
                raise ValueError("nonregular/sparse member")
            if name in paths:
                raise ValueError("duplicate member")
            if member.size < 0 or (member.isdir() and member.size):
                raise ValueError("invalid size")
            total += member.size
            if total > EXPANDED_LIMIT:
                raise ValueError("declared bound")
            paths[name] = member.isdir()
            if member.isfile():
                content = archive.extractfile(member).read(member.size + 1)
                if len(content) != member.size:
                    raise ValueError("actual size mismatch")
                files[name] = content
    check_paths(with_directories(paths))
    return files, len(expanded), total


def package_name(path):
    safe_path(path)
    match = re.fullmatch(r"(?:node_modules/(?:@[^/]+/)?[^/]+/)*node_modules/((?:@[^/]+/)?[^/]+)", path)
    if not match:
        raise ValueError("invalid npm package path")
    return match[1]


def prepare_files(lock_bytes, plan, archives):
    if plan.get("status") != "reviewed" or plan.get("lockSha256") != sha256(lock_bytes):
        raise ValueError("unreviewed plan/lock mismatch")
    if plan.get("missing") or plan.get("unresolved"):
        raise ValueError("blocked missing/unresolved requirements")
    lock = json.loads(lock_bytes)
    output, ledger = {}, []
    compressed = expanded = declared = 0
    if not plan.get("packages"):
        raise ValueError("empty selection")
    for approval in plan["packages"]:
        path = approval["path"]
        name = package_name(path)
        entry = lock["packages"][path]
        if (approval.get("noticeStatus") != "approved" or not approval.get("noticeEvidence")
                or approval.get("licenseStatus") != "approved"):
            raise ValueError("unapproved notice/license")
        if (approval["name"] != name or entry.get("name", name) != name
                or approval["version"] != entry["version"]
                or approval["integrity"] != entry["integrity"]
                or approval["resolved"] != entry["resolved"]):
            raise ValueError("locked identity mismatch")
        data = archives[approval["integrity"]]
        compressed += len(data)
        if compressed > COMPRESSED_LIMIT:
            raise ValueError("total compressed bound")
        files, size, declared_size = inspect(data, approval["integrity"])
        expanded += size
        declared += declared_size
        if max(expanded, declared) > EXPANDED_LIMIT:
            raise ValueError("total expanded/declared bound")
        root = safe_path(approval["archiveRoot"])
        if any(not item.startswith(root + "/") for item in files):
            raise ValueError("archive root mapping mismatch")
        metadata = files[root + "/package.json"]
        manifest = json.loads(metadata)
        if (manifest.get("name") != name or manifest.get("version") != approval["version"]
                or manifest.get("license") != approval["license"]
                or sha256(metadata) != approval["metadataSha256"]):
            raise ValueError("actual metadata identity/hash mismatch")
        selected = approval["files"]
        if "package.json" not in selected:
            raise ValueError("complete package.json required")
        for relative, expected in selected.items():
            safe_path(relative)
            for index in range(1, len(relative.split("/"))):
                nested_metadata = root + "/" + "/".join(relative.split("/")[:index]) + "/package.json"
                if nested_metadata in files:
                    raise ValueError("nested package identity requires separate approval")
            if (relative != "package.json" and
                    (not relative.endswith((".ts", ".tsx", ".mts", ".cts"))
                     or "node_modules" in relative.split("/")
                     or "bin" in relative.split("/"))):
                raise ValueError("non-type/runtime selection denied")
            content = files.get(root + "/" + relative)
            if content is None:
                raise ValueError("missing selected file")
            if sha256(content) != expected:
                raise ValueError("selected file hash mismatch")
            target = path + "/" + relative
            if target in output:
                raise ValueError("duplicate destination")
            output[target] = content
            ledger.append({"path": target, "sha256": expected, "archiveIntegrity": approval["integrity"],
                           "archivePath": root + "/" + relative, "packagePath": path,
                           "metadataSha256": approval["metadataSha256"]})
    check_paths(with_directories({name: False for name in output}))
    if sum(map(len, output.values())) > DESTINATION_LIMIT:
        raise ValueError("destination bound")
    return output, {"state": "prepared_not_compiled", "typeGraphClosure": "NOT established",
                    "runtimeDependencyClosure": "NOT established", "missing": [], "unresolved": [],
                    "lockSha256": sha256(lock_bytes), "planSha256": sha256(json.dumps(plan, sort_keys=True).encode()),
                    "files": ledger}


def directory(root, parts):
    fd = os.dup(root)
    try:
        for part in parts:
            try:
                os.mkdir(part, mode=0o700, dir_fd=fd)
            except FileExistsError:
                pass
            child = os.open(part, DIR_FLAGS, dir_fd=fd)
            os.close(fd)
            fd = child
        return fd
    except BaseException:
        os.close(fd)
        raise


def write_file(root, path, content):
    parts = path.split("/")
    parent = directory(root, parts[:-1])
    try:
        fd = os.open(parts[-1], os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o400, dir_fd=parent)
        with os.fdopen(fd, "wb") as target:
            target.write(content)
            target.flush()
            os.fsync(target.fileno())
    finally:
        os.close(parent)


def verify_files(root, ledger):
    for record in ledger["files"]:
        parts = record["path"].split("/")
        parent = directory(root, parts[:-1])
        try:
            fd = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW, dir_fd=parent)
            with os.fdopen(fd, "rb") as source:
                info = os.fstat(source.fileno())
                if not stat.S_ISREG(info.st_mode) or info.st_size > DESTINATION_LIMIT:
                    raise ValueError("copied file invalid")
                if sha256(source.read(DESTINATION_LIMIT + 1)) != record["sha256"]:
                    raise ValueError("copied file hash mismatch")
        finally:
            os.close(parent)


def project(destination, lock_bytes, plan, archives):
    """Preflight before fresh root creation. Any exception leaves owned artifacts.

    ledger.json AND absence of INCOMPLETE denote preparation only, not closure.
    """
    output, ledger = prepare_files(lock_bytes, plan, archives)
    serialized = (json.dumps(ledger, sort_keys=True, indent=2) + "\n").encode()
    if sum(map(len, output.values())) + len(serialized) + len(b"incomplete; not usable\n") > DESTINATION_LIMIT:
        raise ValueError("destination ledger bound")
    destination = Path(destination)
    parent = os.open(destination.parent, DIR_FLAGS)
    try:
        os.mkdir(destination.name, mode=0o700, dir_fd=parent)
        root = os.open(destination.name, DIR_FLAGS, dir_fd=parent)
    finally:
        os.close(parent)
    try:
        write_file(root, "INCOMPLETE", b"incomplete; not usable\n")
        for path, content in output.items():
            write_file(root, path, content)
        verify_files(root, ledger)
        write_file(root, "ledger.pending", serialized)
        verify_files(root, {"files": [{"path": "ledger.pending", "sha256": sha256(serialized)}]})
        os.rename("ledger.pending", "ledger.json", src_dir_fd=root, dst_dir_fd=root)
        os.fsync(root)
        os.unlink("INCOMPLETE", dir_fd=root)
        os.fsync(root)
    finally:
        os.close(root)
    return ledger
