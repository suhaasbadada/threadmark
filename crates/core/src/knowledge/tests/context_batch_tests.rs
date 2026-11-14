//! AI-01..08: actual SQLite and bounded atomic human-history fixtures.
use super::*;

fn binding(p: &Project) -> ContextReadBinding<'_> {
    ContextReadBinding {
        root: &p.root,
        root_identity: &p.root_identity,
        incarnation: p.incarnation.as_deref().unwrap(),
    }
}
fn request(n: usize, revision: u32) -> ContextBatchEdit {
    ContextBatchEdit {
        version: "human-context-batch-edit-v1".into(),
        actions: (0..n)
            .map(|i| {
                if i % 2 == 0 {
                    ContextBatchAction::Update {
                        id: format!("n{i}"),
                        expected_revision: revision,
                        kind: "decision".into(),
                        text: "synthetic edited".into(),
                    }
                } else {
                    ContextBatchAction::Retire {
                        id: format!("n{i}"),
                        expected_revision: revision,
                    }
                }
            })
            .collect(),
    }
}
fn setup(n: usize) -> (Fixture, Store, Project) {
    let f = Fixture::new();
    let mut s = f.registered();
    for i in 0..n {
        s.write_context("a", &format!("n{i}"), "note", "synthetic original", false)
            .unwrap();
    }
    let p = s.project("a").unwrap();
    (f, s, p)
}
fn histories(s: &Store, n: usize) -> Vec<Value> {
    (0..n)
        .map(|i| s.context("a", &format!("n{i}")).unwrap())
        .collect()
}

#[test]
fn mixed_two_through_eight_reopen_retire_and_explicit_reactivation() {
    for n in 2..=8 {
        let (f, mut s, p) = setup(n);
        let receipt = s
            .edit_context_batch_bound("a", &binding(&p), &request(n, 1), &token(), |_| {})
            .unwrap();
        assert!(serde_json::to_vec(&receipt).unwrap().len() < 8192);
        assert!(!receipt.to_string().contains("synthetic"));
        drop(s);
        let mut s = f.store();
        for (i, history) in histories(&s, n).iter().enumerate() {
            assert_eq!(history["history"][1]["retired"], i % 2 == 1);
            assert_eq!(
                history["history"][1]["text"],
                if i % 2 == 0 {
                    "synthetic edited"
                } else {
                    "synthetic original"
                }
            );
        }
        let mut req = request(n, 2);
        for (i, action) in req.actions.iter_mut().enumerate() {
            *action = ContextBatchAction::Update {
                id: format!("n{i}"),
                expected_revision: 2,
                kind: "note".into(),
                text: "synthetic reactivated".into(),
            };
        }
        s.edit_context_batch_bound("a", &binding(&p), &req, &token(), |_| {})
            .unwrap();
        for h in histories(&s, n) {
            assert_eq!(h["history"][2]["retired"], false);
        }
    }
}

#[test]
fn peer_revision_in_any_position_rejects_every_append() {
    for i in 0..8 {
        let (f, mut s, p) = setup(8);
        let mut peer = f.store();
        peer.write_context("a", &format!("n{i}"), "note", "synthetic peer", true)
            .unwrap();
        let before = histories(&peer, 8);
        assert_eq!(
            s.edit_context_batch_bound("a", &binding(&p), &request(8, 1), &token(), |_| {}),
            Err(Error::ScopeMismatch)
        );
        assert_eq!(histories(&peer, 8), before);
    }
}

#[test]
fn action_order_preserved_while_receipt_is_canonical_and_preflight_cancel_stages_nothing() {
    let (_f, mut s, p) = setup(8);
    let mut req = request(8, 1);
    req.actions.reverse();
    let before = histories(&s, 8);
    let mut stages = Vec::new();
    let cancel = AtomicBool::new(true);
    assert_eq!(
        s.edit_context_batch_bound("a", &binding(&p), &req, &cancel, |stage| stages.push(stage)),
        Err(Error::Canceled)
    );
    assert!(stages.is_empty());
    assert_eq!(histories(&s, 8), before);
    let receipt = s
        .edit_context_batch_bound("a", &binding(&p), &req, &token(), |stage| {
            stages.push(stage)
        })
        .unwrap();
    assert_eq!(receipt["actions"][0]["id"], "n0");
    assert_eq!(receipt["actions"][7]["id"], "n7");
    assert_eq!(stages.len(), 9);
    assert_eq!(stages[0], ContextBatchStage::AppendStaged(1));
    assert_eq!(stages[8], ContextBatchStage::ReadyToCommit);
}

