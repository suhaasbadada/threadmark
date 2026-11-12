#!/usr/bin/env python3
"""Acquire inert public archives, never install/extract/execute dependencies.

Explicit operator command only; not wired into CI. Output is evidence, not an
automatic install authorization. Private archive storage must not be uploaded.
"""

import argparse
import base64
import hashlib
import gzip
import io
import json
from pathlib import Path, PurePosixPath
import re
import tarfile
import urllib.request

MIB = 1024 * 1024
ARCHIVE_LIMIT = 32 * MIB
COMPRESSED_LIMIT = 256 * MIB
EXTRACTED_LIMIT = 1024 * MIB
ALLOWED = {
    "MIT", "ISC", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause",
    "BlueOak-1.0.0", "CC0-1.0", "0BSD", "(AFL-2.1 OR BSD-3-Clause)",
}
EXCEPTIONS = {
    ("spdx-exceptions", "2.5.0"): (
        "CC-BY-3.0",
        "sha512-PiU42r+xO4UbUS1buo3LPJkjlO7430Xn5SVAhdpzzsPHsjbYVflnnFdATgabnLude+Cqu25p6N+g2lw/PFsa4w==",
    ),
    ("caniuse-lite", "1.0.30001826"): (
        "CC-BY-4.0",
        "sha512-wTB+9tIbLro/BCXwLuNV1meHE4L9dS6dArMDwgYfNBPMYScqClHyGunhkCSDtHhe/69Xl0sHlKgBVZ+fNsYtWA==",
    ),
}
COMPILER_INTEGRITY = "sha512-y2TvuxSZPDyQakkFRPZHKFm+KKVqIisdg9/CZwm9ftvKXLP8NRWj38/ODjNbr43SsoXqNuAisEf1GdCxqWcdBw=="


class RejectRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError("registry redirected archive; denied before follow")


def inspect_archive(data):
    """Reject dangerous tar members before reading any member's contents."""
    if len(data) > ARCHIVE_LIMIT:
        raise ValueError("archive compressed bound exceeded")
    # Bound decompression too: tarfile otherwise consumes PAX/GNU extension
    # records before returning a TarInfo on which to enforce declared sizes.
    with gzip.GzipFile(fileobj=io.BytesIO(data)) as compressed:
        chunks = []
        decompressed = 0
        while chunk := compressed.read(min(MIB, EXTRACTED_LIMIT + 1 - decompressed)):
            decompressed += len(chunk)
            if decompressed > EXTRACTED_LIMIT:
                raise ValueError("archive decompressed bound exceeded")
            chunks.append(chunk)
    with tarfile.open(fileobj=io.BytesIO(b"".join(chunks)), mode="r:") as archive:
        members = []
        size = 0
        for member in archive:
            name = member.name
            parts = name.split("/")
            if (not name or name.startswith("/") or "\\" in name
                    or any(p in ("", "..") for p in parts)
                    or not (member.isfile() or member.isdir())):
                raise ValueError("unsafe archive member")
            if member.size < 0:
                raise ValueError("negative member size")
            size += member.size
            if size > EXTRACTED_LIMIT:
                raise ValueError("archive declared extracted bound exceeded")
            members.append(member)
        canonical = {}
        for member in members:
            name = str(PurePosixPath(member.name))
            previous = canonical.get(name)
            if previous is not None:
                if previous.type != member.type or previous.mode != member.mode:
                    raise ValueError("conflicting duplicate archive member")
                if member.isfile() and archive.extractfile(previous).read() != archive.extractfile(member).read():
                    raise ValueError("conflicting duplicate archive contents")
            canonical[name] = member
        files = {m.name: m for m in members if m.isfile()}
        roots = {m.name.split("/")[0] for m in members}
        if len(roots) != 1:
            raise ValueError("archive must have one top-level directory")
        root = next(iter(roots))
        manifest = json.loads(archive.extractfile(files[root + "/package.json"]).read())
        notices = {}
        for name, member in files.items():
            if re.match(r"(?i)^(licen[cs]e|copying|notice|copyright)([.-]|$)", PurePosixPath(name).name):
                content = archive.extractfile(member).read()
                notices[name] = {
                    "sha256": hashlib.sha256(content).hexdigest(),
                    "text": content.decode("utf-8"),
                }
        readmes = {}
        for name, member in files.items():
            if re.match(r"(?i)^readme([.-]|$)", PurePosixPath(name).name):
                content = archive.extractfile(member).read()
                readmes[name] = {"sha256": hashlib.sha256(content).hexdigest(),
                                 "text": content.decode("utf-8", errors="replace")}
        artifacts = [m.name for m in members if m.isfile() and (
            m.mode & 0o111 or re.search(r"\.(node|wasm|dll|dylib|so|exe|a|lib)$", m.name))]
        return manifest, notices, readmes, artifacts, size, len(members), decompressed


