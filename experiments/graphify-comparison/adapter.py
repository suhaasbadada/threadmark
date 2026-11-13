"""Fixed comparison adapter, not a general Graphify snapshot normalizer."""
from importlib import import_module
import json
import re

selection = import_module("experiments.evidence-selection.selection")
norm = import_module("experiments.extraction.normalized")
scoring = import_module("experiments.evaluation-scoring.scoring")
ARMS = ("authored", "graphify")
LIMITS = "LIMITED_STATIC; no semantic closure, macro expansion or runtime proof"


def source_map(sources, task):
    scoring.build_manifest(task)
    norm.require(task["family"] == "definition_directcall", "task")
    norm.scope_checked(task["scope"])
    norm.require(type(sources) is tuple and 0 < len(sources) <= 16, "sources")
    result = {}
    for path, data in sources:
        norm.require(type(path) is str and type(data) is bytes, "sources")
        scoring.validate_anchor({**task["scope"], "path": path, "line": 1, "text": ""})
        norm.require(path.startswith(task["scope"]["project"] + "/")
                     and path.endswith((".rs", ".py", ".md")) and path not in result, "sources")
        result[path] = norm.source_lines(data)
    norm.require(sum(len(data) for _, data in sources) <= 65536, "input_budget")
    norm.require(tuple(sorted(result)) == tuple(p for p, _ in sources), "source_order")
    return result


def graphify(graph, sources, task):
    """Validate ALL anchors/coverage, then match only callable declarations.

    Extra upstream metadata is ignored, never forwarded. Coverage means API
    accounting of every input, NOT structural completeness.
    """
    lines = source_map(sources, task)
    norm.require(type(graph) is dict and set(graph) == {
        "nodes", "edges", "input_tokens", "output_tokens", "failed_sources",
        "skipped_sources", "extracted_sources"}, "graph_shape")
    norm.require(all(type(graph[k]) is int and graph[k] == 0
                     for k in ("input_tokens", "output_tokens")), "tokens")
    norm.require(graph["failed_sources"] == [] and graph["skipped_sources"] == [],
                 "unsupported_coverage")
    coverage = graph["extracted_sources"]
    norm.require(type(coverage) is list and all(type(p) is str for p in coverage)
                 and len(coverage) == len(set(coverage)) and set(coverage) == set(lines),
                 "unsupported_coverage")
    nodes, edges = graph["nodes"], graph["edges"]
    norm.require(type(nodes) is list and len(nodes) <= 2000
                 and type(edges) is list and len(edges) <= 4000, "graph_budget")
    ids, coordinates = {}, {}

    def anchor(raw):
        norm.require(type(raw) is dict and raw.get("_origin") == "ast", "provenance")
        path, location = raw.get("source_file"), raw.get("source_location")
        norm.require(type(path) is str and path in lines and type(location) is str, "anchor")
        match = re.fullmatch(r"L([1-9][0-9]*)(?:-L?([1-9][0-9]*))?", location)
        norm.require(match is not None, "anchor")
        start, end = int(match[1]), int(match[2] or match[1])
        norm.require(1 <= start <= end <= len(lines[path]), "anchor")
        if "confidence" in raw:
            norm.require(type(raw["confidence"]) is str and raw["confidence"] in norm.LABELS,
                         "confidence")
        return path, start

    for node in nodes:
        coordinate = anchor(node)
        nid = node.get("id")
        norm.require(type(nid) is str and bool(nid) and nid not in ids, "node_id")
        nid.encode("utf-8")
        norm.require(type(node.get("label")) is str and node.get("file_type") in ("code", "rationale", "document"),
                     "node_shape")
        node["label"].encode("utf-8")
        for key in ("_callable", "_callable_class"):
            norm.require(key not in node or type(node[key]) is bool, "callable_marker")
        ids[nid], coordinates[nid] = node, coordinate
    words = {w: i for i, w in enumerate(dict.fromkeys(selection.IDENT.findall(task["query"])))}
    targets, groups, facts = {}, [[], []], {}

    def add(category, rank, coordinate, raw):
        path, line = coordinate
        groups[category].append((rank, path.encode("utf-8"), line))
        item = {"kind": selection.CATEGORIES[category], "origin": "ast"}
        if "confidence" in raw:
            item["confidence"] = raw["confidence"]
        facts.setdefault(coordinate, []).append(item)

    for nid, node in ids.items():
        match = re.fullmatch(r"([A-Za-z_][A-Za-z0-9_]*)\(\)", node["label"])
        if (node["file_type"] == "code" and node.get("_callable") is True
                and not node.get("_callable_class", False) and match and match[1] in words):
            targets[nid] = words[match[1]]
            add(0, targets[nid], coordinates[nid], node)
    for edge in edges:
        coordinate = anchor(edge)
        norm.require(type(edge.get("source")) is str and edge["source"] in ids
                     and type(edge.get("target")) is str and edge["target"] in ids,
                     "dangling_edge")
        norm.require(type(edge.get("relation")) is str and bool(edge["relation"])
                     and edge.get("confidence") in norm.LABELS, "edge_shape")
        if edge["relation"] == "calls" and edge["target"] in targets:
            add(1, targets[edge["target"]], coordinate, edge)
    chosen = selection._choose(groups)
    return {"items": [{**task["scope"], "path": p, "line": n, "text": lines[p][n - 1]}
                      for p, n in chosen],
            "metadata": {"policy": selection.POLICY, "limitations": LIMITS,
                         "available_categories": {kind: sum(any(f["kind"] == kind for f in fs)
                                                               for fs in facts.values())
                                                  for kind in selection.CATEGORIES},
                         "selected": [{"path": p, "line": n, "facts": facts[(p, n)]}
                                      for p, n in chosen]}}


