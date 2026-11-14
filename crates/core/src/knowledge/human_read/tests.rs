//! Synthetic SQLite fixtures for P2-A1/A6 and human-history P3-A4 support.
use super::*;

struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let path = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-human-bound-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::create_dir(&path).unwrap();
        for name in ["app", "app-copy"] {
            std::fs::create_dir(path.join(name)).unwrap();
        }
        Self(path)
    }
    fn store(&self) -> Store {
        Store::open(&self.0.join("store")).unwrap()
    }
    fn registered(&self) -> Store {
        let mut s = self.store();
        for name in ["app", "app-copy"] {
            s.add_project(name, &self.0.join(name), vec![]).unwrap();
            s.write_context(name, "memo", "note", &format!("synthetic {name}"), false)
                .unwrap();
        }
        s
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}
fn token() -> AtomicBool {
    AtomicBool::new(false)
}
fn binding(p: &Project) -> ContextReadBinding<'_> {
    ContextReadBinding {
        root: &p.root,
        root_identity: &p.root_identity,
        incarnation: p.incarnation.as_deref().unwrap(),
    }
}
fn all(s: &Store, b: &ContextReadBinding<'_>) -> [Result<Value>; 3] {
    [
        s.contexts_bound("app", b, &token()),
        s.context_bound("app", "memo", b, &token()),
        s.search_context_bound("app", "synthetic", b, &token()),
    ]
}

#[test]
fn replacement_before_read_rejects_at_private_pre_data_boundary() {
    for same_root in [true, false] {
        let f = Fixture::new();
        let s = f.registered();
        let p = s.project("app").unwrap();
        let mut peer = f.store();
        peer.remove_project("app", &token()).unwrap();
        let root = if same_root {
            f.0.join("app")
        } else {
            f.0.join("new-root")
        };
        if !same_root {
            std::fs::create_dir(&root).unwrap();
        }
        peer.add_project("app", &root, vec![]).unwrap();
        peer.write_context("app", "memo", "note", "synthetic B private", false)
            .unwrap();
        assert!(matches!(
            s.read_human_bound("app", &binding(&p), &token(), |_, _| {
                panic!("mismatch reached human SQL boundary")
            }),
            Err(Error::ScopeMismatch)
        ));
        // Even unavailable human tables must not be consulted on namespace mismatch.
        s.db.execute_batch("DROP TABLE context; DROP TABLE forgotten_context;")
            .unwrap();
        for result in all(&s, &binding(&p)) {
            assert!(matches!(result, Err(Error::ScopeMismatch)));
        }
    }
}

#[test]
fn exact_unicode_bytes_for_each_binding_and_legacy_fail_closed() {
    let f = Fixture::new();
    let s = f.registered();
    s.db.execute(
        "UPDATE projects SET root='/synthetic/é',root_identity='identity-é' WHERE id='app'",
        [],
    )
    .unwrap();
    let p = s.project("app").unwrap();
    assert!(all(&s, &binding(&p)).iter().all(Result::is_ok));
    for (root, root_identity, incarnation) in [
        (
            "/synthetic/e\u{301}",
            p.root_identity.as_str(),
            p.incarnation.as_deref().unwrap(),
        ),
        (
            p.root.as_str(),
            "identity-e\u{301}",
            p.incarnation.as_deref().unwrap(),
        ),
        (
            p.root.as_str(),
            p.root_identity.as_str(),
            "00000000000000000000000000000000",
        ),
    ] {
        let b = ContextReadBinding {
            root,
            root_identity,
            incarnation,
        };
        for result in all(&s, &b) {
            assert!(matches!(result, Err(Error::ScopeMismatch)));
        }
    }
    // Genuine legacy shapes: remove v4/v3 objects (and v2 objects for v1).
    s.db.execute_batch("DROP TRIGGER threadmark_source_policy_guard; DROP TRIGGER threadmark_source_evidence_guard; DROP TRIGGER threadmark_source_project_delete_guard; DROP TABLE forgotten_sources; DROP TRIGGER threadmark_project_incarnation_insert; DROP TRIGGER threadmark_project_incarnation_delete; DROP TABLE project_incarnations; PRAGMA user_version=2;").unwrap();
    for version in [2, 1] {
        if version == 1 {
            s.db.execute_batch("DROP TRIGGER threadmark_context_insert_guard; DROP TRIGGER threadmark_context_update_guard; DROP TRIGGER threadmark_project_delete_guard; DROP TABLE forgotten_context; PRAGMA user_version=1;").unwrap();
        }
        assert_eq!(schema::validate(&s.db).unwrap(), version);
        for result in all(&s, &binding(&p)) {
            assert!(matches!(result, Err(Error::ScopeMismatch)));
        }
        assert!(s.contexts("app").is_ok());
        assert!(s.context("app", "memo").is_ok());
        assert!(s.search_context("app", "synthetic", &token()).is_ok());
    }
}

