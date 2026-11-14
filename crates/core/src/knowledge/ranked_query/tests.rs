//! Synthetic SQLite/current-file acceptance for explicit ranked lexical queries.
use super::*;
use std::sync::atomic::AtomicU64;

struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        static NEXT: AtomicU64 = AtomicU64::new(0);
        let path = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-ranked-{}-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::create_dir(&path).unwrap();
        std::fs::create_dir(path.join("source")).unwrap();
        Self(path)
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
fn query(s: &Store, q: &str) -> Value {
    s.query_terms("a", q, &token()).unwrap()
}

#[test]
fn dispersed_terms_rank_beyond_each_terms_first_eight_and_literal_is_unchanged() {
    let f = Fixture::new();
    f.write(
        "a.rs",
        &format!(
            "{}{}alpha gap beta beta\nalpha gap beta\n",
            "alpha\n".repeat(9),
            "beta\n".repeat(9)
        ),
    );
    let s = f.store(&["a.rs"]);
    let before = s.query("a", "alpha beta", &token()).unwrap();
    assert_eq!(before["results"], json!([]));
    let r = query(&s, "alpha beta");
    assert_eq!(r["results"][0]["line"], 19);
    assert_eq!(r["results"][0]["matched_terms"], 2);
    assert_eq!(r["results"][0]["occurrences"], 3);
    assert_eq!(r["results"][1]["line"], 20);
    assert_eq!(r["matching_anchors"], 20);
    assert_eq!(r["results"].as_array().unwrap().len(), 8);
    assert_eq!(r["truncated"], true);
    assert_eq!(s.query("a", "alpha beta", &token()).unwrap(), before);
    assert_eq!(
        s.query("a", "ALPHA", &token()).unwrap()["selection"],
        "bounded-path-line-prefix"
    );
}

#[test]
fn unicode_dedup_nonoverlap_and_deterministic_ties() {
    let f = Fixture::new();
    f.write("b.rs", "ÄÄÄ blue\nÄÄÄ blue\n");
    f.write("a.rs", "ÄÄÄ blue\nÄÄÄ blue\né\ne\u{301}\nİ\n");
    let s = f.store(&["b.rs", "a.rs"]);
    let r = query(&s, "ÄÄ\u{2003}blue ÄÄ BLUE");
    assert_eq!(r["terms"], json!(["ää", "blue"]));
    assert_eq!(r["results"][0]["occurrences"], 2); // ää in äää: one, not two.
    let coords: Vec<_> = r["results"]
        .as_array()
        .unwrap()
        .iter()
        .map(|r| (r["path"].clone(), r["line"].clone()))
        .collect();
    assert_eq!(
        coords,
        vec![
            (json!("a.rs"), json!(1)),
            (json!("a.rs"), json!(2)),
            (json!("b.rs"), json!(1)),
            (json!("b.rs"), json!(2))
        ]
    );
    assert_eq!(query(&s, "é")["results"].as_array().unwrap().len(), 1);
    assert_eq!(query(&s, "İ")["terms"], json!(["i\u{307}"]));
    assert_eq!(query(&s, "absent")["truncated"], false);
    assert_eq!(query(&s, "ÄÄ blue"), r);
}

#[test]
fn strict_query_byte_controls_and_deduplicated_term_bounds() {
    for q in [
        "",
        " ",
        "a\nb",
        "a\tb",
        "a\0",
        "a\u{7f}",
        "a b c d e f g h i",
    ] {
        assert!(validate_query_terms("a", q).is_err());
    }
    for q in [
        "x".repeat(65),
        "é".repeat(33),
        "a ".repeat(129),
        "İ".repeat(22),
    ] {
        assert!(validate_query_terms("a", &q).is_err());
    }
    assert!(validate_query_terms("../bad", "alpha").is_err());
    assert!(validate_query_terms("a", &"é".repeat(32)).is_ok());
    assert!(validate_query_terms("a", &"K".repeat(64)).is_ok());
    assert!(validate_query_terms("a", &format!("{}a", " ".repeat(255))).is_ok());
    assert!(validate_query_terms("a", "a b c d e f g h a A").is_ok());
}

