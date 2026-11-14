//! AG synthetic real SQLite/source tests; no external process deadline fixtures.
use super::*;
use std::os::unix::fs::{PermissionsExt, symlink};

struct Fixture(PathBuf);
fn token() -> AtomicBool {
    AtomicBool::new(false)
}
impl Fixture {
    fn new(files: &[(&str, &[u8])], indexed: bool) -> (Self, Store, Project) {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let f = Self(std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-incremental-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        )));
        std::fs::create_dir(&f.0).unwrap();
        std::fs::create_dir(f.0.join("source")).unwrap();
        for (path, text) in files {
            std::fs::write(f.source(path), text).unwrap();
        }
        let mut s = Store::open(&f.0.join("store")).unwrap();
        s.add_project(
            "a",
            &f.0.join("source"),
            files.iter().map(|(p, _)| (*p).into()).collect(),
        )
        .unwrap();
        if indexed {
            s.index("a", &mut LexicalLines, &token()).unwrap();
        }
        s.write_context("a", "draft", "note", "synthetic human", false)
            .unwrap();
        s.write_context("a", "draft", "note", "synthetic revision", true)
            .unwrap();
        let p = s.project("a").unwrap();
        (f, s, p)
    }
    fn source(&self, p: &str) -> PathBuf {
        self.0.join("source").join(p)
    }
    fn db(&self) -> PathBuf {
        self.0.join("store/knowledge.sqlite")
    }
    fn peer(&self) -> Store {
        Store::open_existing(&self.0.join("store")).unwrap()
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}
fn capture(p: &Project) -> Project {
    Project {
        id: p.id.clone(),
        root: p.root.clone(),
        root_identity: p.root_identity.clone(),
        incarnation: p.incarnation.clone(),
        sources: p.sources.clone(),
        snapshot: p.snapshot.clone(),
    }
}
fn no_source_access(f: impl FnOnce()) {
    source_forget::SOURCE_ACCESSES.with(|n| n.set(0));
    f();
    source_forget::SOURCE_ACCESSES.with(|n| assert_eq!(n.get(), 0));
}
fn rowids(s: &Store) -> Vec<(i64, String, i64, String)> {
    s.db.prepare("SELECT rowid,path,line,text FROM evidence ORDER BY path,line")
        .unwrap()
        .query_map([], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?)))
        .unwrap()
        .collect::<std::result::Result<_, _>>()
        .unwrap()
}

#[test]
fn ag_a2_none_build_exact_query_full_index_and_unicode() {
    let (f, mut s, p) = Fixture::new(
        &[
            ("a.rs", "  λ\t\"quote\"\\雪\r\n\nsecond\n".as_bytes()),
            ("empty.txt", b""),
        ],
        false,
    );
    assert_eq!(
        s.query("a", "λ", &token()).unwrap()["currentness"],
        "stale-or-unindexed"
    );
    let history = s.context("a", "draft").unwrap();
    let r = s.index_incremental(&p, &token()).unwrap();
    assert_eq!(r["reused_anchors"], 0);
    assert_eq!(r["written_anchors"], 2);
    assert_eq!(r["reindexed_files"], 2);
    assert_eq!(r["snapshot_updated"], true);
    let q = s.query("a", "λ", &token()).unwrap();
    assert_eq!(q["results"][0]["text"], "  λ\t\"quote\"\\雪");
    assert_eq!(q["results"][0]["producer"], "lexical-lines-v1");
    assert_eq!(
        q["results"][0]["source_hash"],
        sha256(&std::fs::read(f.source("a.rs")).unwrap())
    );
    let full = s.index("a", &mut LexicalLines, &token()).unwrap();
    assert_eq!(
        full,
        json!({"project":"a","snapshot":r["snapshot"],"files":2,"anchors":2,"empty":false,"coverage":"lexical-lines-only; no semantic coverage"})
    );
    assert_eq!(s.query("a", "λ", &token()).unwrap(), q);
    assert_eq!(s.context("a", "draft").unwrap(), history);
}

