//! Synthetic actual-core preparation/review integration; no network or delivery.
use std::cell::Cell;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::time::{Duration, Instant};
use threadmark_core::knowledge::{LexicalLines, Store};
use threadmark_daemon::preparation::ReviewSession;
use threadmark_refinement::*;

static NEXT: AtomicU64 = AtomicU64::new(0);
struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        let path = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-review-{}-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::create_dir(&path).unwrap();
        std::fs::create_dir(path.join("source")).unwrap();
        std::fs::write(path.join("source/main.rs"), "fn synthetic_blue() {}\n").unwrap();
        Self(path)
    }
    fn store(&self) -> Store {
        let mut store = Store::open(&self.0.join("store")).unwrap();
        store
            .add_project("synthetic", &self.0.join("source"), vec!["main.rs".into()])
            .unwrap();
        store
            .index("synthetic", &mut LexicalLines, &AtomicBool::new(false))
            .unwrap();
        store
    }
    fn session(&self, store: &Store, mode: Mode) -> (ReviewSession, Control) {
        let control = Control::new(Instant::now() + Duration::from_secs(30));
        let session = ReviewSession::capture(
            store,
            "synthetic_blue".into(),
            capture(mode),
            control.clone(),
        )
        .unwrap();
        (session, control)
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}
fn capture(mode: Mode) -> RequestData {
    RequestData {
        request_id: "synthetic-review".into(),
        project: "synthetic".into(),
        snapshot: None,
        original: "Locate synthetic_blue. Do not deploy. 保持 intent.\n".into(),
        constraints: vec![Constraint {
            id: "no-deploy".into(),
            text: "Do not deploy.".into(),
        }],
        attachments: vec![],
        destination: "local-review-only".into(),
        mode,
        evidence: vec![],
        output_budget: 8192,
    }
}
struct Candidate {
    calls: Cell<usize>,
    fail: bool,
    cancel: bool,
}
impl Candidate {
    fn new() -> Self {
        Self {
            calls: Cell::new(0),
            fail: false,
            cancel: false,
        }
    }
}
impl Provider for Candidate {
    fn identity(&self) -> ProviderIdentity {
        ProviderIdentity {
            profile: "synthetic-explicit".into(),
            model: "synthetic-model".into(),
            endpoint: "synthetic-local-test".into(),
            locality: Locality::Local,
        }
    }
    fn refine(
        &self,
        _: &Request,
        mut seed: Brief,
        control: &Control,
        _: usize,
    ) -> Result<Brief, Error> {
        self.calls.set(self.calls.get() + 1);
        if self.cancel {
            control.cancel();
        }
        if self.fail {
            return Err(Error::ProviderFailed);
        }
        seed.objective = "Inspect the selected synthetic function; review required.".into();
        Ok(seed)
    }
}
fn consent(session: &ReviewSession, control: &Control, provider: &Candidate) -> ProviderConsent {
    ProviderConsent {
        request: session.request().clone(),
        identity: provider.identity(),
        data_scope: DataScope::RequestAndSelectedEvidence,
        max_calls: 1,
        output_budget: 8192,
        deadline: control.deadline(),
    }
}

#[test]
fn actual_core_refine_retains_review_state_without_delivery() {
    let fixture = Fixture::new();
    let store = fixture.store();
    let (mut session, control) = fixture.session(&store, Mode::Refine);
    let original = session.request().data().original.clone();
    assert_eq!(session.request().data().evidence.len(), 1);
    assert_eq!(
        session.prepare(&store, None),
        Err(Error::InferenceNotAuthorized)
    );
    assert_eq!(session.state(), PreparationState::NeedsInput);
    let provider = Candidate::new();
    let permission = consent(&session, &control, &provider);
    session
        .prepare(
            &store,
            Some(ProviderAccess {
                provider: &provider,
                consent: &permission,
            }),
        )
        .unwrap();
    assert_eq!(provider.calls.get(), 1);
    assert_eq!(session.state(), PreparationState::Ready);
    assert_eq!(session.preview(&store).unwrap().original, original);
    let approval = session.approve(&store, ReviewChoice::UsePrepared).unwrap();
    let handoff = session.handoff(&store, &approval).unwrap();
    assert_eq!(handoff.delivery, Delivery::NotAttempted);
    assert_eq!(handoff.destination, "local-review-only");
    let mut edited = session.brief().unwrap().clone();
    edited.objective = "Explicitly edited synthetic objective.".into();
    session.edit(edited).unwrap();
    assert_eq!(
        session.handoff(&store, &approval),
        Err(Error::ReviewRequired)
    );
    assert_eq!(session.request().data().original, original);
    assert_eq!(
        session.prepare(
            &store,
            Some(ProviderAccess {
                provider: &provider,
                consent: &permission
            })
        ),
        Err(Error::Budget)
    );
    assert_eq!(provider.calls.get(), 1);
}

