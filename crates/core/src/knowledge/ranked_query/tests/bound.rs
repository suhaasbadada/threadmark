//! Deterministic source-boundary checks, using actual peer SQLite replacements.
use super::*;

#[test]
fn ranked_bound_replacement_never_reaches_source_boundary() {
    for same_root in [false, true] {
        let f = Fixture::new();
        let other = Fixture::new();
        f.write("a.rs", "alpha gap beta\n");
        other.write("a.rs", "alpha replacement beta\n");
        let store = f.store(&["a.rs"]);
        let expected = store.project("a").unwrap();
        let mut peer = Store::open_existing(&f.0.join("store")).unwrap();
        peer.remove_project("a", &token()).unwrap();
        peer.add_project(
            "a",
            &if same_root {
                f.0.join("source")
            } else {
                other.0.join("source")
            },
            vec!["a.rs".into()],
        )
        .unwrap();
        peer.index("a", &mut LexicalLines, &token()).unwrap();
        assert!(matches!(
            store.query_terms_scoped(
                "a",
                "alpha beta",
                &token(),
                Some(&expected),
                || panic!("replacement reached source access"),
                || {}
            ),
            Err(Error::ScopeMismatch)
        ));
        assert!(matches!(
            store.query_terms_bound(&expected, "alpha beta", &token()),
            Err(Error::ScopeMismatch)
        ));
    }
}

#[test]
fn ranked_bound_checks_every_policy_field_before_sources_and_preserves_staleness() {
    let f = Fixture::new();
    f.write("a.rs", "alpha gap beta\n");
    let store = f.store(&["a.rs"]);
    let expected = store.project("a").unwrap();
    for field in ["root", "identity", "incarnation", "sources", "snapshot"] {
        let mut wrong = store.project("a").unwrap();
        match field {
            "root" => wrong.root.push_str("-replacement"),
            "identity" => wrong.root_identity.push('0'),
            "incarnation" => wrong.incarnation = None,
            "sources" => wrong.sources.clear(),
            "snapshot" => wrong.snapshot = Some("0".repeat(64)),
            _ => unreachable!(),
        }
        assert!(
            store
                .query_terms_scoped(
                    "a",
                    "alpha beta",
                    &token(),
                    Some(&wrong),
                    || panic!("policy mismatch read sources"),
                    || {}
                )
                .is_err()
        );
    }
    let cancel = AtomicBool::new(true);
    assert!(matches!(
        store.query_terms_bound(&expected, "alpha beta", &cancel),
        Err(Error::Canceled)
    ));
    assert_eq!(
        store
            .query_terms_bound(&expected, "alpha beta", &token())
            .unwrap()["results"]
            .as_array()
            .unwrap()
            .len(),
        1
    );
    f.write("a.rs", "changed alpha beta\n");
    let stale = store
        .query_terms_bound(&expected, "alpha beta", &token())
        .unwrap();
    assert_eq!(stale["currentness"], "stale-or-unindexed");
    assert_eq!(stale["results"], json!([]));
}