#[test]
fn ag_a2_all_unchanged_no_sql_writes_one_edit_only_changed_rows() {
    let (f, mut s, p) = Fixture::new(
        &[
            ("a.rs", b"one\ntwo\n"),
            ("b.rs", b"other\n"),
            ("empty.txt", b""),
        ],
        true,
    );
    let before = s.db.total_changes();
    let bytes = std::fs::read(f.db()).unwrap();
    let original_rows = rowids(&s);
    let r = s.index_incremental(&p, &token()).unwrap();
    assert_eq!(r["reused_files"], 3);
    assert_eq!(r["reused_anchors"], 3);
    assert_eq!(r["written_anchors"], 0);
    assert_eq!(r["deleted_anchors"], 0);
    assert_eq!(r["snapshot_updated"], false);
    assert_eq!(r["persistent_writes"], false);
    assert_eq!(s.db.total_changes(), before);
    assert_eq!(rowids(&s), original_rows);
    assert_eq!(std::fs::read(f.db()).unwrap(), bytes);
    std::fs::write(f.source("a.rs"), "replacement\n").unwrap();
    let r = s.index_incremental(&p, &token()).unwrap();
    assert_eq!(r["reused_files"], 2);
    assert_eq!(r["reindexed_files"], 1);
    assert_eq!(r["deleted_anchors"], 2);
    assert_eq!(r["written_anchors"], 1);
    assert_eq!(r["reused_anchors"], 1);
    assert_eq!(s.db.total_changes() - before, 4); // 2 deleted, 1 inserted, 1 manifest
    assert_eq!(
        rowids(&s).iter().find(|r| r.1 == "b.rs"),
        original_rows.iter().find(|r| r.1 == "b.rs")
    );
}

#[test]
fn ag_a2_identical_bytes_new_inode_and_full64_zero_anchors() {
    let (f, mut s, p) = Fixture::new(&[("a.rs", b"anchor\n")], true);
    std::fs::write(f.source("replacement.rs"), b"anchor\n").unwrap();
    std::fs::rename(f.source("replacement.rs"), f.source("a.rs")).unwrap();
    let r = s.index_incremental(&p, &token()).unwrap();
    assert_eq!(r["reindexed_files"], 1);
    assert_eq!(r["reused_anchors"], 0);
    assert_ne!(r["snapshot"], p.snapshot.unwrap());
    let names: Vec<_> = (0..64).map(|i| format!("f{i}.rs")).collect();
    let files: Vec<_> = names
        .iter()
        .map(|n| (n.as_str(), b" \n\n".as_slice()))
        .collect();
    let (_f, mut s, p) = Fixture::new(&files, false);
    let r = s.index_incremental(&p, &token()).unwrap();
    assert_eq!(r["files"], 64);
    assert_eq!(r["anchors"], 0);
    assert_eq!(r["empty"], true);
    let p = s.project("a").unwrap();
    let changes = s.db.total_changes();
    assert_eq!(
        s.index_incremental(&p, &token()).unwrap()["reused_files"],
        64
    );
    assert_eq!(s.db.total_changes(), changes);
}

#[test]
fn ag_a1_all_bindings_and_peer_snapshot_fail_before_sources() {
    let (f, mut s, p) = Fixture::new(&[("a.rs", b"one\n"), ("b.rs", b"two\n")], true);
    for case in 0..8 {
        let mut bad = capture(&p);
        match case {
            0 => bad.root.push('x'),
            1 => bad.root_identity.push('0'),
            2 => bad.incarnation = Some("0".repeat(32)),
            3 => bad.sources.reverse(),
            4 => bad.snapshot = None,
            5 => bad.snapshot = Some("0".repeat(64)),
            6 => bad.incarnation = None,
            _ => bad.root = format!("/{}", "λ".repeat(2048)),
        }
        no_source_access(|| assert!(s.index_incremental(&bad, &token()).is_err()));
    }
    std::fs::write(f.source("a.rs"), b"peer update\n").unwrap();
    f.peer().index("a", &mut LexicalLines, &token()).unwrap();
    no_source_access(|| assert_eq!(s.index_incremental(&p, &token()), Err(Error::ScopeMismatch)));
    let fresh = s.project("a").unwrap();
    assert!(s.index_incremental(&fresh, &token()).is_ok());
}

