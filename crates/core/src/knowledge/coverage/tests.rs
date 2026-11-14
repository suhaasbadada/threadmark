//! AD synthetic actual SQLite/source acceptance; no network, host, or deadline fixtures.
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
            "threadmark-coverage-{}-{}",
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
        s.write_context("a", "draft", "note", "synthetic human history", false)
            .unwrap();
        s.write_context("a", "draft", "note", "synthetic revised history", true)
            .unwrap();
        let p = s.project("a").unwrap();
        (f, s, p)
    }
    fn source(&self, path: &str) -> PathBuf {
        self.0.join("source").join(path)
    }
    fn db(&self) -> PathBuf {
        self.0.join("store/knowledge.sqlite")
    }
    fn inspect(&self) -> Store {
        Store::open_existing_for_inspection(&self.0.join("store")).unwrap()
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}
fn no_sources() {
    panic!("invalid request reached source boundary")
}

#[test]
fn ad_a2_current_full_policy_metadata_only_and_exact_preservation() {
    let names: Vec<_> = (0..64).map(|i| format!("file{i}.rs")).collect();
    let files: Vec<_> = names
        .iter()
        .map(|n| (n.as_str(), b"synthetic lexical anchor\n".as_slice()))
        .collect();
    let (f, s, p) = Fixture::new(&files, true);
    let db = std::fs::read(f.db()).unwrap();
    let history = s.context("a", "draft").unwrap();
    let before = entries(&f.0.join("store"));
    let reader = f.inspect();
    let report = reader.coverage_report(&p, &token()).unwrap();
    assert_eq!(report["summary"]["project_snapshot_current"], true);
    assert_eq!(report["summary"]["matching_file_count"], 64);
    assert_eq!(report["summary"]["stored_anchor_record_count"], 64);
    assert_eq!(report["semantic_completeness"], "not-assessed");
    for (i, name) in names.iter().enumerate() {
        assert_eq!(report["files"][i]["path"], *name);
        assert_eq!(report["files"][i]["status"], "current");
        assert_eq!(
            std::fs::read(f.source(name)).unwrap(),
            b"synthetic lexical anchor\n"
        );
    }
    let json = serde_json::to_string(&report).unwrap();
    assert!(!json.contains("synthetic"));
    assert!(!json.contains(&p.root));
    assert!(json.len() < MAX_FILE);
    assert!(reader.db.execute("DELETE FROM evidence", []).is_err());
    assert_eq!(std::fs::read(f.db()).unwrap(), db);
    assert_eq!(s.context("a", "draft").unwrap(), history);
    assert_eq!(entries(&f.0.join("store")), before);
}
fn entries(path: &Path) -> Vec<std::ffi::OsString> {
    let mut names: Vec<_> = std::fs::read_dir(path)
        .unwrap()
        .map(|e| e.unwrap().file_name())
        .collect();
    names.sort();
    names
}

#[test]
fn ad_a2_unindexed_empty_blank_zero_anchor_and_empty_policy() {
    for indexed in [false, true] {
        let (f, _, p) = Fixture::new(&[("empty.txt", b""), ("blank.txt", b" \n\n")], indexed);
        let report = f.inspect().coverage_report(&p, &token()).unwrap();
        assert_eq!(report["files"][0]["status"], "readable-empty");
        assert_eq!(report["files"][0]["baseline_matches"], indexed);
        assert_eq!(
            report["files"][1]["status"],
            if indexed { "current" } else { "unindexed" }
        );
        assert_eq!(report["summary"]["stored_anchor_record_count"], 0);
        assert_eq!(report["summary"]["project_snapshot_current"], indexed);
        assert_eq!(report["baseline_snapshot"].is_null(), !indexed);
    }
    let (f, _, p) = Fixture::new(&[], false);
    let r = f.inspect().coverage_report(&p, &token()).unwrap();
    assert_eq!(r["summary"]["approved_file_count"], 0);
    assert_eq!(r["summary"]["project_snapshot_current"], false);
    assert_eq!(r["semantic_completeness"], "not-assessed");
}

