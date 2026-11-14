use std::collections::BTreeSet;

/// Maximum original UTF-8 byte length; never truncated.
pub const MAX_ORIGINAL_BYTES: usize = 4096;
/// Maximum full escaped request and rendered output byte length.
pub const MAX_OUTPUT_BYTES: usize = 8192;
/// Maximum selected evidence count.
pub const MAX_EVIDENCE: usize = 8;

/// Content-free boundary errors. Provider diagnostic text is never retained.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Error {
    /// Invalid identity, shape, duplicate ID, or empty required value.
    Invalid,
    /// Whole input/output exceeds a bound.
    Overflow,
    /// Trusted core authorization/current evidence is unavailable.
    Unavailable,
    /// Project, snapshot or selected evidence differs from trusted core's read.
    ScopeMismatch,
    /// Selected source is stale or unresolvable.
    Stale,
    /// Explicit matching inference configuration/consent is missing.
    InferenceNotAuthorized,
    /// Provider call/output budget is exhausted.
    Budget,
    /// Deadline expired, including a late provider return.
    Deadline,
    /// Operation canceled.
    Canceled,
    /// Request was explicitly superseded.
    Superseded,
    /// Provider failed; original remains available for explicit review choice.
    ProviderFailed,
    /// Provider/edit changed immutable intent fields or claimed unsupported facts.
    InvalidBrief,
    /// Review approval is absent, out of date, or not ready.
    ReviewRequired,
}

impl std::fmt::Display for Error {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        // Only closed enum labels; never include prompt/source/provider diagnostics.
        write!(formatter, "{self:?}")
    }
}

impl std::error::Error for Error {}

/// Preparation mode; Context and Bypass never invoke a provider.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Mode {
    /// Attach authorized selected evidence without rewriting original.
    Context,
    /// Explicit inference with review required.
    Refine,
    /// Exact original, no evidence in output.
    Bypass,
}

/// Evidence currentness from the frozen core query contract.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Currentness {
    /// Core observed this evidence at the current read.
    CurrentAtRead,
    /// Unindexed or stale; cannot be included as current evidence.
    StaleOrUnindexed,
}

/// Explicit immutable user constraint (including exact negations).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Constraint {
    /// Stable request-local constraint identifier.
    pub id: String,
    /// Exact user text, not an inferred permission.
    pub text: String,
}

/// Attachment reference and exact metadata; this engine never reads its bytes.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Attachment {
    /// Opaque reference supplied by the host.
    pub reference: String,
    /// Exact host-provided metadata, preserved without normalization.
    pub metadata: String,
}

/// Selected core query result, treated as quoted untrusted data.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Evidence {
    /// Selection-local reference used by the brief.
    pub id: String,
    /// Registered project identity, never an authorization credential.
    pub project: String,
    /// Exact source-relative path from core; not opened by this library.
    pub path: String,
    /// Positive one-based line.
    pub line: u32,
    /// Exact source excerpt, never promoted to instructions or permission.
    pub text: String,
    /// Core's source version identity.
    pub source_hash: String,
    /// Exact provenance label from core.
    pub producer: String,
    /// Observed source kind. Only `observed-source-line` is accepted in v1.
    pub kind: String,
    /// Core's read-time currentness.
    pub currentness: Currentness,
    /// Exact coverage/limitation description from core.
    pub coverage: String,
}

/// Mutable capture DTO; freeze using [`Request::new`] before preparation.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RequestData {
    /// Host request identity (not a credential).
    pub request_id: String,
    /// Explicit registered project selection.
    pub project: String,
    /// Current snapshot identity, or none for unavailable/unindexed context.
    pub snapshot: Option<String>,
    /// Exact UTF-8 user request.
    pub original: String,
    /// Exact user-declared constraints/exclusions.
    pub constraints: Vec<Constraint>,
    /// Exact attachment references and metadata, never uploaded implicitly.
    pub attachments: Vec<Attachment>,
    /// Explicit destination identity, never inferred from an application name.
    pub destination: String,
    /// Explicit selected mode.
    pub mode: Mode,
    /// At most eight selected core evidence items.
    pub evidence: Vec<Evidence>,
    /// Full rendered output byte budget, at most 8 KiB.
    pub output_budget: usize,
}