#[test]
fn ag_a1_peer_policy_nonce_and_root_replacement_fail_before_sources() {
    for case in 0..3 {
        let (f, mut s, p) = Fixture::new(&[("a.rs", b"anchor\n")], true);
        let mut peer = f.peer();
        match case {
            0 => peer.set_sources("a", vec![]).unwrap(),
            1 => {
                peer.remove_project("a", &token()).unwrap();
                peer.add_project("a", &f.0.join("source"), p.sources.clone())
                    .unwrap();
            }
            _ => {
                peer.remove_project("a", &token()).unwrap();
                std::fs::create_dir(f.0.join("other")).unwrap();
                peer.add_project("a", &f.0.join("other"), vec![]).unwrap();
            }
        }
        no_source_access(|| assert!(s.index_incremental(&p, &token()).is_err()));
        let fresh = s.project("a").unwrap();
        assert!(fresh.snapshot.is_none());
        assert_eq!(
            s.index_incremental(&fresh, &token()).unwrap()["reused_anchors"],
            0
        );
    }
}

#[test]
fn ag_a3_corrupt_manifest_and_evidence_fail_without_healing() {
    for case in 0..15 {
        let (f, mut s, mut p) =
            Fixture::new(&[("a.rs", b"one\ntwo\n"), ("b.rs", b"three\n")], true);
        match case {
            0 => {
                s.db.execute("UPDATE projects SET manifest='[]'", [])
                    .unwrap();
            }
            1..=4 => {
                let encoded: String =
                    s.db.query_row("SELECT manifest FROM projects", [], |r| r.get(0))
                        .unwrap();
                let mut m: Value = serde_json::from_str(&encoded).unwrap();
                match case {
                    1 => m.as_array_mut().unwrap().reverse(),
                    2 => m[0]["identity"] = json!("bad"),
                    3 => m[0]["extra"] = json!(true),
                    _ => m[0]["hash"] = json!("f".repeat(63)),
                }
                let encoded = m.to_string();
                s.db.execute(
                    "UPDATE projects SET manifest=?1,snapshot=?2",
                    params![encoded, sha256(encoded.as_bytes())],
                )
                .unwrap();
                p = s.project("a").unwrap();
            }
            5 => {
                s.db.execute("UPDATE evidence SET hash=?1", ["0".repeat(64)])
                    .unwrap();
            }
            6 => {
                s.db.execute(
                    "UPDATE evidence SET path='outside.rs' WHERE path='a.rs'",
                    [],
                )
                .unwrap();
            }
            7 => {
                s.db.execute("UPDATE evidence SET line=4097 WHERE path='b.rs'", [])
                    .unwrap();
            }
            8 => {
                s.db.execute("UPDATE evidence SET text='forged'", [])
                    .unwrap();
            }
            9 => {
                s.db.execute("DELETE FROM evidence WHERE path='a.rs' AND line=1", [])
                    .unwrap();
            }
            10 => {
                s.db.execute("UPDATE evidence SET line=3 WHERE path='b.rs'", [])
                    .unwrap();
            }
            11 => {
                s.db.execute("UPDATE projects SET snapshot=NULL,manifest=NULL", [])
                    .unwrap();
                p = s.project("a").unwrap();
            }
            12 => {
                s.db.execute("UPDATE evidence SET producer='bad producer'", [])
                    .unwrap();
            }
            13 => {
                s.db.execute("UPDATE evidence SET text=?1", ["\0"]).unwrap();
            }
            _ => {
                s.db.execute("INSERT INTO evidence SELECT project,path,3,text,hash,producer FROM evidence WHERE path='a.rs' AND line=1", []).unwrap();
            }
        }
        let bytes = std::fs::read(f.db()).unwrap();
        assert!(s.index_incremental(&p, &token()).is_err(), "case {case}");
        assert_eq!(std::fs::read(f.db()).unwrap(), bytes);
    }
}