#[test]
fn ad_a2_mixed_changed_replaced_unavailable_recovery_without_build() {
    let (f, s, p) = Fixture::new(&[("a.rs", b"anchor\n"), ("b.rs", b"other\n")], true);
    let baseline = std::fs::read(f.db()).unwrap();
    std::fs::write(f.source("a.rs"), b"edited\n").unwrap();
    let r = f.inspect().coverage_report(&p, &token()).unwrap();
    assert_eq!(r["files"][0]["status"], "changed");
    assert_eq!(r["files"][1]["status"], "current");
    assert_eq!(r["summary"]["project_snapshot_current"], false);
    std::fs::write(f.source("a.rs"), b"anchor\n").unwrap();
    assert_eq!(
        f.inspect().coverage_report(&p, &token()).unwrap()["summary"]["project_snapshot_current"],
        true
    );
    std::fs::rename(f.source("a.rs"), f.source("saved.rs")).unwrap();
    std::fs::write(f.source("a.rs"), b"anchor\n").unwrap();
    assert_eq!(
        f.inspect().coverage_report(&p, &token()).unwrap()["files"][0]["status"],
        "replaced"
    );
    std::fs::remove_file(f.source("a.rs")).unwrap();
    for unsafe_kind in 0..5 {
        match unsafe_kind {
            0 => {} // Opaque missing, never labeled as missing.
            1 => symlink(f.source("b.rs"), f.source("a.rs")).unwrap(),
            2 => std::fs::hard_link(f.source("b.rs"), f.source("a.rs")).unwrap(),
            3 => std::fs::write(f.source("a.rs"), [0xff]).unwrap(),
            _ => std::fs::write(f.source("a.rs"), b"nul\0").unwrap(),
        }
        let r = f.inspect().coverage_report(&p, &token()).unwrap();
        assert_eq!(r["files"][0]["status"], "unavailable-or-unsafe");
        assert!(r["files"][0]["current_metadata"].is_null());
        assert_eq!(r["summary"]["project_snapshot_current"], false);
        assert_eq!(r["summary"]["needs_readability_review"], true);
        if unsafe_kind != 2 {
            assert_eq!(r["files"][1]["status"], "current");
        }
        if unsafe_kind != 0 {
            std::fs::remove_file(f.source("a.rs")).unwrap();
        }
    }
    std::fs::rename(f.source("saved.rs"), f.source("a.rs")).unwrap();
    assert_eq!(
        f.inspect().coverage_report(&p, &token()).unwrap()["summary"]["project_snapshot_current"],
        true
    );
    assert_eq!(std::fs::read(f.db()).unwrap(), baseline);
    assert_eq!(s.project("a").unwrap().snapshot, p.snapshot);
}

#[test]
fn ad_a1_all_binding_mismatches_precede_first_source_access() {
    let (f, _, p) = Fixture::new(&[("a.rs", b"a\n"), ("b.rs", b"b\n")], true);
    let reader = f.inspect();
    for case in 0..8 {
        let mut bad = Project {
            id: p.id.clone(),
            root: p.root.clone(),
            root_identity: p.root_identity.clone(),
            incarnation: p.incarnation.clone(),
            sources: p.sources.clone(),
            snapshot: p.snapshot.clone(),
        };
        match case {
            0 => bad.root.push('x'),
            1 => bad.root_identity.push('1'),
            2 => bad.incarnation = Some("0".repeat(32)),
            3 => bad.sources.reverse(),
            4 => bad.snapshot = None,
            5 => bad.snapshot = Some("0".repeat(64)),
            6 => bad.incarnation = None,
            _ => bad.root = format!("/{}", "λ".repeat(2048)),
        }
        source_forget::SOURCE_ACCESSES.with(|n| n.set(0));
        assert!(
            reader
                .coverage_scoped(&bad, &token(), no_sources, || {})
                .is_err()
        );
        source_forget::SOURCE_ACCESSES.with(|n| assert_eq!(n.get(), 0));
    }
}

