//! Synthetic filesystem/SQLite acceptance fixtures. No host or network access.
use super::*;
use std::fs::OpenOptions;
use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt, PermissionsExt, symlink};
use std::sync::atomic::AtomicU64;
mod bound_forget_tests;
mod export_tests;
mod forget_tests;
mod incarnation_tests;

struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        static NEXT: AtomicU64 = AtomicU64::new(0);
        let root = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-core-{}-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::create_dir(&root).unwrap();
        std::fs::create_dir(root.join("source")).unwrap();
        std::fs::write(
            root.join("source/code.rs"),
            "fn alpha() {}\n// synthetic rule blue\n",
        )
        .unwrap();
        Self(root)
    }
    fn store(&self) -> Store {
        Store::open(&self.0.join("private-store")).unwrap()
    }
    fn source(&self) -> PathBuf {
        self.0.join("source")
    }
    fn registered(&self) -> Store {
        let mut store = self.store();
        store
            .add_project("a", &self.source(), vec!["code.rs".into()])
            .unwrap();
        store
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

#[test]
fn bound_removal_rejects_stale_root_and_identity_and_survives_restart() {
    let (f, mut s) = removal_fixture();
    let old = s.project("a").unwrap();
    s.remove_project("a", &token()).unwrap();
    let replacement = Fixture::new();
    s.add_project("a", &replacement.source(), vec!["code.rs".into()])
        .unwrap();
    index(&mut s);
    s.write_context("a", "replacement", "note", "synthetic replacement", false)
        .unwrap();
    let before = project_rows(&s, "a");
    assert!(
        s.remove_project_bound("a", &old.root, &old.root_identity, &token())
            .is_err()
    );
    let current = s.project("a").unwrap();
    assert!(
        s.remove_project_bound("a", &current.root, &old.root_identity, &token())
            .is_err()
    );
    assert_eq!(project_rows(&s, "a"), before);
    assert_eq!(
        s.context("a", "replacement").unwrap()["history"][0]["text"],
        "synthetic replacement"
    );
    drop(s);
    let mut s = f.store();
    s.remove_project_bound("a", &current.root, &current.root_identity, &token())
        .unwrap();
    drop(s);
    assert_eq!(project_rows(&f.store(), "a"), [0, 0, 0]);
    assert!(replacement.source().join("code.rs").is_file());
}

// P2-A1/A3/A5, P3-A3/A4: local removal is isolated, atomic and never Forget.
fn project_rows(store: &Store, id: &str) -> Vec<i64> {
    [
        "SELECT count(*) FROM projects WHERE id=?1",
        "SELECT count(*) FROM evidence WHERE project=?1",
        "SELECT count(*) FROM context WHERE project=?1",
    ]
    .iter()
    .map(|sql| store.db.query_row(sql, [id], |r| r.get(0)).unwrap())
    .collect()
}

fn removal_fixture() -> (Fixture, Store) {
    let f = Fixture::new();
    let mut s = f.registered();
    index(&mut s);
    s.write_context("a", "note", "note", "synthetic first note", false)
        .unwrap();
    s.write_context("a", "note", "decision", "synthetic revised note", true)
        .unwrap();
    s.retire_context("a", "note").unwrap();
    (f, s)
}

#[test]
fn project_removal_survives_reopen_without_touching_sources_or_other_projects() {
    let (f, mut s) = removal_fixture();
    let other = Fixture::new();
    s.add_project("b", &other.source(), vec!["code.rs".into()])
        .unwrap();
    s.index("b", &mut LexicalLines, &token()).unwrap();
    s.write_context("b", "note", "note", "synthetic other note", false)
        .unwrap();
    let source = std::fs::read(f.source().join("code.rs")).unwrap();
    let other_source = std::fs::read(other.source().join("code.rs")).unwrap();
    let other_project = serde_json::to_value(s.project("b").unwrap()).unwrap();
    let other_query = s.query("b", "blue", &token()).unwrap();
    let other_context = s.context("b", "note").unwrap();
    let receipt = s.remove_project("a", &token()).unwrap();
    assert_eq!(receipt["project"], "a");
    assert_eq!(receipt["removed"], true);
    let encoded = serde_json::to_string(&receipt).unwrap();
    assert!(encoded.len() < 1024);
    assert!(!encoded.contains(f.0.to_str().unwrap()));
    assert!(!encoded.contains("synthetic first note"));
    assert_eq!(project_rows(&s, "a"), [0, 0, 0]);
    drop(s);
    let mut s = f.store();
    assert_eq!(project_rows(&s, "a"), [0, 0, 0]);
    assert!(s.project("a").is_err());
    assert!(s.query("a", "blue", &token()).is_err());
    assert!(s.contexts("a").is_err());
    assert!(s.context("a", "note").is_err());
    assert!(s.index("a", &mut LexicalLines, &token()).is_err());
    assert_eq!(
        serde_json::to_value(s.project("b").unwrap()).unwrap(),
        other_project
    );
    assert_eq!(s.query("b", "blue", &token()).unwrap(), other_query);
    assert_eq!(s.context("b", "note").unwrap(), other_context);
    assert_eq!(std::fs::read(f.source().join("code.rs")).unwrap(), source);
    assert_eq!(
        std::fs::read(other.source().join("code.rs")).unwrap(),
        other_source
    );
    // Re-registration is new explicit authorization, not restoration of old edits.
    s.add_project("a", &f.source(), vec!["code.rs".into()])
        .unwrap();
    assert_eq!(project_rows(&s, "a"), [1, 0, 0]);
    assert_eq!(matches(&s, "blue"), 0);
    assert!(s.context("a", "note").is_err());
    index(&mut s);
    assert_eq!(matches(&s, "blue"), 1);
    assert_eq!(project_rows(&s, "a"), [1, 2, 0]);
}

#[test]
fn project_removal_unknown_invalid_canceled_and_sql_abort_preserve_all_rows() {
    let (f, mut s) = removal_fixture();
    let snapshot = serde_json::to_value(s.project("a").unwrap()).unwrap();
    let query = s.query("a", "blue", &token()).unwrap();
    let history = s.context("a", "note").unwrap();
    for id in ["unknown", "", "../a", "a' OR 1=1 --"] {
        assert!(s.remove_project(id, &token()).is_err());
        assert_eq!(project_rows(&s, "a"), [1, 2, 3]);
    }
    assert_eq!(
        s.remove_project("a", &AtomicBool::new(true)),
        Err(Error::Canceled)
    );
    for stop in [
        RemovalStage::EvidenceRemoved,
        RemovalStage::ContextRemoved,
        RemovalStage::ReadyToCommit,
    ] {
        let cancel = token();
        assert_eq!(
            s.remove_project_with_progress("a", &cancel, |stage| {
                if stage == stop {
                    cancel.store(true, Ordering::SeqCst);
                }
            }),
            Err(Error::Canceled)
        );
        assert_eq!(project_rows(&s, "a"), [1, 2, 3]);
    }
    // Abort after both child tables were deleted, proving transaction rollback.
    s.db.execute_batch("CREATE TRIGGER synthetic_remove_fail BEFORE DELETE ON projects BEGIN SELECT RAISE(ABORT,'synthetic'); END;").unwrap();
    assert!(s.remove_project("a", &token()).is_err());
    assert_eq!(project_rows(&s, "a"), [1, 2, 3]);
    s.db.execute_batch("DROP TRIGGER synthetic_remove_fail")
        .unwrap();
    let store_root = f.0.join("private-store");
    std::fs::set_permissions(&store_root, std::fs::Permissions::from_mode(0o755)).unwrap();
    assert!(s.remove_project("a", &token()).is_err());
    std::fs::set_permissions(&store_root, std::fs::Permissions::from_mode(0o700)).unwrap();
    drop(s);
    let mut s = f.store();
    assert_eq!(project_rows(&s, "a"), [1, 2, 3]);
    assert_eq!(
        serde_json::to_value(s.project("a").unwrap()).unwrap(),
        snapshot
    );
    assert_eq!(s.query("a", "blue", &token()).unwrap(), query);
    assert_eq!(s.context("a", "note").unwrap(), history);
    s.remove_project("a", &token()).unwrap();
}

#[test]
fn held_index_cannot_resurrect_removed_or_different_root_reregistered_project() {
    for replace in [false, true] {
        let (f, mut worker) = removal_fixture();
        let replacement = Fixture::new(); // Deliberately identical allowlist and content.
        let mut owner = f.store();
        let mut removed = false;
        let result = worker.index_with_progress("a", &mut LexicalLines, &token(), |stage| {
            if stage == IndexStage::Read {
                owner.remove_project("a", &token()).unwrap();
                if replace {
                    owner
                        .add_project("a", &replacement.source(), vec!["code.rs".into()])
                        .unwrap();
                }
                removed = true;
            }
        });
        assert!(removed && result.is_err());
        drop(worker);
        drop(owner);
        let mut reopened = f.store();
        assert_eq!(project_rows(&reopened, "a"), [i64::from(replace), 0, 0]);
        if replace {
            assert_eq!(
                reopened.project("a").unwrap().root,
                replacement.source().to_str().unwrap()
            );
            index(&mut reopened); // Only a new explicitly requested worker may publish.
            assert_eq!(matches(&reopened, "blue"), 1);
        }
    }
}

#[test]
fn bound_index_rechecks_captured_approval_transactionally_after_read() {
    for change in ["root", "policy"] {
        let (f, mut worker) = removal_fixture();
        let approved = worker.project("a").unwrap();
        let replacement = Fixture::new();
        let mut owner = f.store();
        let result = worker.index_scoped(
            "a",
            Some((&approved.root, &approved.root_identity, &approved.sources)),
            &mut LexicalLines,
            &token(),
            |stage| {
                if stage == IndexStage::Read {
                    if change == "root" {
                        owner.remove_project("a", &token()).unwrap();
                        owner
                            .add_project("a", &replacement.source(), vec!["code.rs".into()])
                            .unwrap();
                    } else {
                        owner.set_sources("a", vec![]).unwrap();
                    }
                }
            },
        );
        assert!(result.is_err());
        assert!(owner.project("a").unwrap().snapshot.is_none());
        assert_eq!(project_rows(&owner, "a")[1], 0);
    }
}
#[test]
fn pending_mutations_cannot_target_a_different_root_reusing_the_project_id() {
    for action in ["write", "sources", "retire", "remove"] {
        let (f, mut worker) = removal_fixture();
        // Deterministically split the same production preflight/transaction
        // boundary. A second connection replaces the ID before BEGIN.
        let captured = worker.project("a").unwrap();
        let replacement = Fixture::new();
        let mut owner = f.store();
        owner.remove_project("a", &token()).unwrap();
        owner
            .add_project("a", &replacement.source(), vec!["code.rs".into()])
            .unwrap();
        index(&mut owner);
        owner
            .write_context("a", "note", "note", "synthetic replacement note", false)
            .unwrap();
        let before_project = serde_json::to_value(owner.project("a").unwrap()).unwrap();
        let before_history = owner.context("a", "note").unwrap();
        let before_query = owner.query("a", "blue", &token()).unwrap();
        let result = match action {
            "write" => worker.write_context_for_policy(
                &captured,
                "pending",
                "note",
                "synthetic old-root draft",
                false,
            ),
            "sources" => worker.set_sources_for_policy(&captured, vec![]),
            "retire" => worker.retire_context_for_policy(&captured, "note"),
            "remove" => worker
                .remove_project_for_policy(&captured, &token(), |_| {})
                .map(|_| ()),
            _ => unreachable!(),
        };
        assert_eq!(result, Err(Error::ScopeMismatch), "{action}");
        assert_eq!(
            serde_json::to_value(owner.project("a").unwrap()).unwrap(),
            before_project
        );
        assert_eq!(owner.context("a", "note").unwrap(), before_history);
        assert_eq!(owner.query("a", "blue", &token()).unwrap(), before_query);
        assert!(owner.context("a", "pending").is_err());
    }
}

fn index(store: &mut Store) {
    store.index("a", &mut LexicalLines, &token()).unwrap();
}
fn matches(store: &Store, text: &str) -> usize {
    store.query("a", text, &token()).unwrap()["results"]
        .as_array()
        .unwrap()
        .len()
}

#[test]
fn private_store_rejects_replaceable_ancestors_and_descriptor_creation_stays_scoped() {
    let f = Fixture::new();
    let ancestor = f.0.join("ancestor");
    std::fs::create_dir(&ancestor).unwrap();
    std::fs::set_permissions(&ancestor, std::fs::Permissions::from_mode(0o777)).unwrap();
    assert!(Store::open(&ancestor.join("store")).is_err());
    assert!(!ancestor.join("store").exists());
    std::fs::set_permissions(&ancestor, std::fs::Permissions::from_mode(0o700)).unwrap();
    let store = Store::open(&ancestor.join("store")).unwrap();
    std::fs::set_permissions(&ancestor, std::fs::Permissions::from_mode(0o777)).unwrap();
    assert!(store.projects().is_err());
    drop(store);
    std::fs::set_permissions(&ancestor, std::fs::Permissions::from_mode(0o700)).unwrap();

    let captured = store_directory(&ancestor).unwrap();
    let retained = f.0.join("retained-ancestor");
    let outside = f.0.join("outside");
    std::fs::create_dir(&outside).unwrap();
    std::fs::rename(&ancestor, &retained).unwrap();
    symlink(&outside, &ancestor).unwrap();
    // Even a same-account synthetic swap cannot redirect descriptor-relative creation.
    mkdirat(&captured, "scoped-child", Mode::from_raw_mode(0o700)).unwrap();
    assert!(retained.join("scoped-child").is_dir());
    assert!(!outside.join("scoped-child").exists());
    assert!(Store::open(&ancestor.join("new-store")).is_err());
    assert!(!outside.join("new-store").exists());
}

#[cfg(target_os = "macos")]
#[test]
fn macos_acl_grants_rejected_on_ancestors_store_database_and_sidecars() {
    let f = Fixture::new();
    let grant = |path: &Path, inheritable: bool| {
        let rule = if inheritable {
            "everyone allow read,write,execute,append,delete,delete_child,file_inherit,directory_inherit"
        } else {
            "everyone allow read,write,execute,append"
        };
        let output = std::process::Command::new("/bin/chmod")
            .args(["+a", rule])
            .arg(path)
            .output()
            .unwrap();
        assert!(output.status.success());
        assert!(
            exacl::getfacl(path, None)
                .unwrap()
                .iter()
                .any(|entry| entry.allow)
        );
    };
    let clear = |path: &Path| {
        assert!(
            std::process::Command::new("/bin/chmod")
                .arg("-N")
                .arg(path)
                .output()
                .unwrap()
                .status
                .success()
        );
    };
    let ancestor = f.0.join("acl-parent");
    std::fs::create_dir(&ancestor).unwrap();
    std::fs::set_permissions(&ancestor, std::fs::Permissions::from_mode(0o700)).unwrap();
    grant(&ancestor, true);
    assert!(Store::open(&ancestor.join("new-store")).is_err());
    assert!(!ancestor.join("new-store").exists());

    let store = f.store();
    let root = f.0.join("private-store");
    grant(&root, false);
    assert!(store.projects().is_err());
    assert!(Store::open(&root).is_err());
    clear(&root);
    let database = root.join("knowledge.sqlite");
    let before = std::fs::read(&database).unwrap();
    grant(&database, false);
    assert!(store.projects().is_err());
    assert!(Store::open(&root).is_err());
    assert_eq!(std::fs::read(&database).unwrap(), before);
    clear(&database);
    let journal = root.join("knowledge.sqlite-journal");
    OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .open(&journal)
        .unwrap();
    grant(&journal, false);
    assert!(store.projects().is_err());
    assert!(Store::open(&root).is_err());
    clear(&journal);
    std::fs::remove_file(&journal).unwrap();
    assert!(store.projects().is_ok());
}

#[test]
fn concurrent_registration_never_exceeds_project_limit() {
    let f = Fixture::new();
    let mut store = f.store();
    for n in 0..63 {
        let root = f.0.join(format!("registered-{n}"));
        std::fs::create_dir(&root).unwrap();
        store.add_project(&format!("p{n}"), &root, vec![]).unwrap();
    }
    let left = f.0.join("left");
    let right = f.0.join("right");
    std::fs::create_dir(&left).unwrap();
    std::fs::create_dir(&right).unwrap();
    let barrier = std::sync::Arc::new(std::sync::Barrier::new(3));
    let mut handles = Vec::new();
    for (id, root) in [("left", left), ("right", right)] {
        let mut connection = f.store();
        let barrier = barrier.clone();
        handles.push(std::thread::spawn(move || {
            barrier.wait();
            connection.add_project(id, &root, vec![]).is_ok()
        }));
    }
    barrier.wait();
    let successes = handles
        .into_iter()
        .map(|h| h.join().unwrap())
        .filter(|ok| *ok)
        .count();
    assert_eq!(successes, 1);
    assert_eq!(store.projects().unwrap().len(), 64);
}

#[test]
fn core_input_line_limit_precedes_replaceable_extractor() {
    struct SelectLast(bool);
    impl SourceExtractor for SelectLast {
        fn producer(&self) -> &str {
            "replacement-v1"
        }
        fn extract(&mut self, _: &str, _: &AtomicBool) -> Result<Vec<usize>> {
            self.0 = true;
            Ok(vec![5000])
        }
    }
    let f = Fixture::new();
    let mut store = f.registered();
    index(&mut store);
    let previous = store.project("a").unwrap().snapshot;
    std::fs::write(f.source().join("code.rs"), "x\n".repeat(5000)).unwrap();
    let mut extractor = SelectLast(false);
    assert!(store.index("a", &mut extractor, &token()).is_err());
    assert!(!extractor.0);
    assert_eq!(store.project("a").unwrap().snapshot, previous);
}

#[test]
fn selected_persisted_rows_must_resolve_to_current_source_and_truncation_is_explicit() {
    let f = Fixture::new();
    let mut store = f.registered();
    for sql in [
        "UPDATE evidence SET text='forged blue' WHERE line=2",
        "UPDATE evidence SET line=-1 WHERE line=2",
        "UPDATE evidence SET hash=printf('%064d',0) WHERE line=2",
        "UPDATE evidence SET path='foreign.rs' WHERE line=2",
    ] {
        index(&mut store);
        store.db.execute(sql, []).unwrap();
        assert!(store.query("a", "blue", &token()).is_err());
    }
    std::fs::write(f.source().join("code.rs"), "// blue\n".repeat(9)).unwrap();
    index(&mut store);
    let result = store.query("a", "blue", &token()).unwrap();
    assert_eq!(result["results"].as_array().unwrap().len(), 8);
    assert_eq!(result["truncated"], true);
    assert!(serde_json::to_vec(&result).unwrap().len() <= 8192);
}

#[test]
fn durable_reopen_isolated_worktrees_and_human_revision_history() {
    let f = Fixture::new();
    let mut s = f.registered();
    index(&mut s);
    s.write_context("a", "rule", "decision", "choose blue", false)
        .unwrap();
    s.write_context("a", "rule", "constraint", "choose cyan", true)
        .unwrap();
    s.retire_context("a", "rule").unwrap();
    let other = f.0.join("other-source");
    std::fs::create_dir(&other).unwrap();
    std::fs::write(other.join("code.rs"), "// synthetic rule red\n").unwrap();
    s.add_project("a-similar", &other, vec!["code.rs".into()])
        .unwrap();
    s.index("a-similar", &mut LexicalLines, &token()).unwrap();
    s.write_context("a-similar", "rule", "decision", "choose red", false)
        .unwrap();
    assert!(s.add_project("a", &other, vec![]).is_err());
    assert!(s.add_project("alias", &f.source(), vec![]).is_err());
    drop(s);
    let mut s = f.store();
    assert_eq!(matches(&s, "blue"), 1);
    assert_eq!(matches(&s, "red"), 0);
    assert!(
        s.query("a-similar", "blue", &token()).unwrap()["results"]
            .as_array()
            .unwrap()
            .is_empty()
    );
    let note = s.context("a", "rule").unwrap();
    assert_eq!(note["history"].as_array().unwrap().len(), 3);
    assert_eq!(note["history"][2]["retired"], true);
    assert_eq!(
        s.context("a-similar", "rule").unwrap()["history"][0]["text"],
        "choose red"
    );
    index(&mut s);
    assert_eq!(s.context("a", "rule").unwrap(), note);
    let mode = std::fs::metadata(f.0.join("private-store")).unwrap().mode();
    assert_eq!(mode & 0o777, 0o700);
    assert_eq!(
        std::fs::metadata(f.0.join("private-store/knowledge.sqlite"))
            .unwrap()
            .mode()
            & 0o777,
        0o600
    );
}

#[test]
fn edits_deletion_rename_permission_revocation_and_recovery() {
    let f = Fixture::new();
    let mut s = f.registered();
    index(&mut s);
    std::fs::write(f.source().join("code.rs"), "// synthetic green\n").unwrap();
    assert_eq!(matches(&s, "blue"), 0);
    assert_eq!(
        s.query("a", "blue", &token()).unwrap()["currentness"],
        "stale-or-unindexed"
    );
    index(&mut s);
    assert_eq!(matches(&s, "green"), 1);
    std::fs::rename(f.source().join("code.rs"), f.source().join("renamed.rs")).unwrap();
    assert_eq!(matches(&s, "green"), 0);
    assert!(s.index("a", &mut LexicalLines, &token()).is_err());
    s.set_sources("a", vec!["renamed.rs".into()]).unwrap();
    assert_eq!(s.project("a").unwrap().snapshot, None);
    index(&mut s);
    assert_eq!(matches(&s, "green"), 1);
    s.set_sources("a", vec![]).unwrap();
    assert_eq!(matches(&s, "green"), 0);
    let empty = s.index("a", &mut LexicalLines, &token()).unwrap();
    assert_eq!(empty["empty"], true);
    assert!(empty["coverage"].as_str().unwrap().contains("no semantic"));
    s.set_sources("a", vec!["renamed.rs".into()]).unwrap();
    index(&mut s);
    std::fs::remove_file(f.source().join("renamed.rs")).unwrap();
    assert_eq!(matches(&s, "green"), 0);
}

#[test]
fn bad_policy_symlinks_fifo_hardlinks_and_nested_repositories_never_read() {
    let f = Fixture::new();
    let mut s = f.registered();
    for paths in [
        vec!["../code.rs"],
        vec!["/code.rs"],
        vec![".git/config.txt"],
        vec![".env"],
        vec!["credentials.txt"],
        vec!["code.rs", "code.rs"],
        vec!["a//b.rs"],
        vec!["a/./b.rs"],
        vec!["a/../b.rs"],
        vec!["a.json"],
    ] {
        assert!(
            s.set_sources("a", paths.iter().map(|s| (*s).into()).collect())
                .is_err()
        );
    }
    symlink(f.source().join("code.rs"), f.source().join("link.rs")).unwrap();
    symlink(f.source(), f.source().join("linked")).unwrap();
    std::fs::hard_link(f.source().join("code.rs"), f.source().join("hard.rs")).unwrap();
    assert!(
        std::process::Command::new("mkfifo")
            .arg(f.source().join("pipe.txt"))
            .status()
            .unwrap()
            .success()
    );
    std::fs::create_dir(f.source().join("nested")).unwrap();
    std::fs::write(f.source().join("nested/.git"), "synthetic marker").unwrap();
    std::fs::write(f.source().join("nested/file.rs"), "synthetic").unwrap();
    for path in [
        "link.rs",
        "linked/code.rs",
        "hard.rs",
        "pipe.txt",
        "nested/file.rs",
    ] {
        s.set_sources("a", vec![path.into()]).unwrap();
        let start = std::time::Instant::now();
        assert!(s.index("a", &mut LexicalLines, &token()).is_err());
        assert!(start.elapsed() < std::time::Duration::from_secs(2));
    }
    let linkroot = f.0.join("linkroot");
    symlink(f.source(), &linkroot).unwrap();
    assert!(s.add_project("bad-root", &linkroot, vec![]).is_err());
}

#[test]
fn changed_root_or_same_content_replacement_is_not_current() {
    let f = Fixture::new();
    let mut s = f.registered();
    index(&mut s);
    let original = std::fs::read(f.source().join("code.rs")).unwrap();
    std::fs::write(f.source().join("new.rs"), original).unwrap();
    std::fs::rename(f.source().join("new.rs"), f.source().join("code.rs")).unwrap();
    assert_eq!(matches(&s, "blue"), 0);
    index(&mut s);
    std::fs::rename(f.source(), f.0.join("old-source")).unwrap();
    std::fs::create_dir(f.source()).unwrap();
    std::fs::write(f.source().join("code.rs"), "// foreign blue").unwrap();
    assert_eq!(matches(&s, "blue"), 0);
    assert!(s.index("a", &mut LexicalLines, &token()).is_err());
}

#[test]
fn malformed_oversized_binary_and_invalid_utf8_preserve_snapshot_and_notes() {
    let f = Fixture::new();
    let mut s = f.registered();
    index(&mut s);
    s.write_context("a", "note", "pitfall", "synthetic independent note", false)
        .unwrap();
    let snapshot = s.project("a").unwrap().snapshot;
    let original = std::fs::read(f.source().join("code.rs")).unwrap();
    for bad in [
        vec![0; 10],
        vec![255; 20],
        vec![b'a'; MAX_FILE + 1],
        vec![b'a'; 1025],
        vec![b'\n'; 4097],
    ] {
        std::fs::write(f.source().join("code.rs"), bad).unwrap();
        assert!(s.index("a", &mut LexicalLines, &token()).is_err());
        assert_eq!(s.project("a").unwrap().snapshot, snapshot);
        assert_eq!(matches(&s, "blue"), 0);
        assert_eq!(
            s.context("a", "note").unwrap()["history"][0]["text"],
            "synthetic independent note"
        );
    }
    std::fs::write(f.source().join("code.rs"), original).unwrap();
    assert_eq!(matches(&s, "blue"), 1);
    index(&mut s);
}

struct Interrupt<'a> {
    token: &'a AtomicBool,
    mode: u8,
    file: PathBuf,
}
impl SourceExtractor for Interrupt<'_> {
    fn producer(&self) -> &str {
        "synthetic-extractor-v1"
    }
    fn extract(&mut self, _text: &str, _cancel: &AtomicBool) -> Result<Vec<usize>> {
        match self.mode {
            0 => {
                self.token.store(true, Ordering::SeqCst);
                Ok(vec![1])
            }
            1 => Err(Error::Unavailable),
            2 => Ok(vec![999]),
            3 => {
                std::fs::write(&self.file, "// concurrent synthetic replacement").unwrap();
                Ok(vec![1])
            }
            _ => Ok(vec![1, 1]),
        }
    }
}

