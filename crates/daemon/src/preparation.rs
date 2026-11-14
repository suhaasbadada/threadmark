//! Actual core-backed preparation. Context never invokes a provider; retained
//! review sessions require explicit provider access and never perform delivery.

pub(crate) mod ranked;
mod session;
pub use session::{CaptureBinding, ReviewSession};
pub use threadmark_refinement::RetrievalMode;

use serde_json::{Value, json};
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::{Duration, Instant};
use threadmark_core::{Error, knowledge::Store};
use threadmark_refinement::{
    AuthorizedSnapshot, Control, Currentness, Engine, Evidence, EvidenceAuthority, Mode, Request,
    RequestData,
};

fn engine_error(error: threadmark_refinement::Error) -> Error {
    use threadmark_refinement::Error as E;
    match error {
        E::Canceled | E::Superseded => Error::Canceled,
        E::Stale | E::ScopeMismatch => Error::ScopeMismatch,
        E::Invalid | E::Overflow | E::InvalidBrief => Error::InvalidExtraction,
        _ => Error::Unavailable,
    }
}

fn selection(
    store: &Store,
    project: &str,
    query: &str,
    cancel: &AtomicBool,
) -> Result<AuthorizedSnapshot, Error> {
    let value = store.query(project, query, cancel)?;
    selected_value(value, project)
}

fn selection_bound(
    store: &Store,
    project: &threadmark_core::knowledge::Project,
    query: &str,
    cancel: &AtomicBool,
    retrieval: RetrievalMode,
) -> Result<AuthorizedSnapshot, Error> {
    let value = match retrieval {
        RetrievalMode::Literal => store.query_bound(project, query, cancel)?,
        RetrievalMode::RankedTerms => store.query_terms_bound(project, query, cancel)?,
    };
    selected_value(value, &project.id)
}

fn selected_value(value: Value, project: &str) -> Result<AuthorizedSnapshot, Error> {
    let mut coverage = value["coverage"]
        .as_str()
        .ok_or(Error::InvalidExtraction)?
        .to_owned();
    if value["truncated"] == true {
        coverage.push_str("; bounded selection omits additional matches");
    }
    if value.get("terms").is_some() {
        coverage = format!(
            "ranked-terms; {}; selection={}",
            coverage,
            value["selection"]
                .as_str()
                .ok_or(Error::InvalidExtraction)?
        );
    }
    if value["currentness"] != "current-at-read" {
        coverage.push_str("; source context stale or unindexed");
        return Ok(AuthorizedSnapshot {
            project: project.into(),
            snapshot: None,
            evidence: vec![],
            coverage,
        });
    }
    let string = |value: &Value, key: &str| {
        value[key]
            .as_str()
            .map(str::to_owned)
            .ok_or(Error::InvalidExtraction)
    };
    let snapshot = Some(string(&value, "snapshot")?);
    let mut evidence = Vec::new();
    for (index, item) in value["results"]
        .as_array()
        .ok_or(Error::InvalidExtraction)?
        .iter()
        .enumerate()
    {
        if item["project"] != project || item["currentness"] != "current-at-read" {
            return Err(Error::ScopeMismatch);
        }
        evidence.push(Evidence {
            id: format!("source-{index}"),
            project: project.into(),
            path: string(item, "path")?,
            line: item["line"]
                .as_u64()
                .and_then(|n| u32::try_from(n).ok())
                .ok_or(Error::InvalidExtraction)?,
            text: string(item, "text")?,
            source_hash: string(item, "source_hash")?,
            producer: string(item, "producer")?,
            kind: string(item, "kind")?,
            currentness: Currentness::CurrentAtRead,
            coverage: string(item, "coverage")?,
        });
    }
    Ok(AuthorizedSnapshot {
        project: project.into(),
        snapshot,
        evidence,
        coverage,
    })
}

struct CoreAuthority<'a> {
    store: &'a Store,
    project: &'a str,
    query: &'a str,
    cancel: &'a AtomicBool,
    expected: &'a threadmark_core::knowledge::Project,
    retrieval: RetrievalMode,
}
impl EvidenceAuthority for CoreAuthority<'_> {
    fn current(
        &self,
        request: &Request,
    ) -> Result<AuthorizedSnapshot, threadmark_refinement::Error> {
        if request.data().project != self.project || request.retrieval_mode() != self.retrieval {
            return Err(threadmark_refinement::Error::ScopeMismatch);
        }
        context_selection(
            self.store,
            self.expected,
            self.query,
            self.cancel,
            self.retrieval,
        )
        .map_err(|error| match error {
            Error::Canceled => threadmark_refinement::Error::Canceled,
            Error::ScopeMismatch => threadmark_refinement::Error::ScopeMismatch,
            _ => threadmark_refinement::Error::Unavailable,
        })
    }
}

