//! Synthetic actual SQLite CAS acceptance: partial P2-A1/A3 and P3-A4.
use super::*;

fn binding(p: &Project, revision: u32) -> ContextRevisionBinding<'_> {
    ContextRevisionBinding {
        root: &p.root,
        root_identity: &p.root_identity,
        incarnation: p.incarnation.as_deref().unwrap(),
        revision,
    }
}

fn mutate(s: &mut Store, p: &Project, revision: u32, retire: bool) -> Result<()> {
    if retire {
        s.retire_context_revision_bound(&p.id, "note", &binding(p, revision), &token())
    } else {
        s.update_context_revision_bound(
            &p.id,
            "note",
            "decision",
            "synthetic guarded",
            &binding(p, revision),
            &token(),
        )
    }
}

#[test]
fn two_connections_stale_update_and_retire_append_nothing_fresh_appends_exactly_one() {
    for retire in [false, true] {
        let f = Fixture::new();
        let mut first = f.registered();
        first
            .write_context("a", "note", "note", "synthetic original", false)
            .unwrap();
        let p = first.project("a").unwrap();
        let mut peer = f.store();
        peer.write_context("a", "note", "constraint", "synthetic peer", true)
            .unwrap();
        let before = peer.context("a", "note").unwrap();
        assert_eq!(mutate(&mut first, &p, 1, retire), Err(Error::ScopeMismatch));
        assert_eq!(first.context("a", "note").unwrap(), before);
        mutate(&mut first, &p, 2, retire).unwrap();
        let after = peer.context("a", "note").unwrap();
        assert_eq!(after["history"].as_array().unwrap().len(), 3);
        assert_eq!(after["history"][2]["revision"], 3);
        assert_eq!(after["history"][2]["retired"], retire);
        assert_eq!(
            after["history"][2]["text"],
            if retire {
                "synthetic peer"
            } else {
                "synthetic guarded"
            }
        );
        assert_eq!(mutate(&mut first, &p, 2, retire), Err(Error::ScopeMismatch));
        drop(first);
        assert_eq!(f.store().context("a", "note").unwrap(), after);
    }
}

#[test]
fn simultaneous_expected_revision_writers_publish_only_one_append() {
    let f = Fixture::new();
    let mut first = f.registered();
    first
        .write_context("a", "note", "note", "synthetic original", false)
        .unwrap();
    let p = first.project("a").unwrap();
    let mut second = f.store();
    let peer_project = second.project("a").unwrap();
    let barrier = std::sync::Arc::new(std::sync::Barrier::new(2));
    let peer_barrier = barrier.clone();
    let peer = std::thread::spawn(move || {
        peer_barrier.wait();
        mutate(&mut second, &peer_project, 1, true)
    });
    barrier.wait();
    let update = mutate(&mut first, &p, 1, false);
    let retire = peer.join().unwrap();
    assert_eq!(usize::from(update.is_ok()) + usize::from(retire.is_ok()), 1);
    assert_eq!(
        if update.is_err() { update } else { retire },
        Err(Error::ScopeMismatch)
    );
    let after = first.context("a", "note").unwrap();
    assert_eq!(after["history"].as_array().unwrap().len(), 2);
    assert_eq!(after["history"][1]["retired"], retire.is_ok());
}

#[test]
fn registration_and_revision_are_rechecked_together_after_captured_policy() {
    for retire in [false, true] {
        for replacement in ["same-root", "different-root"] {
            let f = Fixture::new();
            let mut s = f.registered();
            s.write_context("a", "note", "note", "synthetic old", false)
                .unwrap();
            let p = s.project("a").unwrap();
            let mut peer = f.store();
            peer.remove_project("a", &token()).unwrap();
            let other = Fixture::new();
            let root = if replacement == "same-root" {
                f.source()
            } else {
                other.source()
            };
            peer.add_project("a", &root, vec!["code.rs".into()])
                .unwrap();
            peer.write_context("a", "note", "note", "synthetic replacement", false)
                .unwrap();
            let before = peer.context("a", "note").unwrap();
            assert_eq!(mutate(&mut s, &p, 1, retire), Err(Error::ScopeMismatch));
            // Bypass public preflight to exercise the actual captured-policy
            // transaction boundary, including identical root + revision reuse.
            let result = if retire {
                s.retire_context_guarded(&p, "note", Some((1, &token())))
            } else {
                s.write_context_guarded(
                    &p,
                    "note",
                    "note",
                    "synthetic stale",
                    true,
                    Some((1, &token())),
                )
            };
            assert_eq!(result, Err(Error::ScopeMismatch));
            assert_eq!(s.context("a", "note").unwrap(), before);
        }
    }
}