#[test]
fn real_index_cancel_dependency_failure_bad_anchors_and_concurrent_change_are_atomic() {
    let f = Fixture::new();
    let mut s = f.registered();
    index(&mut s);
    s.write_context("a", "note", "decision", "survives", false)
        .unwrap();
    let snapshot = s.project("a").unwrap().snapshot;
    let before = AtomicBool::new(true);
    assert_eq!(
        s.index("a", &mut LexicalLines, &before),
        Err(Error::Canceled)
    );
    for mode in 0..5 {
        let cancel = token();
        let mut worker = Interrupt {
            token: &cancel,
            mode,
            file: f.source().join("code.rs"),
        };
        assert!(s.index("a", &mut worker, &cancel).is_err());
        assert_eq!(s.project("a").unwrap().snapshot, snapshot);
        assert_eq!(
            s.context("a", "note").unwrap()["history"][0]["text"],
            "survives"
        );
    }
    index(&mut s);
    assert_eq!(matches(&s, "replacement"), 1);
}

#[test]
fn cancellation_and_source_change_after_sql_staging_never_publish_late_output() {
    let f = Fixture::new();
    let mut s = f.registered();
    index(&mut s);
    s.write_context("a", "note", "constraint", "human edit survives", false)
        .unwrap();
    let original = std::fs::read(f.source().join("code.rs")).unwrap();
    let snapshot = s.project("a").unwrap().snapshot;
    std::fs::write(f.source().join("code.rs"), "// synthetic revised green").unwrap();
    let cancel = token();
    let result = s.index_with_progress("a", &mut LexicalLines, &cancel, |stage| {
        if stage == IndexStage::ReadyToCommit {
            cancel.store(true, Ordering::SeqCst);
        }
    });
    assert_eq!(result, Err(Error::Canceled));
    assert_eq!(s.project("a").unwrap().snapshot, snapshot);
    let result = s.index_with_progress("a", &mut LexicalLines, &token(), |stage| {
        if stage == IndexStage::ReadyToCommit {
            std::fs::write(f.source().join("code.rs"), "// changed during transaction").unwrap();
        }
    });
    assert!(result.is_err());
    assert_eq!(s.project("a").unwrap().snapshot, snapshot);
    std::fs::write(f.source().join("code.rs"), original).unwrap();
    assert_eq!(matches(&s, "blue"), 1);
    assert_eq!(
        s.context("a", "note").unwrap()["history"][0]["text"],
        "human edit survives"
    );
    index(&mut s);
}