#[test]
fn actual_simultaneous_batch_and_single_cas_cannot_both_accept_base() {
    let (f, mut s, p) = setup(8);
    let mut peer = f.store();
    let q = peer.project("a").unwrap();
    let barrier = std::sync::Arc::new(std::sync::Barrier::new(2));
    let b = barrier.clone();
    let child = std::thread::spawn(move || {
        b.wait();
        peer.update_context_revision_bound(
            "a",
            "n7",
            "note",
            "synthetic peer",
            &ContextRevisionBinding {
                root: &q.root,
                root_identity: &q.root_identity,
                incarnation: q.incarnation.as_deref().unwrap(),
                revision: 1,
            },
            &token(),
        )
    });
    barrier.wait();
    let batch = s.edit_context_batch_bound("a", &binding(&p), &request(8, 1), &token(), |_| {});
    let single = child.join().unwrap();
    assert_eq!(usize::from(batch.is_ok()) + usize::from(single.is_ok()), 1);
    let h = histories(&s, 8);
    for item in h.iter().take(7) {
        assert_eq!(
            item["history"].as_array().unwrap().len(),
            if batch.is_ok() { 2 } else { 1 }
        );
    }
}

#[test]
fn cancellation_after_each_append_and_ready_rolls_back_all() {
    for boundary in 1..=9 {
        let (_f, mut s, p) = setup(8);
        let before = histories(&s, 8);
        let cancel = token();
        let result =
            s.edit_context_batch_bound("a", &binding(&p), &request(8, 1), &cancel, |stage| {
                if stage == ContextBatchStage::AppendStaged(boundary)
                    || (boundary == 9 && stage == ContextBatchStage::ReadyToCommit)
                {
                    cancel.store(true, Ordering::SeqCst);
                }
            });
        assert_eq!(result, Err(Error::Canceled));
        assert_eq!(histories(&s, 8), before);
        s.edit_context_batch_bound("a", &binding(&p), &request(8, 1), &token(), |_| {})
            .unwrap();
    }
}

#[test]
fn sql_abort_on_second_append_and_capacity_failure_preserve_every_history() {
    for capacity in [false, true] {
        let (_f, mut s, p) = setup(8);
        let before = histories(&s, 8);
        if !capacity {
            s.db.execute_batch("CREATE TEMP TRIGGER fail_batch BEFORE INSERT ON context WHEN NEW.id='n1' AND NEW.revision=2 BEGIN SELECT RAISE(ABORT,'synthetic'); END;").unwrap();
        } else {
            let pages: i64 =
                s.db.query_row("PRAGMA page_count", [], |r| r.get(0))
                    .unwrap();
            s.db.pragma_update(None, "max_page_count", pages).unwrap();
            s.db.execute_batch("CREATE TEMP TRIGGER fill_batch BEFORE INSERT ON context WHEN NEW.id='n1' AND NEW.revision=2 BEGIN INSERT INTO context VALUES('a','capacity',1,'note',zeroblob(1000000),0); END;").unwrap();
        }
        let mut staged = 0;
        let result =
            s.edit_context_batch_bound("a", &binding(&p), &request(8, 1), &token(), |stage| {
                if let ContextBatchStage::AppendStaged(n) = stage {
                    staged = n;
                }
            });
        assert!(result.is_err());
        assert_eq!(staged, 1);
        assert_eq!(histories(&s, 8), before);
    }
}

#[test]
fn binding_precedes_human_sql_even_with_dropped_tables_and_unicode_byte_mismatch() {
    let (_f, mut s, p) = setup(2);
    s.db.execute_batch("DROP TABLE context; DROP TABLE forgotten_context;")
        .unwrap();
    for root in [
        format!("{}x", p.root),
        format!("{}/é", p.root),
        format!("{}/e\u{301}", p.root),
    ] {
        let b = ContextReadBinding {
            root: &root,
            ..binding(&p)
        };
        assert_eq!(
            s.edit_context_batch_bound("a", &b, &request(2, 1), &token(), |_| {}),
            Err(Error::ScopeMismatch)
        );
    }
    s.db.execute(
        "UPDATE projects SET root='/synthetic/é',root_identity='identity-é' WHERE id='a'",
        [],
    )
    .unwrap();
    for (root, identity) in [
        ("/synthetic/e\u{301}", "identity-é"),
        ("/synthetic/é", "identity-e\u{301}"),
    ] {
        let b = ContextReadBinding {
            root,
            root_identity: identity,
            incarnation: p.incarnation.as_deref().unwrap(),
        };
        assert_eq!(
            s.edit_context_batch_bound("a", &b, &request(2, 1), &token(), |_| {}),
            Err(Error::ScopeMismatch)
        );
    }
}