#[test]
fn wrong_namespace_fields_and_similarly_named_projects_never_mutate_peer_history() {
    let f = Fixture::new();
    let mut s = f.registered();
    let other = Fixture::new();
    s.add_project("a-copy", &other.source(), vec!["code.rs".into()])
        .unwrap();
    for id in ["a", "a-copy"] {
        s.write_context(id, "note", "note", "synthetic scoped", false)
            .unwrap();
    }
    let p = s.project("a").unwrap();
    let q = s.project("a-copy").unwrap();
    let before = s.context("a-copy", "note").unwrap();
    for field in ["project", "root", "identity", "incarnation"] {
        let mut bad = binding(&q, 1);
        match field {
            "root" => bad.root = &p.root,
            "identity" => bad.root_identity = &p.root_identity,
            "incarnation" => bad.incarnation = p.incarnation.as_deref().unwrap(),
            _ => bad = binding(&p, 1),
        }
        assert_eq!(
            s.update_context_revision_bound(
                "a-copy",
                "note",
                "note",
                "synthetic denied",
                &bad,
                &token()
            ),
            Err(Error::ScopeMismatch)
        );
        assert_eq!(
            s.retire_context_revision_bound("a-copy", "note", &bad, &token()),
            Err(Error::ScopeMismatch)
        );
    }
    mutate(&mut s, &p, 1, false).unwrap();
    assert_eq!(s.context("a-copy", "note").unwrap(), before);
    // Source policy is not human-history scope. Revocation cannot be widened
    // by an edit; independent human text remains editable in this namespace.
    s.set_sources("a", vec![]).unwrap();
    mutate(&mut s, &p, 2, false).unwrap();
    assert!(s.project("a").unwrap().sources.is_empty());
}

#[test]
fn retire_reactivate_forget_rebuild_and_restart_preserve_history_and_suppression() {
    let f = Fixture::new();
    let mut s = f.registered();
    let source = std::fs::read(f.source().join("code.rs")).unwrap();
    s.write_context("a", "note", "note", "synthetic original", false)
        .unwrap();
    let p = s.project("a").unwrap();
    mutate(&mut s, &p, 1, true).unwrap();
    assert_eq!(
        s.search_context("a", "synthetic", &token()).unwrap()["matched_entries"],
        0
    );
    assert_eq!(mutate(&mut s, &p, 1, false), Err(Error::ScopeMismatch));
    mutate(&mut s, &p, 2, false).unwrap();
    assert_eq!(
        s.context("a", "note").unwrap()["history"][2]["retired"],
        false
    );
    index(&mut s);
    assert_eq!(
        s.context("a", "note").unwrap()["history"]
            .as_array()
            .unwrap()
            .len(),
        3
    );
    s.forget_context("a", "note", &token()).unwrap();
    for retire in [false, true] {
        assert!(mutate(&mut s, &p, 3, retire).is_err());
    }
    assert!(
        s.write_context_bound(
            "a",
            (&p.root, &p.root_identity, p.incarnation.as_deref().unwrap()),
            "note",
            "note",
            "synthetic denied",
            false
        )
        .is_err()
    );
    drop(s);
    let mut s = f.store();
    index(&mut s);
    assert!(s.context("a", "note").is_err());
    assert_eq!(
        s.forgotten_contexts("a").unwrap()["forgotten"],
        json!([{"id":"note"}])
    );
    assert_eq!(std::fs::read(f.source().join("code.rs")).unwrap(), source);
}

#[test]
fn bounds_missing_ids_and_legacy_forms_preserve_existing_semantics() {
    let f = Fixture::new();
    let mut s = f.registered();
    let p = s.project("a").unwrap();
    for retire in [false, true] {
        assert!(mutate(&mut s, &p, 1, retire).is_err());
        for invalid in [0, 33, u32::MAX] {
            assert!(mutate(&mut s, &p, invalid, retire).is_err());
        }
    }
    assert_eq!(project_rows(&s, "a")[2], 0);
    s.write_context_bound(
        "a",
        (&p.root, &p.root_identity, p.incarnation.as_deref().unwrap()),
        "note",
        "note",
        "synthetic",
        false,
    )
    .unwrap();
    assert!(
        s.write_context("a", "note", "note", "synthetic duplicate add", false)
            .is_err()
    );
    s.write_context_bound(
        "a",
        (&p.root, &p.root_identity, p.incarnation.as_deref().unwrap()),
        "note",
        "note",
        "synthetic legacy edit",
        true,
    )
    .unwrap();
    s.retire_context_bound(
        "a",
        (&p.root, &p.root_identity, p.incarnation.as_deref().unwrap()),
        "note",
    )
    .unwrap();
    s.write_context("a", "note", "note", "synthetic trusted", true)
        .unwrap();
    s.retire_context("a", "note").unwrap();
    for revision in 5..32 {
        mutate(&mut s, &p, revision, false).unwrap();
    }
    for retire in [false, true] {
        assert!(mutate(&mut s, &p, 32, retire).is_err());
    }
    assert_eq!(
        s.context("a", "note").unwrap()["history"]
            .as_array()
            .unwrap()
            .len(),
        32
    );
}