#[test]
fn sql_failure_after_delete_rolls_back_and_forward_schema_is_read_only_rejected() {
    let f = Fixture::new();
    let mut s = f.registered();
    index(&mut s);
    let snapshot = s.project("a").unwrap().snapshot;
    s.db.execute_batch("CREATE TRIGGER synthetic_fail BEFORE INSERT ON evidence BEGIN SELECT RAISE(ABORT,'synthetic'); END;").unwrap();
    assert!(s.index("a", &mut LexicalLines, &token()).is_err());
    assert_eq!(s.project("a").unwrap().snapshot, snapshot);
    assert_eq!(matches(&s, "blue"), 1);
    s.db.execute_batch("DROP TRIGGER synthetic_fail").unwrap();
    index(&mut s);
    s.db.pragma_update(None, "user_version", 4).unwrap();
    drop(s);
    let path = f.0.join("private-store/knowledge.sqlite");
    let bytes = std::fs::read(&path).unwrap();
    assert!(Store::open(path.parent().unwrap()).is_err());
    assert_eq!(std::fs::read(path).unwrap(), bytes);
}

#[test]
fn unknown_insecure_symlinked_replaced_or_malformed_store_fails_closed() {
    let f = Fixture::new();
    let mut s = f.registered();
    index(&mut s);
    let store_root = f.0.join("private-store");
    let db = store_root.join("knowledge.sqlite");
    std::fs::set_permissions(&store_root, std::fs::Permissions::from_mode(0o755)).unwrap();
    assert!(Store::open(&store_root).is_err());
    assert!(s.query("a", "blue", &token()).is_err());
    std::fs::set_permissions(&store_root, std::fs::Permissions::from_mode(0o700)).unwrap();
    std::fs::rename(&db, store_root.join("old.sqlite")).unwrap();
    std::fs::write(&db, b"synthetic not SQLite").unwrap();
    std::fs::set_permissions(&db, std::fs::Permissions::from_mode(0o600)).unwrap();
    assert!(s.query("a", "blue", &token()).is_err());
    assert!(Store::open(&store_root).is_err());
    std::fs::remove_file(&db).unwrap();
    symlink(store_root.join("old.sqlite"), &db).unwrap();
    assert!(Store::open(&store_root).is_err());
    drop(s);
    let unknown = f.0.join("unknown");
    std::fs::DirBuilder::new()
        .mode(0o700)
        .create(&unknown)
        .unwrap();
    assert!(Store::open(&unknown).is_err());
    OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .open(unknown.join("knowledge.sqlite"))
        .unwrap();
    assert!(Store::open(&unknown).is_err());
    assert_eq!(
        std::fs::metadata(unknown.join("knowledge.sqlite"))
            .unwrap()
            .len(),
        0
    );
}

