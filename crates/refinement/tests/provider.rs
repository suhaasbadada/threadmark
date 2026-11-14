//! Synthetic numeric-loopback HTTP only. No live model, credential or quality claim.
use serde_json::{Value, json};
use std::io::{Read, Write};
use std::net::TcpListener;
use std::sync::mpsc;
use std::thread;
use std::time::{Duration, Instant};
use threadmark_refinement::*;

fn capture() -> Request {
    Request::new(RequestData {
        request_id: "fixture-request".into(),
        project: "fixture-project".into(),
        snapshot: Some("fixture-snapshot".into()),
        original: "Fix Équipe. Do NOT change permissions.\r\n🦀".into(),
        constraints: vec![Constraint {
            id: "no-permissions".into(),
            text: "Do NOT change permissions.".into(),
        }],
        attachments: vec![Attachment {
            reference: "fixture-attachment".into(),
            metadata: "name=synthetic.txt".into(),
        }],
        destination: "fixture-draft".into(),
        mode: Mode::Refine,
        evidence: vec![Evidence {
            id: "source".into(),
            project: "fixture-project".into(),
            path: "fixture.rs".into(),
            line: 1,
            text: "fn fixture() {}".into(),
            source_hash: "fixture-hash".into(),
            producer: "fixture".into(),
            kind: "observed-source-line".into(),
            currentness: Currentness::CurrentAtRead,
            coverage: "one synthetic line".into(),
        }],
        output_budget: 8192,
    })
    .unwrap()
}

// Independent fixed fixture authority, not a production authorization adapter.
struct Authority;
impl EvidenceAuthority for Authority {
    fn current(&self, _: &Request) -> Result<AuthorizedSnapshot, Error> {
        let fixture = capture();
        Ok(AuthorizedSnapshot {
            project: fixture.data().project.clone(),
            snapshot: fixture.data().snapshot.clone(),
            evidence: fixture.data().evidence.clone(),
            coverage: "synthetic fixture".into(),
        })
    }
}

fn settings(endpoint: String, locality: Locality) -> ProviderSettings {
    ProviderSettings {
        profiles: vec![ProviderIdentity {
            profile: "fixture-profile".into(),
            model: "fixture-model".into(),
            endpoint,
            locality,
        }],
        selected_profile: Some("fixture-profile".into()),
        enabled: true,
    }
}
fn response(content: Value) -> Vec<u8> {
    serde_json::to_vec(&json!({"choices":[{"finish_reason":"stop","message":{"role":"assistant","content":content.to_string()}}]})).unwrap()
}
fn proposal() -> Value {
    json!({"objective":"Propose fixing Équipe without changing permissions.","output_expectations":"A reviewed patch; checks proposed, not run.","unknowns":[],"questions":[]})
}
fn http(status: &str, body: &[u8]) -> Vec<u8> {
    let mut reply = format!(
        "HTTP/1.1 {status}\r\nContent-Type: application/json\r\nContent-Length: {}\r\n\r\n",
        body.len()
    )
    .into_bytes();
    reply.extend(body);
    reply
}

fn server(
    reply: Vec<u8>,
    delay: Duration,
) -> (String, mpsc::Receiver<Vec<u8>>, thread::JoinHandle<()>) {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let endpoint = format!(
        "http://{}/v1/chat/completions",
        listener.local_addr().unwrap()
    );
    let (tx, rx) = mpsc::channel();
    let worker = thread::spawn(move || {
        let (mut socket, _) = listener.accept().unwrap();
        socket
            .set_read_timeout(Some(Duration::from_secs(2)))
            .unwrap();
        let mut header = Vec::new();
        while !header.ends_with(b"\r\n\r\n") {
            let mut byte = [0];
            socket.read_exact(&mut byte).unwrap();
            header.push(byte[0]);
            assert!(header.len() < 4096);
        }
        let header = String::from_utf8(header).unwrap();
        assert!(header.starts_with("POST /v1/chat/completions HTTP/1.1\r\n"));
        assert!(!header.to_ascii_lowercase().contains("authorization"));
        let length = header
            .lines()
            .find_map(|s| s.strip_prefix("Content-Length: "))
            .unwrap()
            .parse::<usize>()
            .unwrap();
        assert!(length <= MAX_PROVIDER_INPUT);
        let mut body = vec![0; length];
        socket.read_exact(&mut body).unwrap();
        tx.send(body).unwrap();
        thread::sleep(delay);
        let _ = socket.write_all(&reply);
    });
    (endpoint, rx, worker)
}

