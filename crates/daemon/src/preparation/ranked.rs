//! Ranked-only provenance disclosure; literal/native response DTOs are untouched.
use serde_json::{Value, json};
use threadmark_refinement::Request;

pub(crate) fn evidence(request: &Request) -> Value {
    json!(
        request
            .data()
            .evidence
            .iter()
            .map(|e| json!({
                "id": e.id, "project": e.project, "path": e.path, "line": e.line,
                "text": e.text, "source_hash": e.source_hash, "producer": e.producer,
                "kind": e.kind, "currentness": "current-at-read", "coverage": e.coverage,
            }))
            .collect::<Vec<_>>()
    )
}