#[test]
fn retrieval_is_json_escaped_and_budgeted_without_semantic_claims() {
    let f = Fixture::new();
    let mut s = f.registered();
    let line = format!("needle {}\n", "\"\\\t".repeat(250));
    std::fs::write(f.source().join("code.rs"), line.repeat(20)).unwrap();
    index(&mut s);
    let q = s.query("a", "needle", &token()).unwrap();
    assert!(serde_json::to_vec(&q).unwrap().len() <= 8192);
    assert!(q["results"].as_array().unwrap().len() <= 8);
    let result = &q["results"][0];
    assert_eq!(result["producer"], "lexical-lines-v1");
    assert_eq!(result["kind"], "observed-source-line");
    assert_eq!(result["source_hash"].as_str().unwrap().len(), 64);
    assert_eq!(
        sha256(b"abc"),
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    );
    assert!(s.query("a", "", &token()).is_err());
    assert!(s.query("a", &"a".repeat(257), &token()).is_err());
    assert_eq!(
        s.query("a", "needle", &AtomicBool::new(true)),
        Err(Error::Canceled)
    );
}

#[test]
fn sqlite_full_during_actual_replacement_preserves_previous_snapshot() {
    let f = Fixture::new();
    let mut s = f.registered();
    index(&mut s);
    s.write_context("a", "note", "decision", "survives full storage", false)
        .unwrap();
    let original = std::fs::read(f.source().join("code.rs")).unwrap();
    let snapshot = s.project("a").unwrap().snapshot;
    let pages: i64 =
        s.db.pragma_query_value(None, "page_count", |r| r.get(0))
            .unwrap();
    s.db.pragma_update(None, "max_page_count", pages).unwrap();
    std::fs::write(
        f.source().join("code.rs"),
        format!("// {}\n", "x".repeat(200)).repeat(250),
    )
    .unwrap();
    assert!(s.index("a", &mut LexicalLines, &token()).is_err());
    assert_eq!(s.project("a").unwrap().snapshot, snapshot);
    assert_eq!(
        s.context("a", "note").unwrap()["history"][0]["text"],
        "survives full storage"
    );
    std::fs::write(f.source().join("code.rs"), original).unwrap();
    assert_eq!(matches(&s, "blue"), 1);
    s.db.pragma_update(None, "max_page_count", 32768).unwrap();
    index(&mut s);
}