#[test]
fn ad_a4_corrupt_baseline_and_evidence_fail_before_sources() {
    for case in 0..9 {
        let (f, s, mut p) = Fixture::new(&[("a.rs", b"anchor\n")], true);
        match case {
            0 => {
                s.db.execute("UPDATE projects SET manifest='[]'", [])
                    .unwrap();
            }
            1..=3 => {
                let mut m: Value = serde_json::from_str(
                    &s.db
                        .query_row("SELECT manifest FROM projects", [], |r| {
                            r.get::<_, String>(0)
                        })
                        .unwrap(),
                )
                .unwrap();
                match case {
                    1 => m[0]["path"] = json!("outside.rs"),
                    2 => m[0]["hash"] = json!("f".repeat(63)),
                    _ => m[0]["extra"] = json!(true),
                }
                let encoded = m.to_string();
                s.db.execute(
                    "UPDATE projects SET manifest=?1,snapshot=?2",
                    params![encoded, sha256(encoded.as_bytes())],
                )
                .unwrap();
                p = s.project("a").unwrap();
            }
            4 => {
                s.db.execute("UPDATE evidence SET path='outside.rs'", [])
                    .unwrap();
            }
            5 => {
                s.db.execute("UPDATE evidence SET hash=?1", ["0".repeat(64)])
                    .unwrap();
            }
            6 => {
                s.db.execute("UPDATE evidence SET line=4097", []).unwrap();
            }
            7 => {
                s.db.execute("UPDATE projects SET snapshot=NULL,manifest=NULL", [])
                    .unwrap();
                p = s.project("a").unwrap();
            }
            _ => {
                s.db.execute("DROP TABLE evidence", []).unwrap();
            }
        }
        let before = std::fs::read(f.db()).unwrap();
        assert!(s.coverage_scoped(&p, &token(), no_sources, || {}).is_err());
        assert_eq!(std::fs::read(f.db()).unwrap(), before);
    }
}

#[test]
fn ad_a3_cancel_before_after_read_and_publication_source_change() {
    let (f, _, p) = Fixture::new(&[("a.rs", b"anchor\n")], true);
    let reader = f.inspect();
    let c = AtomicBool::new(true);
    assert!(matches!(
        reader.coverage_scoped(&p, &c, no_sources, || {}),
        Err(Error::Canceled)
    ));
    c.store(false, Ordering::SeqCst);
    assert!(matches!(
        reader.coverage_scoped(&p, &c, || c.store(true, Ordering::SeqCst), || {}),
        Err(Error::Canceled)
    ));
    c.store(false, Ordering::SeqCst);
    assert!(matches!(
        reader.coverage_scoped(&p, &c, || {}, || c.store(true, Ordering::SeqCst)),
        Err(Error::Canceled)
    ));
    assert!(
        reader
            .coverage_scoped(
                &p,
                &token(),
                || {},
                || {
                    std::fs::write(f.source("a.rs"), b"changed\n").unwrap();
                }
            )
            .is_err()
    );
    std::fs::write(f.source("a.rs"), b"anchor\n").unwrap();
    reader.coverage_report(&p, &token()).unwrap();
}

#[test]
fn ad_a4_delete_guard_blocks_peer_revocation_and_store_replacement_fails() {
    let (f, _, p) = Fixture::new(&[("a.rs", b"anchor\n")], true);
    let peer = Store::open_existing(&f.0.join("store")).unwrap();
    peer.db.busy_timeout(std::time::Duration::ZERO).unwrap();
    let reader = f.inspect();
    reader
        .coverage_scoped(
            &p,
            &token(),
            || {},
            || {
                assert!(
                    peer.db
                        .execute(
                            "UPDATE projects SET sources='[]',snapshot=NULL,manifest=NULL",
                            []
                        )
                        .is_err()
                );
            },
        )
        .unwrap();
    assert!(
        reader
            .coverage_scoped(
                &p,
                &token(),
                || {},
                || {
                    std::fs::rename(f.0.join("store"), f.0.join("saved-store")).unwrap();
                    std::fs::create_dir(f.0.join("store")).unwrap();
                }
            )
            .is_err()
    );
}

