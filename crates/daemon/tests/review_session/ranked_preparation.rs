use super::*;

fn ranked(store: &Store, control: Control, query: &str, mode: Mode) -> ReviewSession {
    ReviewSession::capture_with_retrieval(
        store,
        query.into(),
        capture(mode),
        control,
        RetrievalMode::RankedTerms,
    )
    .unwrap()
}

#[test]
fn mode_is_immutable_in_consent_even_when_evidence_and_control_are_identical() {
    for query in ["synthetic_blue", "no-match"] {
        let f = Fixture::new();
        let store = f.store();
        let control = Control::new(Instant::now() + Duration::from_secs(30));
        let literal =
            ReviewSession::capture(&store, query.into(), capture(Mode::Refine), control.clone())
                .unwrap();
        let mut terms = ranked(&store, control.clone(), query, Mode::Refine);
        assert_eq!(literal.request().data(), terms.request().data());
        assert_ne!(literal.request(), terms.request());
        assert_eq!(terms.request().retrieval_mode(), RetrievalMode::RankedTerms);
        let provider = Candidate::new();
        let permission = consent(&literal, &control, &provider);
        assert_eq!(
            terms.prepare(
                &store,
                Some(ProviderAccess {
                    provider: &provider,
                    consent: &permission
                })
            ),
            Err(Error::InferenceNotAuthorized)
        );
        assert_eq!(provider.calls.get(), 0);
    }
}

#[test]
fn changed_mode_or_selection_cannot_reuse_review_and_cancel_rejects_late_provider() {
    let f = Fixture::new();
    let store = f.store();
    let control = Control::new(Instant::now() + Duration::from_secs(30));
    let mut literal = ReviewSession::capture(
        &store,
        "synthetic_blue".into(),
        capture(Mode::Context),
        control.clone(),
    )
    .unwrap();
    literal.prepare(&store, None).unwrap();
    let approved = literal.approve(&store, ReviewChoice::UsePrepared).unwrap();
    let mut terms = ranked(&store, control.clone(), "synthetic_blue", Mode::Context);
    terms.prepare(&store, None).unwrap();
    assert_eq!(terms.handoff(&store, &approved), Err(Error::ReviewRequired));
    let mut other = ranked(&store, control.clone(), "no-match", Mode::Context);
    other.prepare(&store, None).unwrap();
    assert_eq!(other.handoff(&store, &approved), Err(Error::ReviewRequired));
    let ranked_original = terms.approve(&store, ReviewChoice::UseOriginal).unwrap();
    assert_eq!(
        other.handoff(&store, &ranked_original),
        Err(Error::ReviewRequired)
    );
    assert!(terms.coverage().contains("ranked-terms"));
    let mut refine = ranked(&store, control.clone(), "synthetic blue", Mode::Refine);
    let provider = Candidate {
        cancel: true,
        ..Candidate::new()
    };
    let permission = consent(&refine, &control, &provider);
    assert_eq!(
        refine.prepare(
            &store,
            Some(ProviderAccess {
                provider: &provider,
                consent: &permission
            })
        ),
        Err(Error::Canceled)
    );
    assert_eq!(refine.preview(&store), Err(Error::Canceled));
    assert_eq!(
        refine.request().data().original,
        capture(Mode::Refine).original
    );
}

#[test]
fn ranked_preparation_omits_whole_anchors_or_rejects_whole_envelope_without_inference() {
    let f = Fixture::new();
    let mut store = f.store();
    // More than eight small anchors: selection omission is visible in coverage.
    std::fs::write(f.0.join("source/main.rs"), "alpha_gap_beta\n".repeat(12)).unwrap();
    store
        .index("synthetic", &mut LexicalLines, &AtomicBool::new(false))
        .unwrap();
    let control = Control::new(Instant::now() + Duration::from_secs(30));
    let mut session = ranked(&store, control.clone(), "alpha beta", Mode::Context);
    assert_eq!(session.request().data().evidence.len(), 8);
    assert!(session.coverage().contains("omits additional matches"));
    session.prepare(&store, None).unwrap();
    assert!(session.preview(&store).unwrap().proposed.len() <= 8192);
    // Complete selected entries fit the query but the request+original may not.
    let large = format!("alpha beta {}\n", "\\\"".repeat(400));
    std::fs::write(f.0.join("source/main.rs"), large.repeat(10)).unwrap();
    store
        .index("synthetic", &mut LexicalLines, &AtomicBool::new(false))
        .unwrap();
    let mut data = capture(Mode::Refine);
    data.original = "o".repeat(4096);
    assert!(matches!(
        ReviewSession::capture_with_retrieval(
            &store,
            "alpha beta".into(),
            data,
            control,
            RetrievalMode::RankedTerms
        ),
        Err(Error::Overflow)
    ));
}