fn consent(provider: &dyn Provider, request: &Request, control: &Control) -> ProviderConsent {
    ProviderConsent {
        request: request.clone(),
        identity: provider.identity(),
        data_scope: DataScope::RequestAndSelectedEvidence,
        max_calls: 1,
        output_budget: 8192,
        deadline: control.deadline(),
    }
}

#[test]
fn explicit_configuration_is_off_and_missing_selection_fails_closed() {
    let mut config = ProviderSettings::default();
    assert_eq!(
        config.selected().unwrap_err(),
        Error::InferenceNotAuthorized
    );
    config.enabled = true;
    assert_eq!(
        config.selected().unwrap_err(),
        Error::InferenceNotAuthorized
    );
    let config = settings("http://127.0.0.1:1234/v1".into(), Locality::Local);
    let endpoint = config.selected().unwrap();
    assert_eq!(endpoint.identity().model, "fixture-model");
    assert_eq!(endpoint.identity().profile, "fixture-profile");
    let mut duplicate = config.clone();
    duplicate.profiles.push(config.profiles[0].clone());
    assert_eq!(duplicate.selected().unwrap_err(), Error::Invalid);
}

#[test]
fn endpoint_secrets_locality_and_redirect_attack_shapes_reject() {
    for endpoint in [
        "http://example.invalid/v1",
        "https://user:password@example.invalid/v1",
        "https://example.invalid/v1?key=synthetic",
        "https://example.invalid/v1#fragment",
        "http://localhost/v1",
        "http://127.0.0.1:0/v1",
        "http://127.0.0.1/v1%0d",
        "http://[::1]evil/v1",
        "file:///fixture",
    ] {
        for locality in [Locality::Local, Locality::Remote] {
            assert!(
                settings(endpoint.into(), locality).selected().is_err(),
                "invalid endpoint accepted"
            );
        }
    }
    for endpoint in [
        "https://./v1",
        "https://-bad.invalid/v1",
        "https://bad..invalid/v1",
        "https://localhost/v1",
        "https://127.0.0.2/v1",
        "https://0.0.0.0/v1",
    ] {
        assert!(
            settings(endpoint.into(), Locality::Remote)
                .selected()
                .is_err()
        );
    }
    assert!(
        settings(
            "https://provider.invalid/v1/chat/completions".into(),
            Locality::Remote
        )
        .selected()
        .is_ok()
    );
    let endpoint = settings("https://provider.invalid/v1".into(), Locality::Remote)
        .selected()
        .unwrap();
    assert_eq!(
        LoopbackHttp.post(
            &endpoint,
            b"{}",
            &Control::new(Instant::now() + Duration::from_secs(1)),
            100
        ),
        Err(Error::InferenceNotAuthorized)
    );
}