#[test]
fn ad_a3_failed_utf8_and_nul_reads_still_exhaust_aggregate_budget() {
    let names: Vec<_> = (0..17).map(|i| format!("file{i}.txt")).collect();
    for byte in [0_u8, 0xff] {
        let content = vec![byte; MAX_FILE];
        let files: Vec<_> = names
            .iter()
            .map(|n| (n.as_str(), content.as_slice()))
            .collect();
        let (f, _, p) = Fixture::new(&files, false);
        assert!(f.inspect().coverage_report(&p, &token()).is_err());
    }
    let (f, _, p) = Fixture::new(&[("a.txt", b"a")], false);
    std::fs::write(f.source("a.txt"), vec![b'a'; MAX_FILE + 1]).unwrap();
    assert!(f.inspect().coverage_report(&p, &token()).is_err());
    std::fs::write(f.source("a.txt"), "\n".repeat(4097)).unwrap();
    assert!(f.inspect().coverage_report(&p, &token()).is_err());
}

#[test]
fn ad_a3_malformed_observed_bytes_cannot_hide_line_budget_violations() {
    for text in ["", "a", "\n", "\r\n", "a\rb", "λ\n\n", "λ\r\nlast"] {
        assert_eq!(observed_source_lines(text.as_bytes()), text.lines().count());
    }
    let (f, s, p) = Fixture::new(&[("a.txt", b"initial")], false);
    let db = std::fs::read(f.db()).unwrap();
    let history = s.context("a", "draft").unwrap();
    for invalid in [0, 0xff] {
        for count in [4096, 4097] {
            let mut bytes = vec![b'\n'; count];
            bytes.push(invalid);
            std::fs::write(f.source("a.txt"), bytes).unwrap();
            assert!(f.inspect().coverage_report(&p, &token()).is_err());
            assert_eq!(std::fs::read(f.db()).unwrap(), db);
            assert_eq!(s.context("a", "draft").unwrap(), history);
        }
        let mut bytes = vec![b'\n'; 4095];
        bytes.push(invalid);
        std::fs::write(f.source("a.txt"), bytes).unwrap();
        let report = f.inspect().coverage_report(&p, &token()).unwrap();
        assert_eq!(report["files"][0]["status"], "unavailable-or-unsafe");
    }
    std::fs::write(f.source("a.txt"), b"restored\n").unwrap();
    assert!(f.inspect().coverage_report(&p, &token()).is_ok());
}

#[test]
fn ad_a5_forget_rebuild_never_reintroduces_path_or_human_text() {
    let (f, mut s, p) = Fixture::new(&[("a.rs", b"anchor\n"), ("b.rs", b"other\n")], true);
    let a = std::fs::read(f.source("a.rs")).unwrap();
    let history = s.context("a", "draft").unwrap();
    s.forget_source("a", "a.rs", &token()).unwrap();
    assert!(f.inspect().coverage_report(&p, &token()).is_err());
    s.index("a", &mut LexicalLines, &token()).unwrap();
    let current = s.project("a").unwrap();
    let db = std::fs::read(f.db()).unwrap();
    let r = f.inspect().coverage_report(&current, &token()).unwrap();
    assert_eq!(r["files"].as_array().unwrap().len(), 1);
    assert_eq!(r["files"][0]["path"], "b.rs");
    assert_eq!(std::fs::read(f.source("a.rs")).unwrap(), a);
    assert_eq!(s.context("a", "draft").unwrap(), history);
    assert_eq!(std::fs::read(f.db()).unwrap(), db);
}

#[test]
fn ad_a4_wal_refused_without_sqlite_open_or_directory_changes() {
    let (f, s, _) = Fixture::new(&[("a.rs", b"anchor\n")], true);
    s.db.pragma_update(None, "journal_mode", "WAL").unwrap();
    drop(s);
    let bytes = std::fs::read(f.db()).unwrap();
    let names = entries(&f.0.join("store"));
    assert_eq!(&bytes[18..20], &[2, 2]);
    assert!(Store::open_existing_for_inspection(&f.0.join("store")).is_err());
    assert_eq!(std::fs::read(f.db()).unwrap(), bytes);
    assert_eq!(entries(&f.0.join("store")), names);
    let db = Connection::open(f.db()).unwrap();
    assert_eq!(
        db.pragma_query_value(None, "journal_mode", |r| r.get::<_, String>(0))
            .unwrap(),
        "wal"
    );
    assert_eq!(
        std::fs::metadata(f.db()).unwrap().permissions().mode() & 0o777,
        0o600
    );
}

