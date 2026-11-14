use super::selection;
use std::sync::atomic::AtomicBool;
use threadmark_core::knowledge::{Project, Store};
use threadmark_refinement::{
    Approval, AuthorizedSnapshot, Brief, Control, Engine, Error, EvidenceAuthority, Handoff,
    PreparationState, Preview, ProviderAccess, Request, RequestData, ReviewChoice,
};

fn core_error(error: threadmark_core::Error) -> Error {
    match error {
        threadmark_core::Error::Canceled => Error::Canceled,
        threadmark_core::Error::ScopeMismatch => Error::ScopeMismatch,
        _ => Error::Unavailable,
    }
}

struct Namespace {
    root: String,
    root_identity: String,
    incarnation: String,
    sources: Vec<String>,
}

impl Namespace {
    fn capture(project: Project) -> Result<Self, Error> {
        Ok(Self {
            root: project.root,
            root_identity: project.root_identity,
            // Long-lived cached consent cannot safely bind a legacy registration.
            incarnation: project.incarnation.ok_or(Error::ScopeMismatch)?,
            sources: project.sources,
        })
    }

    fn check(&self, store: &Store, project: &str) -> Result<(), Error> {
        let current = store.project(project).map_err(core_error)?;
        if current.root != self.root
            || current.root_identity != self.root_identity
            || current.incarnation.as_deref() != Some(&self.incarnation)
            || current.sources != self.sources
        {
            return Err(Error::ScopeMismatch);
        }
        Ok(())
    }
}

struct Authority<'a> {
    store: &'a Store,
    namespace: &'a Namespace,
    query: &'a str,
    control: &'a Control,
}

impl EvidenceAuthority for Authority<'_> {
    fn current(&self, request: &Request) -> Result<AuthorizedSnapshot, Error> {
        self.control.checkpoint()?;
        self.namespace.check(self.store, &request.data().project)?;
        // Core query is independently bounded. The operation token is checked
        // before/after it; arbitrary provider calls must honor the same token.
        let selected = selection(
            self.store,
            &request.data().project,
            self.query,
            &AtomicBool::new(false),
        )
        .map_err(core_error)?;
        self.namespace.check(self.store, &request.data().project)?;
        self.control.checkpoint()?;
        Ok(selected)
    }
}

/// One memory-only core-backed request, consent, preview and review lifecycle.
/// The caller retains a [`Control`] clone for cancellation/supersession. No
/// credentials, provider selection, inference consent or delivery are inferred.
/// This is a synchronous API, not a listener or durable session registry.
pub struct ReviewSession {
    engine: Engine,
    namespace: Namespace,
    query: String,
    control: Control,
}

impl ReviewSession {
    /// Freeze user intent and a fresh authorized core selection. `capture` must
    /// have no caller-supplied snapshot/evidence; core alone supplies those fields.
    /// Requires an incarnation-bearing registration (no implicit legacy upgrade).
    pub fn capture(
        store: &Store,
        query: String,
        mut capture: RequestData,
        control: Control,
    ) -> Result<Self, Error> {
        control.checkpoint()?;
        if capture.snapshot.is_some() || !capture.evidence.is_empty() {
            return Err(Error::Invalid);
        }
        // Validate intent/shape before reading any source content.
        Request::new(capture.clone())?;
        let namespace = Namespace::capture(store.project(&capture.project).map_err(core_error)?)?;
        let selected = selection(store, &capture.project, &query, &AtomicBool::new(false))
            .map_err(core_error)?;
        namespace.check(store, &capture.project)?;
        control.checkpoint()?;
        capture.snapshot = selected.snapshot;
        capture.evidence = selected.evidence;
        let request = Request::new(capture)?;
        Ok(Self {
            engine: Engine::new(request, control.clone()),
            namespace,
            query,
            control,
        })
    }

    /// Exact frozen request to disclose before creating matching explicit consent.
    pub fn request(&self) -> &Request {
        self.engine.request()
    }

    /// Effective preparation state, not approval, delivery or downstream success.
    pub fn state(&self) -> PreparationState {
        self.engine.state()
    }

    /// Content-free failure; original remains available through `request()`.
    pub fn failure(&self) -> Option<Error> {
        self.engine.failure()
    }

    /// Prepare/retry with explicit access for Refine. Context ignores access.
    /// The existing engine enforces exact consent, call budgets and late results.
    pub fn prepare(
        &mut self,
        store: &Store,
        access: Option<ProviderAccess<'_>>,
    ) -> Result<(), Error> {
        let authority = Authority {
            store,
            namespace: &self.namespace,
            query: &self.query,
            control: &self.control,
        };
        self.engine.prepare(&authority, access)
    }

    /// Current validated brief for explicit editing, never implicitly approved.
    pub fn brief(&self) -> Option<&Brief> {
        self.engine.brief()
    }

    /// Validate an explicit user edit and invalidate earlier approvals.
    pub fn edit(&mut self, brief: Brief) -> Result<(), Error> {
        self.engine.edit(brief)
    }

    /// Revalidate scope/evidence before publishing a preview to the caller.
    pub fn preview(&self, store: &Store) -> Result<Preview, Error> {
        let authority = Authority {
            store,
            namespace: &self.namespace,
            query: &self.query,
            control: &self.control,
        };
        let selected = authority.current(self.request())?;
        let request = self.request().data();
        if selected.snapshot != request.snapshot || selected.evidence != request.evidence {
            return Err(Error::ScopeMismatch);
        }
        self.engine.preview()
    }

    /// Explicit review choice bound to exact content and fresh core authority.
    pub fn approve(&self, store: &Store, choice: ReviewChoice) -> Result<Approval, Error> {
        self.engine.approve(
            choice,
            &Authority {
                store,
                namespace: &self.namespace,
                query: &self.query,
                control: &self.control,
            },
        )
    }

    /// Revalidate and return a reviewed value only. Does not send, copy, place a
    /// host draft, or establish task success. Host delivery remains a separate gate.
    pub fn handoff(&self, store: &Store, approval: &Approval) -> Result<Handoff, Error> {
        self.engine.handoff(
            approval,
            &Authority {
                store,
                namespace: &self.namespace,
                query: &self.query,
                control: &self.control,
            },
        )
    }
}