#[test]
fn wal_replacement_during_each_read_never_adopts_b_and_rejects_publication() {
    for operation in ["list", "history", "search"] {
        let f = Fixture::new();
        let s = f.registered();
        let mut peer = f.store();
        s.db.pragma_update(None, "journal_mode", "WAL").unwrap();
        let p = s.project("app").unwrap();
        let result = s.read_human_bound("app", &binding(&p), &token(), |tx, registration| {
            peer.remove_project("app", &token()).unwrap();
            peer.add_project("app", &f.0.join("app"), vec![]).unwrap();
            peer.write_context("app", "replacement", "note", "synthetic B private", false)
                .unwrap();
            let value = match operation {
                "list" => Store::contexts_in(tx, "app")?,
                "history" => Store::context_in(tx, "app", "memo")?,
                _ => s.search_context_in(tx, registration, "synthetic", &token(), || {})?,
            };
            let encoded = value.to_string();
            assert!(!encoded.contains("replacement") && !encoded.contains("B private"));
            assert!(encoded.contains("memo") || encoded.contains("synthetic app"));
            Ok(value)
        });
        assert!(matches!(result, Err(Error::ScopeMismatch)));
        assert_eq!(
            peer.context("app", "replacement").unwrap()["history"][0]["text"],
            "synthetic B private"
        );
    }
}

#[test]
fn source_policy_snapshot_changes_do_not_invalidate_human_reads_or_read_sources() {
    let f = Fixture::new();
    let mut s = f.registered();
    let p = s.project("app").unwrap();
    let before: Vec<Value> = all(&s, &binding(&p))
        .into_iter()
        .map(Result::unwrap)
        .collect();
    s.set_sources("app", vec!["unavailable.rs".into()]).unwrap();
    s.db.execute(
        "UPDATE projects SET snapshot=?1 WHERE id='app'",
        ["a".repeat(64)],
    )
    .unwrap();
    std::fs::rename(f.0.join("app"), f.0.join("unavailable-root")).unwrap();
    source_forget::SOURCE_ACCESSES.with(|n| n.set(0));
    let after: Vec<Value> = all(&s, &binding(&p))
        .into_iter()
        .map(Result::unwrap)
        .collect();
    assert_eq!(before, after);
    source_forget::SOURCE_ACCESSES.with(|n| assert_eq!(n.get(), 0));
    // Malformed rows in another similarly named project are never scanned.
    s.db.execute(
        "UPDATE context SET text=?1 WHERE project='app-copy'",
        ["x".repeat(4097)],
    )
    .unwrap();
    assert!(all(&s, &binding(&p)).iter().all(Result::is_ok));
}

