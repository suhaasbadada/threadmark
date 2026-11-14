//! Unit Z synthetic actual core/SQLite acceptance; no host or network calls.
use super::*;
use std::os::unix::fs::symlink;

struct Fixture(PathBuf);
impl Fixture {
    fn new(text: &str) -> (Self, Store, Project, SourceAnchorInspection) {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let root = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-inspect-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::create_dir(&root).unwrap();
        std::fs::create_dir(root.join("source")).unwrap();
        std::fs::write(root.join("source/code.rs"), text).unwrap();
        let f = Self(root);
        let mut s = Store::open(&f.0.join("store")).unwrap();
        s.add_project("a", &f.0.join("source"), vec!["code.rs".into()])
            .unwrap();
        s.index("a", &mut LexicalLines, &token()).unwrap();
        s.write_context("a", "draft", "note", "synthetic human note", false)
            .unwrap();
        let p = s.project("a").unwrap();
        let q = s.query_bound(&p, "center", &token()).unwrap();
        let row = &q["results"][0];
        let a = SourceAnchorInspection {
            path: "code.rs".into(),
            line: row["line"].as_u64().unwrap() as usize,
            source_hash: row["source_hash"].as_str().unwrap().into(),
            radius: 3,
        };
        (f, s, p, a)
    }
    fn source(&self) -> PathBuf {
        self.0.join("source/code.rs")
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
const CODE: &str = "// before\nfn wrapper() {\n\n    center(\"λ\\\");\n    after();\n}\n// end\n";

#[test]
fn z_a4_inspection_open_is_read_only_and_rejects_wal_before_sqlite_open() {
    let (f, s, p, a) = Fixture::new(CODE);
    let database = f.0.join("store/knowledge.sqlite");
    let before = std::fs::read(&database).unwrap();
    let inspected = Store::open_existing_for_inspection(&f.0.join("store")).unwrap();
    inspected.inspect_source_anchor(&p, &a, &token()).unwrap();
    assert!(inspected.db.execute("DELETE FROM context", []).is_err());
    assert_eq!(std::fs::read(&database).unwrap(), before);
    assert_eq!(
        s.context("a", "draft").unwrap()["history"][0]["text"],
        "synthetic human note"
    );
    drop(inspected);
    s.db.pragma_update(None, "journal_mode", "WAL").unwrap();
    drop(s);
    let before = std::fs::read(&database).unwrap();
    assert_eq!(&before[18..20], &[2, 2]);
    assert!(Store::open_existing_for_inspection(&f.0.join("store")).is_err());
    assert_eq!(std::fs::read(&database).unwrap(), before);
    assert!(!f.0.join("store/knowledge.sqlite-wal").exists());
    assert!(!f.0.join("store/knowledge.sqlite-shm").exists());
    assert!(Store::open_existing_for_inspection(&f.0.join("missing")).is_err());
    assert!(!f.0.join("missing").exists());
}

#[test]
fn z_a2_query_to_inspect_proves_complete_window_provenance_and_no_writes() {
    let (f, s, p, a) = Fixture::new(CODE);
    let db = std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap();
    let reply = s.inspect_source_anchor(&p, &a, &token()).unwrap();
    assert_eq!(reply["format"], "threadmark-source-anchor-inspection");
    assert_eq!(reply["version"], 1);
    assert_eq!(reply["snapshot"], p.snapshot.as_deref().unwrap());
    assert_eq!(reply["source_hash"], a.source_hash);
    assert_eq!(reply["producer"], "lexical-lines-v1");
    let lines = reply["lines"].as_array().unwrap();
    assert_eq!(lines.len(), 7);
    for (i, line) in CODE.lines().enumerate() {
        assert_eq!(lines[i]["line"], i + 1);
        assert_eq!(lines[i]["text"], line);
        assert_eq!(lines[i]["is_anchor"], i == 3);
        assert_eq!(
            lines[i]["kind"],
            if i == 3 {
                "indexed-anchor"
            } else {
                "observed-source-text"
            }
        );
    }
    assert_eq!(
        serde_json::from_slice::<Value>(&serde_json::to_vec(&reply).unwrap()).unwrap(),
        reply
    );
    assert!(serde_json::to_vec(&reply).unwrap().len() < 8192);
    assert_eq!(
        std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap(),
        db
    );
    assert_eq!(std::fs::read_to_string(f.source()).unwrap(), CODE);
    assert_eq!(
        s.context("a", "draft").unwrap()["history"][0]["text"],
        "synthetic human note"
    );
    for (line, radius, count) in [(1, 3, 4), (7, 3, 4), (4, 0, 1)] {
        let a = SourceAnchorInspection {
            line,
            radius,
            ..a_for(&a)
        };
        assert_eq!(
            s.inspect_source_anchor(&p, &a, &token()).unwrap()["lines"]
                .as_array()
                .unwrap()
                .len(),
            count
        );
    }
}
fn a_for(a: &SourceAnchorInspection) -> SourceAnchorInspection {
    SourceAnchorInspection {
        path: a.path.clone(),
        line: a.line,
        source_hash: a.source_hash.clone(),
        radius: a.radius,
    }
}
fn no_source() {
    panic!("invalid binding reached first source boundary");
}

#[test]
fn z_a1_complete_binding_and_evidence_hash_fail_before_source_access() {
    let (_f, mut s, p, a) = Fixture::new(CODE);
    // A second approved file makes order mismatches distinguishable from membership.
    std::fs::write(Path::new(&p.root).join("other.rs"), "// center other\n").unwrap();
    s.set_sources("a", vec!["code.rs".into(), "other.rs".into()])
        .unwrap();
    s.index("a", &mut LexicalLines, &token()).unwrap();
    let p = s.project("a").unwrap();
    let accesses = source_forget::SOURCE_ACCESSES.with(|n| n.get());
    for field in [
        "id", "root", "identity", "nonce", "order", "snapshot", "none", "unicode",
    ] {
        let mut wrong = s.project("a").unwrap();
        match field {
            "id" => wrong.id = "b".into(),
            "root" => wrong.root.push_str("-other"),
            "identity" => wrong.root_identity = "1:2".into(),
            "nonce" => wrong.incarnation = Some("0".repeat(32)),
            "order" => wrong.sources.reverse(),
            "snapshot" => wrong.snapshot = Some("0".repeat(64)),
            "none" => wrong.snapshot = None,
            "unicode" => wrong.root = format!("/{}", "λ".repeat(2048)),
            _ => unreachable!(),
        }
        assert!(
            s.inspect_anchor_scoped(&wrong, &a, &token(), no_source, || {})
                .is_err(),
            "{field}"
        );
    }
    let mut wrong = a_for(&a);
    wrong.source_hash = "0".repeat(64);
    assert!(
        s.inspect_anchor_scoped(&p, &wrong, &token(), no_source, || {})
            .is_err()
    );
    for (line, radius) in [(0, 0), (4097, 0), (4, 4), (3, 0), (99, 0)] {
        let wrong = SourceAnchorInspection {
            line,
            radius,
            ..a_for(&a)
        };
        assert!(
            s.inspect_anchor_scoped(&p, &wrong, &token(), no_source, || {})
                .is_err()
        );
    }
    // A registered but unindexed line is not an anchor API authority.
    s.db.execute("DELETE FROM evidence WHERE project='a' AND line=4", [])
        .unwrap();
    assert!(
        s.inspect_anchor_scoped(&p, &a, &token(), no_source, || {})
            .is_err()
    );
    assert_eq!(source_forget::SOURCE_ACCESSES.with(|n| n.get()), accesses);
}

#[test]
fn z_a1_same_id_new_nonce_and_cross_project_never_reach_sources() {
    for same_root in [false, true] {
        let (f, s, p, a) = Fixture::new(CODE);
        let mut peer = Store::open_existing(&f.0.join("store")).unwrap();
        peer.remove_project("a", &token()).unwrap();
        let root = if same_root {
            f.0.join("source")
        } else {
            let root = f.0.join("replacement");
            std::fs::create_dir(&root).unwrap();
            std::fs::write(root.join("code.rs"), CODE).unwrap();
            root
        };
        peer.add_project("a", &root, vec!["code.rs".into()])
            .unwrap();
        peer.index("a", &mut LexicalLines, &token()).unwrap();
        assert!(
            s.inspect_anchor_scoped(&p, &a, &token(), no_source, || {})
                .is_err()
        );
    }
}

#[test]
fn z_a3_source_failures_preserve_database_notes_and_recover_without_autoindex() {
    for change in [
        "edit", "delete", "rename", "symlink", "hardlink", "fifo", "root",
    ] {
        let (f, s, p, a) = Fixture::new(CODE);
        let db = std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap();
        match change {
            "edit" => std::fs::write(f.source(), "// center changed\n").unwrap(),
            "delete" => std::fs::remove_file(f.source()).unwrap(),
            "rename" => std::fs::rename(f.source(), f.0.join("renamed.rs")).unwrap(),
            "symlink" => {
                std::fs::rename(f.source(), f.0.join("original.rs")).unwrap();
                symlink(f.0.join("original.rs"), f.source()).unwrap();
            }
            "hardlink" => std::fs::hard_link(f.source(), f.0.join("alias.rs")).unwrap(),
            "fifo" => {
                std::fs::remove_file(f.source()).unwrap();
                assert!(
                    std::process::Command::new("mkfifo")
                        .arg(f.source())
                        .status()
                        .unwrap()
                        .success()
                );
            }
            "root" => {
                std::fs::rename(f.0.join("source"), f.0.join("old-source")).unwrap();
                std::fs::create_dir(f.0.join("source")).unwrap();
                std::fs::write(f.source(), CODE).unwrap();
            }
            _ => unreachable!(),
        }
        assert!(
            s.inspect_source_anchor(&p, &a, &token()).is_err(),
            "{change}"
        );
        assert_eq!(
            std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap(),
            db
        );
        assert_eq!(
            s.context("a", "draft").unwrap()["history"][0]["text"],
            "synthetic human note"
        );
        if change == "edit" {
            std::fs::write(f.source(), CODE).unwrap();
            assert!(s.inspect_source_anchor(&p, &a, &token()).is_ok());
        }
    }
}

#[test]
fn z_a3_final_source_change_cancellation_corruption_overflow_and_recovery() {
    let (f, s, p, a) = Fixture::new(CODE);
    for boundary in [0, 1, 2] {
        let cancel = AtomicBool::new(boundary == 0);
        let r = s.inspect_anchor_scoped(
            &p,
            &a,
            &cancel,
            || {
                if boundary == 1 {
                    cancel.store(true, Ordering::SeqCst);
                }
            },
            || {
                if boundary == 2 {
                    cancel.store(true, Ordering::SeqCst);
                }
            },
        );
        assert!(matches!(r, Err(Error::Canceled)));
        assert!(s.inspect_source_anchor(&p, &a, &token()).is_ok());
    }
    assert!(
        s.inspect_anchor_scoped(
            &p,
            &a,
            &token(),
            || {},
            || {
                std::fs::write(f.source(), "// center new bytes\n").unwrap();
            }
        )
        .is_err()
    );
    std::fs::write(f.source(), CODE).unwrap();
    s.db.execute("UPDATE evidence SET text='forged center' WHERE line=4", [])
        .unwrap();
    assert!(s.inspect_source_anchor(&p, &a, &token()).is_err());
    // Seven legal indexed full lines can exceed encoded output via escaping.
    let line = format!("// center{}\n", "\t".repeat(1000));
    let (_f, s, p, a) = Fixture::new(&line.repeat(7));
    let a = SourceAnchorInspection { line: 4, ..a };
    assert!(s.inspect_source_anchor(&p, &a, &token()).is_err());
    let a = SourceAnchorInspection { radius: 0, ..a };
    assert_eq!(
        s.inspect_source_anchor(&p, &a, &token()).unwrap()["lines"][0]["text"],
        line.trim_end_matches('\n')
    );
}

#[test]
fn z_a4_delete_journal_serializes_peer_replacement_and_wal_refuses() {
    let (f, s, p, a) = Fixture::new(CODE);
    let mut peer = Store::open_existing(&f.0.join("store")).unwrap();
    peer.db.busy_timeout(std::time::Duration::ZERO).unwrap();
    let reply = s
        .inspect_anchor_scoped(
            &p,
            &a,
            &token(),
            || {},
            || {
                assert!(peer.remove_project("a", &token()).is_err());
                assert!(peer.set_sources("a", vec![]).is_err());
            },
        )
        .unwrap();
    assert_eq!(reply["lines"][3]["is_anchor"], true);
    peer.remove_project("a", &token()).unwrap();
    assert!(
        s.inspect_anchor_scoped(&p, &a, &token(), no_source, || {})
            .is_err()
    );
    let (_f, s, p, a) = Fixture::new(CODE);
    s.db.pragma_update(None, "journal_mode", "WAL").unwrap();
    assert!(
        s.inspect_anchor_scoped(&p, &a, &token(), no_source, || {})
            .is_err()
    );
}

#[test]
fn z_a4_forget_and_omitted_path_rebuild_never_resurrect_anchor_or_notes() {
    let (f, mut s, p, a) = Fixture::new(CODE);
    s.forget_source("a", "code.rs", &token()).unwrap();
    assert!(
        s.inspect_anchor_scoped(&p, &a, &token(), no_source, || {})
            .is_err()
    );
    s.index("a", &mut LexicalLines, &token()).unwrap();
    let fresh = s.project("a").unwrap();
    assert!(
        s.inspect_anchor_scoped(&fresh, &a, &token(), no_source, || {})
            .is_err()
    );
    assert!(s.set_sources("a", vec!["code.rs".into()]).is_err());
    assert_eq!(std::fs::read_to_string(f.source()).unwrap(), CODE);
    assert_eq!(
        s.context("a", "draft").unwrap()["history"][0]["text"],
        "synthetic human note"
    );
}

#[test]
fn z_a2_sparse_extraction_is_not_arbitrary_registered_file_access() {
    struct CenterOnly;
    impl SourceExtractor for CenterOnly {
        fn producer(&self) -> &str {
            "synthetic-center-only-v1"
        }
        fn extract(&mut self, _: &str, _: &AtomicBool) -> Result<Vec<usize>> {
            Ok(vec![4])
        }
    }
    let (_f, mut s, _p, a) = Fixture::new(CODE);
    s.index("a", &mut CenterOnly, &token()).unwrap();
    let p = s.project("a").unwrap();
    let reply = s.inspect_source_anchor(&p, &a, &token()).unwrap();
    assert_eq!(reply["producer"], "synthetic-center-only-v1");
    assert_eq!(reply["lines"][0]["kind"], "observed-source-text");
    let wrong = SourceAnchorInspection { line: 1, ..a };
    assert!(
        s.inspect_anchor_scoped(&p, &wrong, &token(), no_source, || {})
            .is_err()
    );
}

#[test]
fn z_a3_nested_repository_and_final_store_dependency_fail_closed_and_recover() {
    let (f, mut s, _p, mut a) = Fixture::new(CODE);
    std::fs::create_dir(f.0.join("source/nested")).unwrap();
    std::fs::rename(f.source(), f.0.join("source/nested/code.rs")).unwrap();
    s.set_sources("a", vec!["nested/code.rs".into()]).unwrap();
    s.index("a", &mut LexicalLines, &token()).unwrap();
    a.path = "nested/code.rs".into();
    let p = s.project("a").unwrap();
    std::fs::create_dir(f.0.join("source/nested/.git")).unwrap();
    assert!(s.inspect_source_anchor(&p, &a, &token()).is_err());
    std::fs::remove_dir(f.0.join("source/nested/.git")).unwrap();
    assert!(s.inspect_source_anchor(&p, &a, &token()).is_ok());
    let db = std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap();
    assert!(
        s.inspect_anchor_scoped(
            &p,
            &a,
            &token(),
            || {},
            || {
                std::fs::rename(f.0.join("store"), f.0.join("held-store")).unwrap();
            }
        )
        .is_err()
    );
    std::fs::rename(f.0.join("held-store"), f.0.join("store")).unwrap();
    assert_eq!(
        std::fs::read(f.0.join("store/knowledge.sqlite")).unwrap(),
        db
    );
    assert!(s.inspect_source_anchor(&p, &a, &token()).is_ok());
}

#[test]
fn z_a1_unicode_root_bytes_and_manifest_hash_mismatch_precede_all_source_access() {
    let (f, mut s, p, a) = Fixture::new(CODE);
    s.remove_project("a", &token()).unwrap();
    let unicode = f.0.join("caf\u{e9}");
    std::fs::rename(&p.root, &unicode).unwrap();
    s.add_project("a", &unicode, vec!["code.rs".into()])
        .unwrap();
    s.index("a", &mut LexicalLines, &token()).unwrap();
    let mut p = s.project("a").unwrap();
    assert!(s.inspect_source_anchor(&p, &a, &token()).is_ok());
    p.root = p.root.replace('\u{e9}', "e\u{301}");
    let before = source_forget::SOURCE_ACCESSES.with(|n| n.get());
    assert!(
        s.inspect_anchor_scoped(&p, &a, &token(), no_source, || {})
            .is_err()
    );
    let p = s.project("a").unwrap();
    // A forged evidence hash matching the request still cannot bypass the manifest.
    let a = SourceAnchorInspection {
        source_hash: "0".repeat(64),
        ..a
    };
    s.db.execute("UPDATE evidence SET hash=?1 WHERE line=4", [&a.source_hash])
        .unwrap();
    assert!(
        s.inspect_anchor_scoped(&p, &a, &token(), no_source, || {})
            .is_err()
    );
    assert_eq!(source_forget::SOURCE_ACCESSES.with(|n| n.get()), before);
}