def authored(sources, task):
    source_map(sources, task)
    value = json.loads(selection.select(sources, task))
    norm.require(sum(c["declaration_count"] for c in value["observed_coverage"]) <= 2000
                 and sum(c["call_count"] for c in value["observed_coverage"]) <= 4000, "graph_budget")
    return {"items": [{k: item[k] for k in scoring.ANCHOR_KEYS} for item in value["evidence"]],
            "metadata": {"policy": value["policy"], "limitations": LIMITS,
                         "available_categories": value["available_categories"],
                         "selected": [{"path": item["path"], "line": item["line"],
                                       "facts": [{"kind": kind, "origin": "authored_static"}
                                                 for kind in item["categories"]]}
                                      for item in value["evidence"]]}}


def candidate(result, base, arm):
    """Exact existing scorer unit; metadata is bound but not semantically scored."""
    norm.require(arm in ARMS and type(result) is dict and set(result) == {"items", "metadata"}, "result")
    metadata = result["metadata"]
    scoring.keys(metadata, ("policy", "limitations", "available_categories", "selected"))
    norm.require(metadata["policy"] == selection.POLICY and metadata["limitations"] == LIMITS, "metadata")
    scoring.keys(metadata["available_categories"], selection.CATEGORIES)
    norm.require(all(type(n) is int and 0 <= n <= 6000
                     for n in metadata["available_categories"].values()), "metadata")
    norm.require(type(result["items"]) is list and type(metadata["selected"]) is list
                 and len(metadata["selected"]) == len(result["items"]) <= 8, "metadata")
    for selected, item in zip(metadata["selected"], result["items"]):
        scoring.keys(selected, ("path", "line", "facts"))
        norm.require(selected["path"] == item["path"] and selected["line"] == item["line"]
                     and type(selected["facts"]) is list and bool(selected["facts"]), "metadata")
        for fact in selected["facts"]:
            norm.require(type(fact) is dict and {"kind", "origin"} <= set(fact)
                         and set(fact) <= {"kind", "origin", "confidence"}
                         and fact["kind"] in selection.CATEGORIES
                         and fact["origin"] == ("ast" if arm == "graphify" else "authored_static"), "metadata")
            norm.require("confidence" not in fact or fact["confidence"] in norm.LABELS, "metadata")
    coverage = list(base["coverage"]) + [
        "prospective comparison; selection=" + selection.POLICY,
        "backend=" + arm + "; " + LIMITS,
        "selection observation sha256=" + norm.identity(result["metadata"])]
    value = {"schema": scoring.VERSION, "scope": base["scope"],
             "coverage": {"status": "complete", "envelope": coverage}, "items": result["items"]}
    fixture = scoring.Fixture(tuple(base["scope"][k] for k in scoring.SCOPE_KEYS), tuple(coverage),
        tuple(scoring.Anchor(**a) for a in base["anchors"]),
        frozenset(scoring.Anchor(**a) for a in base["gold"]),
        frozenset(scoring.Anchor(**a) for a in base["rejected"]), base["family"])
    score = scoring.score(fixture, value)
    norm.require(score["status"] == "valid", "candidate_invalid")
    return value, score