#[test]
fn full_envelope_omits_whole_entries_never_truncates_text() {
    let f = Fixture::new();
    let line = format!("alpha{}", "\"\\".repeat(500));
    f.write("a.rs", &(line.clone() + "\n").repeat(8));
    let s = f.store(&["a.rs"]);
    let r = query(&s, "alpha");
    assert!(serde_json::to_vec(&r).unwrap().len() < 8192); // includes one CLI newline
    let results = r["results"].as_array().unwrap();
    assert!(!results.is_empty() && results.len() < 8);
    assert!(results.iter().all(|r| r["text"] == line));
    assert_eq!(r["truncated"], true);
    assert_eq!(r["matching_anchors"], 8);
}

#[test]
fn any_changed_deleted_or_unreadable_approved_file_suppresses_complete_snapshot() {
    use std::os::unix::fs::symlink;
    for mode in 0..4 {
        let f = Fixture::new();
        f.write("a.rs", "alpha gap beta\n");
        f.write("b.rs", "unmatched\n");
        let mut s = f.store(&["a.rs", "b.rs"]);
        match mode {
            0 => f.write("b.rs", "changed\n"),
            1 => std::fs::remove_file(f.0.join("source/b.rs")).unwrap(),
            2 => {
                std::fs::remove_file(f.0.join("source/b.rs")).unwrap();
                symlink("a.rs", f.0.join("source/b.rs")).unwrap();
            }
            _ => s.set_sources("a", vec![]).unwrap(),
        }
        let r = query(&s, "alpha beta");
        assert_eq!(r["results"], json!([]));
        assert_eq!(r["currentness"], "stale-or-unindexed");
        if mode == 0 {
            s.index("a", &mut LexicalLines, &token()).unwrap();
            assert_eq!(
                query(&s, "alpha beta")["results"].as_array().unwrap().len(),
                1
            );
        }
    }
}

#[test]
fn selected_rows_must_resolve_path_line_text_hash_and_producer() {
    for sql in [
        "UPDATE evidence SET path='unapproved.rs'",
        "UPDATE evidence SET line=0",
        "UPDATE evidence SET line=4097",
        "UPDATE evidence SET text='alpha forged'",
        "UPDATE evidence SET hash=printf('%064d',0)",
        "UPDATE evidence SET producer='../bad'",
    ] {
        let f = Fixture::new();
        f.write("a.rs", "alpha\n");
        let s = f.store(&["a.rs"]);
        s.db.execute(sql, []).unwrap();
        assert!(s.query_terms("a", "alpha", &token()).is_err());
    }
}

#[test]
fn final_boundary_cancellation_source_change_revocation_and_same_root_reuse() {
    for mode in 0..7 {
        let f = Fixture::new();
        f.write("a.rs", "alpha\n");
        let s = f.store(&["a.rs"]);
        let mut other = Store::open_existing(&f.0.join("store")).unwrap();
        let cancel = token();
        let result = s.query_terms_with_progress("a", "alpha", &cancel, || match mode {
            0 => cancel.store(true, Ordering::SeqCst),
            1 => f.write("a.rs", "changed\n"),
            2 => {
                other.set_sources("a", vec![]).unwrap();
            }
            3 => {
                other.remove_project("a", &token()).unwrap();
                other
                    .add_project("a", &f.0.join("source"), vec!["a.rs".into()])
                    .unwrap();
                other.index("a", &mut LexicalLines, &token()).unwrap();
            }
            4 => {
                std::fs::rename(f.0.join("source"), f.0.join("old-source")).unwrap();
                std::fs::create_dir(f.0.join("source")).unwrap();
                f.write("a.rs", "alpha\n");
            }
            5 => {
                f.write("a.rs", "changed alpha\n");
                other.index("a", &mut LexicalLines, &token()).unwrap();
            }
            _ => std::fs::remove_file(f.0.join("source/a.rs")).unwrap(),
        });
        match mode {
            0 => assert!(matches!(result, Err(Error::Canceled))),
            1 | 4 | 6 => {
                let r = result.unwrap();
                assert_eq!(r["currentness"], "stale-or-unindexed");
                assert_eq!(r["results"], json!([]));
            }
            _ => assert!(matches!(result, Err(Error::ScopeMismatch))),
        }
    }
}

