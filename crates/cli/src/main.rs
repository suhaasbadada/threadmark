//! Manual local knowledge commands and offline diagnostics; never a service probe.

mod local_refinement;
mod local_review;

fn main() -> std::process::ExitCode {
    let args: Vec<_> = std::env::args_os().skip(1).collect();
    if args.first().is_some_and(|s| s == "--data-dir") {
        return knowledge(&args);
    }
    if args.len() != 1 {
        return usage();
    }
    if args[0] == "--version" {
        println!("threadmark {}", env!("CARGO_PKG_VERSION"));
    } else if args[0] == "status" {
        println!(
            "stage=manual-lexical-core contract={} service=not-connected storage=explicit-data-dir-sqlite adapters=none inference=disabled",
            threadmark_core::CONTRACT_VERSION
        );
    } else if args[0] == "smoke" {
        if threadmark_daemon::smoke().is_err() {
            eprintln!("foundation check failed");
            return std::process::ExitCode::FAILURE;
        }
        println!("foundation check passed; synthetic_items=1; no host delivery");
    } else {
        return usage();
    }
    std::process::ExitCode::SUCCESS
}

fn usage() -> std::process::ExitCode {
    eprintln!(
        "optional ranked preparation: context prepare PROJECT QUERY --terms; refine preview PROJECT QUERY --terms (all inference confirmation/binding flags still required). Inspect query-terms PROJECT QUERY first; no automatic fallback or inference."
    );
    eprintln!(
        "explicit lexical ranking: --data-dir EXISTING_STORE query-terms PROJECT QUERY (1..8 deduplicated Unicode-lowercase whitespace terms, <=64 UTF-8 bytes each; query <=256 bytes, no controls; any-term matches, distinct terms then occurrences descending, path/line ascending; no semantic search; literal query and Context/Refine defaults unchanged)"
    );
    eprintln!(
        "usage: threadmark --version | status | smoke; or --data-dir ABSOLUTE_NEW_PRIVATE_DIR project add ID ROOT [FILE ...] | project list | project show ID | project sources ID [FILE ...] | project remove ID --confirm-remove-local-data (local policy/evidence/context only; sources untouched; not Forget or forensic erasure) | index PROJECT | query PROJECT TEXT | context prepare PROJECT QUERY (original on stdin) | context add/update PROJECT ID KIND (stdin) | context retire/show PROJECT ID | context list PROJECT"
    );
    eprintln!(
        "human-only lexical retrieval: context search PROJECT QUERY (active latest human revisions, not source-backed facts; max 256 query UTF-8 bytes, 8 whole entries, 8192 JSON bytes including newline)"
    );
    eprintln!(
        "optional exact removal approval binding: --expected-root ROOT --expected-root-identity IDENTITY (both required together; not credentials)"
    );
    eprintln!(
        "bound lexical reconciliation: index PROJECT --expected-root ROOT --expected-root-identity IDENTITY --expected-sources FILE ... (exact nonempty registered policy; not credentials)"
    );
    eprintln!(
        "cached mutations: project sources ID --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-sources OLD ... --new-sources NEW ... (each list may be empty; at most 64 files); context add/update PROJECT ID KIND and context retire PROJECT ID accept the same three registration flags. Unbound forms remain explicit operator commands; bindings are not credentials."
    );
    eprintln!(
        "local sensitive-content export: --data-dir EXISTING_STORE project export PROJECT --confirm-export-local-content (stdout only; no delivery)"
    );
    eprintln!(
        "human-history removal: context forget PROJECT ID --confirm-forget-local-history; context forgotten PROJECT (active removal/suppression only, not forensic erasure; sources untouched)"
    );
    eprintln!(
        "optional exact Forget approval: --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-revision N (all four required together; N=1..32; native always binds; not credentials)"
    );
    eprintln!(
        "explicit compatibility change: store upgrade --confirm-local-schema-upgrade (existing store only; older binaries cannot open schema v2; no automatic downgrade)"
    );
    eprintln!(
        "schema v3: store upgrade --to-version 3 --confirm-local-schema-upgrade --confirm-legacy-workers-stopped (existing store only; stop older workers first; operator attestation is not machine proof); native removal/index bindings additionally require --expected-incarnation TOKEN before --expected-sources"
    );
    eprintln!(
        "source forget PROJECT PATH --confirm-forget-source [--expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-sources FILE ...]; source forgotten PROJECT; requires existing schema v4; source files and human context untouched; no forensic erasure. Upgrade with store upgrade --to-version 4 --confirm-local-schema-upgrade --confirm-legacy-workers-stopped (stop all legacy workers first; not universal worker fencing)."
    );
    eprintln!("{}", local_refinement::USAGE);
    eprintln!(
        "cached source reads: query PROJECT TEXT or context prepare PROJECT QUERY (original only on bounded stdin), followed by --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-snapshot HASH|none --expected-sources [FILE ...] (exact list last, at most 64; all flags required together; current registration alone authorizes source reads, not these metadata values)"
    );
    std::process::ExitCode::from(2)
}

