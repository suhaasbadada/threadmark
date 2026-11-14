//! Actual CLI opt-in tests; owned synthetic SQLite and ephemeral fake HTTP only.
use super::*;

fn ranked_fixture() -> Fixture {
    let f = Fixture::new();
    std::fs::write(
        f.0.join("source/main.rs"),
        "fn alpha_gap_beta() {}\nfn alpha_only() {}\nfn synthetic_blue() {}\n",
    )
    .unwrap();
    std::fs::write(
        f.0.join("source/unapproved.rs"),
        "alpha beta NEVER_SELECT\n",
    )
    .unwrap();
    f.ok(&["index", "synthetic"]);
    f.run(
        &["context", "add", "synthetic", "human", "note"],
        b"alpha beta HUMAN_HISTORY",
    )
    .status
    .success()
    .then_some(())
    .unwrap();
    f
}

#[test]
fn actual_context_ranked_opt_in_has_current_anchors_and_literal_shape_is_unchanged() {
    let f = ranked_fixture();
    let original = "Do not deploy. 保持 exact negations.\r\n";
    let run = |flags: &[&str]| {
        let out = f.run(flags, original.as_bytes());
        assert!(
            out.status.success(),
            "{}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert!(out.stdout.len() <= 8192);
        serde_json::from_slice::<Value>(&out.stdout).unwrap()
    };
    let literal = run(&["context", "prepare", "synthetic", "alpha beta"]);
    assert_eq!(literal["state"], "needs-input");
    assert!(literal.get("retrieval_mode").is_none());
    assert!(literal.get("coverage").is_none());
    let terms = run(&["context", "prepare", "synthetic", "alpha beta", "--terms"]);
    assert_eq!(terms["state"], "ready-for-review");
    assert_eq!(terms["original"], original);
    assert_eq!(terms["snapshot"], literal["snapshot"]);
    assert_eq!(terms["retrieval_mode"], "ranked-terms");
    assert!(
        terms["coverage"]
            .as_str()
            .unwrap()
            .contains("distinct-matched-terms")
    );
    let proposed = terms["proposed"].as_str().unwrap();
    assert!(proposed.contains("alpha_gap_beta"));
    assert_eq!(terms["evidence"][0]["path"], "main.rs");
    assert_eq!(terms["evidence"][0]["line"], 1);
    assert_eq!(
        terms["evidence"][0]["source_hash"].as_str().unwrap().len(),
        64
    );
    assert!(!proposed.contains("NEVER_SELECT"));
    assert!(!proposed.contains("HUMAN_HISTORY"));
    assert_eq!(terms["provider"], "not-invoked");
    assert_eq!(terms["approval"], "not-requested");
    assert_eq!(terms["delivery"], "not-attempted");
    // Existing default operator query remains a literal substring query.
    assert_eq!(
        f.ok(&["query", "synthetic", "alpha beta"])["results"],
        json!([])
    );
    assert_eq!(
        f.ok(&["context", "show", "synthetic", "human"])["history"]
            .as_array()
            .unwrap()
            .len(),
        1
    );
}

#[test]
fn ranked_refine_sends_exact_inspected_selection_and_never_approves_or_delivers() {
    let f = ranked_fixture();
    let (listener, endpoint) = listener();
    let mut flags = f.flags(&endpoint); // flags helper expects old literal fixture
    flags[3] = "alpha beta".into();
    flags.push("--terms".into());
    let inspected = f.ok(&["query-terms", "synthetic", "alpha beta"]);
    let selected = inspected["results"].as_array().unwrap().clone();
    let expected_snapshot = inspected["snapshot"].clone();
    let original = "Do not change permissions. 保持\r\n\"literal\"\\\n";
    let server = std::thread::spawn(move || {
        let (stream, body) = receive(&listener);
        let payload: Value =
            serde_json::from_str(body["messages"][1]["content"].as_str().unwrap()).unwrap();
        assert_eq!(payload["original"], original);
        assert_eq!(payload["snapshot"], expected_snapshot);
        assert!(
            payload["retrieval_mode"]
                .as_str()
                .unwrap()
                .contains("ranked-terms")
        );
        let evidence = payload["evidence"].as_array().unwrap();
        assert_eq!(evidence.len(), selected.len());
        for (actual, selected) in evidence.iter().zip(selected) {
            for key in [
                "path",
                "line",
                "text",
                "source_hash",
                "producer",
                "kind",
                "coverage",
            ] {
                assert_eq!(actual[key], selected[key]);
            }
        }
        assert!(!payload.to_string().contains("HUMAN_HISTORY"));
        assert!(!payload.to_string().contains("NEVER_SELECT"));
        respond(
            stream,
            "200 OK",
            &proposal(
                json!([]),
                "Inspect only selected source; do not deploy.".into(),
            ),
        );
        listener
    });
    let out = f.preview(&flags, original.as_bytes());
    let listener = server.join().unwrap();
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert!(out.stdout.len() <= 8192);
    let value: Value = serde_json::from_slice(&out.stdout).unwrap();
    assert_eq!(value["original"], original);
    assert_eq!(value["retrieval_mode"], "ranked-terms");
    assert_eq!(value["approval"], "not-requested");
    assert_eq!(value["delivery"], "not-attempted");
    assert!(listener.accept().is_err());
}

#[test]
fn ranked_cli_omission_and_whole_envelope_bounds_are_explicit() {
    let f = Fixture::new();
    std::fs::write(f.0.join("source/main.rs"), "alpha_gap_beta\n".repeat(12)).unwrap();
    f.ok(&["index", "synthetic"]);
    let out = f.run(
        &["context", "prepare", "synthetic", "alpha beta", "--terms"],
        b"Do not deploy.",
    );
    assert!(out.status.success());
    assert!(out.stdout.len() <= 8192);
    let value: Value = serde_json::from_slice(&out.stdout).unwrap();
    assert_eq!(value["evidence"].as_array().unwrap().len(), 8);
    assert!(
        value["coverage"]
            .as_str()
            .unwrap()
            .contains("omits additional matches")
    );
    assert_eq!(value["provider"], "not-invoked");
    // Core omits complete heavily escaped anchors at its own envelope bound.
    // Preparation may reject the larger original/preview/provenance envelope,
    // but must never truncate it or return a partial line/original fallback.
    std::fs::write(
        f.0.join("source/main.rs"),
        format!("alpha beta {}\n", "\\\"".repeat(400)).repeat(12),
    )
    .unwrap();
    f.ok(&["index", "synthetic"]);
    let query = f.ok(&["query-terms", "synthetic", "alpha beta"]);
    assert_eq!(query["truncated"], true);
    assert!(query["results"].as_array().unwrap().len() < 8);
    let out = f.run(
        &["context", "prepare", "synthetic", "alpha beta", "--terms"],
        "original".repeat(500).as_bytes(),
    );
    rejected(&out);
}

#[test]
fn malformed_and_repeated_terms_fail_before_store_open() {
    let f = Fixture::new();
    let absent = f.0.join("absent-store");
    for query in [
        "alpha beta",
        "",
        "a\nb",
        "a b c d e f g h i",
        &"x".repeat(65),
    ] {
        for repeated in [false, true] {
            if query == "alpha beta" && !repeated {
                continue;
            }
            let mut args = vec!["context", "prepare", "synthetic", query, "--terms"];
            if repeated {
                args.push("--terms");
            }
            let out = Command::new(env!("CARGO_BIN_EXE_threadmark"))
                .arg("--data-dir")
                .arg(&absent)
                .args(&args)
                .stdin(Stdio::null())
                .output()
                .unwrap();
            assert_eq!(out.status.code(), Some(2));
            assert!(!absent.exists());
        }
    }
    let (_, endpoint) = listener();
    let flags = f.flags(&endpoint);
    for query in ["", "a\nb", "a b c d e f g h i", &"x".repeat(65)] {
        let mut flags = flags.clone();
        flags[3] = query.into();
        flags.push("--terms".into());
        let out = Command::new(env!("CARGO_BIN_EXE_threadmark"))
            .arg("--data-dir")
            .arg(&absent)
            .args(&flags)
            .stdin(Stdio::null())
            .output()
            .unwrap();
        assert_eq!(out.status.code(), Some(2));
        assert!(!absent.exists());
    }
    for extra in [
        vec!["--terms", "--terms"],
        vec!["--terms=ranked"],
        vec!["--literal", "--terms"],
    ] {
        let mut flags = flags.clone();
        flags.extend(extra.into_iter().map(str::to_owned));
        let out = f.preview(&flags, b"Do not deploy.");
        assert_eq!(out.status.code(), Some(2));
        assert!(out.stdout.is_empty());
    }
    // Valid-shaped ranked invocation still requires all explicit inference flags.
    rejected(&f.run(
        &["refine", "preview", "synthetic", "alpha beta", "--terms"],
        b"Do not deploy.",
    ));
}

#[test]
fn ranked_mismatch_stale_and_replacement_never_connect_and_provider_change_rejects() {
    for case in ["root", "snapshot", "stale", "replacement"] {
        let f = Fixture::new();
        let (listener, endpoint) = listener();
        let mut flags = f.flags(&endpoint);
        flags[3] = "synthetic blue".into();
        flags.push("--terms".into());
        match case {
            "root" => replace(&mut flags, "--expected-root", "/synthetic/wrong"),
            "snapshot" => replace(&mut flags, "--expected-snapshot", &"0".repeat(64)),
            "stale" => std::fs::write(f.0.join("source/main.rs"), "fn changed() {}\n").unwrap(),
            "replacement" => {
                f.ok(&[
                    "project",
                    "remove",
                    "synthetic",
                    "--confirm-remove-local-data",
                ]);
                f.ok(&[
                    "project",
                    "add",
                    "synthetic",
                    f.0.join("source").to_str().unwrap(),
                    "main.rs",
                ]);
                f.ok(&["index", "synthetic"]);
            }
            _ => unreachable!(),
        }
        rejected(&f.preview(&flags, b"Do not deploy."));
        assert!(listener.accept().is_err());
    }
    let f = Fixture::new();
    let (listener, endpoint) = listener();
    let mut flags = f.flags(&endpoint);
    flags[3] = "synthetic blue".into();
    flags.push("--terms".into());
    let path = f.0.join("source/main.rs");
    let server = std::thread::spawn(move || {
        let (stream, _) = receive(&listener);
        std::fs::write(path, "fn changed_during_ranked_provider() {}\n").unwrap();
        respond(
            stream,
            "200 OK",
            &proposal(json!([]), "Inspect only.".into()),
        );
    });
    let out = f.preview(&flags, b"Do not deploy.");
    server.join().unwrap();
    rejected(&out);
}
