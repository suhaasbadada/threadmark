"""Experimental scoped-static-v1 boundary; stdlib only, no extraction or storage."""
import hashlib
import json
from pathlib import PurePosixPath
import re

SCHEMA = "threadmark.scoped-static.v1"
LIMITATIONS = ["LIMITED_STATIC", "No semantic closure, macro expansion or runtime proof",
               "Supplied scope and IDs are not authentication, lineage or freshness"]
LABELS = {"EXTRACTED", "INFERRED", "AMBIGUOUS"}


def require(condition, category):
    if not condition:
        raise ValueError(category)


def text(value, limit=512):
    require(isinstance(value, str) and 0 < len(value) <= limit
            and all(ord(c) >= 32 for c in value)
            and "/" not in value and "\\" not in value, "text")
    return value


def scope_checked(scope):
    require(isinstance(scope, dict) and set(scope) == {"project", "worktree", "revision"}, "scope")
    for value in scope.values():
        require(isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9_.-]{1,80}", value), "scope")
    return dict(scope)


def identity(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"),
                                     ensure_ascii=True).encode()).hexdigest()


def source_lines(content):
    # Graphify's tree-sitter anchors count LF rows, not Python's wider set of
    # Unicode line separators. Remove only CR in a CRLF and the terminal split.
    lines = content.decode("utf-8").replace("\r\n", "\n").split("\n")
    if lines[-1] == "":
        lines.pop()
    return tuple(lines)


def source_manifest(sources):
    require(isinstance(sources, dict) and 0 < len(sources) <= 16, "input_budget")
    require(all(isinstance(b, bytes) for b in sources.values()), "source_bytes")
    require(sum(map(len, sources.values())) <= 65536, "input_budget")
    result = {}
    for path, content in sources.items():
        require(isinstance(path, str) and re.fullmatch(r"[A-Za-z0-9_./-]+", path), "path")
        parts = PurePosixPath(path).parts
        require(not PurePosixPath(path).is_absolute() and ".." not in parts
                and PurePosixPath(path).as_posix() == path
                and PurePosixPath(path).suffix in (".py", ".rs"), "path")
        try:
            lines = source_lines(content)
        except UnicodeError:
            raise ValueError("source_encoding") from None
        result[path] = {"sha256": hashlib.sha256(content).hexdigest(), "lines": len(lines)}
    return dict(sorted(result.items()))


def anchor(item, sources, manifest):
    path, location = item.get("source_file"), item.get("source_location")
    require(isinstance(path, str) and path in manifest, "source_path")
    require(isinstance(location, str), "anchor")
    match = re.fullmatch(r"L([1-9][0-9]*)(?:-L?([1-9][0-9]*))?", location)
    require(match is not None, "anchor")
    start, end = int(match[1]), int(match[2] or match[1])
    require(1 <= start <= end <= manifest[path]["lines"], "anchor")
    return {"path": path, "start": start, "end": end,
            "sha256": manifest[path]["sha256"],
            "excerpt": "\n".join(source_lines(sources[path])[start - 1:end])}