fn context_selection(
    store: &Store,
    expected: &threadmark_core::knowledge::Project,
    query: &str,
    cancel: &AtomicBool,
    retrieval: RetrievalMode,
) -> Result<AuthorizedSnapshot, Error> {
    if retrieval == RetrievalMode::Literal && expected.incarnation.is_none() {
        // Preserve the existing explicit legacy operator command; cached/new
        // ranked selections always require an incarnation-bearing binding.
        selection(store, &expected.id, query, cancel)
    } else {
        selection_bound(store, expected, query, cancel, retrieval)
    }
}

/// Prepare an escaped original-versus-context preview from the actual registered
/// source policy. This never stores the original, invokes inference, approves or
/// sends. Missing evidence is visibly needs-input, not fabricated expertise.
pub fn context(
    store: &Store,
    project: &str,
    query: &str,
    original: String,
    cancel: &AtomicBool,
) -> Result<Value, Error> {
    context_with_retrieval(
        store,
        project,
        query,
        original,
        cancel,
        RetrievalMode::Literal,
    )
}

/// Cached native Context selection, including every engine revalidation.
pub fn context_bound(
    store: &Store,
    expected: &threadmark_core::knowledge::Project,
    query: &str,
    original: String,
    cancel: &AtomicBool,
) -> Result<Value, Error> {
    context_bound_with_retrieval(
        store,
        expected,
        query,
        original,
        cancel,
        RetrievalMode::Literal,
    )
}

/// Explicit algorithm selection with a complete pre-read cached-scope binding.
pub fn context_bound_with_retrieval(
    store: &Store,
    expected: &threadmark_core::knowledge::Project,
    query: &str,
    original: String,
    cancel: &AtomicBool,
    retrieval: RetrievalMode,
) -> Result<Value, Error> {
    threadmark_core::knowledge::validate_query_binding(expected, query)?;
    context_scoped(
        store,
        &expected.id,
        query,
        original,
        cancel,
        expected,
        retrieval,
    )
}

/// Explicit algorithm opt-in; literal response shape is unchanged. Ranked output
/// discloses selection/coverage and never invokes a provider or delivers anything.
pub fn context_with_retrieval(
    store: &Store,
    project: &str,
    query: &str,
    original: String,
    cancel: &AtomicBool,
    retrieval: RetrievalMode,
) -> Result<Value, Error> {
    if cancel.load(Ordering::SeqCst) {
        return Err(Error::Canceled);
    }
    if retrieval == RetrievalMode::RankedTerms {
        threadmark_core::knowledge::validate_query_terms(project, query)?;
    }
    let expected = store.project(project)?;
    context_scoped(
        store, project, query, original, cancel, &expected, retrieval,
    )
}

fn context_scoped(
    store: &Store,
    project: &str,
    query: &str,
    original: String,
    cancel: &AtomicBool,
    expected: &threadmark_core::knowledge::Project,
    retrieval: RetrievalMode,
) -> Result<Value, Error> {
    if cancel.load(Ordering::SeqCst) {
        return Err(Error::Canceled);
    }
    if retrieval == RetrievalMode::RankedTerms {
        threadmark_core::knowledge::validate_query_terms(project, query)?;
    }
    let selected = context_selection(store, expected, query, cancel, retrieval)?;
    let coverage = selected.coverage.clone();
    let needs_input = selected.snapshot.is_none() || selected.evidence.is_empty();
    let request = Request::new_with_retrieval(
        RequestData {
            request_id: "local-context-preview".into(),
            project: project.into(),
            snapshot: selected.snapshot,
            original,
            constraints: vec![],
            attachments: vec![],
            destination: "local-review-only".into(),
            mode: Mode::Context,
            evidence: selected.evidence,
            output_budget: 8192,
        },
        retrieval,
    )
    .map_err(engine_error)?;
    let mut engine = Engine::new(
        request,
        Control::new(Instant::now() + Duration::from_secs(30)),
    );
    let authority = CoreAuthority {
        expected,
        store,
        project,
        query,
        cancel,
        retrieval,
    };
    engine.prepare(&authority, None).map_err(engine_error)?;
    let preview = engine.preview().map_err(engine_error)?;
    if cancel.load(Ordering::SeqCst) {
        return Err(Error::Canceled);
    }
    let mut value = json!({
        "project":project, "snapshot":engine.request().data().snapshot,
        "mode":"context-only", "state":if needs_input { "needs-input" } else { "ready-for-review" },
        "original":preview.original, "proposed":preview.proposed, "changed":preview.changed,
        "approval":"not-requested", "delivery":"not-attempted", "provider":"not-invoked",
    });
    if retrieval == RetrievalMode::RankedTerms {
        value["retrieval_mode"] = json!("ranked-terms");
        value["coverage"] = json!(coverage);
        value["evidence"] = ranked::evidence(engine.request());
    }
    if serde_json::to_vec(&value)
        .map_err(|_| Error::Unavailable)?
        .len()
        + usize::from(retrieval == RetrievalMode::RankedTerms)
        > 8192
    {
        return Err(Error::InvalidExtraction);
    }
    Ok(value)
}