// Child harness test intentionally leaves a real transaction open. Only the owning
// parent kills this process, after reading the staged notification through its pipe.
#[test]
fn transaction_child() {
    use std::io::Write;
    let Some(path) = std::env::var_os("THREADMARK_SYNTHETIC_TRANSACTION_CHILD") else {
        return;
    };
    let mut s = Store::open(Path::new(&path)).unwrap();
    if std::env::var_os("THREADMARK_SYNTHETIC_UNKNOWN_HEADER").is_some() {
        s.db.pragma_update(None, "application_id", 0).unwrap();
    }
    if std::env::var_os("THREADMARK_SYNTHETIC_FORWARD_HEADER").is_some() {
        s.db.pragma_update(None, "user_version", 4).unwrap();
    }
    let tx = s.db.transaction().unwrap();
    tx.execute("DELETE FROM evidence WHERE project='a'", [])
        .unwrap();
    tx.execute(
        "UPDATE projects SET snapshot='uncommitted' WHERE id='a'",
        [],
    )
    .unwrap();
    tx.execute(
        "INSERT INTO context VALUES('a','note',2,'decision','uncommitted',0)",
        [],
    )
    .unwrap();
    assert!(Path::new(&path).join("knowledge.sqlite-journal").is_file());
    println!("transaction-staged");
    std::io::stdout().flush().unwrap();
    let mut byte = [0];
    let _ = std::io::stdin().read_exact(&mut byte);
    drop(tx); // If stdin closes normally, rollback still happens.
}