#[test]
fn real_engine_http_success_preserves_original_and_requires_review() {
    let (endpoint, received, worker) =
        server(http("200 OK", &response(proposal())), Duration::ZERO);
    let config = settings(endpoint, Locality::Local);
    let provider = ConfiguredProvider::new(&config, &LoopbackHttp).unwrap();
    let request = capture();
    let control = Control::new(Instant::now() + Duration::from_secs(2));
    let consent = consent(&provider, &request, &control);
    let mut engine = Engine::new(request.clone(), control);
    assert_eq!(
        engine.approve(ReviewChoice::UsePrepared, &Authority),
        Err(Error::ReviewRequired)
    );
    engine
        .prepare(
            &Authority,
            Some(ProviderAccess {
                provider: &provider,
                consent: &consent,
            }),
        )
        .unwrap();
    assert_eq!(engine.state(), PreparationState::Ready);
    assert_eq!(
        engine.preview().unwrap().original.as_bytes(),
        request.data().original.as_bytes()
    );
    assert_eq!(
        engine.brief().unwrap().constraints,
        request.data().constraints
    );
    let wire: Value = serde_json::from_slice(&received.recv().unwrap()).unwrap();
    assert_eq!(wire["model"], "fixture-model");
    assert_eq!(wire["stream"], false);
    let payload: Value =
        serde_json::from_str(wire["messages"][1]["content"].as_str().unwrap()).unwrap();
    assert_eq!(payload["original"], request.data().original);
    assert_eq!(payload["attachments"][0]["reference"], "fixture-attachment");
    let approval = engine
        .approve(ReviewChoice::UsePrepared, &Authority)
        .unwrap();
    assert_eq!(
        engine.handoff(&approval, &Authority).unwrap().delivery,
        Delivery::NotAttempted
    );
    engine.edit(engine.brief().unwrap().clone()).unwrap();
    assert_eq!(
        engine.handoff(&approval, &Authority),
        Err(Error::ReviewRequired)
    );
    worker.join().unwrap();
}

