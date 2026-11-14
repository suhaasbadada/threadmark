//! One finite local-operator invocation. No listener, persisted session or sender.
use crate::preparation::{CaptureBinding, RetrievalMode, ReviewSession};
use serde_json::json;
use std::path::Path;
use std::time::{Duration, Instant};
use threadmark_core::knowledge::Store;
use threadmark_refinement::{
    ConfiguredProvider, Control, DataScope, Endpoint, Error, Locality, LoopbackHttp, Mode,
    PreparationState, Provider, ProviderAccess, ProviderConsent, ProviderIdentity,
    ProviderSettings, Request, RequestData,
};

/// Nonsecret explicit flags; no discovery, environment credentials or defaults.
pub struct Options {
    /// Expected inspected core scope.
    pub expected: CaptureBinding,
    /// Exact query the operator inspected before confirmation.
    pub query: String,
    /// Explicit nonsecret profile label.
    pub profile: String,
    /// Exact selected model.
    pub model: String,
    /// Numeric-loopback HTTP endpoint only.
    pub endpoint: String,
    /// Per-invocation consent, separate from profile enablement.
    pub confirm_local_inference: bool,
}

impl Options {
    pub(crate) fn identity(&self) -> ProviderIdentity {
        ProviderIdentity {
            profile: self.profile.clone(),
            model: self.model.clone(),
            endpoint: self.endpoint.clone(),
            locality: Locality::Local,
        }
    }

    /// Validate flags before opening an existing store or reading any source.
    pub fn validate(&self) -> Result<(), Error> {
        self.expected.validate()?;
        if self.query.is_empty() || self.query.len() > 256 {
            return Err(Error::Invalid);
        }
        Endpoint::new(self.identity())?; // Locality::Local rejects remote before DNS.
        if !self.confirm_local_inference {
            return Err(Error::InferenceNotAuthorized);
        }
        Ok(())
    }

    pub(crate) fn capture(&self, original: String) -> RequestData {
        RequestData {
            request_id: "local-refinement-preview".into(),
            project: self.expected.project.clone(),
            snapshot: None,
            original,
            constraints: vec![],
            attachments: vec![],
            destination: "local-review-only".into(),
            mode: Mode::Refine,
            evidence: vec![],
            output_budget: 8192,
        }
    }
}

/// Return one whole JSON line (including its newline <=8192 bytes), or nothing.
/// Original stays in memory; errors contain no content. Humans review externally;
/// the retained ReviewSession ends here, with no cross-process approval claim.
pub fn preview(data_dir: &Path, options: Options, original: String) -> Result<String, Error> {
    preview_with_retrieval(data_dir, options, original, RetrievalMode::Literal)
}

/// Explicit ranked opt-in; preserves the existing options DTO and literal JSON.
pub fn preview_with_retrieval(
    data_dir: &Path,
    options: Options,
    original: String,
    retrieval: RetrievalMode,
) -> Result<String, Error> {
    options.validate()?;
    if retrieval == RetrievalMode::RankedTerms {
        threadmark_core::knowledge::validate_query_terms(&options.expected.project, &options.query)
            .map_err(|_| Error::Invalid)?;
    }
    let capture = options.capture(original);
    Request::new(capture.clone())?; // Shape and original bounds before store open.
    let control = Control::new(Instant::now() + Duration::from_secs(30));
    let store = Store::open_existing(data_dir).map_err(|_| Error::Unavailable)?;
    let mut session = ReviewSession::capture_bound_with_retrieval(
        &store,
        options.query.clone(),
        capture,
        control.clone(),
        &options.expected,
        retrieval,
    )?;
    let transport = LoopbackHttp;
    let identity = options.identity();
    let settings = ProviderSettings {
        profiles: vec![identity.clone()],
        selected_profile: Some(options.profile),
        enabled: true,
    };
    let provider = ConfiguredProvider::new(&settings, &transport)?;
    let consent = ProviderConsent {
        request: session.request().clone(),
        identity: provider.identity(),
        data_scope: DataScope::RequestAndSelectedEvidence,
        max_calls: 1,
        output_budget: 8192,
        deadline: control.deadline(),
    };
    session.prepare(
        &store,
        Some(ProviderAccess {
            provider: &provider,
            consent: &consent,
        }),
    )?;
    let preview = session.preview(&store)?;
    let brief = session.brief().ok_or(Error::Unavailable)?;
    let state = match session.state() {
        PreparationState::Ready => "ready-for-review",
        PreparationState::NeedsInput => "needs-input",
        _ => return Err(Error::Unavailable),
    };
    let mut value = json!({
        "project": options.expected.project, "snapshot": session.request().data().snapshot,
        "root": options.expected.root, "root_identity": options.expected.root_identity,
        "incarnation": options.expected.incarnation, "query": options.query,
        "mode":"refinement-preview", "state":state,
        "original":preview.original, "proposed":preview.proposed, "changed":preview.changed,
        "material_questions":brief.questions, "coverage":session.coverage(),
        "approval":"not-requested", "delivery":"not-attempted",
        "provider":{"profile":identity.profile, "model":identity.model,
            "endpoint":identity.endpoint, "locality":"local",
            "data_scope":"request-and-selected-evidence", "max_calls":1,
            "max_tokens":1024, "deadline_seconds":30, "output_byte_budget":8192},
    });
    if retrieval == RetrievalMode::RankedTerms {
        value["retrieval_mode"] = json!("ranked-terms");
        value["evidence"] = crate::preparation::ranked::evidence(session.request());
    }
    let mut line = serde_json::to_string(&value).map_err(|_| Error::Unavailable)?;
    line.push('\n');
    if line.len() > 8192 {
        return Err(Error::Overflow);
    }
    control.checkpoint()?;
    Ok(line)
}