#[test]
fn killed_owned_process_rolls_back_sqlite_transaction_on_reopen() {
    use std::io::BufRead;
    use std::process::{Command, Stdio};
    for header in ["recognized", "foreign", "forward"] {
        let f = Fixture::new();
        let mut s = f.registered();
        index(&mut s);
        s.write_context("a", "note", "decision", "committed human edit", false)
            .unwrap();
        let snapshot = s.project("a").unwrap().snapshot;
        drop(s);
        let mut command = Command::new(std::env::current_exe().unwrap());
        command
            .args([
                "--exact",
                "knowledge::tests::transaction_child",
                "--nocapture",
            ])
            .env(
                "THREADMARK_SYNTHETIC_TRANSACTION_CHILD",
                f.0.join("private-store"),
            )
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        if header == "foreign" {
            command.env("THREADMARK_SYNTHETIC_UNKNOWN_HEADER", "1");
        }
        if header == "forward" {
            command.env("THREADMARK_SYNTHETIC_FORWARD_HEADER", "1");
        }
        let mut child = command.spawn().unwrap();
        // Child::wait closes an owned stdin handle. Keep it separately alive
        // until reaping so normal EOF rollback cannot race the kill handshake.
        let held_stdin = child.stdin.take().unwrap();
        let mut reader = std::io::BufReader::new(child.stdout.take().unwrap());
        let mut staged = false;
        for _ in 0..10 {
            let mut line = String::new();
            if reader.read_line(&mut line).unwrap() == 0 {
                break;
            }
            if line.trim() == "transaction-staged" {
                staged = true;
                break;
            }
        }
        child.kill().unwrap();
        let status = child.wait().unwrap();
        drop(held_stdin);
        assert!(staged);
        assert!(!status.success());
        let journal = f.0.join("private-store/knowledge.sqlite-journal");
        assert!(
            journal.exists(),
            "staged rollback journal missing; header case={header}"
        );
        assert_eq!(std::fs::metadata(&journal).unwrap().mode() & 0o777, 0o600);
        if header != "recognized" {
            let database = f.0.join("private-store/knowledge.sqlite");
            let before_db = std::fs::read(&database).unwrap();
            let before_journal = std::fs::read(&journal).unwrap();
            assert!(Store::open(&f.0.join("private-store")).is_err());
            assert_eq!(std::fs::read(&database).unwrap(), before_db);
            assert_eq!(std::fs::read(&journal).unwrap(), before_journal);
            continue;
        }
        let s = f.store();
        assert_eq!(s.project("a").unwrap().snapshot, snapshot);
        assert_eq!(matches(&s, "blue"), 1);
        let notes = s.context("a", "note").unwrap();
        assert_eq!(notes["history"].as_array().unwrap().len(), 1);
        assert_eq!(notes["history"][0]["text"], "committed human edit");
    }
}

