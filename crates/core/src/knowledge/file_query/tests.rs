//! AK acceptance: real SQLite and synthetic source bytes, no alternate retrieval engine.
use super::*;

struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let p = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-file-query-{}-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::create_dir(&p).unwrap();
        std::fs::create_dir(p.join("source")).unwrap();
        Self(p)
    }
    fn write(&self, path: &str, text: &str) {
        std::fs::write(self.0.join("source").join(path), text).unwrap();
    }
    fn store(&self, paths: &[&str]) -> Store {
        let mut s = Store::open(&self.0.join("store")).unwrap();
        s.add_project(
            "a",
            &self.0.join("source"),
            paths.iter().map(|s| (*s).into()).collect(),
        )
        .unwrap();
        s.index("a", &mut LexicalLines, &token()).unwrap();
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
fn request(mode: FileQueryMode, query: &str, paths: &[&str]) -> FileQuery {
    FileQuery {
        mode,
        query: query.into(),
        selected_paths: paths.iter().map(|p| (*p).into()).collect(),
    }
}
fn modes() -> [FileQueryMode; 2] {
    [FileQueryMode::Literal, FileQueryMode::RankedAnyTerms]
}

#[test]
fn filter_precedes_scores_top_eight_and_byte_budget_and_preserves_defaults() {
    let f = Fixture::new();
    f.write(
        "a.rs",
        &(format!("alpha beta beta{}\n", "\\\"".repeat(400))).repeat(12),
    );
    f.write("z.rs", "alpha beta\nalpha beta\n");
    let s = f.store(&["z.rs", "a.rs"]);
    let p = s.project("a").unwrap();
    let literal = s.query_bound(&p, "alpha", &token()).unwrap();
    let ranked = s.query_terms_bound(&p, "alpha beta", &token()).unwrap();
    for mode in modes() {
        let q = if mode == FileQueryMode::Literal {
            "alpha"
        } else {
            "alpha beta"
        };
        let r = s
            .query_files_bound(&p, &request(mode, q, &["z.rs"]), &token())
            .unwrap();
        assert_eq!(r["selected_paths"], json!(["z.rs"]));
        assert_eq!(r["matching_anchors"], 2);
        assert_eq!(r["scanned_anchors"], 2);
        assert_eq!(r["truncated"], false);
        assert_eq!(r["results"].as_array().unwrap().len(), 2);
        assert_eq!(r["results"][0]["path"], "z.rs");
        assert_eq!(r["results"][0]["line"], 1);
        assert_eq!(r["results"][1]["line"], 2);
        assert!(serde_json::to_vec(&r).unwrap().len() < 8192);
    }
    assert_eq!(s.query_bound(&p, "alpha", &token()).unwrap(), literal);
    assert_eq!(
        s.query_terms_bound(&p, "alpha beta", &token()).unwrap(),
        ranked
    );
}

#[test]
fn canonical_order_full_subset_equivalence_unicode_and_exact_literal_folding() {
    let f = Fixture::new();
    f.write("z.rs", "ALPHA\nÄ\né\ne\u{301}\nİ\nquote\"\\\n");
    f.write("a.rs", "ALPHA\n");
    let s = f.store(&["z.rs", "a.rs"]);
    let p = s.project("a").unwrap();
    for mode in modes() {
        for q in [
            "alpha",
            "ä",
            "Ä",
            "é",
            "e\u{301}",
            "İ",
            "quote\"\\",
            "absent",
        ] {
            let r = s
                .query_files_bound(&p, &request(mode, q, &["a.rs", "z.rs"]), &token())
                .unwrap();
            let old = if mode == FileQueryMode::Literal {
                s.query_bound(&p, q, &token())
            } else {
                s.query_terms_bound(&p, q, &token())
            }
            .unwrap();
            assert_eq!(r["results"], old["results"]);
            assert_eq!(r["truncated"], old["truncated"]);
            assert_eq!(r["selected_paths"], json!(["z.rs", "a.rs"]));
            assert_eq!(
                r,
                s.query_files_bound(&p, &request(mode, q, &["z.rs", "a.rs"]), &token())
                    .unwrap()
            );
            if q == "ä" {
                assert_eq!(
                    r["matching_anchors"],
                    if mode == FileQueryMode::Literal { 0 } else { 1 }
                );
            }
        }
    }
}

#[test]
fn unselected_changed_deleted_symlink_hardlink_and_fifo_suppress_everything() {
    use std::os::unix::fs::symlink;
    for mode in modes() {
        for mutation in 0..5 {
            let f = Fixture::new();
            f.write("a.rs", "alpha\n");
            f.write("z.rs", "alpha\n");
            let s = f.store(&["a.rs", "z.rs"]);
            let p = s.project("a").unwrap();
            match mutation {
                0 => f.write("a.rs", "changed\n"),
                1 => std::fs::remove_file(f.0.join("source/a.rs")).unwrap(),
                2 => {
                    std::fs::remove_file(f.0.join("source/a.rs")).unwrap();
                    symlink("z.rs", f.0.join("source/a.rs")).unwrap();
                }
                3 => {
                    std::fs::remove_file(f.0.join("source/a.rs")).unwrap();
                    std::fs::hard_link(f.0.join("source/z.rs"), f.0.join("source/a.rs")).unwrap();
                }
                _ => {
                    std::fs::remove_file(f.0.join("source/a.rs")).unwrap();
                    assert!(
                        std::process::Command::new("mkfifo")
                            .arg(f.0.join("source/a.rs"))
                            .status()
                            .unwrap()
                            .success()
                    );
                }
            }
            let r = s
                .query_files_bound(&p, &request(mode, "alpha", &["z.rs"]), &token())
                .unwrap();
            assert_eq!(r["currentness"], "stale-or-unindexed");
            assert_eq!(r["results"], json!([]));
            assert_eq!(r["matching_anchors"], 0);
        }
    }
}

#[test]
fn complete_binding_precedes_source_authority_and_evidence_sql_even_after_precheck() {
    for mode in modes() {
        for mutation in 0..5 {
            let f = Fixture::new();
            f.write("a.rs", "alpha\n");
            f.write("z.rs", "alpha\n");
            let s = f.store(&["a.rs", "z.rs"]);
            let mut p = s.project("a").unwrap();
            match mutation {
                0 => p.root.push('x'),
                1 => p.root_identity.push('0'),
                2 => p.incarnation = Some("0".repeat(32)),
                3 => p.snapshot = Some("0".repeat(64)),
                _ => p.sources.reverse(),
            }
            let r = request(mode, "alpha", &["z.rs"]).canonical(&p).unwrap();
            let result = s.query_selected_pipeline(
                "a",
                &r.query,
                &token(),
                (Some(&p), Some(&r)),
                || panic!("source authority before complete binding"),
                || {},
            );
            assert!(
                matches!(result, Err(Error::ScopeMismatch)),
                "{mode:?} {mutation}: {result:?}"
            );
            s.db.execute("DROP TABLE evidence", []).unwrap();
            // V4 integrity validation may detect the missing dependency first;
            // neither error may reach the first source authority callback.
            assert!(
                s.query_selected_pipeline(
                    "a",
                    &r.query,
                    &token(),
                    (Some(&p), Some(&r)),
                    || panic!("SQL failure reached source authority"),
                    || {}
                )
                .is_err()
            );
        }
    }
}

#[test]
fn invalid_subsets_and_query_metadata_are_pure_and_byte_bounded() {
    let f = Fixture::new();
    f.write("a.rs", "alpha\n");
    let s = f.store(&["a.rs"]);
    let p = s.project("a").unwrap();
    for paths in [
        vec![],
        vec!["a.rs", "a.rs"],
        vec!["unknown.rs"],
        vec!["../a.rs"],
        vec![".git/config"],
        vec!["a.rs"; 65],
    ] {
        for mode in modes() {
            assert!(request(mode, "alpha", &paths).validate(&p).is_err());
        }
    }
    for mode in modes() {
        for q in ["".to_string(), "é".repeat(129), "a\0b".into()] {
            assert!(request(mode, &q, &["a.rs"]).validate(&p).is_err());
        }
        let mut missing = s.project("a").unwrap();
        missing.incarnation = None;
        assert!(request(mode, "a", &["a.rs"]).validate(&missing).is_err());
    }
    assert!(
        request(FileQueryMode::Literal, &"é".repeat(128), &["a.rs"])
            .validate(&p)
            .is_ok()
    );
    assert!(
        request(FileQueryMode::RankedAnyTerms, &"é".repeat(33), &["a.rs"])
            .validate(&p)
            .is_err()
    );
}

#[test]
fn whole_entries_frame_and_explicit_header_overflow() {
    let f = Fixture::new();
    let line = format!("alpha{}", "\"\\".repeat(500));
    f.write("a.rs", &(line.clone() + "\n").repeat(8));
    let s = f.store(&["a.rs"]);
    let p = s.project("a").unwrap();
    for mode in modes() {
        let r = s
            .query_files_bound(&p, &request(mode, "alpha", &["a.rs"]), &token())
            .unwrap();
        assert!(serde_json::to_vec(&r).unwrap().len() < 8192);
        assert_eq!(r["truncated"], true);
        assert_eq!(r["matching_anchors"], 8);
        assert!(
            r["results"]
                .as_array()
                .unwrap()
                .iter()
                .all(|r| r["text"] == line)
        );
        assert!(r["results"].as_array().unwrap().len() < 8);
    }
    let g = Fixture::new();
    let mut t = Store::open(&g.0.join("store")).unwrap();
    let paths: Vec<_> = (0..64)
        .map(|i| format!("f{i:02}/{}.rs", "x".repeat(230)))
        .collect();
    t.add_project("a", &g.0.join("source"), paths.clone())
        .unwrap();
    let p = t.project("a").unwrap();
    let r = FileQuery {
        query: "alpha".into(),
        mode: FileQueryMode::Literal,
        selected_paths: paths,
    };
    assert!(t.query_files_bound(&p, &r, &token()).is_err());
}

#[test]
fn publication_peer_replacement_policy_snapshot_source_cancel_and_dependency() {
    for mode in modes() {
        for mutation in 0..6 {
            let f = Fixture::new();
            f.write("a.rs", "alpha\n");
            f.write("z.rs", "alpha\n");
            let s = f.store(&["a.rs", "z.rs"]);
            let p = s.project("a").unwrap();
            let mut other = Store::open_existing(&f.0.join("store")).unwrap();
            let r = request(mode, "alpha", &["z.rs"]).canonical(&p).unwrap();
            let cancel = token();
            let result = s.query_selected_pipeline(
                "a",
                &r.query,
                &cancel,
                (Some(&p), Some(&r)),
                || {},
                || match mutation {
                    0 => cancel.store(true, Ordering::SeqCst),
                    1 => f.write("a.rs", "changed\n"),
                    2 => other.set_sources("a", vec!["z.rs".into()]).unwrap(),
                    3 => {
                        other.remove_project("a", &token()).unwrap();
                        f.write("z.rs", "B alpha\n");
                        other
                            .add_project("a", &f.0.join("source"), vec!["z.rs".into()])
                            .unwrap();
                        other.index("a", &mut LexicalLines, &token()).unwrap();
                    }
                    4 => {
                        f.write("a.rs", "changed\n");
                        other.index("a", &mut LexicalLines, &token()).unwrap();
                    }
                    _ => {
                        other.db.execute("DROP TABLE projects", []).unwrap();
                    }
                },
            );
            if mutation == 1 {
                let r = result.unwrap();
                assert_eq!(r["results"], json!([]));
                assert_eq!(r["matching_anchors"], 0);
                assert_eq!(r["truncated"], false);
            } else {
                assert!(result.is_err());
            }
        }
    }
}

#[test]
fn source_forget_old_capture_new_subset_no_resurrection_and_notes_bytes_preserved() {
    let f = Fixture::new();
    f.write("a.rs", "alpha\n");
    f.write("z.rs", "alpha\n");
    let mut s = f.store(&["a.rs", "z.rs"]);
    s.write_context("a", "memo", "note", "human alpha", false)
        .unwrap();
    let p = s.project("a").unwrap();
    s.forget_source("a", "z.rs", &token()).unwrap();
    for mode in modes() {
        assert!(
            s.query_files_bound(&p, &request(mode, "alpha", &["z.rs"]), &token())
                .is_err()
        );
        let now = s.project("a").unwrap();
        assert!(request(mode, "alpha", &["z.rs"]).validate(&now).is_err());
    }
    s.index("a", &mut LexicalLines, &token()).unwrap();
    let now = s.project("a").unwrap();
    for mode in modes() {
        assert_eq!(
            s.query_files_bound(&now, &request(mode, "alpha", &["a.rs"]), &token())
                .unwrap()["matching_anchors"],
            1
        );
    }
    assert_eq!(
        std::fs::read_to_string(f.0.join("source/z.rs")).unwrap(),
        "alpha\n"
    );
    assert_eq!(
        s.context("a", "memo").unwrap()["history"][0]["text"],
        "human alpha"
    );
}

#[test]
fn unindexed_empty_selected_candidates_and_precancel() {
    let f = Fixture::new();
    f.write("a.rs", "\n");
    let mut s = Store::open(&f.0.join("store")).unwrap();
    s.add_project("a", &f.0.join("source"), vec!["a.rs".into()])
        .unwrap();
    for indexed in [false, true] {
        if indexed {
            s.index("a", &mut LexicalLines, &token()).unwrap();
        }
        let p = s.project("a").unwrap();
        for mode in modes() {
            let q = request(mode, "alpha", &["a.rs"]);
            let r = s.query_files_bound(&p, &q, &token()).unwrap();
            assert_eq!(r["results"], json!([]));
            assert_eq!(r["truncated"], false);
            assert!(matches!(
                s.query_files_bound(&p, &q, &AtomicBool::new(true)),
                Err(Error::Canceled)
            ));
        }
    }
}

#[test]
fn wal_peer_publication_never_adopts_a_different_policy_or_snapshot() {
    for mode in modes() {
        let f = Fixture::new();
        f.write("a.rs", "alpha\n");
        f.write("z.rs", "alpha\n");
        let s = f.store(&["a.rs", "z.rs"]);
        let p = s.project("a").unwrap();
        let mut peer = Store::open_existing(&f.0.join("store")).unwrap();
        let journal: String = peer
            .db
            .query_row("PRAGMA journal_mode=WAL", [], |r| r.get(0))
            .unwrap();
        assert_eq!(journal, "wal");
        let request = request(mode, "alpha", &["z.rs"]).canonical(&p).unwrap();
        let result = s.query_selected_pipeline(
            "a",
            &request.query,
            &token(),
            (Some(&p), Some(&request)),
            || {},
            || {
                peer.set_sources("a", vec!["z.rs".into()]).unwrap();
                peer.index("a", &mut LexicalLines, &token()).unwrap();
            },
        );
        assert!(matches!(result, Err(Error::ScopeMismatch)));
        // This uses existing query publication semantics, not a long-lived read
        // transaction that could conceal a WAL peer's committed new policy.
    }
}

#[test]
fn utf8_root_metadata_is_exact_and_literal_controls_do_not_adopt_terms_normalization() {
    let f = Fixture::new();
    let root = f.0.join("é-source");
    std::fs::create_dir(&root).unwrap();
    std::fs::write(root.join("a.rs"), "alpha beta\n").unwrap();
    let mut s = Store::open(&f.0.join("store")).unwrap();
    s.add_project("a", &root, vec!["a.rs".into()]).unwrap();
    s.index("a", &mut LexicalLines, &token()).unwrap();
    for mode in modes() {
        let mut p = s.project("a").unwrap();
        // Metadata byte identity is not a filesystem normalization/alias lookup.
        p.root = if p.root.contains('é') {
            p.root.replace('é', "e\u{301}")
        } else {
            p.root.replace("e\u{301}", "é")
        };
        let r = request(mode, "alpha", &["a.rs"]).canonical(&p).unwrap();
        assert!(matches!(
            s.query_selected_pipeline(
                "a",
                &r.query,
                &token(),
                (Some(&p), Some(&r)),
                || panic!("normalized metadata reached source authority"),
                || {}
            ),
            Err(Error::ScopeMismatch)
        ));
    }
    let p = s.project("a").unwrap();
    let r = s
        .query_files_bound(
            &p,
            &request(FileQueryMode::Literal, "alpha\nbeta", &["a.rs"]),
            &token(),
        )
        .unwrap();
    assert_eq!(r["results"], json!([]));
    assert!(
        request(FileQueryMode::RankedAnyTerms, "alpha\nbeta", &["a.rs"])
            .validate(&p)
            .is_err()
    );
}

#[test]
fn selected_persisted_anchors_must_resolve_current_approved_path_hash_line_and_text() {
    for mode in modes() {
        for sql in [
            "UPDATE evidence SET path='unapproved.rs'",
            "UPDATE evidence SET line=0",
            "UPDATE evidence SET text='alpha forged'",
            "UPDATE evidence SET hash=printf('%064d',0)",
            "UPDATE evidence SET producer='../invalid'",
        ] {
            let f = Fixture::new();
            f.write("a.rs", "alpha\n");
            let s = f.store(&["a.rs"]);
            let p = s.project("a").unwrap();
            s.db.execute(sql, []).unwrap();
            assert!(
                s.query_files_bound(&p, &request(mode, "alpha", &["a.rs"]), &token())
                    .is_err()
            );
        }
    }
}
