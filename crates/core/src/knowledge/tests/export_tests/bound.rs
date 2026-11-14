//! Captured approval is checked against the SQL Project before root/source I/O.
use super::*;

#[test]
fn every_binding_field_fails_before_first_root_or_source_access() {
    let f = Fixture::new();
    let mut s = f.registered();
    index(&mut s);
    for field in [
        "id", "root", "identity", "nonce", "policy", "snapshot", "none",
    ] {
        let mut p = s.project("a").unwrap();
        match field {
            "id" => p.id = "b".into(),
            "root" => p.root.push_str("/different"),
            "identity" => p.root_identity = "0:0".into(),
            "nonce" => p.incarnation = Some("0".repeat(32)),
            "policy" => p.sources.clear(),
            "snapshot" => p.snapshot = Some("0".repeat(64)),
            "none" => p.snapshot = None,
            _ => unreachable!(),
        }
        assert!(matches!(
            s.export_scoped(
                "a",
                &token(),
                Some(&p),
                || { panic!("mismatched {field} reached root/source access") },
                |_| {}
            ),
            Err(Error::ScopeMismatch)
        ));
    }
    let expected = s.project("a").unwrap();
    // Even inaccessible roots must not mask the metadata mismatch.
    std::fs::rename(f.source(), f.0.join("synthetic-moved-root")).unwrap();
    let mut wrong = s.project("a").unwrap();
    wrong.snapshot = None;
    assert!(matches!(
        s.export_scoped("a", &token(), Some(&wrong), || panic!("root I/O"), |_| {}),
        Err(Error::ScopeMismatch)
    ));
    assert!(s.export_project_bound(&expected, &token()).is_err());
}

#[test]
fn same_id_replacement_at_same_or_different_root_never_crosses_boundary() {
    for same_root in [true, false] {
        let f = Fixture::new();
        let other = Fixture::new();
        let mut s = f.registered();
        index(&mut s);
        let p = s.project("a").unwrap();
        let mut peer = f.store();
        peer.remove_project("a", &token()).unwrap();
        peer.add_project(
            "a",
            &if same_root {
                f.source()
            } else {
                other.source()
            },
            vec!["code.rs".into()],
        )
        .unwrap();
        peer.index("a", &mut LexicalLines, &token()).unwrap();
        assert!(matches!(
            s.export_scoped(
                "a",
                &token(),
                Some(&p),
                || panic!("replacement source I/O"),
                |_| {}
            ),
            Err(Error::ScopeMismatch)
        ));
        assert!(matches!(
            s.export_project_bound(&p, &token()),
            Err(Error::ScopeMismatch)
        ));
    }
}

#[test]
fn bound_export_keeps_reader_lock_after_binding_and_revalidates_before_publish() {
    for operation in ["replace", "revoke", "history", "source", "cancel"] {
        let f = Fixture::new();
        let mut s = f.registered();
        index(&mut s);
        let p = s.project("a").unwrap();
        let before = s.export_project_bound(&p, &token()).unwrap();
        let cancel = token();
        let mut peer = f.store();
        peer.db.busy_timeout(std::time::Duration::ZERO).unwrap();
        let result = s.export_scoped(
            "a",
            &cancel,
            Some(&p),
            || match operation {
                "replace" => assert!(peer.remove_project("a", &token()).is_err()),
                "revoke" => assert!(peer.set_sources("a", vec![]).is_err()),
                "history" => assert!(
                    peer.write_context("a", "memo", "note", "synthetic", false)
                        .is_err()
                ),
                _ => {}
            },
            |stage| {
                if stage == ExportStage::ReadyToPublish {
                    match operation {
                        "source" => {
                            std::fs::write(f.source().join("code.rs"), "synthetic changed\n")
                                .unwrap()
                        }
                        "cancel" => cancel.store(true, Ordering::SeqCst),
                        _ => {}
                    }
                }
            },
        );
        match operation {
            "source" => assert!(matches!(result, Err(Error::ScopeMismatch))),
            "cancel" => assert!(matches!(result, Err(Error::Canceled))),
            _ => assert_eq!(result.unwrap(), before),
        }
        // Reader teardown permits recovery, not a permanent lease.
        peer.set_sources("a", vec![]).unwrap();
        assert!(matches!(
            s.export_project_bound(&p, &token()),
            Err(Error::ScopeMismatch)
        ));
    }
}

#[test]
fn none_empty_policy_unicode_history_forget_and_legacy_keep_v1_semantics() {
    let f = Fixture::new();
    let mut s = f.store();
    let root = f.0.join("synthetic-é");
    std::fs::create_dir(&root).unwrap();
    std::fs::write(root.join("other.rs"), "synthetic λ\n").unwrap();
    std::fs::write(root.join("code.rs"), "synthetic source\n").unwrap();
    s.add_project("a", &root, vec!["other.rs".into(), "code.rs".into()])
        .unwrap();
    index(&mut s);
    let p = s.project("a").unwrap();
    let mut reversed = s.project("a").unwrap();
    reversed.sources.reverse();
    assert!(matches!(
        s.export_project_bound(&reversed, &token()),
        Err(Error::ScopeMismatch)
    ));
    s.write_context("a", "memo", "note", "synthetic λ\t\"", false)
        .unwrap();
    s.write_context("a", "memo", "decision", "synthetic revised", true)
        .unwrap();
    s.retire_context("a", "memo").unwrap();
    assert_eq!(
        s.export_project_bound(&p, &token()).unwrap(),
        s.export_project("a", &token()).unwrap()
    );
    s.forget_context("a", "memo", &token()).unwrap();
    assert_eq!(
        s.export_project_bound(&p, &token()).unwrap()["human_history"],
        json!([])
    );
    s.set_sources("a", vec![]).unwrap();
    let empty = s.project("a").unwrap();
    assert!(empty.snapshot.is_none());
    let archive = s.export_project_bound(&empty, &token()).unwrap();
    assert_eq!(archive, s.export_project("a", &token()).unwrap());
    assert_eq!(archive["evidence"], json!([]));
    assert_eq!(
        std::fs::read_to_string(root.join("other.rs")).unwrap(),
        "synthetic λ\n"
    );
    let (_f, mut legacy) = forget_tests::v1_fixture();
    let old = legacy.project("a").unwrap();
    assert!(legacy.export_project_bound(&old, &token()).is_err());
    assert!(legacy.export_project("a", &token()).is_ok());
    legacy.upgrade_to_v3(&token()).unwrap();
    assert!(legacy.export_project_bound(&old, &token()).is_err());
    assert!(
        legacy
            .export_project_bound(&legacy.project("a").unwrap(), &token())
            .is_ok()
    );
}

#[test]
fn bound_export_preserves_wal_dependency_and_early_cancel_guards() {
    let f = Fixture::new();
    let s = f.registered();
    let p = s.project("a").unwrap();
    assert!(matches!(
        s.export_scoped(
            "a",
            &AtomicBool::new(true),
            Some(&p),
            || panic!("canceled I/O"),
            |_| {}
        ),
        Err(Error::Canceled)
    ));
    s.db.execute_batch("PRAGMA journal_mode=WAL;").unwrap();
    assert!(matches!(
        s.export_scoped("a", &token(), Some(&p), || panic!("WAL I/O"), |_| {}),
        Err(Error::Unavailable)
    ));
    s.db.execute_batch("PRAGMA journal_mode=DELETE; DROP TABLE evidence;")
        .unwrap();
    assert!(s.export_project_bound(&p, &token()).is_err());
}