#[test]
fn full_project_budget_and_sql_failure_roll_back_guarded_appends() {
    for retire in [false, true] {
        let f = Fixture::new();
        let mut s = f.registered();
        s.write_context("a", "note", "note", "synthetic original", false)
            .unwrap();
        let p = s.project("a").unwrap();
        s.db.execute_batch("CREATE TEMP TRIGGER synthetic_fail AFTER INSERT ON context BEGIN SELECT RAISE(ABORT,'synthetic'); END;").unwrap();
        let before = s.context("a", "note").unwrap();
        assert!(mutate(&mut s, &p, 1, retire).is_err());
        assert_eq!(s.context("a", "note").unwrap(), before);
        s.db.execute_batch("DROP TRIGGER synthetic_fail;").unwrap();
        // Fill real table cheaply, keeping the target revision appendable.
        let tx = s.db.transaction().unwrap();
        for n in 1..4096 {
            tx.execute(
                "INSERT INTO context VALUES('a',?1,1,'note','synthetic',0)",
                [format!("n{n}")],
            )
            .unwrap();
        }
        tx.commit().unwrap();
        assert!(mutate(&mut s, &p, 1, retire).is_err());
        assert_eq!(s.context("a", "note").unwrap(), before);
        assert_eq!(project_rows(&s, "a")[2], 4096);
    }
}

#[test]
fn cancellation_after_real_append_rolls_back_and_connection_recovers() {
    for retire in [false, true] {
        let f = Fixture::new();
        let mut s = f.registered();
        s.write_context("a", "note", "note", "synthetic original", false)
            .unwrap();
        let p = s.project("a").unwrap();
        let before = s.context("a", "note").unwrap();
        let cancel = std::sync::Arc::new(token());
        let hook_cancel = cancel.clone();
        context_revision::BEFORE_COMMIT.with_borrow_mut(|hook| {
            *hook = Some(Box::new(move || hook_cancel.store(true, Ordering::SeqCst)))
        });
        let result = if retire {
            s.retire_context_revision_bound("a", "note", &binding(&p, 1), &cancel)
        } else {
            s.update_context_revision_bound(
                "a",
                "note",
                "note",
                "synthetic canceled",
                &binding(&p, 1),
                &cancel,
            )
        };
        assert_eq!(result, Err(Error::Canceled));
        assert_eq!(s.context("a", "note").unwrap(), before);
        mutate(&mut s, &p, 1, retire).unwrap();
    }
}

#[test]
fn revision_transaction_child() {
    use std::io::Write;
    let Some(path) = std::env::var_os("THREADMARK_SYNTHETIC_REVISION_CHILD") else {
        return;
    };
    let mut s = Store::open_existing(Path::new(&path)).unwrap();
    let p = s.project("a").unwrap();
    context_revision::BEFORE_COMMIT.with_borrow_mut(|hook| {
        *hook = Some(Box::new(|| {
            println!("revision-staged");
            std::io::stdout().flush().unwrap();
            let _ = std::io::stdin().read_exact(&mut [0]);
        }))
    });
    mutate(
        &mut s,
        &p,
        1,
        std::env::var_os("THREADMARK_SYNTHETIC_RETIRE").is_some(),
    )
    .unwrap();
}

#[test]
fn killed_guarded_append_recovers_previous_human_history() {
    use std::io::BufRead;
    use std::process::{Command, Stdio};
    for retire in [false, true] {
        let f = Fixture::new();
        let mut s = f.registered();
        s.write_context("a", "note", "note", "synthetic original", false)
            .unwrap();
        let before = s.context("a", "note").unwrap();
        drop(s);
        let mut command = Command::new(std::env::current_exe().unwrap());
        command
            .args([
                "--exact",
                "knowledge::tests::context_revision_tests::revision_transaction_child",
                "--nocapture",
            ])
            .env(
                "THREADMARK_SYNTHETIC_REVISION_CHILD",
                f.0.join("private-store"),
            )
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        if retire {
            command.env("THREADMARK_SYNTHETIC_RETIRE", "1");
        }
        let mut child = command.spawn().unwrap();
        let held_stdin = child.stdin.take().unwrap();
        let mut reader = std::io::BufReader::new(child.stdout.take().unwrap());
        let mut staged = false;
        for _ in 0..10 {
            let mut line = String::new();
            if reader.read_line(&mut line).unwrap() == 0 {
                break;
            }
            if line.trim() == "revision-staged" {
                staged = true;
                break;
            }
        }
        child.kill().unwrap();
        assert!(!child.wait().unwrap().success());
        drop(held_stdin);
        assert!(staged);
        assert_eq!(f.store().context("a", "note").unwrap(), before);
    }
}