#[test]
fn ad_a3_cancellation_inside_shared_chunk_read_and_escaped_whole_output_limit() {
    let (f, _, p) = Fixture::new(&[("a.txt", b"small")], false);
    std::fs::write(f.source("a.txt"), vec![b'a'; 20000]).unwrap();
    let c = token();
    CANCEL_AFTER_CHUNKS.with(|n| n.set(Some(2)));
    assert!(matches!(
        f.inspect().coverage_report(&p, &c),
        Err(Error::Canceled)
    ));
    c.store(false, Ordering::SeqCst);
    f.inspect().coverage_report(&p, &c).unwrap();
    // Whole JSON encoding, not character or unescaped value length; include newline.
    let mut reply = json!({"x":""});
    let base = serde_json::to_vec(&reply).unwrap().len() + 1;
    reply["x"] = json!("a".repeat(MAX_FILE - base));
    output_bound(&reply).unwrap();
    reply["x"] = json!("a".repeat(MAX_FILE - base + 1));
    assert!(output_bound(&reply).is_err());
    reply["x"] = json!("\0".repeat(MAX_FILE / 6));
    assert!(output_bound(&reply).is_err());
}

#[test]
fn ad_a3_fifo_nested_repository_unreadable_and_directory_are_local_unknowns() {
    let (f, _, p) = Fixture::new(&[("a.rs", b"anchor\n"), ("b.rs", b"other\n")], true);
    std::fs::remove_file(f.source("a.rs")).unwrap();
    assert!(
        std::process::Command::new("mkfifo")
            .arg(f.source("a.rs"))
            .status()
            .unwrap()
            .success()
    );
    let r = f.inspect().coverage_report(&p, &token()).unwrap();
    assert_eq!(r["files"][0]["status"], "unavailable-or-unsafe");
    assert_eq!(r["files"][1]["status"], "current");
    assert!(r["summary"]["needs_build"].is_null());
    std::fs::remove_file(f.source("a.rs")).unwrap();
    std::fs::create_dir(f.source("a.rs")).unwrap();
    assert_eq!(
        f.inspect().coverage_report(&p, &token()).unwrap()["files"][0]["status"],
        "unavailable-or-unsafe"
    );
    std::fs::remove_dir(f.source("a.rs")).unwrap();
    std::fs::write(f.source("a.rs"), b"anchor\n").unwrap();
    std::fs::set_permissions(f.source("a.rs"), std::fs::Permissions::from_mode(0o0)).unwrap();
    assert_eq!(
        f.inspect().coverage_report(&p, &token()).unwrap()["files"][0]["status"],
        "unavailable-or-unsafe"
    );
    std::fs::set_permissions(f.source("a.rs"), std::fs::Permissions::from_mode(0o600)).unwrap();
    let (f, mut s, _) = Fixture::new(&[("b.rs", b"other\n")], false);
    std::fs::create_dir(f.source("nested")).unwrap();
    std::fs::write(f.source("nested/a.rs"), b"anchor\n").unwrap();
    std::fs::write(f.source("nested/.git"), b"synthetic nested repository").unwrap();
    s.set_sources("a", vec!["nested/a.rs".into(), "b.rs".into()])
        .unwrap();
    let p = s.project("a").unwrap();
    let r = f.inspect().coverage_report(&p, &token()).unwrap();
    assert_eq!(r["files"][0]["status"], "unavailable-or-unsafe");
    assert_eq!(r["files"][1]["status"], "unindexed");
}

#[test]
fn ad_a4_dependency_loss_before_and_after_reads_fails_whole() {
    for table in [
        "evidence",
        "context",
        "project_incarnations",
        "forgotten_sources",
    ] {
        let (f, s, p) = Fixture::new(&[("a.rs", b"anchor\n")], true);
        s.db.execute(&format!("DROP TABLE {table}"), []).unwrap();
        assert!(s.coverage_scoped(&p, &token(), no_sources, || {}).is_err());
        assert!(Store::open_existing_for_inspection(&f.0.join("store")).is_err());
    }
    let (_f, s, p) = Fixture::new(&[("a.rs", b"anchor\n")], true);
    assert!(
        s.coverage_scoped(
            &p,
            &token(),
            || {},
            || {
                s.db.execute("DROP TABLE context", []).unwrap();
            }
        )
        .is_err()
    );
}