#[test]
fn malformed_status_auth_redirect_size_and_json_reject_without_draft_replacement() {
    let replies = vec![http("401 Unauthorized", b"synthetic rejection"), http("403 Forbidden", b"{}"),
        b"HTTP/1.1 302 Found\r\nLocation: https://provider.invalid/steal\r\nContent-Length: 0\r\n\r\n".to_vec(),
        http("500 Failure", b"{}"), http("200 OK", b"not json"), http("200 OK", b"{}"),
        http("200 OK", &response(json!({"objective":"x"}))),
        http("200 OK", &response(json!({"objective":"x","output_expectations":"y","unknowns":[],"questions":[],"permissions":"invented"}))),
        b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 999999999\r\n\r\n".to_vec(),
        b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nTransfer-Encoding: chunked\r\n\r\n".to_vec(),
        b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 2\r\nContent-Length: 2\r\n\r\n{}".to_vec()];
    for reply in replies {
        let (endpoint, received, worker) = server(reply, Duration::ZERO);
        let config = settings(endpoint, Locality::Local);
        let provider = ConfiguredProvider::new(&config, &LoopbackHttp).unwrap();
        let request = capture();
        let control = Control::new(Instant::now() + Duration::from_secs(2));
        let consent = consent(&provider, &request, &control);
        let mut engine = Engine::new(request.clone(), control);
        assert!(
            engine
                .prepare(
                    &Authority,
                    Some(ProviderAccess {
                        provider: &provider,
                        consent: &consent
                    })
                )
                .is_err()
        );
        assert_eq!(engine.request(), &request);
        assert_eq!(
            engine.approve(ReviewChoice::UsePrepared, &Authority),
            Err(Error::ReviewRequired)
        );
        let original = engine
            .approve(ReviewChoice::UseOriginal, &Authority)
            .unwrap();
        assert_eq!(
            engine
                .handoff(&original, &Authority)
                .unwrap()
                .text
                .as_bytes(),
            request.data().original.as_bytes()
        );
        received.recv().unwrap();
        worker.join().unwrap();
    }
}

#[test]
fn timeout_and_cancel_tear_down_and_cannot_adopt_late_result() {
    for cancel in [false, true] {
        let (endpoint, received, worker) = server(
            http("200 OK", &response(proposal())),
            Duration::from_millis(200),
        );
        let config = settings(endpoint, Locality::Local);
        let request = capture();
        let control =
            Control::new(Instant::now() + Duration::from_millis(if cancel { 1000 } else { 75 }));
        let signal = control.clone();
        let trigger = thread::spawn(move || {
            received.recv().unwrap();
            if cancel {
                signal.cancel();
            }
        });
        let provider = ConfiguredProvider::new(&config, &LoopbackHttp).unwrap();
        let consent = consent(&provider, &request, &control);
        let mut engine = Engine::new(request.clone(), control);
        let start = Instant::now();
        assert_eq!(
            engine.prepare(
                &Authority,
                Some(ProviderAccess {
                    provider: &provider,
                    consent: &consent
                })
            ),
            Err(if cancel {
                Error::Canceled
            } else {
                Error::Deadline
            })
        );
        assert!(start.elapsed() < Duration::from_millis(180));
        trigger.join().unwrap();
        worker.join().unwrap();
        assert!(engine.brief().is_none());
        assert_eq!(engine.request(), &request);
        assert!(
            engine
                .approve(ReviewChoice::UseOriginal, &Authority)
                .is_err()
        );
    }
}

#[test]
fn missing_or_wrong_data_consent_never_calls_transport() {
    struct Never;
    impl JsonTransport for Never {
        fn post(&self, _: &Endpoint, _: &[u8], _: &Control, _: usize) -> Result<Vec<u8>, Error> {
            panic!("no consent must not call transport")
        }
    }
    let config = settings("http://127.0.0.1:1234/v1".into(), Locality::Local);
    let provider = ConfiguredProvider::new(&config, &Never).unwrap();
    let request = capture();
    let control = Control::new(Instant::now() + Duration::from_secs(2));
    let mut consent = consent(&provider, &request, &control);
    consent.identity.locality = Locality::Remote;
    let mut engine = Engine::new(request, control);
    assert_eq!(
        engine.prepare(&Authority, None),
        Err(Error::InferenceNotAuthorized)
    );
    assert_eq!(
        engine.prepare(
            &Authority,
            Some(ProviderAccess {
                provider: &provider,
                consent: &consent
            })
        ),
        Err(Error::InferenceNotAuthorized)
    );
}

#[test]
fn generated_questions_block_approval_and_oversized_proposals_fail_whole() {
    for oversized in [false, true] {
        let mut value = proposal();
        if oversized {
            value["objective"] = json!("x".repeat(MAX_OUTPUT_BYTES));
        } else {
            value["questions"] = json!(["Which behavior is authorized?"]);
        }
        let (endpoint, received, worker) = server(http("200 OK", &response(value)), Duration::ZERO);
        let config = settings(endpoint, Locality::Local);
        let provider = ConfiguredProvider::new(&config, &LoopbackHttp).unwrap();
        let request = capture();
        let control = Control::new(Instant::now() + Duration::from_secs(2));
        let consent = consent(&provider, &request, &control);
        let mut engine = Engine::new(request.clone(), control);
        let prepared = engine.prepare(
            &Authority,
            Some(ProviderAccess {
                provider: &provider,
                consent: &consent,
            }),
        );
        if oversized {
            assert!(prepared.is_err());
        } else {
            prepared.unwrap();
            assert_eq!(engine.state(), PreparationState::NeedsInput);
        }
        assert_eq!(
            engine.approve(ReviewChoice::UsePrepared, &Authority),
            Err(Error::ReviewRequired)
        );
        assert_eq!(engine.request(), &request);
        received.recv().unwrap();
        worker.join().unwrap();
    }
}

#[test]
fn injected_transport_cannot_bypass_response_bound_or_late_result_gate() {
    struct Injected {
        late: bool,
    }
    impl JsonTransport for Injected {
        fn post(
            &self,
            _: &Endpoint,
            _: &[u8],
            control: &Control,
            _: usize,
        ) -> Result<Vec<u8>, Error> {
            if self.late {
                control.supersede();
                Ok(response(proposal()))
            } else {
                Ok(vec![b' '; MAX_PROVIDER_RESPONSE + 1])
            }
        }
    }
    for late in [false, true] {
        let config = settings("http://127.0.0.1:1234/v1".into(), Locality::Local);
        let transport = Injected { late };
        let provider = ConfiguredProvider::new(&config, &transport).unwrap();
        let request = capture();
        let control = Control::new(Instant::now() + Duration::from_secs(1));
        let consent = consent(&provider, &request, &control);
        let mut engine = Engine::new(request.clone(), control);
        assert_eq!(
            engine.prepare(
                &Authority,
                Some(ProviderAccess {
                    provider: &provider,
                    consent: &consent
                })
            ),
            Err(if late {
                Error::Superseded
            } else {
                Error::ProviderFailed
            })
        );
        assert!(engine.brief().is_none());
        assert_eq!(engine.request(), &request);
    }
}
