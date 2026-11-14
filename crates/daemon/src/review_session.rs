//! Finite private-stdio review protocol v1, retaining the actual core-backed engine.
use crate::local_refinement::Options;
use crate::preparation::{RetrievalMode, ReviewSession};
use serde::{
    Deserialize, Deserializer,
    de::{MapAccess, Visitor, value::MapAccessDeserializer},
};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::path::Path;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, Instant, SystemTime};
use threadmark_core::knowledge::Store;
use threadmark_refinement::{
    ConfiguredProvider, DataScope, LoopbackHttp, PreparationState, Provider, ProviderAccess,
    ProviderConsent, ProviderSettings, Request, ReviewChoice,
};
// Same existing engine types, not parallel protocol cancellation or error models.
pub use threadmark_refinement::{Control, Error};

/// Maximum frame size, including LF, checked before deserialization.
pub const FRAME_BYTES: usize = 8192;
/// Maximum input or output frames in one session.
pub const MAX_FRAMES: usize = 8;
/// Maximum total input or output bytes in one session.
pub const TOTAL_BYTES: usize = 65536;

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Capture {
    version: u8,
    original: String,
}

/// Equality challenge for the last published review, not an approval credential.
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Challenge {
    revision: u64,
    digest: String,
}

/// Only the two existing mutable prose fields; never a whole caller-supplied brief.
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Edit {
    revision: u64,
    digest: String,
    objective: String,
    output_expectations: String,
}

/// Explicit empty cancel payload rejects unknown and duplicate fields.
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Cancel {}

/// Closed action grammar; external tagging rejects duplicate tags and extra keys.
#[derive(Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Action {
    /// Change only objective and output-expectations prose.
    Edit(#[serde(deserialize_with = "object")] Edit),
    /// Explicit use of exact reviewed prepared text.
    UsePrepared(#[serde(deserialize_with = "object")] Challenge),
    /// Explicit use of original, including after provider failure.
    UseOriginal(#[serde(deserialize_with = "object")] Challenge),
    /// Cancel; never an implicit original handoff.
    Cancel(#[serde(deserialize_with = "object")] Cancel),
}

// Serde's derived structs also accept positional arrays. Protocol v1 deliberately
// accepts objects only, at both the frame and action-payload boundaries. Preserve
// MapAccess for the typed decoder so duplicate keys cannot be collapsed by Value.
fn object<'de, D: Deserializer<'de>, T: Deserialize<'de>>(decoder: D) -> Result<T, D::Error> {
    struct Object<T>(std::marker::PhantomData<T>);
    impl<'de, T: Deserialize<'de>> Visitor<'de> for Object<T> {
        type Value = T;
        fn expecting(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
            formatter.write_str("protocol object")
        }
        fn visit_map<A: MapAccess<'de>>(self, map: A) -> Result<T, A::Error> {
            T::deserialize(MapAccessDeserializer::new(map))
        }
    }
    decoder.deserialize_map(Object(std::marker::PhantomData))
}

fn decode<T: for<'de> Deserialize<'de>>(frame: &[u8]) -> Result<T, Error> {
    if frame.len() > FRAME_BYTES || !frame.ends_with(b"\n") {
        return Err(Error::Overflow);
    }
    let mut decoder = serde_json::Deserializer::from_slice(frame);
    let value = object(&mut decoder).map_err(|_| Error::Invalid)?;
    decoder.end().map_err(|_| Error::Invalid)?;
    Ok(value)
}

/// Decode the first frame only, rejecting caller evidence and invalid original.
pub fn original(frame: &[u8]) -> Result<String, Error> {
    let capture: Capture = decode(frame)?;
    if capture.version != 1 || capture.original.is_empty() {
        return Err(Error::Invalid);
    }
    if capture.original.len() > 4096 {
        return Err(Error::Overflow);
    }
    Ok(capture.original)
}

/// Strict typed action decoder; no diagnostic text or arbitrary command execution.
pub fn action(frame: &[u8]) -> Result<Action, Error> {
    decode(frame)
}