/// Immutable bounded request. Accessors return shared references only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Request(RequestData, RetrievalMode);

/// Explicit source selection algorithm, independent of Context/Refine mode.
/// Frozen privately in Request so consent equality includes even empty selections
/// without changing the existing capture DTO or literal wire responses.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum RetrievalMode {
    /// Existing literal substring selection (the default).
    #[default]
    Literal,
    /// Explicit bounded any-term lexical ranking; not semantic retrieval.
    RankedTerms,
}

impl Request {
    /// Freeze a capture, rejecting overflow/duplicates rather than truncating.
    pub fn new(data: RequestData) -> Result<Self, Error> {
        if data.original.len() > MAX_ORIGINAL_BYTES
            || data.evidence.len() > MAX_EVIDENCE
            || data.output_budget > MAX_OUTPUT_BYTES
            || format!("{data:?}").len() > MAX_OUTPUT_BYTES
        {
            return Err(Error::Overflow);
        }
        if data.request_id.is_empty()
            || data.project.is_empty()
            || data.destination.is_empty()
            || data.original.is_empty()
            || data.output_budget == 0
            || data.snapshot.as_ref().is_some_and(String::is_empty)
            || !unique(data.constraints.iter().map(|item| item.id.as_str()))
            || !unique(data.attachments.iter().map(|item| item.reference.as_str()))
            || !unique(data.evidence.iter().map(|item| item.id.as_str()))
            || data.constraints.iter().any(|item| item.text.is_empty())
        {
            return Err(Error::Invalid);
        }
        for item in &data.evidence {
            if item.project != data.project {
                return Err(Error::ScopeMismatch);
            }
            if item.path.is_empty()
                || item.line == 0
                || item.source_hash.is_empty()
                || item.producer.is_empty()
                || item.kind != "observed-source-line"
                || item.coverage.is_empty()
            {
                return Err(Error::Invalid);
            }
            if item.currentness != Currentness::CurrentAtRead || data.snapshot.is_none() {
                return Err(Error::Stale);
            }
        }
        Ok(Self(data, RetrievalMode::Literal))
    }

    /// Freeze explicit retrieval metadata along with exact selected data. This
    /// does not authorize sources or inference; trusted core must supply evidence.
    pub fn new_with_retrieval(data: RequestData, retrieval: RetrievalMode) -> Result<Self, Error> {
        let mut request = Self::new(data)?;
        request.1 = retrieval;
        Ok(request)
    }

    /// Immutable algorithm bound by provider consent and review approval.
    pub fn retrieval_mode(&self) -> RetrievalMode {
        self.1
    }

    /// Read the frozen capture without allowing mutation.
    pub fn data(&self) -> &RequestData {
        &self.0
    }
}

pub(crate) fn unique<'a>(items: impl Iterator<Item = &'a str>) -> bool {
    let mut seen = BTreeSet::new();
    items
        .into_iter()
        .all(|item| !item.is_empty() && seen.insert(item))
}

/// Evidence-backed source quotation, not a claim of independently verified truth.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SourceQuote {
    /// Selected current evidence ID.
    pub evidence_id: String,
    /// Must exactly equal the selected source excerpt.
    pub text: String,
}

/// A source-backed candidate decision; applicability always needs human review.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Decision {
    /// Exact source quotation, not source-derived permission.
    pub source: SourceQuote,
    /// Known conflict; engine also requires an explicit question for this case.
    pub conflicting: bool,
}

/// Evidence-backed proposed risk guidance, never a completed verification result.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Risk {
    /// Current selected evidence supporting consideration of this risk.
    pub evidence_ids: Vec<String>,
    /// Proposed causal mechanism, not an independently verified assertion.
    pub mechanism: String,
    /// Why this might apply to the request.
    pub applicability: String,
    /// Explicit uncertainty; cannot be omitted.
    pub uncertainty: String,
    /// Proposed prevention, not permission to execute it.
    pub prevention: String,
    /// Proposed check only; no field can represent a passed test.
    pub proposed_verification: String,
}