fn knowledge(args: &[std::ffi::OsString]) -> std::process::ExitCode {
    use std::io::Read;
    use threadmark_daemon::knowledge::{Command, run};
    if args.len() < 3 {
        return usage();
    }
    let data_dir = std::path::Path::new(&args[1]);
    // Recognize the private protocol before generic argument rejection. Its
    // watchdog and closed JSON errors must also cover malformed launch arguments.
    if args.get(2).is_some_and(|word| word == "refine")
        && args.get(3).is_some_and(|word| word == "review")
    {
        return local_review::run(data_dir, &args[2..]);
    }
    // Bounded parser; untrusted arguments and errors are never echoed.
    if args.len() > 80 {
        return usage();
    }
    let Some(words) = args[2..]
        .iter()
        .map(|s| s.to_str().filter(|s| s.len() <= 4096).map(str::to_owned))
        .collect::<Option<Vec<_>>>()
    else {
        return usage();
    };
    if words.first().is_some_and(|word| word == "refine") {
        return local_refinement::run(data_dir, &words);
    }
    let command = match words
        .iter()
        .map(String::as_str)
        .collect::<Vec<_>>()
        .as_slice()
    {
        ["store", "upgrade", "--confirm-local-schema-upgrade"] => Command::UpgradeStore,
        [
            "store",
            "upgrade",
            "--to-version",
            "4",
            "--confirm-local-schema-upgrade",
            "--confirm-legacy-workers-stopped",
        ] => Command::UpgradeStoreV4,
        ["source", "forget", project, path, "--confirm-forget-source"] => {
            Command::ForgetSource((*project).into(), (*path).into())
        }
        [
            "source",
            "forget",
            project,
            path,
            "--confirm-forget-source",
            "--expected-root",
            root,
            "--expected-root-identity",
            identity,
            "--expected-incarnation",
            token,
            "--expected-sources",
            files @ ..,
        ] => Command::ForgetSourceBound(
            (*project).into(),
            (*path).into(),
            (*root).into(),
            (*identity).into(),
            (*token).into(),
            files.iter().map(|s| (*s).into()).collect(),
        ),
        ["source", "forgotten", project] => Command::ForgottenSources((*project).into()),
        [
            "store",
            "upgrade",
            "--to-version",
            "3",
            "--confirm-local-schema-upgrade",
            "--confirm-legacy-workers-stopped",
        ] => Command::UpgradeStoreV3,
        [
            "project",
            "remove",
            id,
            "--confirm-remove-local-data",
            "--expected-root",
            root,
            "--expected-root-identity",
            identity,
            "--expected-incarnation",
            token,
        ] => Command::RemoveProjectIncarnationBound(
            (*id).into(),
            (*root).into(),
            (*identity).into(),
            (*token).into(),
        ),
        [
            "index",
            id,
            "--expected-root",
            root,
            "--expected-root-identity",
            identity,
            "--expected-incarnation",
            token,
            "--expected-sources",
            files @ ..,
        ] => Command::IndexIncarnationBound(
            (*id).into(),
            (*root).into(),
            (*identity).into(),
            files.iter().map(|s| (*s).into()).collect(),
            (*token).into(),
        ),
        [
            "context",
            "forget",
            project,
            id,
            "--confirm-forget-local-history",
            "--expected-root",
            root,
            "--expected-root-identity",
            identity,
            "--expected-incarnation",
            token,
            "--expected-revision",
            revision,
        ] => {
            let Ok(revision) = revision.parse::<u32>() else {
                return usage();
            };
            Command::ForgetContextBound(
                (*project).into(),
                (*id).into(),
                (*root).into(),
                (*identity).into(),
                (*token).into(),
                revision,
            )
        }
        [
            "context",
            "forget",
            project,
            id,
            "--confirm-forget-local-history",
        ] => Command::ForgetContext((*project).into(), (*id).into()),
        ["context", "forgotten", project] => Command::ForgottenContexts((*project).into()),
        ["project", "add", id, root, files @ ..] => Command::AddProject(
            (*id).into(),
            (*root).into(),
            files.iter().map(|s| (*s).into()).collect(),
        ),
        ["project", "list"] => Command::Projects,
        ["project", "show", id] => Command::Project((*id).into()),
        ["project", "export", id, "--confirm-export-local-content"] => {
            Command::ExportProject((*id).into())
        }
        ["project", "remove", id, "--confirm-remove-local-data"] => {
            Command::RemoveProject((*id).into())
        }
        [
            "project",
            "remove",
            id,
            "--confirm-remove-local-data",
            "--expected-root",
            root,
            "--expected-root-identity",
            identity,
        ] => Command::RemoveProjectBound((*id).into(), (*root).into(), (*identity).into()),
        [
            "project",
            "sources",
            id,
            "--expected-root",
            root,
            "--expected-root-identity",
            identity,
            "--expected-incarnation",
            token,
            "--expected-sources",
            files @ ..,
        ] => {
            let Some(split) = files.iter().position(|p| *p == "--new-sources") else {
                return usage();
            };
            let (old, rest) = files.split_at(split);
            let new = &rest[1..];
            if old.len() > 64
                || new.len() > 64
                || old.iter().chain(new).any(|p| p.starts_with("--"))
            {
                return usage();
            }
            Command::SourcesBound(
                (*id).into(),
                (*root).into(),
                (*identity).into(),
                (*token).into(),
                old.iter().map(|s| (*s).into()).collect(),
                new.iter().map(|s| (*s).into()).collect(),
            )
        }
        ["project", "sources", id, files @ ..] if !files.iter().any(|p| p.starts_with("--")) => {
            Command::Sources((*id).into(), files.iter().map(|s| (*s).into()).collect())
        }
        ["index", id] => Command::Index((*id).into()),
        [
            "index",
            id,
            "--expected-root",
            root,
            "--expected-root-identity",
            identity,
            "--expected-sources",
            files @ ..,
        ] => Command::IndexBound(
            (*id).into(),
            (*root).into(),
            (*identity).into(),
            files.iter().map(|s| (*s).into()).collect(),
        ),
        ["query", id, text] => Command::Query((*id).into(), (*text).into()),
        ["query", id, text, binding @ ..] => {
            let Some(expected) = read_binding(id, text, binding) else {
                return usage();
            };
            Command::QueryBound(expected, (*text).into())
        }
        ["context", "prepare", id, query, binding @ ..]
            if !binding.is_empty() && binding != ["--terms"] =>
        {
            let Some(expected) = read_binding(id, query, binding) else {
                return usage();
            };
            let mut bytes = Vec::new();
            if std::io::stdin().take(4097).read_to_end(&mut bytes).is_err() || bytes.len() > 4096 {
                return failure();
            }
            let Ok(original) = String::from_utf8(bytes) else {
                return failure();
            };
            Command::PrepareContextBound(expected, (*query).into(), original)
        }
        ["context", "search", project, query] => {
            Command::SearchContext((*project).into(), (*query).into())
        }
        ["query-terms", id, text] => Command::QueryTerms((*id).into(), (*text).into()),
        ["context", "prepare", project, query, flags @ ..] => {
            let ranked = match flags {
                [] => false,
                ["--terms"] => true,
                _ => return usage(),
            };
            if ranked && threadmark_core::knowledge::validate_query_terms(project, query).is_err() {
                return usage();
            }
            let mut bytes = Vec::new();
            if std::io::stdin().take(4097).read_to_end(&mut bytes).is_err() || bytes.len() > 4096 {
                return failure();
            }
            let Ok(original) = String::from_utf8(bytes) else {
                return failure();
            };
            if ranked {
                Command::PrepareContextTerms((*project).into(), (*query).into(), original)
            } else {
                Command::PrepareContext((*project).into(), (*query).into(), original)
            }
        }
        [
            "context",
            op @ ("add" | "update"),
            project,
            id,
            kind,
            binding @ ..,
        ] => {
            let bound = match binding {
                [] => None,
                [
                    "--expected-root",
                    root,
                    "--expected-root-identity",
                    identity,
                    "--expected-incarnation",
                    token,
                ] => {
                    if threadmark_core::knowledge::validate_removal_binding(project, root, identity)
                        .is_err()
                        || threadmark_core::knowledge::validate_incarnation(token).is_err()
                    {
                        return usage();
                    }
                    Some((
                        (*root).to_owned(),
                        (*identity).to_owned(),
                        (*token).to_owned(),
                    ))
                }
                _ => return usage(),
            };
            let mut bytes = Vec::new();
            if std::io::stdin().take(4097).read_to_end(&mut bytes).is_err() || bytes.len() > 4096 {
                return failure();
            }
            let Ok(text) = String::from_utf8(bytes) else {
                return failure();
            };
            if let Some((root, identity, token)) = bound {
                Command::WriteContextBound(
                    (*project).into(),
                    (*id).into(),
                    (*kind).into(),
                    text,
                    *op == "update",
                    root,
                    identity,
                    token,
                )
            } else {
                Command::WriteContext(
                    (*project).into(),
                    (*id).into(),
                    (*kind).into(),
                    text,
                    *op == "update",
                )
            }
        }
        [
            "context",
            "retire",
            project,
            id,
            "--expected-root",
            root,
            "--expected-root-identity",
            identity,
            "--expected-incarnation",
            token,
        ] => Command::RetireContextBound(
            (*project).into(),
            (*id).into(),
            (*root).into(),
            (*identity).into(),
            (*token).into(),
        ),
        ["context", "retire", project, id] => {
            Command::RetireContext((*project).into(), (*id).into())
        }
        ["context", "list", project] => Command::Contexts((*project).into()),
        ["context", "show", project, id] => Command::Context((*project).into(), (*id).into()),
        _ => return usage(),
    };
    match run(
        data_dir,
        command,
        &std::sync::atomic::AtomicBool::new(false),
    )
    .and_then(|value| {
        serde_json::to_string(&value).map_err(|_| threadmark_core::Error::Unavailable)
    }) {
        Ok(json) => {
            println!("{json}");
            std::process::ExitCode::SUCCESS
        }
        Err(_) => failure(),
    }
}

fn failure() -> std::process::ExitCode {
    eprintln!("local knowledge operation failed; no content published");
    std::process::ExitCode::FAILURE
}

// Sources are last, so no path can be confused with a later option. No filesystem
// lookup uses these arguments; only the current core registration authorizes reads.
fn read_binding(
    id: &str,
    query: &str,
    words: &[&str],
) -> Option<threadmark_core::knowledge::Project> {
    let [
        "--expected-root",
        root,
        "--expected-root-identity",
        identity,
        "--expected-incarnation",
        token,
        "--expected-snapshot",
        snapshot,
        "--expected-sources",
        sources @ ..,
    ] = words
    else {
        return None;
    };
    if sources.iter().any(|s| s.starts_with("--")) {
        return None;
    }
    let expected = threadmark_core::knowledge::Project {
        id: id.into(),
        root: (*root).into(),
        root_identity: (*identity).into(),
        incarnation: Some((*token).into()),
        sources: sources.iter().map(|s| (*s).into()).collect(),
        snapshot: if *snapshot == "none" {
            None
        } else {
            Some((*snapshot).into())
        },
    };
    threadmark_core::knowledge::validate_query_binding(&expected, query).ok()?;
    Some(expected)
}
