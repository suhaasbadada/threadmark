//! Dedicated strict parser for explicit one-shot local inference previews.
use std::io::{Read, Write};
use std::path::Path;
use std::process::ExitCode;
use threadmark_daemon::local_refinement::{Options, preview_with_retrieval};
use threadmark_daemon::preparation::{CaptureBinding, RetrievalMode};

pub const USAGE: &str = "local refinement: --data-dir EXISTING_STORE refine preview PROJECT QUERY --profile PROFILE --model MODEL --endpoint URL --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-snapshot SNAPSHOT --confirm-local-inference (original UTF-8 on stdin only, <=4096 bytes). First inspect project show PROJECT and query PROJECT QUERY; explicitly bind that exact registration/snapshot and selected evidence. Confirmation authorizes this one local-operator request, not agent access to arbitrary servers. Only numeric-loopback HTTP; no DNS, remote/TLS/auth, credentials or environment reuse. A local server may forward elsewhere: no isolation claim. At most one call, 30 seconds, 1024 generated tokens, whole JSON line <=8192 bytes; no truncation/fallback. Output includes exact nonsecret profile/model/endpoint/locality; human review occurs outside this CLI. Approval not requested, delivery not attempted; no approve/handoff/copy/send/host draft. Process ends after preview; no retained cross-process approval. Library cancellation is cooperative; CLI cancellation is parent-owned process termination (no signal handler).";

fn parse(words: &[String]) -> Option<(Options, RetrievalMode)> {
    let words = words.iter().map(String::as_str).collect::<Vec<_>>();
    let ["refine", "preview", project, query, flags @ ..] = words.as_slice() else {
        return None;
    };
    let mut values = std::collections::BTreeMap::new();
    let mut confirm = false;
    let mut retrieval = RetrievalMode::Literal;
    let mut index = 0;
    while index < flags.len() {
        let flag = flags[index];
        if flag == "--terms" {
            if retrieval != RetrievalMode::Literal {
                return None;
            }
            retrieval = RetrievalMode::RankedTerms;
            index += 1;
            continue;
        }
        if flag == "--confirm-local-inference" {
            if confirm {
                return None;
            }
            confirm = true;
            index += 1;
            continue;
        }
        if ![
            "--profile",
            "--model",
            "--endpoint",
            "--expected-root",
            "--expected-root-identity",
            "--expected-incarnation",
            "--expected-snapshot",
        ]
        .contains(&flag)
        {
            return None;
        }
        let value = *flags.get(index + 1)?;
        if value.is_empty() || value.starts_with("--") || values.insert(flag, value).is_some() {
            return None;
        }
        index += 2;
    }
    let options = Options {
        expected: CaptureBinding {
            project: (*project).into(),
            root: values.get("--expected-root")?.to_string(),
            root_identity: values.get("--expected-root-identity")?.to_string(),
            incarnation: values.get("--expected-incarnation")?.to_string(),
            snapshot: values.get("--expected-snapshot")?.to_string(),
        },
        query: (*query).into(),
        profile: values.get("--profile")?.to_string(),
        model: values.get("--model")?.to_string(),
        endpoint: values.get("--endpoint")?.to_string(),
        confirm_local_inference: confirm,
    };
    options.validate().ok()?;
    if retrieval == RetrievalMode::RankedTerms {
        threadmark_core::knowledge::validate_query_terms(project, query).ok()?;
    }
    Some((options, retrieval))
}

pub fn run(data_dir: &Path, words: &[String]) -> ExitCode {
    let Some((options, retrieval)) = parse(words) else {
        eprintln!(
            "Optional --terms selects bounded any-term lexical ranking; inspect query-terms with the exact query first. Literal is the default; repeated mode flags are invalid."
        );
        eprintln!("{USAGE}");
        return ExitCode::from(2);
    };
    let mut bytes = Vec::new();
    if std::io::stdin().take(4097).read_to_end(&mut bytes).is_err() || bytes.len() > 4096 {
        return super::failure();
    }
    let Ok(original) = String::from_utf8(bytes) else {
        return super::failure();
    };
    match preview_with_retrieval(data_dir, options, original, retrieval) {
        Ok(line) => {
            if std::io::stdout().lock().write_all(line.as_bytes()).is_err() {
                return super::failure();
            }
            ExitCode::SUCCESS
        }
        Err(_) => super::failure(),
    }
}
