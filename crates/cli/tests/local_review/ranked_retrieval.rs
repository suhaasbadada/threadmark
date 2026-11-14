//! Explicit retained ranked retrieval, using only owned synthetic resources.
use super::*;

#[test]
fn library_ranked_validation_precedes_even_existing_store_access() {
    use threadmark_daemon::local_refinement::Options;
    use threadmark_daemon::preparation::{CaptureBinding, RetrievalMode};
    use threadmark_daemon::review_session::{Control, Error, LocalReview};
    let fixture = Fixture::new();
    let project = fixture.ok(&["project", "show", "synthetic"]);
    let query = fixture.ok(&["query", "synthetic", "synthetic_blue"]);
    let absent = fixture.0.join("absent-store");
    for terms in [
        " ".into(),
        "a\nb".into(),
        "x".repeat(65),
        "a b c d e f g h i".into(),
    ] {
        let options = Options {
            expected: CaptureBinding {
                project: "synthetic".into(),
                root: project["root"].as_str().unwrap().into(),
                root_identity: project["root_identity"].as_str().unwrap().into(),
                incarnation: project["incarnation"].as_str().unwrap().into(),
                snapshot: query["snapshot"].as_str().unwrap().into(),
            },
            query: terms,
            profile: "synthetic".into(),
            model: "synthetic".into(),
            endpoint: "http://127.0.0.1:1/v1/chat/completions".into(),
            confirm_local_inference: true,
        };
        assert!(matches!(
            LocalReview::start_with_retrieval(
                &absent,
                options,
                "PRIVATE_ORIGINAL".into(),
                Control::new(Instant::now() + Duration::from_secs(5)),
                RetrievalMode::RankedTerms,
            ),
            Err(Error::Invalid)
        ));
        assert!(!absent.exists());
    }
}

#[test]
fn ranked_mode_cannot_be_supplied_or_changed_through_closed_json_frames() {
    let fixture = Fixture::new();
    let (listener, endpoint) = listener();
    let flags = fixture.retrieval_flags(&endpoint, true);
    let mut child = fixture.child(&flags);
    child.send(json!({"version":1,"original":"PRIVATE_ORIGINAL","retrieval_mode":"literal"}));
    assert_eq!(child.event()["code"], "Invalid");
    child.finish(false);
    assert_eq!(
        listener.accept().unwrap_err().kind(),
        std::io::ErrorKind::WouldBlock
    );
    let server = server(listener, false, false);
    let mut child = fixture.child(&flags);
    child.capture();
    let review = child.event();
    let mut action = edit(&review, "PRIVATE_EDIT");
    action["edit"]["retrieval_mode"] = json!("literal");
    child.send(action);
    assert_eq!(child.event()["code"], "Invalid");
    child.finish(false);
    one_call(server);
    fixture.unchanged();
}

#[test]
fn ranked_selection_edit_fresh_challenge_and_exact_handoff_keep_v1_shape() {
    let fixture = Fixture::new();
    assert_eq!(
        fixture.ok(&["query", "synthetic", "synthetic blue"])["results"],
        json!([])
    );
    let inspected = fixture.ok(&["query-terms", "synthetic", "synthetic blue"]);
    let (listener, endpoint) = listener();
    let mut child = fixture.child(&fixture.retrieval_flags(&endpoint, true));
    let server = std::thread::spawn(move || {
        let (stream, body) = receive(&listener);
        assert_eq!(body["max_tokens"], 1024);
        let payload: Value =
            serde_json::from_str(body["messages"][1]["content"].as_str().unwrap()).unwrap();
        assert!(
            payload["retrieval_mode"]
                .as_str()
                .unwrap()
                .contains("ranked-terms")
        );
        assert_eq!(payload["snapshot"], inspected["snapshot"]);
        let selected = inspected["results"].as_array().unwrap();
        let evidence = payload["evidence"].as_array().unwrap();
        assert_eq!(evidence.len(), selected.len());
        assert_eq!(evidence.len(), 1);
        for (actual, expected) in evidence.iter().zip(selected) {
            for key in [
                "path",
                "line",
                "text",
                "source_hash",
                "producer",
                "kind",
                "coverage",
            ] {
                assert_eq!(actual[key], expected[key]);
            }
        }
        respond(stream, false, false);
        listener
    });
    child.capture();
    let preview = child.event();
    assert_eq!(preview["event"], "preview");
    assert!(
        preview["coverage"]
            .as_str()
            .unwrap()
            .contains("ranked-terms")
    );
    // No new wire fields: selection mode is frozen at launch, not mutable JSON.
    assert!(preview.get("retrieval_mode").is_none());
    child.send(edit(&preview, "PRIVATE_EDIT Do not deploy. 保持"));
    let edited = child.event();
    assert_eq!(edited["revision"], 2);
    assert_ne!(edited["digest"], preview["digest"]);
    assert!(
        edited["proposed"]
            .as_str()
            .unwrap()
            .contains("PRIVATE_EDIT")
    );
    child.send(choose("use-prepared", &preview));
    assert_eq!(child.event()["code"], "ReviewRequired");
    child.send(choose("use-prepared", &edited));
    let handoff = child.event();
    assert_eq!(handoff["event"], "handoff");
    assert_eq!(handoff["text"], edited["proposed"]);
    child.finish(true);
    one_call(server);
    fixture.unchanged();
}