struct Custom;
impl SourceExtractor for Custom {
    fn producer(&self) -> &str {
        "custom-v1"
    }
    fn extract(&mut self, _: &str, _: &AtomicBool) -> Result<Vec<usize>> {
        Ok(vec![2])
    }
}
#[test]
fn ag_a3_custom_rows_full_file_fallback_not_partial_reuse() {
    let (_f, mut s, _) = Fixture::new(&[("a.rs", b"first\nsecond\n")], false);
    s.index("a", &mut Custom, &token()).unwrap();
    let p = s.project("a").unwrap();
    let before = s.db.total_changes();
    let r = s.index_incremental(&p, &token()).unwrap();
    assert_eq!(r["reused_anchors"], 0);
    assert_eq!(r["deleted_anchors"], 1);
    assert_eq!(r["written_anchors"], 2);
    assert_eq!(r["snapshot_updated"], false);
    assert_eq!(r["persistent_writes"], true);
    assert_eq!(s.db.total_changes() - before, 3);
    assert_eq!(
        s.query("a", "first", &token()).unwrap()["results"][0]["producer"],
        "lexical-lines-v1"
    );
}

#[test]
fn ag_a4_cancel_all_stages_and_chunks_roll_back_joined_operation() {
    for stage in [
        IndexStage::Read,
        IndexStage::Extracted,
        IndexStage::ReadyToCommit,
    ] {
        let (f, mut s, p) = Fixture::new(&[("a.rs", b"anchor\n")], true);
        let history = s.context("a", "draft").unwrap();
        let bytes = std::fs::read(f.db()).unwrap();
        std::fs::write(f.source("a.rs"), b"new\n").unwrap();
        let cancel = token();
        assert_eq!(
            s.index_incremental_with_progress(&p, &cancel, |at| {
                if at == stage {
                    cancel.store(true, Ordering::SeqCst);
                }
            }),
            Err(Error::Canceled)
        );
        assert_eq!(std::fs::read(f.db()).unwrap(), bytes);
        assert_eq!(s.project("a").unwrap().snapshot, p.snapshot);
        assert_eq!(s.context("a", "draft").unwrap(), history);
        assert!(s.index_incremental(&p, &token()).is_ok());
    }
    let (f, mut s, p) = Fixture::new(&[("a.rs", b"anchor\n")], true);
    let bytes = std::fs::read(f.db()).unwrap();
    let cancel = AtomicBool::new(true);
    no_source_access(|| assert_eq!(s.index_incremental(&p, &cancel), Err(Error::Canceled)));
    let cancel = token();
    CANCEL_CHUNK.with(|n| n.set(true));
    assert_eq!(s.index_incremental(&p, &cancel), Err(Error::Canceled));
    assert_eq!(std::fs::read(f.db()).unwrap(), bytes);
}

#[test]
fn ag_a4_source_changes_before_and_after_sql_reject_and_recover() {
    for stage in [
        IndexStage::Read,
        IndexStage::Extracted,
        IndexStage::ReadyToCommit,
    ] {
        let (f, mut s, p) = Fixture::new(&[("a.rs", b"old\n")], true);
        let bytes = std::fs::read(f.db()).unwrap();
        std::fs::write(f.source("a.rs"), b"new\n").unwrap();
        assert_eq!(
            s.index_incremental_with_progress(&p, &token(), |at| {
                if at == stage {
                    std::fs::write(f.source("a.rs"), b"raced\n").unwrap();
                }
            }),
            Err(Error::ScopeMismatch)
        );
        assert_eq!(std::fs::read(f.db()).unwrap(), bytes);
        assert_eq!(
            s.index_incremental(&p, &token()).unwrap()["written_anchors"],
            1
        );
    }
}

