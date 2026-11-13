"""Two inert archive receipts only; no acquisition CLI or type-closure approval."""

import base64
import gzip
import hashlib
import io
import json

import project_types

PINS = {
    "@types/emscripten": ("1.40.0", "emscripten", "sha512-MD2JJ25S4tnjnhjWyalMS6K6p0h+zQV6+Ylm+aGbiS8tSn/aHLSGNzBgduj6FB4zH0ax2GRMGYi/8G1uOxhXWA=="),
    "@types/json-schema": ("7.0.15", "json-schema", "sha512-5+fP8P8MFNC+AyZCDxrB2pkZFPGzqQWUzpSeuuVLvm8VMcorNYavBqoFcxK8bQz4Qsbn4oUEEem4wDLfcysGHA=="),
}


def identity(manifest, lock, name):
    version, root, integrity = PINS[name]
    url = f"https://registry.npmjs.org/{name}/-/{root}-{version}.tgz"
    if manifest["devDependencies"].get(name) != version:
        raise ValueError("manifest pin mismatch")
    if lock["packages"][""]["devDependencies"].get(name) != version:
        raise ValueError("lock root pin mismatch")
    entry = lock["packages"].get("node_modules/" + name, {})
    if any(entry.get(k) != v for k, v in {
        "version": version, "resolved": url, "integrity": integrity,
    }.items()):
        raise ValueError("lock archive identity mismatch")
    return version, root, integrity, url


def inspect(manifest, lock, name, data):
    version, root, integrity, url = identity(manifest, lock, name)
    if len(data) > 512 * 1024:
        raise ValueError("small archive bound")
    computed = "sha512-" + base64.b64encode(hashlib.sha512(data).digest()).decode()
    if computed != integrity:
        raise ValueError("archive integrity mismatch")
    with gzip.GzipFile(fileobj=io.BytesIO(data)) as source:
        if len(source.read(1024 * 1024 + 1)) > 1024 * 1024:
            raise ValueError("small expanded bound")
    # The existing strict inspector verifies integrity BEFORE parsing and accepts
    # the authentic DefinitelyTyped root without rewriting package metadata.
    files, expanded, declared = project_types.inspect(data, integrity)
    if expanded > 1024 * 1024 or set(files) != {
        root + "/" + p for p in ("package.json", "index.d.ts", "LICENSE", "README.md")
    }:
        raise ValueError("unexpected archive inventory")
    metadata = json.loads(files[root + "/package.json"])
    if (metadata.get("name") != name or metadata.get("version") != version
            or metadata.get("license") != "MIT" or metadata.get("types") != "index.d.ts"
            or any(metadata.get(field) for field in (
                "dependencies", "devDependencies", "peerDependencies", "optionalDependencies", "scripts"
            ))):
        raise ValueError("actual metadata mismatch")
    notice = files[root + "/LICENSE"]
    if not notice.lstrip().startswith(b"MIT License") or b"Copyright" not in notice:
        raise ValueError("missing actual MIT notice")
    return {
        "name": name, "version": version, "resolved": url, "integrity": integrity,
        "archiveSha256": hashlib.sha256(data).hexdigest(),
        "compressedBytes": len(data), "expandedBytes": expanded,
        "declaredExtractedBytes": declared, "manifest": metadata,
        "files": {p: {"sha256": hashlib.sha256(b).hexdigest(), "bytes": len(b)}
                  for p, b in sorted(files.items())},
        "noticePath": root + "/LICENSE", "typesPath": root + "/index.d.ts",
    }, files