#[test]
fn ranked_questions_and_provider_failure_never_fallback_or_clear_on_edit() {
    failure_and_questions(true);
}

#[test]
fn ranked_cancel_and_eof_during_provider_and_review_never_emit_late_handoff() {
    cancel_and_eof(true);
}

#[test]
fn ranked_stale_source_policy_namespace_and_snapshot_reject_after_edit() {
    changes_after_edit(true);
}

#[test]
fn malformed_ranked_flags_reject_before_store_stdin_or_provider() {
    let fixture = Fixture::new();
    let (listener, endpoint) = listener();
    for scenario in [
        "repeat", "empty", "control", "long", "many", "unknown", "confirm",
    ] {
        let mut flags = fixture.retrieval_flags(&endpoint, true);
        match scenario {
            "repeat" => flags.push("--terms".into()),
            "empty" => flags[3] = "  ".into(),
            "control" => flags[3] = "synthetic\nblue".into(),
            "long" => flags[3] = "x".repeat(65),
            "many" => flags[3] = "a b c d e f g h i".into(),
            "unknown" => flags.push("--ranked".into()),
            "confirm" => {
                flags.retain(|flag| flag != "--confirm-local-inference");
            }
            _ => unreachable!(),
        }
        let absent = fixture.0.join("absent-store");
        let mut command = Command::new(env!("CARGO_BIN_EXE_threadmark"));
        command
            .arg("--data-dir")
            .arg(&absent)
            .args(flags)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        // Keep stdin open without sending a frame: parser must finish first.
        let child = Session::new(command.spawn().unwrap());
        let event = child.event();
        assert_eq!(event["code"], "Invalid");
        assert_eq!(event["terminal"], true);
        child.finish(false);
        assert!(!absent.exists());
    }
    assert_eq!(
        listener.accept().unwrap_err().kind(),
        std::io::ErrorKind::WouldBlock
    );
    fixture.unchanged();
}

#[test]
fn ranked_wrong_expected_namespace_and_stale_sources_never_call_provider() {
    for scenario in ["root", "identity", "incarnation", "snapshot", "source"] {
        let fixture = Fixture::new();
        let (listener, endpoint) = listener();
        let mut flags = fixture.retrieval_flags(&endpoint, true);
        let flag = match scenario {
            "root" => Some((
                "--expected-root",
                fixture.0.join("other").to_str().unwrap().to_owned(),
            )),
            "identity" => Some(("--expected-root-identity", "0:0".into())),
            "incarnation" => Some(("--expected-incarnation", "0".repeat(32))),
            "snapshot" => Some(("--expected-snapshot", "0".repeat(64))),
            "source" => {
                std::fs::write(fixture.0.join("source/main.rs"), "changed\n").unwrap();
                None
            }
            _ => unreachable!(),
        };
        if let Some((flag, value)) = flag {
            let index = flags.iter().position(|word| word == flag).unwrap();
            flags[index + 1] = value;
        }
        let mut child = fixture.child(&flags);
        child.capture();
        let event = child.event();
        assert_eq!(event["event"], "failure");
        assert_eq!(event["terminal"], true);
        assert!(event.get("text").is_none());
        assert_ne!(
            event["code"], "Invalid",
            "valid-shaped stale binding, not parser rejection"
        );
        child.finish(false);
        assert_eq!(
            listener.accept().unwrap_err().kind(),
            std::io::ErrorKind::WouldBlock
        );
    }
}

#[test]
fn literal_and_ranked_identical_selection_cannot_replay_each_others_challenges() {
    let fixture = Fixture::new();
    let (literal_listener, literal_endpoint) = listener();
    let (ranked_listener, ranked_endpoint) = listener();
    let literal_server = server(literal_listener, false, false);
    let ranked_server = server(ranked_listener, false, false);
    let mut literal = fixture.child(&fixture.flags(&literal_endpoint));
    let mut ranked_flags = fixture.flags(&ranked_endpoint);
    ranked_flags.push("--terms".into()); // Same query and evidence, different mode.
    let mut ranked = fixture.child(&ranked_flags);
    literal.capture();
    ranked.capture();
    let literal_review = literal.event();
    let ranked_review = ranked.event();
    assert_ne!(literal_review["digest"], ranked_review["digest"]);
    literal.send(choose("use-prepared", &ranked_review));
    ranked.send(choose("use-original", &literal_review));
    assert_eq!(literal.event()["code"], "ReviewRequired");
    assert_eq!(ranked.event()["code"], "ReviewRequired");
    literal.send(choose("use-prepared", &literal_review));
    ranked.send(choose("use-prepared", &ranked_review));
    assert_eq!(literal.event()["text"], literal_review["proposed"]);
    assert_eq!(ranked.event()["text"], ranked_review["proposed"]);
    literal.finish(true);
    ranked.finish(true);
    one_call(literal_server);
    one_call(ranked_server);
    fixture.unchanged();
}