#[test]
fn ag_a4_serializes_peer_policy_snapshot_nonce_and_preserves_history() {
    let (f, mut s, p) = Fixture::new(&[("a.rs", b"anchor\n")], true);
    let peer = f.peer();
    peer.db.busy_timeout(std::time::Duration::ZERO).unwrap();
    s.index_incremental_with_progress(&p, &token(), |stage| {
        if stage == IndexStage::ReadyToCommit {
            for sql in [
                "UPDATE projects SET sources='[]'",
                "UPDATE projects SET snapshot=NULL,manifest=NULL",
                "UPDATE project_incarnations SET incarnation='00000000000000000000000000000000'",
                "DELETE FROM evidence",
                "DELETE FROM projects",
            ] {
                assert!(peer.db.execute(sql, []).is_err());
            }
        }
    })
    .unwrap();
    assert_eq!(
        s.context("a", "draft").unwrap()["history"]
            .as_array()
            .unwrap()
            .len(),
        2
    );
}

#[test]
fn ag_a4_sql_abort_full_dependency_rollback_and_recovery() {
    for case in 0..3 {
        let (f, mut s, p) = Fixture::new(&[("a.rs", b"old\n")], true);
        let before = std::fs::read(f.db()).unwrap();
        if case == 0 {
            s.db.execute_batch("CREATE TEMP TRIGGER reject_incremental BEFORE INSERT ON main.evidence BEGIN SELECT RAISE(ABORT,'synthetic failure'); END;").unwrap();
        }
        if case == 1 {
            let pages: i64 =
                s.db.pragma_query_value(None, "page_count", |r| r.get(0))
                    .unwrap();
            s.db.pragma_update(None, "max_page_count", pages).unwrap();
        }
        let changed = if case == 1 {
            "x".repeat(1024) + "\n"
        } else {
            "new\n".into()
        };
        std::fs::write(
            f.source("a.rs"),
            if case == 1 {
                changed.repeat(60)
            } else {
                changed
            },
        )
        .unwrap();
        let result = s.index_incremental_with_progress(&p, &token(), |stage| {
            if stage == IndexStage::ReadyToCommit && case == 2 {
                std::fs::set_permissions(f.db(), std::fs::Permissions::from_mode(0o644)).unwrap();
            }
        });
        assert!(result.is_err(), "case {case}");
        if case == 2 {
            std::fs::set_permissions(f.db(), std::fs::Permissions::from_mode(0o600)).unwrap();
        }
        assert_eq!(std::fs::read(f.db()).unwrap(), before);
        assert_eq!(s.project("a").unwrap().snapshot, p.snapshot);
        if case == 0 {
            s.db.execute_batch("DROP TRIGGER reject_incremental")
                .unwrap();
        }
        s.db.pragma_update(None, "max_page_count", 32768).unwrap();
        assert!(s.index_incremental(&p, &token()).is_ok());
    }
}

