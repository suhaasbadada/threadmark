//! Unit Y: registration admission before suppression metadata, synthetic only.
use super::*;

fn reads(s: &Store, p: &Project, cancel: &AtomicBool) -> [Result<Value>; 2] {
    [
        s.forgotten_contexts_bound("app", &binding(p), cancel),
        s.forgotten_sources_bound("app", &binding(p), cancel),
    ]
}
fn seed(s: &Store, id: &str, path: &str) {
    s.db.execute("INSERT INTO forgotten_context VALUES('app',?1)", [id])
        .unwrap();
    s.db.execute("INSERT INTO forgotten_sources VALUES('app',?1)", [path])
        .unwrap();
}
fn in_snapshot(tx: &Connection, source: bool) -> Result<Value> {
    if source {
        Store::forgotten_sources_in(tx, "app")
    } else {
        Store::forgotten_contexts_in(tx, "app")
    }
}

#[test]
fn marker_replacement_is_rejected_before_first_marker_sql() {
    for same_root in [true, false] {
        let f = Fixture::new();
        let s = f.registered();
        let p = s.project("app").unwrap();
        let mut peer = f.store();
        peer.remove_project("app", &token()).unwrap();
        std::fs::create_dir(f.0.join("new-root")).unwrap();
        peer.add_project(
            "app",
            &f.0.join(if same_root { "app" } else { "new-root" }),
            vec![],
        )
        .unwrap();
        seed(&peer, "b-private-id", "b-private-path.rs");
        for result in reads(&s, &p, &token()) {
            assert!(matches!(result, Err(Error::ScopeMismatch)));
        }
        // If either endpoint consulted its marker table first, this would be
        // Unavailable, not ScopeMismatch. Store-open schema admission is separate.
        s.db.execute_batch("DROP TABLE forgotten_context; DROP TABLE forgotten_sources;")
            .unwrap();
        for result in reads(&s, &p, &token()) {
            assert!(matches!(result, Err(Error::ScopeMismatch)));
        }
    }
}

#[test]
fn both_wal_marker_snapshots_stay_a_and_replacement_blocks_publication() {
    for source in [false, true] {
        let f = Fixture::new();
        let s = f.registered();
        let mut peer = f.store();
        s.db.pragma_update(None, "journal_mode", "WAL").unwrap();
        seed(&s, "a-id", "a-path.rs");
        let p = s.project("app").unwrap();
        let expected = in_snapshot(&s.db, source).unwrap();
        let result = s.read_human_bound("app", &binding(&p), &token(), |tx, _| {
            peer.remove_project("app", &token()).unwrap();
            peer.add_project("app", &f.0.join("app"), vec![]).unwrap();
            seed(&peer, "b-private-id", "b-private-path.rs");
            // The marker query runs AFTER B commits but inside snapshot A.
            let value = in_snapshot(tx, source)?;
            assert_eq!(value, expected);
            assert!(!value.to_string().contains("b-private"));
            Ok(value)
        });
        assert!(matches!(result, Err(Error::ScopeMismatch)));
        assert!(
            in_snapshot(&peer.db, source)
                .unwrap()
                .to_string()
                .contains("b-private")
        );
    }
}

