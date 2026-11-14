//! A bound query must not reload a preflighted ID into replacement source access.
use super::*;

#[test]
fn replacement_between_preflight_and_query_never_reaches_source_traversal() {
    for same_root in [false, true] {
        let fixture = Fixture::new();
        let replacement = Fixture::new();
        let mut store = fixture.registered();
        store.index("a", &mut LexicalLines, &token()).unwrap();
        let expected = store.project("a").unwrap();
        // Deterministic interleaving: the daemon's earlier metadata precheck
        // succeeds, then a peer replaces the ID before core selection starts.
        store
            .bound_project(
                "a",
                &expected.root,
                &expected.root_identity,
                expected.incarnation.as_deref().unwrap(),
            )
            .unwrap();
        let mut peer = fixture.store();
        peer.remove_project("a", &token()).unwrap();
        let root = if same_root {
            fixture.source()
        } else {
            replacement.source()
        };
        peer.add_project("a", &root, vec!["code.rs".into()])
            .unwrap();
        peer.index("a", &mut LexicalLines, &token()).unwrap();
        let before = peer.project("a").unwrap();
        let result = store.query_scoped("a", "alpha", &token(), Some(&expected), || {
            panic!("replacement must fail before any source traversal")
        });
        assert!(matches!(result, Err(Error::ScopeMismatch)));
        assert!(matches!(
            store.query_bound(&expected, "alpha", &token()),
            Err(Error::ScopeMismatch)
        ));
        assert_eq!(peer.project("a").unwrap().incarnation, before.incarnation);
        assert_eq!(
            peer.query("a", "alpha", &token()).unwrap()["results"]
                .as_array()
                .unwrap()
                .len(),
            1
        );
    }
}

#[test]
fn bound_query_checks_policy_snapshot_and_cancellation_before_source_boundary() {
    let fixture = Fixture::new();
    let mut store = fixture.registered();
    store.index("a", &mut LexicalLines, &token()).unwrap();
    let expected = store.project("a").unwrap();
    assert_eq!(
        store.query_bound(&expected, "alpha", &token()).unwrap()["currentness"],
        "current-at-read"
    );
    for field in ["sources", "snapshot", "incarnation"] {
        let mut wrong = store.project("a").unwrap();
        match field {
            "sources" => wrong.sources.clear(),
            "snapshot" => wrong.snapshot = Some("0".repeat(64)),
            "incarnation" => wrong.incarnation = None,
            _ => unreachable!(),
        }
        assert!(matches!(
            store.query_scoped("a", "alpha", &token(), Some(&wrong), || panic!(
                "mismatch reached source boundary"
            )),
            Err(Error::ScopeMismatch)
        ));
    }
    let canceled = AtomicBool::new(true);
    assert!(matches!(
        store.query_bound(&expected, "alpha", &canceled),
        Err(Error::Canceled)
    ));
    std::fs::write(fixture.source().join("code.rs"), "fn changed() {}\n").unwrap();
    let stale = store.query_bound(&expected, "alpha", &token()).unwrap();
    assert_eq!(stale["currentness"], "stale-or-unindexed");
    assert!(stale["results"].as_array().unwrap().is_empty());
}

#[test]
fn cached_read_requires_complete_valid_metadata_but_not_an_indexed_snapshot() {
    let fixture = Fixture::new();
    let store = fixture.registered();
    let captured = store.project("a").unwrap();
    assert!(captured.snapshot.is_none());
    let result = store.query_bound(&captured, "alpha", &token()).unwrap();
    assert_eq!(result["currentness"], "stale-or-unindexed");
    assert!(result["results"].as_array().unwrap().is_empty());
    for field in ["root", "identity", "incarnation", "snapshot", "sources"] {
        let mut malformed = store.project("a").unwrap();
        match field {
            "root" => malformed.root = "relative".into(),
            "identity" => malformed.root_identity.clear(),
            "incarnation" => malformed.incarnation = Some("legacy".into()),
            "snapshot" => malformed.snapshot = Some("not-a-hash".into()),
            "sources" => malformed.sources = vec!["../escape.rs".into()],
            _ => unreachable!(),
        }
        assert!(validate_query_binding(&malformed, "alpha").is_err());
        assert!(store.query_bound(&malformed, "alpha", &token()).is_err());
    }
    for query in ["".into(), "a".repeat(257), "nul\0query".into()] {
        assert!(validate_query_binding(&captured, &query).is_err());
    }
    let mut wrong = store.project("a").unwrap();
    wrong.root_identity = "different-filesystem-identity".into();
    assert!(matches!(
        store.query_scoped("a", "alpha", &token(), Some(&wrong), || panic!(
            "root mismatch reached source boundary"
        )),
        Err(Error::ScopeMismatch)
    ));
}
