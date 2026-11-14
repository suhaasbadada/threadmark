//! One-shot output-candidate scope, never a reduced permission/freshness policy.
use super::*;
use std::cell::Cell;
use threadmark_core::knowledge::{FileQuery, FileQueryMode, Project};

const LIMITATIONS: &str = "Selected files are output candidates only; all approved sources are read for full freshness. Bounded lexical evidence, not semantic/AST expertise, I/O avoidance, privacy or performance gain. Current-at-read is not a filesystem lock or revocation lease.";

/// Immutable owned capture for explicit file-scoped Context. No mutable accessor,
/// unbound constructor, global request-ID capability or retained-session reuse.
#[derive(Debug)]
pub struct FileContextPlan {
    expected: Project,
    query: FileQuery,
    output_budget: usize,
}

impl FileContextPlan {
    /// Pure admission before stdin/store/source access. Consumes the full capture
    /// and copies selection into captured policy order, using AK validation.
    pub fn new(expected: Project, mut query: FileQuery) -> Result<Self, Error> {
        query.validate(&expected)?;
        query.selected_paths = expected
            .sources
            .iter()
            .filter(|path| query.selected_paths.contains(path))
            .cloned()
            .collect();
        let mut plan = Self {
            expected,
            query,
            output_budget: 0,
        };
        let header = serde_json::to_vec(&plan.header()).map_err(|_| Error::Unavailable)?;
        plan.output_budget = 8192usize
            .checked_sub(header.len() + 1)
            .filter(|budget| *budget > 0)
            .ok_or(Error::InvalidExtraction)?;
        Ok(plan)
    }

    fn retrieval(&self) -> RetrievalMode {
        match self.query.mode {
            FileQueryMode::Literal => RetrievalMode::Literal,
            FileQueryMode::RankedAnyTerms => RetrievalMode::RankedTerms,
        }
    }

    fn header(&self) -> Value {
        json!({
            "format":"threadmark-file-scoped-context", "version":1,
            "selected_paths":self.query.selected_paths,
            "retrieval_mode":match self.query.mode {
                FileQueryMode::Literal => "literal",
                FileQueryMode::RankedAnyTerms => "ranked-any-terms",
            },
            "limitations":LIMITATIONS,
        })
    }

    fn select(&self, store: &Store, cancel: &AtomicBool) -> Result<Value, Error> {
        store.query_files_bound(&self.expected, &self.query, cancel)
    }
}

pub(crate) fn validate_original(original: &str) -> Result<(), Error> {
    if original.is_empty() || original.len() > 4096 || original.contains('\0') {
        return Err(Error::InvalidExtraction);
    }
    Ok(())
}

// Created with exactly one immutable engine request, never exported or cached.
struct FileAuthority<'a> {
    plan: FileContextPlan,
    request: Request,
    store: &'a Store,
    cancel: &'a AtomicBool,
    observe: &'a dyn Fn(&FileContextPlan, usize),
    boundary: Cell<usize>,
}

impl EvidenceAuthority for FileAuthority<'_> {
    fn current(
        &self,
        request: &Request,
    ) -> Result<AuthorizedSnapshot, threadmark_refinement::Error> {
        if request != &self.request {
            return Err(threadmark_refinement::Error::ScopeMismatch);
        }
        let boundary = self.boundary.get() + 1;
        self.boundary.set(boundary);
        (self.observe)(&self.plan, boundary);
        let value = self.plan.select(self.store, self.cancel);
        value
            .and_then(|value| selected_value(value, &self.plan.expected.id))
            .map_err(|error| match error {
                Error::Canceled => threadmark_refinement::Error::Canceled,
                Error::ScopeMismatch => threadmark_refinement::Error::ScopeMismatch,
                _ => threadmark_refinement::Error::Unavailable,
            })
    }
}

/// Explicit Context-only preparation; all reads/revalidations use one frozen AK
/// file plan. No provider, approval, retained state, delivery or original storage.
pub fn context_files(
    store: &Store,
    plan: FileContextPlan,
    original: String,
    cancel: &AtomicBool,
) -> Result<Value, Error> {
    context_files_observed(store, plan, original, cancel, &|_, _| {})
}

fn context_files_observed(
    store: &Store,
    plan: FileContextPlan,
    original: String,
    cancel: &AtomicBool,
    observe: &dyn Fn(&FileContextPlan, usize),
) -> Result<Value, Error> {
    validate_original(&original)?;
    if cancel.load(Ordering::SeqCst) {
        return Err(Error::Canceled);
    }
    observe(&plan, 0);
    let value = plan.select(store, cancel)?;
    let selected = selected_value(value.clone(), &plan.expected.id)?;
    let needs_input = selected.snapshot.is_none() || selected.evidence.is_empty();
    let request = context_request(
        &plan.expected.id,
        &selected,
        original,
        plan.retrieval(),
        plan.output_budget,
    )?;
    let mut response = plan.header();
    let authority = FileAuthority {
        plan,
        request: request.clone(),
        store,
        cancel,
        observe,
        boundary: Cell::new(0),
    };
    let control = Control::new(Instant::now() + Duration::from_secs(30));
    let mut engine = Engine::new(request, control.clone());
    engine.prepare(&authority, None).map_err(engine_error)?;
    let preview = engine.preview().map_err(engine_error)?;
    // Final authority read uses the identical frozen plan, not ID-only metadata.
    if authority.current(engine.request()).map_err(engine_error)? != selected {
        return Err(Error::ScopeMismatch);
    }
    let fields = json!({
        "project":engine.request().data().project,
        "snapshot":engine.request().data().snapshot,
        "mode":"context-only", "state":if needs_input { "needs-input" } else { "ready-for-review" },
        "original":preview.original,
        "proposed":if needs_input { &preview.original } else { &preview.proposed },
        "changed":!needs_input && preview.changed,
        "approval":"not-requested", "delivery":"not-attempted", "provider":"not-invoked",
        "coverage":selected.coverage, "evidence":ranked::evidence(engine.request()),
        "selection":value["selection"], "truncated":value["truncated"],
        "matching_anchors":value["matching_anchors"], "scanned_anchors":value["scanned_anchors"],
    });
    response
        .as_object_mut()
        .ok_or(Error::InvalidExtraction)?
        .extend(fields.as_object().ok_or(Error::InvalidExtraction)?.clone());
    if serde_json::to_vec(&response)
        .map_err(|_| Error::Unavailable)?
        .len()
        + 1
        > 8192
    {
        return Err(Error::InvalidExtraction);
    }
    if cancel.load(Ordering::SeqCst) {
        return Err(Error::Canceled);
    }
    control.checkpoint().map_err(engine_error)?;
    Ok(response)
}

#[cfg(test)]
mod tests;