#[test]
fn malformed_old_history_max_revision_and_whole_project_budget_reject_before_append() {
    for mode in ["history", "revision", "quota"] {
        let (_f, mut s, p) = setup(8);
        let mut req = request(8, 1);
        match mode {
            "history" => {
                s.write_context("a", "n7", "note", "synthetic latest", true)
                    .unwrap();
                req.actions[7] = ContextBatchAction::Retire {
                    id: "n7".into(),
                    expected_revision: 2,
                };
                s.db.execute(
                    "UPDATE context SET text='' WHERE id='n7' AND revision=1",
                    [],
                )
                .unwrap();
            }
            "revision" => {
                for _ in 1..32 {
                    s.write_context("a", "n7", "note", "synthetic", true)
                        .unwrap();
                }
                req.actions[7] = ContextBatchAction::Retire {
                    id: "n7".into(),
                    expected_revision: 32,
                };
            }
            _ => {
                s.db.execute_batch("WITH RECURSIVE n(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM n WHERE x<4081) INSERT INTO context SELECT 'a','extra'||x,1,'note','synthetic',0 FROM n;").unwrap();
            }
        }
        let count: i64 =
            s.db.query_row("SELECT count(*) FROM context", [], |r| r.get(0))
                .unwrap();
        assert!(
            s.edit_context_batch_bound("a", &binding(&p), &req, &token(), |_| {})
                .is_err()
        );
        assert_eq!(
            s.db.query_row("SELECT count(*) FROM context", [], |r| r.get::<_, i64>(0))
                .unwrap(),
            count
        );
        assert_eq!(
            s.context("a", "n0").unwrap()["history"]
                .as_array()
                .unwrap()
                .len(),
            1
        );
    }
}

#[test]
fn forget_any_of_eight_blocks_batch_without_resurrection() {
    for i in 0..8 {
        let (_f, mut s, p) = setup(8);
        s.forget_context("a", &format!("n{i}"), &token()).unwrap();
        let before = s.export_project("a", &token()).unwrap();
        assert!(
            s.edit_context_batch_bound("a", &binding(&p), &request(8, 1), &token(), |_| {})
                .is_err()
        );
        assert_eq!(s.export_project("a", &token()).unwrap(), before);
    }
}

#[test]
fn replacement_nonce_different_root_identity_and_legacy_are_not_admitted() {
    for same in [true, false] {
        let (_f, mut s, p) = setup(2);
        let replacement = Fixture::new();
        s.remove_project("a", &token()).unwrap();
        let replacement_root = replacement.source();
        s.add_project(
            "a",
            if same {
                Path::new(&p.root)
            } else {
                &replacement_root
            },
            vec!["code.rs".into()],
        )
        .unwrap();
        for id in ["n0", "n1"] {
            s.write_context("a", id, "note", "synthetic replacement", false)
                .unwrap();
        }
        let before = histories(&s, 2);
        assert_eq!(
            s.edit_context_batch_bound("a", &binding(&p), &request(2, 1), &token(), |_| {}),
            Err(Error::ScopeMismatch)
        );
        let q = s.project("a").unwrap();
        let bad = ContextReadBinding {
            root_identity: "synthetic-mismatch",
            ..binding(&q)
        };
        assert_eq!(
            s.edit_context_batch_bound("a", &bad, &request(2, 1), &token(), |_| {}),
            Err(Error::ScopeMismatch)
        );
        assert_eq!(histories(&s, 2), before);
    }
    for version in [1, 2] {
        let (_f, mut s) = forget_tests::v1_fixture();
        if version == 2 {
            s.upgrade(&token()).unwrap();
        }
        let p = s.project("a").unwrap();
        let b = ContextReadBinding {
            root: &p.root,
            root_identity: &p.root_identity,
            incarnation: "0123456789abcdef0123456789abcdef",
        };
        assert_eq!(
            s.edit_context_batch_bound("a", &b, &request(2, 1), &token(), |_| {}),
            Err(Error::ScopeMismatch)
        );
        assert_eq!(schema::version(&s.db).unwrap(), version);
    }
}

#[test]
fn missing_root_invalid_source_policy_and_missing_snapshot_do_not_authorize_or_block_human_edits() {
    let (f, mut s, p) = setup(2);
    s.db.execute(
        "UPDATE projects SET sources='malformed unrelated source policy' WHERE id='a'",
        [],
    )
    .unwrap();
    let moved = f.0.join("moved-source");
    std::fs::rename(f.source(), &moved).unwrap();
    let bytes = std::fs::read(moved.join("code.rs")).unwrap();
    s.edit_context_batch_bound("a", &binding(&p), &request(2, 1), &token(), |_| {})
        .unwrap();
    assert_eq!(std::fs::read(moved.join("code.rs")).unwrap(), bytes);
    assert_eq!(
        s.context_bound("a", "n0", &binding(&p), &token()).unwrap()["history"]
            .as_array()
            .unwrap()
            .len(),
        2
    );
}