#[test]
fn declared_file_total_line_and_context_budgets_are_enforced() {
    let f = Fixture::new();
    let mut s = f.registered();
    assert!(
        s.set_sources("a", (0..65).map(|n| format!("f{n}.txt")).collect())
            .is_err()
    );
    let mut files = Vec::new();
    let text = format!("{}\n", "x".repeat(1023)).repeat(64);
    for n in 0..17 {
        let name = format!("f{n}.txt");
        std::fs::write(f.source().join(&name), &text).unwrap();
        files.push(name);
    }
    s.set_sources("a", files.clone()).unwrap();
    assert!(s.index("a", &mut LexicalLines, &token()).is_err());
    files.pop();
    s.set_sources("a", files).unwrap();
    assert_eq!(
        s.index("a", &mut LexicalLines, &token()).unwrap()["files"],
        16
    );
    assert!(
        s.write_context("a", "n", "decision", &"a".repeat(4097), false)
            .is_err()
    );
    assert!(
        s.write_context("a", "n", "authority", "not authorization", false)
            .is_err()
    );
    s.write_context("a", "n", "decision", "bounded", false)
        .unwrap();
    for _ in 1..32 {
        s.write_context("a", "n", "decision", "bounded edit", true)
            .unwrap();
    }
    assert!(
        s.write_context("a", "n", "decision", "too many edits", true)
            .is_err()
    );
    assert!(s.retire_context("a", "n").is_err());
    assert_eq!(
        s.context("a", "n").unwrap()["history"]
            .as_array()
            .unwrap()
            .len(),
        32
    );
}