#[test]
fn ag_a3_budgets_containment_and_recovery() {
    for case in 0..11 {
        let (f, mut s, p) = Fixture::new(&[("a.rs", b"old\n")], true);
        let bytes = std::fs::read(f.db()).unwrap();
        match case {
            0 => std::fs::write(f.source("a.rs"), vec![b'x'; MAX_FILE + 1]).unwrap(),
            1 => std::fs::write(f.source("a.rs"), "a\n".repeat(4097)).unwrap(),
            2 => std::fs::write(f.source("a.rs"), "x".repeat(1025)).unwrap(),
            3 => std::fs::write(f.source("a.rs"), b"\0").unwrap(),
            4 => std::fs::write(f.source("a.rs"), [0xff]).unwrap(),
            5 => {
                std::fs::rename(f.source("a.rs"), f.source("other.rs")).unwrap();
                symlink("other.rs", f.source("a.rs")).unwrap();
            }
            6 => {
                std::fs::hard_link(f.source("a.rs"), f.source("other.rs")).unwrap();
            }
            7 => {
                std::fs::remove_file(f.source("a.rs")).unwrap();
                std::fs::create_dir(f.source("a.rs")).unwrap();
            }
            8 => {
                std::fs::remove_file(f.source("a.rs")).unwrap();
                assert!(
                    std::process::Command::new("mkfifo")
                        .arg(f.source("a.rs"))
                        .status()
                        .unwrap()
                        .success()
                );
            }
            9 => {
                std::fs::remove_file(f.source("a.rs")).unwrap();
            }
            _ => {
                std::fs::rename(f.0.join("source"), f.0.join("moved")).unwrap();
                std::fs::create_dir(f.0.join("source")).unwrap();
            }
        }
        assert!(s.index_incremental(&p, &token()).is_err(), "case {case}");
        assert_eq!(std::fs::read(f.db()).unwrap(), bytes);
    }
    // Valid single files can still exceed aggregate byte/anchor admission.
    for anchors in [false, true] {
        let names: Vec<_> = (0..17).map(|i| format!("f{i}.rs")).collect();
        let files: Vec<_> = names.iter().map(|n| (n.as_str(), b"".as_slice())).collect();
        let (f, mut s, p) = Fixture::new(&files, true);
        let bytes = std::fs::read(f.db()).unwrap();
        for name in &names {
            let text = if anchors {
                "a\n".repeat(4096)
            } else {
                ("x".repeat(1023) + "\n").repeat(64)
            };
            std::fs::write(f.source(name), text).unwrap();
        }
        assert!(s.index_incremental(&p, &token()).is_err());
        assert_eq!(std::fs::read(f.db()).unwrap(), bytes);
    }
}

#[test]
fn ag_a5_forget_recapture_none_build_preserves_sources_human_and_markers() {
    let (f, mut s, p) = Fixture::new(&[("a.rs", b"forget\n"), ("b.rs", b"keep\n")], true);
    let history = s.context("a", "draft").unwrap();
    s.forget_source("a", "a.rs", &token()).unwrap();
    no_source_access(|| assert!(s.index_incremental(&p, &token()).is_err()));
    let fresh = s.project("a").unwrap();
    assert!(fresh.snapshot.is_none());
    let r = s.index_incremental(&fresh, &token()).unwrap();
    assert_eq!(r["reused_anchors"], 0);
    assert_eq!(r["files"], 1);
    assert_eq!(
        s.query("a", "forget", &token()).unwrap()["results"],
        json!([])
    );
    assert_eq!(
        s.forgotten_sources("a").unwrap()["forgotten"],
        json!([{"path":"a.rs"}])
    );
    assert_eq!(s.context("a", "draft").unwrap(), history);
    assert_eq!(std::fs::read(f.source("a.rs")).unwrap(), b"forget\n");
    assert_eq!(std::fs::read(f.source("b.rs")).unwrap(), b"keep\n");
    assert!(s.set_sources("a", vec!["a.rs".into()]).is_err());
}

#[test]
fn ag_a4_owned_staging_child() {
    use std::io::Write;
    let Some(path) = std::env::var_os("THREADMARK_SYNTHETIC_AG_CHILD") else {
        return;
    };
    let mut s = Store::open_existing(Path::new(&path)).unwrap();
    let p = s.project("a").unwrap();
    s.index_incremental_with_progress(&p, &token(), |stage| {
        if stage == IndexStage::ReadyToCommit {
            println!("ag-staged");
            std::io::stdout().flush().unwrap();
            std::io::stdin().read_exact(&mut [0]).unwrap();
        }
    })
    .unwrap();
}