/// A closed metadata event. Content-free errors only, never provider diagnostics.
pub fn failure(error: Error) -> Value {
    json!({"version":1,"event":if error == Error::Canceled {"canceled"} else {"failure"},
        "code":error.to_string(),"terminal":error != Error::ReviewRequired,"delivery":"DeliveryNotAttempted"})
}

/// One retained engine and existing SQLite connection. No persistence or delivery.
pub struct LocalReview {
    store: Store,
    session: ReviewSession,
    options: Options,
    core_binding: String,
    instance: String,
    revision: u64,
    digest: String,
    proposal: Option<String>,
}

static NEXT: AtomicU64 = AtomicU64::new(0);

impl LocalReview {
    /// Validate and capture the expected core namespace before reading sources;
    /// invoke the existing configured provider at most once. Provider failure
    /// retains original for an explicit core-revalidated choice, never fallback.
    pub fn start(
        data_dir: &Path,
        options: Options,
        original: String,
        control: Control,
    ) -> Result<Self, Error> {
        Self::start_with_retrieval(data_dir, options, original, control, RetrievalMode::Literal)
    }

    /// Explicit immutable retrieval opt-in; protocol frames and literal defaults
    /// remain unchanged. Reject invalid terms before opening even an existing store.
    pub fn start_with_retrieval(
        data_dir: &Path,
        options: Options,
        original: String,
        control: Control,
        retrieval: RetrievalMode,
    ) -> Result<Self, Error> {
        options.validate()?;
        if retrieval == RetrievalMode::RankedTerms {
            threadmark_core::knowledge::validate_query_terms(
                &options.expected.project,
                &options.query,
            )
            .map_err(|_| Error::Invalid)?;
        }
        let mut capture = options.capture(original);
        capture.request_id = "local-refinement-review".into();
        Request::new_with_retrieval(capture.clone(), retrieval)?;
        let store = Store::open_existing(data_dir).map_err(|_| Error::Unavailable)?;
        let mut session = ReviewSession::capture_bound_with_retrieval(
            &store,
            options.query.clone(),
            capture,
            control.clone(),
            &options.expected,
            retrieval,
        )?;
        let core_binding = format!(
            "{:?}",
            store
                .project(&options.expected.project)
                .map_err(|_| Error::Unavailable)?
        );
        let settings = ProviderSettings {
            profiles: vec![options.identity()],
            selected_profile: Some(options.profile.clone()),
            enabled: true,
        };
        let transport = LoopbackHttp;
        let provider = ConfiguredProvider::new(&settings, &transport)?;
        let consent = ProviderConsent {
            request: session.request().clone(),
            identity: provider.identity(),
            data_scope: DataScope::RequestAndSelectedEvidence,
            max_calls: 1,
            output_budget: FRAME_BYTES,
            deadline: control
                .deadline()
                .min(Instant::now() + Duration::from_secs(30)),
        };
        if let Err(error) = session.prepare(
            &store,
            Some(ProviderAccess {
                provider: &provider,
                consent: &consent,
            }),
        ) {
            // Only provider/call failure can continue to an explicit original.
            // Source authorization, protocol and operation-control failures close.
            if error != Error::ProviderFailed {
                return Err(error);
            }
            control.checkpoint()?;
        }
        Ok(Self {
            store,
            session,
            options,
            core_binding,
            instance: format!(
                "{}-{:?}-{}",
                std::process::id(),
                SystemTime::now(),
                NEXT.fetch_add(1, Ordering::Relaxed)
            ),
            revision: 0,
            digest: String::new(),
            proposal: None,
        })
    }