#[test]
fn project_scope_no_unapproved_source_or_human_history_and_precancel() {
    let f = Fixture::new();
    f.write("a.rs", "alpha\n");
    f.write("unapproved.rs", "beta\n");
    let mut s = f.store(&["a.rs"]);
    s.write_context("a", "memo", "note", "beta", false).unwrap();
    s.write_context("a", "memo", "note", "gamma", true).unwrap();
    assert_eq!(query(&s, "beta gamma")["results"], json!([]));
    let g = Fixture::new();
    g.write("b.rs", "beta\n");
    s.add_project("b", &g.0.join("source"), vec!["b.rs".into()])
        .unwrap();
    s.index("b", &mut LexicalLines, &token()).unwrap();
    assert_eq!(query(&s, "beta")["results"], json!([]));
    assert_eq!(
        s.query_terms("b", "beta", &token()).unwrap()["results"][0]["project"],
        "b"
    );
    assert!(matches!(
        s.query_terms("a", "alpha", &AtomicBool::new(true)),
        Err(Error::Canceled)
    ));
}

#[test]
fn observed_64_file_16384_anchor_fixture_with_late_best_result() {
    let f = Fixture::new();
    let paths: Vec<_> = (0..64).map(|i| format!("f{i:02}.rs")).collect();
    for (i, path) in paths.iter().enumerate() {
        let text = if i == 63 {
            format!("{}alpha gap beta\n", "x\n".repeat(255))
        } else {
            "x\n".repeat(256)
        };
        f.write(path, &text);
    }
    let s = f.store(&paths.iter().map(String::as_str).collect::<Vec<_>>());
    let start = std::time::Instant::now();
    let r = query(&s, "x alpha beta");
    eprintln!(
        "synthetic 64*256 ranked scan elapsed_ms={}",
        start.elapsed().as_millis()
    );
    assert_eq!(r["scanned_anchors"], 16384);
    assert_eq!(r["matching_anchors"], 16384);
    assert_eq!(r["results"][0]["path"], "f63.rs");
    assert_eq!(r["results"][0]["line"], 256);
    assert!(serde_json::to_vec(&r).unwrap().len() < 8192); // includes one CLI newline
}

#[test]
fn synthetic_sqlite_expanded_anchor_bound_scans_262144_rows() {
    // Production index retains its existing 16,384-anchor cap. This lower-level
    // retrieval fixture deliberately expands only source-resolvable SQLite rows
    // to exercise the independent 64*4096 retrieval bound without changing index.
    struct Sparse;
    impl SourceExtractor for Sparse {
        fn producer(&self) -> &str {
            "synthetic-sparse-v1"
        }
        fn extract(&mut self, _: &str, _: &AtomicBool) -> Result<Vec<usize>> {
            Ok(vec![1])
        }
    }
    let f = Fixture::new();
    let paths: Vec<_> = (0..64).map(|i| format!("f{i:02}.rs")).collect();
    for path in &paths {
        f.write(path, &"x\n".repeat(4096));
    }
    let mut s = Store::open(&f.0.join("store")).unwrap();
    s.add_project("a", &f.0.join("source"), paths).unwrap();
    s.index("a", &mut Sparse, &token()).unwrap();
    s.db.execute_batch("BEGIN IMMEDIATE;
        WITH RECURSIVE lines(n) AS (SELECT 2 UNION ALL SELECT n+1 FROM lines WHERE n<4096)
        INSERT INTO evidence SELECT project,path,n,text,hash,producer FROM evidence CROSS JOIN lines WHERE line=1;
        COMMIT;").unwrap();
    let start = std::time::Instant::now();
    let r = query(&s, "x");
    eprintln!(
        "synthetic SQL-expanded 64*4096 ranked scan elapsed_ms={}",
        start.elapsed().as_millis()
    );
    assert_eq!(r["scanned_anchors"], 262144);
    assert_eq!(r["matching_anchors"], 262144);
    assert_eq!(r["results"][0]["path"], "f00.rs");
    assert_eq!(r["results"][0]["line"], 1);
    assert_eq!(r["results"][7]["line"], 8);
    s.db.execute("INSERT INTO evidence SELECT project,path,4097,text,hash,producer FROM evidence WHERE path='f63.rs' AND line=1", []).unwrap();
    assert!(s.query_terms("a", "x", &token()).is_err());
}