#[test]
fn ag_a4_killed_staging_recovers_previous_snapshot_and_human_rows() {
    use std::io::BufRead;
    use std::process::{Command, Stdio};
    let (f, s, p) = Fixture::new(&[("a.rs", b"old\n"), ("b.rs", b"unchanged\n")], true);
    let original = rowids(&s);
    let history = s.context("a", "draft").unwrap();
    drop(s);
    std::fs::write(f.source("a.rs"), b"staged change\n").unwrap();
    let mut child = Command::new(std::env::current_exe().unwrap())
        .args([
            "--exact",
            "knowledge::incremental::tests::ag_a4_owned_staging_child",
            "--nocapture",
        ])
        .env("THREADMARK_SYNTHETIC_AG_CHILD", f.0.join("store"))
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let held = child.stdin.take().unwrap();
    let mut output = std::io::BufReader::new(child.stdout.take().unwrap());
    let mut staged = false;
    for _ in 0..10 {
        let mut line = String::new();
        if output.read_line(&mut line).unwrap() == 0 {
            break;
        }
        if line.trim() == "ag-staged" {
            staged = true;
            break;
        }
    }
    child.kill().unwrap();
    assert!(!child.wait().unwrap().success());
    drop(held);
    assert!(staged);
    assert!(f.0.join("store/knowledge.sqlite-journal").exists());
    let mut s = f.peer();
    assert_eq!(rowids(&s), original);
    assert_eq!(s.project("a").unwrap().snapshot, p.snapshot);
    assert_eq!(s.context("a", "draft").unwrap(), history);
    assert!(s.index_incremental(&p, &token()).is_ok());
    assert_eq!(
        s.query("a", "staged", &token()).unwrap()["results"][0]["text"],
        "staged change"
    );
}

#[test]
fn ag_a3_exact_byte_line_anchor_bounds_and_nested_repository() {
    // Exactly 1 MiB and 16384 anchors is admitted; escaped lines stay source
    // exact, but report never contains them. Default query remains JSON-escaped.
    let names: Vec<_> = (0..16).map(|i| format!("f{i}.rs")).collect();
    let files: Vec<_> = names.iter().map(|n| (n.as_str(), b"".as_slice())).collect();
    let (f, mut s, p) = Fixture::new(&files, false);
    let line = "\\\"".repeat(31) + "x\n"; // 64 bytes/line, 1024 lines/file
    assert_eq!(line.len(), 64);
    for name in &names {
        std::fs::write(f.source(name), line.repeat(1024)).unwrap();
    }
    let r = s.index_incremental(&p, &token()).unwrap();
    assert_eq!(r["anchors"], 16384);
    assert!(serde_json::to_vec(&r).unwrap().len() < 65536);
    assert!(!r.to_string().contains("\\\\"));
    let q = s.query("a", "x", &token()).unwrap();
    assert_eq!(q["results"][0]["text"], line.trim_end_matches('\n'));
    let p = s.project("a").unwrap();
    let changes = s.db.total_changes();
    assert_eq!(
        s.index_incremental(&p, &token()).unwrap()["reused_anchors"],
        16384
    );
    assert_eq!(s.db.total_changes(), changes);
    let (_empty, mut empty, p) = Fixture::new(&[], false);
    assert_eq!(empty.index_incremental(&p, &token()).unwrap()["files"], 0);

    let (f, mut s, _) = Fixture::new(&[], false);
    std::fs::create_dir(f.source("nested")).unwrap();
    std::fs::write(f.source("nested/a.rs"), b"anchor\n").unwrap();
    s.set_sources("a", vec!["nested/a.rs".into()]).unwrap();
    let p = s.project("a").unwrap();
    s.index_incremental(&p, &token()).unwrap();
    let p = s.project("a").unwrap();
    let bytes = std::fs::read(f.db()).unwrap();
    std::fs::create_dir(f.source("nested/.git")).unwrap();
    assert!(s.index_incremental(&p, &token()).is_err());
    assert_eq!(std::fs::read(f.db()).unwrap(), bytes);
}