#[test]
fn ad_a4_record_limit_and_manifest_order_are_checked_before_source_io() {
    let (_f, s, p) = Fixture::new(
        &[
            ("a.rs", b"a\n"),
            ("b.rs", b"b\n"),
            ("c.rs", b"c\n"),
            ("d.rs", b"d\n"),
            ("e.rs", b"e\n"),
        ],
        true,
    );
    let encoded: String =
        s.db.query_row("SELECT manifest FROM projects", [], |r| r.get(0))
            .unwrap();
    let manifest: Vec<Source> = serde_json::from_str(&encoded).unwrap();
    s.db.execute("DELETE FROM evidence", []).unwrap();
    s.db.execute_batch("BEGIN").unwrap();
    for n in 0..16385 {
        let source = &manifest[n / 4096];
        s.db.execute(
            "INSERT INTO evidence VALUES('a',?1,?2,'synthetic',?3,'lexical-lines-v1')",
            params![source.path, (n % 4096 + 1) as i64, source.hash],
        )
        .unwrap();
    }
    s.db.execute_batch("COMMIT").unwrap();
    assert!(s.coverage_scoped(&p, &token(), no_sources, || {}).is_err());
    s.db.execute("DELETE FROM evidence", []).unwrap();
    let mut manifest = manifest;
    manifest.reverse();
    let encoded = serde_json::to_string(&manifest).unwrap();
    s.db.execute(
        "UPDATE projects SET manifest=?1,snapshot=?2",
        params![encoded, sha256(encoded.as_bytes())],
    )
    .unwrap();
    let p = s.project("a").unwrap();
    assert!(s.coverage_scoped(&p, &token(), no_sources, || {}).is_err());
}

#[test]
fn ad_a4_publication_rebinding_never_adopts_replacement_project() {
    let (f, s, p) = Fixture::new(&[("a.rs", b"anchor\n")], true);
    std::fs::create_dir(f.0.join("replacement")).unwrap();
    std::fs::write(
        f.0.join("replacement/a.rs"),
        b"synthetic private replacement\n",
    )
    .unwrap();
    let db = std::fs::read(f.db()).unwrap();
    assert!(
        s.coverage_scoped(
            &p,
            &token(),
            || {},
            || {
                s.db.execute(
                    "UPDATE projects SET root=?1",
                    [f.0.join("replacement").to_str().unwrap()],
                )
                .unwrap();
                s.db.execute(
                    "UPDATE project_incarnations SET incarnation=?1",
                    ["0".repeat(32)],
                )
                .unwrap();
            }
        )
        .is_err()
    );
    // Diagnostic failure rolls back injected same-connection peer simulation.
    assert_eq!(std::fs::read(f.db()).unwrap(), db);
    assert_eq!(s.project("a").unwrap().root, p.root);
    let report = s.coverage_report(&p, &token()).unwrap();
    assert!(!report.to_string().contains("synthetic private replacement"));
    assert!(
        s.coverage_scoped(
            &p,
            &token(),
            || {},
            || {
                std::fs::remove_file(f.source("a.rs")).unwrap();
            }
        )
        .is_err()
    );
}

#[test]
fn ad_a4_refused_source_observations_change_without_becoming_current_metadata() {
    let (f, _, p) = Fixture::new(&[("a.rs", b"anchor\n"), ("b.rs", b"other\n")], true);
    let reader = f.inspect();
    std::fs::write(f.source("a.rs"), b"first\0").unwrap();
    let r = reader.coverage_report(&p, &token()).unwrap();
    assert!(r["files"][0]["current_metadata"].is_null());
    assert_eq!(r["files"][1]["status"], "current");
    assert!(
        reader
            .coverage_scoped(
                &p,
                &token(),
                || {},
                || {
                    std::fs::write(f.source("a.rs"), b"second\0").unwrap();
                }
            )
            .is_err()
    );
    std::fs::remove_file(f.source("a.rs")).unwrap();
    assert!(
        reader
            .coverage_scoped(
                &p,
                &token(),
                || {},
                || {
                    std::fs::write(f.source("a.rs"), b"anchor\n").unwrap();
                }
            )
            .is_err()
    );
}