#[test]
fn bound_and_trusted_results_match_history_retirement_forget_ranking_and_budgets() {
    let f = Fixture::new();
    let mut s = f.registered();
    let p = s.project("app").unwrap();
    s.write_context("app", "memo", "decision", "synthetic new", true)
        .unwrap();
    s.write_context("app", "retired", "note", "synthetic old", false)
        .unwrap();
    s.retire_context("app", "retired").unwrap();
    s.write_context("app", "forgotten", "note", "synthetic old", false)
        .unwrap();
    s.forget_context("app", "forgotten", &token()).unwrap();
    let huge = format!("synthetic{}", "\u{1}".repeat(4000));
    s.write_context("app", "a-huge", "note", &huge, false)
        .unwrap();
    for n in 0..12 {
        s.write_context(
            "app",
            &format!("b{n:02}"),
            "note",
            "synthetic synthetic",
            false,
        )
        .unwrap();
    }
    assert_eq!(
        s.contexts_bound("app", &binding(&p), &token()).unwrap(),
        s.contexts("app").unwrap()
    );
    assert_eq!(
        s.context_bound("app", "memo", &binding(&p), &token())
            .unwrap(),
        s.context("app", "memo").unwrap()
    );
    assert!(
        s.context_bound("app", "forgotten", &binding(&p), &token())
            .is_err()
    );
    assert_eq!(
        s.context_bound("app", "retired", &binding(&p), &token())
            .unwrap()["history"][1]["retired"],
        true
    );
    let result = s
        .search_context_bound("app", "synthetic", &binding(&p), &token())
        .unwrap();
    assert_eq!(
        result,
        s.search_context("app", "synthetic", &token()).unwrap()
    );
    assert_eq!(result["matched_entries"], 14);
    assert_eq!(result["results"].as_array().unwrap().len(), 8);
    assert_eq!(result["results"][0]["id"], "b00");
    assert!(serde_json::to_vec(&result).unwrap().len() < 8192);
    for _ in 2..32 {
        s.write_context("app", "memo", "note", "synthetic revision", true)
            .unwrap();
    }
    assert_eq!(
        s.context_bound("app", "memo", &binding(&p), &token())
            .unwrap()["history"]
            .as_array()
            .unwrap()
            .len(),
        32
    );
    s.db.execute(
        "INSERT INTO context VALUES('app','memo',33,'note','synthetic overflow',0)",
        [],
    )
    .unwrap();
    assert!(
        s.context_bound("app", "memo", &binding(&p), &token())
            .is_err()
    );
    assert!(s.contexts_bound("app", &binding(&p), &token()).is_err());
    assert!(
        s.search_context_bound("app", "synthetic", &binding(&p), &token())
            .is_err()
    );
}

#[test]
fn cancellation_validation_and_dependency_failure_publish_nothing() {
    let f = Fixture::new();
    let s = f.registered();
    let p = s.project("app").unwrap();
    let cancel = AtomicBool::new(true);
    assert!(matches!(
        s.contexts_bound("app", &binding(&p), &cancel),
        Err(Error::Canceled)
    ));
    assert!(matches!(
        s.context_bound("app", "memo", &binding(&p), &cancel),
        Err(Error::Canceled)
    ));
    assert!(matches!(
        s.search_context_bound("app", "synthetic", &binding(&p), &cancel),
        Err(Error::Canceled)
    ));
    for query in ["", "\n", "x\ty", &"é".repeat(129)] {
        assert!(
            s.search_context_bound("app", query, &binding(&p), &token())
                .is_err()
        );
    }
    assert!(
        s.context_bound("app", "../bad", &binding(&p), &token())
            .is_err()
    );
    let cancel = token();
    assert!(matches!(
        s.read_human_bound("app", &binding(&p), &cancel, |tx, _| {
            let value = Store::context_in(tx, "app", "memo")?;
            cancel.store(true, Ordering::SeqCst);
            Ok(value)
        }),
        Err(Error::Canceled)
    ));
    s.db.execute("DROP TABLE context", []).unwrap();
    assert!(all(&s, &binding(&p)).iter().all(Result::is_err));
}

#[test]
fn bound_search_byte_budget_cancellation_and_project_row_limit() {
    let f = Fixture::new();
    let mut s = f.registered();
    let p = s.project("app").unwrap();
    s.retire_context("app", "memo").unwrap();
    let text = format!("synthetic{}", "界".repeat(1300));
    for id in ["a", "b", "c"] {
        s.write_context("app", id, "note", &text, false).unwrap();
    }
    let result = s
        .search_context_bound("app", "synthetic", &binding(&p), &token())
        .unwrap();
    assert_eq!(result["matched_entries"], 3);
    assert_eq!(result["omitted_entries"], 2);
    assert_eq!(result["results"].as_array().unwrap().len(), 1);
    assert_eq!(result["results"][0]["text"], text);
    assert!(serde_json::to_vec(&result).unwrap().len() < 8192);
    for at in [1, 2] {
        let cancel = token();
        let mut n = 0;
        let result = s.read_human_bound("app", &binding(&p), &cancel, |tx, registration| {
            s.search_context_in(tx, registration, "synthetic", &cancel, || {
                n += 1;
                if n == at {
                    cancel.store(true, Ordering::SeqCst);
                }
            })
        });
        assert!(matches!(result, Err(Error::Canceled)));
    }
    s.db.execute_batch("WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM n WHERE i<4097) INSERT INTO context SELECT 'app','overflow'||i,1,'note','synthetic',0 FROM n;").unwrap();
    assert!(s.contexts_bound("app", &binding(&p), &token()).is_err());
    assert!(
        s.search_context_bound("app", "synthetic", &binding(&p), &token())
            .is_err()
    );
}