#[test]
fn unreadable_sources_and_revocation_during_extraction_invalidate_retrieval() {
    let f = Fixture::new();
    let mut s = f.registered();
    index(&mut s);
    s.write_context("a", "note", "decision", "independent", false)
        .unwrap();
    let file = f.source().join("code.rs");
    std::fs::set_permissions(&file, std::fs::Permissions::from_mode(0o000)).unwrap();
    assert_eq!(matches(&s, "blue"), 0);
    assert!(s.index("a", &mut LexicalLines, &token()).is_err());
    std::fs::set_permissions(file, std::fs::Permissions::from_mode(0o600)).unwrap();
    assert_eq!(matches(&s, "blue"), 1);
    struct Revoke(Store);
    impl SourceExtractor for Revoke {
        fn producer(&self) -> &str {
            "synthetic-revoke-v1"
        }
        fn extract(&mut self, _text: &str, _cancel: &AtomicBool) -> Result<Vec<usize>> {
            self.0.set_sources("a", vec![])?;
            Ok(vec![1])
        }
    }
    let mut revoke = Revoke(f.store());
    assert!(s.index("a", &mut revoke, &token()).is_err());
    assert_eq!(s.project("a").unwrap().snapshot, None);
    assert_eq!(matches(&s, "blue"), 0);
    assert_eq!(
        s.context("a", "note").unwrap()["history"][0]["text"],
        "independent"
    );
}