#[test]
fn provider_failure_requires_explicit_original_and_cancel_rejects_late_values() {
    let fixture = Fixture::new();
    let store = fixture.store();
    for cancel in [false, true] {
        let (mut session, control) = fixture.session(&store, Mode::Refine);
        let provider = Candidate {
            fail: !cancel,
            cancel,
            ..Candidate::new()
        };
        let permission = consent(&session, &control, &provider);
        let result = session.prepare(
            &store,
            Some(ProviderAccess {
                provider: &provider,
                consent: &permission,
            }),
        );
        if cancel {
            assert_eq!(result, Err(Error::Canceled));
            assert_eq!(
                session.approve(&store, ReviewChoice::UseOriginal),
                Err(Error::Canceled)
            );
            assert_eq!(session.preview(&store), Err(Error::Canceled));
        } else {
            assert_eq!(result, Err(Error::ProviderFailed));
            assert_eq!(
                session.approve(&store, ReviewChoice::UsePrepared),
                Err(Error::ReviewRequired)
            );
            let approval = session.approve(&store, ReviewChoice::UseOriginal).unwrap();
            let value = session.handoff(&store, &approval).unwrap();
            assert_eq!(value.text, session.request().data().original);
            assert_eq!(value.delivery, Delivery::NotAttempted);
        }
    }
}

#[test]
fn source_changes_and_same_root_registration_reuse_invalidate_session() {
    let fixture = Fixture::new();
    let mut store = fixture.store();
    let (mut session, _) = fixture.session(&store, Mode::Context);
    session.prepare(&store, None).unwrap();
    let approval = session.approve(&store, ReviewChoice::UsePrepared).unwrap();
    std::fs::write(
        fixture.0.join("source/main.rs"),
        "fn synthetic_green() {}\n",
    )
    .unwrap();
    assert_eq!(session.preview(&store), Err(Error::ScopeMismatch));
    assert_eq!(
        session.handoff(&store, &approval),
        Err(Error::ScopeMismatch)
    );
    // Restore identical source and snapshot but replace the registration itself.
    std::fs::write(fixture.0.join("source/main.rs"), "fn synthetic_blue() {}\n").unwrap();
    store
        .remove_project("synthetic", &AtomicBool::new(false))
        .unwrap();
    store
        .add_project(
            "synthetic",
            &fixture.0.join("source"),
            vec!["main.rs".into()],
        )
        .unwrap();
    store
        .index("synthetic", &mut LexicalLines, &AtomicBool::new(false))
        .unwrap();
    assert_eq!(
        session.handoff(&store, &approval),
        Err(Error::ScopeMismatch)
    );
    assert_eq!(session.prepare(&store, None), Err(Error::ScopeMismatch));
    assert_eq!(
        session.handoff(&store, &approval),
        Err(Error::ReviewRequired)
    );
}

#[test]
fn forged_evidence_and_unregistered_capture_are_rejected() {
    let fixture = Fixture::new();
    let store = fixture.store();
    let mut data = capture(Mode::Refine);
    data.snapshot = Some("caller-claim".into());
    let control = Control::new(Instant::now() + Duration::from_secs(30));
    assert!(matches!(
        ReviewSession::capture(&store, "synthetic_blue".into(), data, control.clone()),
        Err(Error::Invalid)
    ));
    let mut data = capture(Mode::Refine);
    data.project = "unregistered".into();
    assert!(ReviewSession::capture(&store, "synthetic_blue".into(), data, control).is_err());
}

#[test]
fn provider_result_is_rejected_when_source_changes_during_inference() {
    struct ChangingProvider(PathBuf);
    impl Provider for ChangingProvider {
        fn identity(&self) -> ProviderIdentity {
            Candidate::new().identity()
        }
        fn refine(&self, _: &Request, seed: Brief, _: &Control, _: usize) -> Result<Brief, Error> {
            std::fs::write(&self.0, "fn synthetic_changed_during_inference() {}\n").unwrap();
            Ok(seed)
        }
    }
    let fixture = Fixture::new();
    let store = fixture.store();
    let (mut session, control) = fixture.session(&store, Mode::Refine);
    let permission = consent(&session, &control, &Candidate::new());
    let provider = ChangingProvider(fixture.0.join("source/main.rs"));
    assert_eq!(
        session.prepare(
            &store,
            Some(ProviderAccess {
                provider: &provider,
                consent: &permission
            })
        ),
        Err(Error::ScopeMismatch)
    );
    assert_eq!(session.state(), PreparationState::Failed);
    assert_eq!(session.failure(), Some(Error::ScopeMismatch));
    assert_eq!(session.preview(&store), Err(Error::ScopeMismatch));
    assert_eq!(
        session.request().data().original,
        capture(Mode::Refine).original
    );
}

#[test]
fn source_policy_revocation_supersession_and_deadline_block_review() {
    let fixture = Fixture::new();
    let mut store = fixture.store();
    let (mut session, _) = fixture.session(&store, Mode::Context);
    session.prepare(&store, None).unwrap();
    store.set_sources("synthetic", vec![]).unwrap();
    assert_eq!(session.preview(&store), Err(Error::ScopeMismatch));
    assert_eq!(
        session.approve(&store, ReviewChoice::UseOriginal),
        Err(Error::ScopeMismatch)
    );
    let (mut superseded, control) = fixture.session(&store, Mode::Bypass);
    superseded.prepare(&store, None).unwrap();
    control.supersede();
    assert_eq!(
        superseded.approve(&store, ReviewChoice::UseOriginal),
        Err(Error::Superseded)
    );
    assert_eq!(superseded.state(), PreparationState::Canceled);
    let expired = Control::new(Instant::now());
    assert!(matches!(
        ReviewSession::capture(
            &store,
            "synthetic_blue".into(),
            capture(Mode::Refine),
            expired
        ),
        Err(Error::Deadline)
    ));
}