    /// Revalidate before publishing a new revision and equality challenge.
    pub fn review(&mut self) -> Result<Value, Error> {
        self.revision = self.revision.checked_add(1).ok_or(Error::Budget)?;
        self.proposal = if self.session.state() == PreparationState::Failed {
            // Failure discloses no original or proposed content. Explicit original
            // still revalidates actual core at approve and handoff below.
            None
        } else {
            Some(self.session.preview(&self.store)?.proposed)
        };
        let components = [
            "local-review-stdio-v1".into(),
            self.instance.clone(),
            self.revision.to_string(),
            format!("{:?}", self.session.request()),
            format!("{:?}", self.session.request().retrieval_mode()),
            format!("{:?}", self.session.brief()),
            self.core_binding.clone(),
            format!("{:?}", self.options.expected),
            self.options.query.clone(),
            format!("{:?}", self.options.identity()),
            self.session.coverage().into(),
            format!("{:?}", self.session.state()),
            format!("{:?}", self.session.failure()),
            format!("{:?}", self.proposal),
        ];
        let mut hash = Sha256::new();
        for component in components {
            hash.update((component.len() as u64).to_be_bytes());
            hash.update(component.as_bytes());
        }
        self.digest = hash
            .finalize()
            .iter()
            .map(|byte| format!("{byte:02x}"))
            .collect();
        if self.session.state() == PreparationState::Failed {
            return Ok(json!({"version":1,"event":"failure","terminal":false,
                "code":self.session.failure().ok_or(Error::Unavailable)?.to_string(),
                "revision":self.revision,"digest":self.digest,
                "delivery":"DeliveryNotAttempted",
                "downstream":"clipboard-draft-send-execution-not-attempted"}));
        }
        let brief = self.session.brief();
        Ok(json!({"version":1,"terminal":false,
            "event":match self.session.state() {
                PreparationState::Ready => "preview",
                PreparationState::NeedsInput => "needsinput",
                PreparationState::Failed => "failure",
                _ => return Err(Error::Unavailable),
            },
            "code": self.session.failure().map(|e| e.to_string()),
            "revision":self.revision,"digest":self.digest,
            "proposed":self.proposal,
            "changed": self.proposal.as_ref().map(|s| s != &self.session.request().data().original),
            "editable":brief.map(|b| json!({"objective":b.objective,"output_expectations":b.output_expectations})),
            "material_questions":brief.map(|b| &b.questions),
            "coverage":self.session.coverage(),
            "provider":{"profile":self.options.profile,"model":self.options.model,
                "endpoint":self.options.endpoint,"locality":"local","max_calls":1,
                "max_tokens":1024,"deadline_seconds":30,"output_byte_budget":8192,
                "data_scope":"request-and-selected-evidence"},
            "delivery":"DeliveryNotAttempted",
            "downstream":"clipboard-draft-send-execution-not-attempted",
        }))
    }

    fn matches(&self, revision: u64, digest: &str) -> Result<(), Error> {
        if self.revision == 0 || revision != self.revision || digest != self.digest {
            return Err(Error::ReviewRequired);
        }
        Ok(())
    }

    /// Return (event, terminal). ReviewRequired alone is recoverable and never
    /// creates an approval. All other errors must close the enclosing process.
    pub fn apply(&mut self, action: Action) -> Result<(Value, bool), Error> {
        let (choice, challenge) = match action {
            Action::Cancel(_) => return Ok((failure(Error::Canceled), true)),
            Action::Edit(edit) => {
                self.matches(edit.revision, &edit.digest)?;
                let mut brief = self.session.brief().cloned().ok_or(Error::ReviewRequired)?;
                brief.objective = edit.objective;
                brief.output_expectations = edit.output_expectations;
                self.session.edit(brief)?;
                return Ok((self.review()?, false));
            }
            Action::UsePrepared(challenge) => (ReviewChoice::UsePrepared, challenge),
            Action::UseOriginal(challenge) => (ReviewChoice::UseOriginal, challenge),
        };
        self.matches(challenge.revision, &challenge.digest)?;
        let approval = self.session.approve(&self.store, choice)?;
        let handoff = self.session.handoff(&self.store, &approval)?;
        Ok((
            json!({"version":1,"event":"handoff","terminal":true,"text":handoff.text,
            "choice": if choice == ReviewChoice::UsePrepared {"use-prepared"} else {"use-original"},
            "revision":self.revision,"digest":self.digest,
            "delivery":"DeliveryNotAttempted",
            "downstream":"clipboard-draft-send-execution-not-attempted"}),
            true,
        ))
    }
}