#[test]
fn build_source_forget_other_projects_and_dependency_failure_preserve_human_scope() {
    let (f, mut s, p) = setup(8);
    let other = Fixture::new();
    s.add_project("b", &other.source(), vec!["code.rs".into()])
        .unwrap();
    s.write_context("b", "n0", "note", "synthetic other", false)
        .unwrap();
    index(&mut s);
    let other_before = s.export_project("b", &token()).unwrap();
    let source = std::fs::read(f.source().join("code.rs")).unwrap();
    s.edit_context_batch_bound("a", &binding(&p), &request(8, 1), &token(), |_| {})
        .unwrap();
    let h = histories(&s, 8);
    index(&mut s);
    assert_eq!(histories(&s, 8), h);
    s.upgrade_to_with_progress(4, &token(), |_| {}).unwrap();
    s.forget_source("a", "code.rs", &token()).unwrap();
    assert_eq!(histories(&s, 8), h);
    assert_eq!(s.export_project("b", &token()).unwrap(), other_before);
    assert_eq!(std::fs::read(f.source().join("code.rs")).unwrap(), source);
    s.db.execute_batch("DROP TABLE forgotten_context;").unwrap();
    let mut staged = false;
    assert!(
        s.edit_context_batch_bound("a", &binding(&p), &request(8, 2), &token(), |_| {
            staged = true;
        })
        .is_err()
    );
    assert!(!staged);
    assert_eq!(
        s.db.query_row("SELECT count(*) FROM context WHERE project='a'", [], |r| {
            r.get::<_, i64>(0)
        })
        .unwrap(),
        16
    );
}

#[test]
fn batch_transaction_child() {
    use std::io::Write;
    let Some(path) = std::env::var_os("THREADMARK_SYNTHETIC_BATCH_CHILD") else {
        return;
    };
    let mut s = Store::open_existing(Path::new(&path)).unwrap();
    let p = s.project("a").unwrap();
    s.edit_context_batch_bound("a", &binding(&p), &request(8, 1), &token(), |stage| {
        if stage == ContextBatchStage::AppendStaged(1) {
            println!("batch-staged");
            std::io::stdout().flush().unwrap();
            std::io::stdin().read_exact(&mut [0]).unwrap();
        }
    })
    .unwrap();
}

#[test]
fn killed_owned_child_after_first_staging_recovers_all_old_rows_and_fresh_batch_succeeds() {
    use std::io::BufRead;
    use std::process::{Command, Stdio};
    let (f, mut s, p) = setup(8);
    index(&mut s);
    s.write_context("a", "untouched", "note", "synthetic untouched", false)
        .unwrap();
    let before = s.export_project("a", &token()).unwrap();
    let source = std::fs::read(f.source().join("code.rs")).unwrap();
    drop(s);
    let mut child = Command::new(std::env::current_exe().unwrap())
        .args([
            "--exact",
            "knowledge::tests::context_batch_tests::batch_transaction_child",
            "--nocapture",
        ])
        .env(
            "THREADMARK_SYNTHETIC_BATCH_CHILD",
            f.0.join("private-store"),
        )
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let held = child.stdin.take().unwrap();
    let stdout = child.stdout.take().unwrap();
    let (tx, rx) = std::sync::mpsc::channel();
    let reader = std::thread::spawn(move || {
        let mut input = std::io::BufReader::new(stdout);
        let mut found = false;
        for _ in 0..10 {
            let mut line = String::new();
            if input.read_line(&mut line).unwrap() == 0 {
                break;
            }
            if line.trim() == "batch-staged" {
                found = true;
                break;
            }
        }
        let _ = tx.send(found);
    });
    let staged = rx.recv_timeout(std::time::Duration::from_secs(10));
    child.kill().unwrap();
    assert!(!child.wait().unwrap().success());
    drop(held);
    reader.join().unwrap();
    assert_eq!(staged, Ok(true));
    let mut s = f.store();
    assert_eq!(s.export_project("a", &token()).unwrap(), before);
    assert_eq!(std::fs::read(f.source().join("code.rs")).unwrap(), source);
    s.edit_context_batch_bound("a", &binding(&p), &request(8, 1), &token(), |_| {})
        .unwrap();
    assert_eq!(
        s.context("a", "untouched").unwrap()["history"]
            .as_array()
            .unwrap()
            .len(),
        1
    );
}