def acquire(lock, store, result):
    records = result["records"]
    blockers = []
    compressed = extracted = expanded = 0
    # No proxy, auth, cookies or inherited credential settings.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), RejectRedirects())
    for path, entry in sorted(lock["packages"].items()):
        if not path:
            continue
        record = {"path": path, "version": entry["version"],
                  "integrity": entry.get("integrity"), "resolved": entry.get("resolved")}
        records.append(record)
        if entry.get("optional"):
            record["status"] = "EXCLUDED optional; not acquired or verified"
            continue
        url = entry.get("resolved", "")
        if not url.startswith("https://registry.npmjs.org/") or "?" in url or "#" in url:
            raise ValueError("non-public-registry provenance")
        integrity = entry.get("integrity", "")
        if not re.fullmatch(r"sha512-[A-Za-z0-9+/]{86}==", integrity):
            raise ValueError("missing exact SHA-512 integrity")
        with opener.open(url, timeout=30) as response:
            if response.url != url:
                raise ValueError("registry redirected archive")
            data = response.read(ARCHIVE_LIMIT + 1)
        compressed += len(data)
        result["compressedBytes"] = compressed
        if compressed > COMPRESSED_LIMIT:
            raise ValueError("total compressed bound exceeded")
        computed = "sha512-" + base64.b64encode(hashlib.sha512(data).digest()).decode()
        if computed != integrity:
            raise ValueError("archive integrity mismatch")
        manifest, notices, readmes, artifacts, size, count, expanded_size = inspect_archive(data)
        extracted += size
        expanded += expanded_size
        result["declaredExtractedBytes"] = extracted
        result["expandedBytes"] = expanded
        if expanded > EXTRACTED_LIMIT:
            raise ValueError("total expanded bound exceeded")
        if extracted > EXTRACTED_LIMIT:
            raise ValueError("total declared extracted bound exceeded")
        name = entry.get("name", path.rsplit("node_modules/", 1)[-1])
        if manifest["name"] != name or manifest["version"] != entry["version"]:
            raise ValueError("actual manifest identity mismatch")
        license_id = manifest.get("license")
        if license_id not in ALLOWED and EXCEPTIONS.get((name, entry["version"])) != (license_id, integrity):
            raise ValueError("unapproved actual manifest license: " + name + " " + str(license_id))
        if name == "typescript" and (entry["version"] != "6.0.3" or integrity != COMPILER_INTEGRITY):
            raise ValueError("compiler pin mismatch")
        record.update(status="bytes and structure verified; notice review required",
                      computedIntegrity=computed, compressedBytes=len(data),
                       declaredExtractedBytes=size, expandedBytes=expanded_size,
                       members=count, manifest=manifest,
                      notices=notices, readmes=readmes, platformOrExecutableArtifacts=artifacts)
        if not notices:
            blockers.append({"package": name, "version": entry["version"],
                             "reason": "No archive license/notice; immutable upstream notice evidence required"})
        (store / (hashlib.sha256(data).hexdigest() + ".tgz")).write_bytes(data)
    return {"status": "BLOCKED pending actual notices/provenance and closure review; NOT install approval",
            "execution": "NONE; no extraction or dependency execution", "records": records,
             "compressedBytes": compressed, "declaredExtractedBytes": extracted,
             "expandedBytes": expanded,
            "noticeBlockers": blockers}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--store", type=Path, required=True,
                        help="new private directory, outside repository; do not upload")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--notices-output", type=Path, required=True)
    args = parser.parse_args()
    args.store.mkdir(mode=0o700, parents=False, exist_ok=False)
    source = Path(__file__).with_name("package-lock.json").read_bytes()
    result = {"status": "BLOCKED; acquisition incomplete; NOT install approval",
              "execution": "NONE; no extraction or dependency execution", "records": []}
    try:
        result = acquire(json.loads(source), args.store, result)
    except ValueError as error:
        result["stopReason"] = str(error)
    result["packageLockSha256"] = hashlib.sha256(source).hexdigest()
    write_evidence(result, args.output, args.notices_output)
    print(json.dumps({k: v for k, v in result.items() if k != "records"}, indent=2))


def write_evidence(result, output, notices_output):
    """Keep hashes/manifests in ledger, actual legal text in dedicated notices.

    Do not vendor package code or ordinary READMEs into repository evidence.
    Never infer missing notices from the license identifier alone.
    """
    notices = [
        "THREADMARK NATIVE EXPERIMENT — PROVISIONAL THIRD-PARTY NOTICES",
        "Private nonredistributed development/static checking only.",
        "BLOCKED: incomplete notice/provenance review; not an install or distribution approval.",
        "Archive integrity establishes byte identity, not publisher authentication.",
        "Root MIT licensing does not relicense these dependencies.",
        "AFL/BSD alternative: only the explicit BSD-3-Clause option is selected.",
        "\nExact development-only attribution exceptions (no blanket CC exception):",
        "spdx-exceptions@2.5.0: CC-BY-3.0; unmodified archive.",
        "https://creativecommons.org/licenses/by/3.0/",
        "Source README: https://github.com/kemitchell/spdx-exceptions.json/blob/3aa64bec339abc6a3eca00c3436aaa7e154b8799/README.md",
        "caniuse-lite@1.0.30001826: CC-BY-4.0, including shipped helpers; unmodified archive.",
        "https://creativecommons.org/licenses/by/4.0/",
        "Data: caniuse.com / Alexis Deveria. Package author: Ben Briggs.",
        "Source: https://github.com/browserslist/caniuse-lite/tree/942f16cd659e11288cfffbda649f9d650e4500c4",
    ]
    seen = set()
    for record in result["records"]:
        manifest = record.get("manifest")
        if not manifest:
            continue
        identity = (manifest["name"], manifest["version"])
        if identity not in seen:
            seen.add(identity)
            notices += ["\n" + "=" * 72, "@".join(identity), record["integrity"],
                        "Declared license: " + str(manifest.get("license"))]
            if not record["notices"]:
                notices.append("NO ARCHIVE LICENSE FILE: upstream/README notice verification still required.")
            for name, content in record["notices"].items():
                notices += ["\n" + name + " SHA-256 " + content["sha256"], content["text"]]
            if identity in EXCEPTIONS:
                for name, content in record["readmes"].items():
                    if name.count("/") == 1:
                        notices += ["\nAttribution README: " + name + " SHA-256 " + content["sha256"], content["text"]]
        for content in [*record["notices"].values(), *record["readmes"].values()]:
            content.pop("text", None)
    output.write_text(json.dumps(result, indent=2) + "\n")
    notices_output.write_text("\n".join(notices) + "\n")


if __name__ == "__main__":
    main()