/// Provider-neutral proposed brief; all generated prose remains review-required.
/// Structural checks do not prove semantic fidelity or absence of hallucinations.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Brief {
    /// Exact immutable original.
    pub original: String,
    /// Proposed objective summary, not new authority or a verified fact.
    pub objective: String,
    /// Exact ordered constraints including IDs and negations.
    pub constraints: Vec<Constraint>,
    /// All selected current evidence references, in selection order.
    pub evidence_ids: Vec<String>,
    /// Exact quotations; arbitrary verified assertions are not representable.
    pub source_quotes: Vec<SourceQuote>,
    /// Candidate decisions, explicitly not independently verified permissions.
    pub decisions: Vec<Decision>,
    /// Questions/unknowns; mandatory engine limitations must remain present.
    pub unknowns: Vec<String>,
    /// Material unresolved questions; any nonempty list blocks brief approval.
    pub questions: Vec<String>,
    /// Proposed mechanisms/prevention/checks supported by selected evidence.
    pub risks: Vec<Risk>,
    /// Proposed expected output, subject to user review.
    pub output_expectations: String,
}

/// Always-visible review limitation; no automated NLP guarantee is claimed.
pub const REVIEW_LIMITATION: &str = "Generated prose is unverified; human review of intent, permissions and semantic fidelity is required.";
/// Empty context is not project expertise.
pub const EMPTY_LIMITATION: &str =
    "No selected current evidence is available; no project expertise is established.";
/// Missing index snapshot remains visible.
pub const SNAPSHOT_LIMITATION: &str = "Current source snapshot is unavailable; select/index authorized sources before grounded refinement.";
/// Conflicting decisions are never silently resolved.
pub const CONFLICT_QUESTION: &str =
    "Selected decisions conflict: which decision applies? No resolution has been inferred.";

impl Brief {
    /// A conservative seed; providers may propose prose, never alter intent fields.
    /// This is not AI inference and makes no quality claim.
    pub fn seed(request: &Request) -> Self {
        let data = request.data();
        let mut unknowns = vec![REVIEW_LIMITATION.into()];
        if data.evidence.is_empty() {
            unknowns.push(EMPTY_LIMITATION.into());
        }
        if data.snapshot.is_none() {
            unknowns.push(SNAPSHOT_LIMITATION.into());
        }
        Self {
            original: data.original.clone(),
            objective: data.original.clone(),
            constraints: data.constraints.clone(),
            evidence_ids: data.evidence.iter().map(|item| item.id.clone()).collect(),
            source_quotes: Vec::new(),
            decisions: Vec::new(),
            unknowns,
            questions: Vec::new(),
            risks: Vec::new(),
            output_expectations: "User review must confirm expected output; no execution or verification has occurred.".into(),
        }
    }

    pub(crate) fn validate(&self, request: &Request) -> Result<(), Error> {
        let seed = Self::seed(request);
        let data = request.data();
        let known = |id: &str| data.evidence.iter().find(|item| item.id == id);
        let quote_valid = |quote: &SourceQuote| {
            known(&quote.evidence_id).is_some_and(|item| item.text == quote.text)
        };
        if self.original != data.original
            || self.constraints != data.constraints
            || self.evidence_ids != seed.evidence_ids
            || self.objective.is_empty()
            || self.output_expectations.is_empty()
            || self.unknowns.iter().any(String::is_empty)
            || self.questions.iter().any(String::is_empty)
            || !seed
                .unknowns
                .iter()
                .all(|item| self.unknowns.contains(item))
            || self.source_quotes.iter().any(|quote| !quote_valid(quote))
            || self
                .decisions
                .iter()
                .any(|decision| !quote_valid(&decision.source))
            || (self.decisions.iter().any(|item| item.conflicting)
                && !self.questions.iter().any(|item| item == CONFLICT_QUESTION))
            || self.risks.iter().any(|risk| {
                risk.evidence_ids.is_empty()
                    || !unique(risk.evidence_ids.iter().map(String::as_str))
                    || risk.evidence_ids.iter().any(|id| known(id).is_none())
                    || [
                        &risk.mechanism,
                        &risk.applicability,
                        &risk.uncertainty,
                        &risk.prevention,
                        &risk.proposed_verification,
                    ]
                    .iter()
                    .any(|text| text.is_empty())
            })
        {
            return Err(Error::InvalidBrief);
        }
        Ok(())
    }
}
