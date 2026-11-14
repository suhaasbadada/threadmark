//! Synthetic real-SQLite human-only retrieval acceptance; no external content.
use super::*;
mod kind_filter;

struct Fixture(PathBuf);
impl Fixture {
    fn new() -> Self {
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let path = std::env::temp_dir().canonicalize().unwrap().join(format!(
            "threadmark-human-search-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::create_dir(&path).unwrap();
        for project in ["app", "app-copy"] {
            std::fs::create_dir(path.join(project)).unwrap();
            std::fs::write(
                path.join(project).join("code.rs"),
                "// synthetic source only\n",
            )
            .unwrap();
        }
        Self(path)
    }
    fn store(&self) -> Store {
        Store::open(&self.0.join("store")).unwrap()
    }
    fn registered(&self) -> Store {
        let mut s = self.store();
        for project in ["app", "app-copy"] {
            s.add_project(project, &self.0.join(project), vec!["code.rs".into()])
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

#[test]
fn active_latest_human_scope_revision_retirement_forget_and_reopen() {
    let f = Fixture::new();
    let mut s = f.registered();
    s.write_context("app", "memo", "note", "synthetic cobalt", false)
        .unwrap();
    s.write_context(
        "app",
        "rule",
        "constraint",
        "synthetic cobalt cobalt",
        false,
    )
    .unwrap();
    s.write_context("app-copy", "memo", "decision", "synthetic amber", false)
        .unwrap();
    let before_other = s.context("app-copy", "memo").unwrap();
    let first = s.search_context("app", "cobalt", &token()).unwrap();
    assert_eq!(first["results"][0]["id"], "rule");
    assert_eq!(first["producer"], "human-authored");
    assert_eq!(
        first["root_identity"],
        s.project("app").unwrap().root_identity
    );
    assert_eq!(
        first["incarnation"],
        s.project("app").unwrap().incarnation.unwrap()
    );
    assert!(first.get("currentness").is_none());
    assert_eq!(
        s.search_context("app-copy", "cobalt", &token()).unwrap()["matched_entries"],
        0
    );
    s.write_context("app", "memo", "decision", "synthetic amber", true)
        .unwrap();
    let edited = s.search_context("app", "amber", &token()).unwrap();
    assert_eq!(edited["results"][0]["revision"], 2);
    assert_eq!(edited["results"][0]["kind"], "decision");
    s.retire_context("app", "rule").unwrap();
    assert_eq!(
        s.search_context("app", "cobalt", &token()).unwrap()["matched_entries"],
        0
    );
    s.forget_context("app", "memo", &token()).unwrap();
    drop(s);
    let mut s = f.store();
    assert_eq!(
        s.search_context("app", "amber", &token()).unwrap()["matched_entries"],
        0
    );
    assert!(
        s.write_context("app", "memo", "note", "amber", false)
            .is_err()
    );
    assert_eq!(before_other, s.context("app-copy", "memo").unwrap());
    for project in ["app", "app-copy"] {
        assert_eq!(
            std::fs::read_to_string(f.0.join(project).join("code.rs")).unwrap(),
            "// synthetic source only\n"
        );
    }
}

#[test]
fn unicode_determinism_entry_count_and_escaped_byte_budget_omit_whole_entries() {
    let f = Fixture::new();
    let mut s = f.registered();
    let text = format!("ÉCLAIR{}", "\u{1}".repeat(4000));
    s.write_context("app", "a-large", "note", &text, false)
        .unwrap();
    for n in (0..10).rev() {
        s.write_context("app", &format!("b{n:02}"), "pitfall", "éclair", false)
            .unwrap();
    }
    let first = s.search_context("app", "ÉCLAIR", &token()).unwrap();
    assert_eq!(first["matched_entries"], 11);
    assert_eq!(first["omitted_entries"], 3);
    assert_eq!(first["truncated"], true);
    let results = first["results"].as_array().unwrap();
    assert_eq!(results.len(), 8);
    assert_eq!(results[0]["id"], "b00");
    assert_eq!(results[7]["id"], "b07");
    assert!(results.iter().all(|r| r["text"] == "éclair"));
    assert!(serde_json::to_vec(&first).unwrap().len() < 8192); // reserve the newline
    for _ in 0..3 {
        assert_eq!(first, s.search_context("app", "ÉCLAIR", &token()).unwrap());
    }
    // Query size is UTF-8 bytes, not character count; no normalization is claimed.
    assert!(validate_human_search("app", &"é".repeat(128)).is_ok());
    assert!(validate_human_search("app", &"é".repeat(129)).is_err());
    assert_eq!(
        s.search_context("app", "e\u{301}clair", &token()).unwrap()["matched_entries"],
        0
    );
}

#[test]
fn aggregate_json_budget_counts_newline_and_never_slices_text() {
    let f = Fixture::new();
    let mut s = f.registered();
    let text = format!("synthetic{}", "界".repeat(1300));
    for id in ["a", "b", "c"] {
        s.write_context("app", id, "note", &text, false).unwrap();
    }
    let result = s.search_context("app", "synthetic", &token()).unwrap();
    assert_eq!(result["matched_entries"], 3);
    assert_eq!(result["omitted_entries"], 2);
    assert_eq!(result["results"].as_array().unwrap().len(), 1);
    assert_eq!(result["results"][0]["text"], text);
    assert!(serde_json::to_vec(&result).unwrap().len() < 8192); // reserve the newline
    s.write_context(
        "app",
        "a",
        "note",
        &format!("synthetic{}", "\u{1}".repeat(4000)),
        true,
    )
    .unwrap();
    s.retire_context("app", "b").unwrap();
    s.retire_context("app", "c").unwrap();
    let result = s.search_context("app", "synthetic", &token()).unwrap();
    assert_eq!(result["matched_entries"], 1);
    assert_eq!(result["omitted_entries"], 1);
    assert_eq!(result["truncated"], true);
    assert!(result["results"].as_array().unwrap().is_empty());
}

#[test]
fn over_capacity_or_unavailable_sql_fails_closed_without_partial_output() {
    let f = Fixture::new();
    let s = f.registered();
    s.db.execute_batch("WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM n WHERE i<4097) INSERT INTO context SELECT 'app','n'||i,1,'note','synthetic',0 FROM n;").unwrap();
    assert!(s.search_context("app", "synthetic", &token()).is_err());
    s.db.execute("DELETE FROM context WHERE project='app'", [])
        .unwrap();
    s.db.execute("DROP TABLE context", []).unwrap();
    assert!(s.search_context("app", "synthetic", &token()).is_err());
}

#[test]
fn validation_cancel_failure_and_no_source_access() {
    let f = Fixture::new();
    let mut s = f.registered();
    s.write_context("app", "memo", "note", "synthetic search", false)
        .unwrap();
    for query in ["", "   ", "\n", "x\0y", "x\ty"] {
        assert!(s.search_context("app", query, &token()).is_err());
    }
    assert!(s.search_context("../app", "search", &token()).is_err());
    assert!(s.search_context("absent", "search", &token()).is_err());
    assert!(matches!(
        s.search_context("app", "search", &AtomicBool::new(true)),
        Err(Error::Canceled)
    ));
    for cancel_at in [1, 2] {
        let cancel = token();
        let mut n = 0;
        assert!(matches!(
            s.search_context_observed("app", "search", &cancel, || {
                n += 1;
                if n == cancel_at {
                    cancel.store(true, Ordering::SeqCst);
                }
            }),
            Err(Error::Canceled)
        ));
    }
    // A human-only read must work even when source roots are unavailable.
    std::fs::rename(f.0.join("app"), f.0.join("unavailable-root")).unwrap();
    source_forget::SOURCE_ACCESSES.with(|n| n.set(0));
    assert_eq!(
        s.search_context("app", "search", &token()).unwrap()["results"][0]["text"],
        "synthetic search"
    );
    source_forget::SOURCE_ACCESSES.with(|n| assert_eq!(n.get(), 0));
    // Corrupt persisted active text fails closed; no partial results escape.
    s.db.execute(
        "UPDATE context SET text=?1 WHERE project='app'",
        ["x".repeat(4097)],
    )
    .unwrap();
    assert!(s.search_context("app", "x", &token()).is_err());
}

#[test]
fn coherent_snapshot_blocks_concurrent_history_publication_and_checks_registration() {
    let f = Fixture::new();
    let mut s = f.registered();
    s.write_context("app", "memo", "note", "old synthetic", false)
        .unwrap();
    let mut writer = f.store();
    writer.db.busy_timeout(std::time::Duration::ZERO).unwrap();
    let result = s
        .search_context_observed("app", "synthetic", &token(), || {
            assert!(
                writer
                    .write_context("app", "memo", "note", "new synthetic", true)
                    .is_err()
            );
        })
        .unwrap();
    assert_eq!(result["results"][0]["revision"], 1);
    assert_eq!(
        s.context("app", "memo").unwrap()["history"]
            .as_array()
            .unwrap()
            .len(),
        1
    );
    let old = result["incarnation"].clone();
    s.remove_project("app", &token()).unwrap();
    s.add_project("app", &f.0.join("app"), vec!["code.rs".into()])
        .unwrap();
    let result = s.search_context("app", "synthetic", &token()).unwrap();
    assert_ne!(result["incarnation"], old);
    assert_eq!(result["matched_entries"], 0);
    // Same-connection tampering at the publication boundary is rejected and rolled back.
    assert!(
        s.search_context_observed("app", "synthetic", &token(), || {
            s.db.execute(
                "UPDATE projects SET root_identity='changed' WHERE id='app'",
                [],
            )
            .unwrap();
        })
        .is_err()
    );
    assert_ne!(s.project("app").unwrap().root_identity, "changed");
}