def normalize(graph, sources, scope):
    """Atomic return or rejection; input is the actual Graphify API result.

    Syntax preflight is a separate worker prerequisite, NOT inferred from this
    function's success. No old envelope or complete=true field is accepted.
    """
    scope = scope_checked(scope)
    manifest = source_manifest(sources)
    require(isinstance(graph, dict) and set(graph) == {
        "nodes", "edges", "input_tokens", "output_tokens", "failed_sources",
        "skipped_sources", "extracted_sources"}, "graph_shape")
    require(type(graph["input_tokens"]) is int and graph["input_tokens"] == 0
            and type(graph["output_tokens"]) is int and graph["output_tokens"] == 0, "tokens")
    require(graph["failed_sources"] == [] and graph["skipped_sources"] == [], "partial")
    coverage = graph["extracted_sources"]
    require(isinstance(coverage, list) and all(isinstance(p, str) for p in coverage)
            and len(coverage) == len(set(coverage)) and set(coverage) == set(manifest), "coverage")
    raw_nodes, raw_edges = graph["nodes"], graph["edges"]
    require(isinstance(raw_nodes, list) and 0 < len(raw_nodes) <= 2000
            and isinstance(raw_edges, list) and len(raw_edges) <= 4000, "item_budget")
    nodes, edges, ids = [], [], {}
    node_required = {"id", "label", "file_type", "source_file", "source_location", "_origin"}
    edge_required = {"source", "target", "relation", "confidence", "source_file", "source_location", "_origin", "weight"}
    for raw in raw_nodes:
        require(isinstance(raw, dict) and node_required <= set(raw)
                and set(raw) <= node_required | {"_callable", "confidence"}, "node_shape")
        raw_id = text(raw["id"])
        require(raw_id not in ids, "duplicate_id")
        require(raw["_origin"] == "ast" and raw["file_type"] in ("code", "rationale"), "provenance")
        require("_callable" not in raw or type(raw["_callable"]) is bool, "node_shape")
        a = anchor(raw, sources, manifest)
        node = {"id": identity([SCHEMA, scope, raw_id, a]), "upstream_id": raw_id,
                "label": text(raw["label"]), "file_type": raw["file_type"],
                "origin": raw["_origin"], "anchor": a}
        if "confidence" in raw:
            require(isinstance(raw["confidence"], str) and raw["confidence"] in LABELS, "confidence")
            node["confidence"] = raw["confidence"]
        ids[raw_id] = node["id"]
        nodes.append(node)
    require({n["anchor"]["path"] for n in nodes} == set(manifest), "node_coverage")
    edge_ids = set()
    for raw in raw_edges:
        require(isinstance(raw, dict) and edge_required <= set(raw)
                and set(raw) <= edge_required | {"context"}, "edge_shape")
        require(isinstance(raw["source"], str) and isinstance(raw["target"], str)
                and raw["source"] in ids and raw["target"] in ids, "dangling_edge")
        require(raw["_origin"] == "ast", "provenance")
        require(isinstance(raw["confidence"], str) and raw["confidence"] in LABELS, "confidence")
        require(type(raw["weight"]) in (int, float) and raw["weight"] == 1, "weight")
        edge = {"source": ids[raw["source"]], "target": ids[raw["target"]],
                "upstream_source": raw["source"], "upstream_target": raw["target"],
                "relation": text(raw["relation"]), "confidence": raw["confidence"],
                "origin": raw["_origin"], "anchor": anchor(raw, sources, manifest)}
        if "context" in raw:
            edge["context"] = text(raw["context"])
        edge["id"] = identity([SCHEMA, scope, edge])
        require(edge["id"] not in edge_ids, "duplicate_edge")
        edge_ids.add(edge["id"])
        edges.append(edge)
    return {"schema": SCHEMA, "scope": scope, "coverage": "LIMITED_STATIC",
            "limitations": list(LIMITATIONS), "manifest": manifest,
            "producer": {"name": "graphifyy", "version": "0.9.101", "api": "graphify.extract.extract"},
            "nodes": sorted(nodes, key=lambda n: n["id"]),
            "edges": sorted(edges, key=lambda e: e["id"])}


def query_rows(snapshot, expected_scope):
    """Two exact fixture questions, not ranking, symbol resolution or policy truth."""
    require(snapshot.get("schema") == SCHEMA and snapshot.get("scope") == scope_checked(expected_scope), "scope")
    definitions = [n for n in snapshot["nodes"] if n["label"] == "normalize()"]
    targets = {n["id"] for n in definitions}
    calls = [e for e in snapshot["edges"] if e["relation"] == "calls" and e["target"] in targets]
    return {"where_is_normalize": definitions, "what_directly_calls_normalize": calls}