#[test]
fn receipt_binding_is_exact_readonly_policy_independent_and_bounded() {
    let f = Fixture::new();
    let mut s = f.registered();
    seed(&s, "a-id", "a-path.rs");
    s.db.execute(
        "UPDATE projects SET root='/synthetic/é',root_identity='identity-é' WHERE id='app'",
        [],
    )
    .unwrap();
    let p = s.project("app").unwrap();
    let expected = [
        s.forgotten_contexts("app").unwrap(),
        s.forgotten_sources("app").unwrap(),
    ];
    let before = s.db.total_changes();
    for (value, expected) in reads(&s, &p, &token()).into_iter().zip(&expected) {
        let value = value.unwrap();
        assert_eq!(&value, expected);
        assert!(serde_json::to_vec(&value).unwrap().len() < 1_048_576);
    }
    assert_eq!(before, s.db.total_changes());
    for (root, identity) in [
        ("/synthetic/e\u{301}", p.root_identity.as_str()),
        (p.root.as_str(), "identity-e\u{301}"),
    ] {
        let mut changed = s.project("app").unwrap();
        changed.root = root.into();
        changed.root_identity = identity.into();
        for result in reads(&s, &changed, &token()) {
            assert!(matches!(result, Err(Error::ScopeMismatch)));
        }
    }
    s.set_sources("app", vec!["missing.rs".into()]).unwrap();
    s.db.execute(
        "UPDATE projects SET snapshot=?1 WHERE id='app'",
        ["a".repeat(64)],
    )
    .unwrap();
    std::fs::rename(f.0.join("app"), f.0.join("unavailable-root")).unwrap();
    source_forget::SOURCE_ACCESSES.with(|n| n.set(0));
    for (result, expected) in reads(&s, &p, &token()).into_iter().zip(&expected) {
        assert_eq!(&result.unwrap(), expected);
    }
    source_forget::SOURCE_ACCESSES.with(|n| assert_eq!(n.get(), 0));
    for result in reads(&s, &p, &AtomicBool::new(true)) {
        assert!(matches!(result, Err(Error::Canceled)));
    }
    for source in [false, true] {
        let cancel = token();
        let result = s.read_human_bound("app", &binding(&p), &cancel, |tx, _| {
            let value = in_snapshot(tx, source)?;
            cancel.store(true, Ordering::SeqCst);
            Ok(value)
        });
        assert!(matches!(result, Err(Error::Canceled)));
    }
    s.db.execute("INSERT INTO forgotten_context VALUES('app','../bad')", [])
        .unwrap();
    assert!(
        s.forgotten_contexts_bound("app", &binding(&p), &token())
            .is_err()
    );
    s.db.execute("INSERT INTO forgotten_sources VALUES('app','../bad')", [])
        .unwrap();
    assert!(
        s.forgotten_sources_bound("app", &binding(&p), &token())
            .is_err()
    );
}

#[test]
fn marker_legacy_compatibility_and_dependency_failure_do_not_migrate() {
    let f = Fixture::new();
    let s = f.registered();
    seed(&s, "a-id", "a.rs");
    let p = s.project("app").unwrap();
    s.db.execute_batch("DROP TRIGGER threadmark_source_policy_guard; DROP TRIGGER threadmark_source_evidence_guard; DROP TRIGGER threadmark_source_project_delete_guard; DROP TABLE forgotten_sources; PRAGMA user_version=3;").unwrap();
    assert_eq!(
        s.forgotten_contexts_bound("app", &binding(&p), &token())
            .unwrap(),
        s.forgotten_contexts("app").unwrap()
    );
    assert!(matches!(
        s.forgotten_sources_bound("app", &binding(&p), &token()),
        Err(Error::Unavailable)
    ));
    assert_eq!(schema::validate(&s.db).unwrap(), 3);
    s.db.execute_batch("DROP TRIGGER threadmark_project_incarnation_insert; DROP TRIGGER threadmark_project_incarnation_delete; DROP TABLE project_incarnations; PRAGMA user_version=2;").unwrap();
    for result in reads(&s, &p, &token()) {
        assert!(matches!(result, Err(Error::ScopeMismatch)));
    }
    assert_eq!(
        s.forgotten_contexts("app").unwrap()["forgotten"][0]["id"],
        "a-id"
    );
    assert_eq!(schema::validate(&s.db).unwrap(), 2);
    // Already-open dependency loss fails closed in an otherwise admitted v4 store.
    let f2 = Fixture::new();
    let s2 = f2.registered();
    let p2 = s2.project("app").unwrap();
    s2.db
        .execute_batch("DROP TABLE forgotten_context; DROP TABLE forgotten_sources;")
        .unwrap();
    assert!(reads(&s2, &p2, &token()).iter().all(Result::is_err));
}

#[test]
fn bound_marker_count_limits_never_publish_a_truncated_prefix() {
    let f = Fixture::new();
    let s = f.registered();
    let p = s.project("app").unwrap();
    s.db.execute_batch("WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM n WHERE i<4096) INSERT INTO forgotten_context SELECT 'app','id'||i FROM n; WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM n WHERE i<64) INSERT INTO forgotten_sources SELECT 'app','file'||i||'.rs' FROM n;").unwrap();
    for (result, count) in reads(&s, &p, &token()).into_iter().zip([4096, 64]) {
        let value = result.unwrap();
        assert_eq!(value["forgotten"].as_array().unwrap().len(), count);
        assert!(serde_json::to_vec(&value).unwrap().len() + 1 < 1_048_576);
    }
    s.db.execute("INSERT INTO forgotten_context VALUES('app','overflow')", [])
        .unwrap();
    s.db.execute(
        "INSERT INTO forgotten_sources VALUES('app','overflow.rs')",
        [],
    )
    .unwrap();
    assert!(reads(&s, &p, &token()).iter().all(Result::is_err));
}
