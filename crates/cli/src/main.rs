//! Manual local knowledge commands and offline diagnostics; never a service probe.

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
        "usage: threadmark --version | status | smoke; or --data-dir ABSOLUTE_NEW_PRIVATE_DIR project add ID ROOT [FILE ...] | project list | project show ID | project sources ID [FILE ...] | project remove ID --confirm-remove-local-data (local policy/evidence/context only; sources untouched; not Forget or forensic erasure) | index PROJECT | query PROJECT TEXT | context prepare PROJECT QUERY (original on stdin) | context add/update PROJECT ID KIND (stdin) | context retire/show PROJECT ID | context list PROJECT"
    );
    eprintln!(
        "optional exact removal approval binding: --expected-root ROOT --expected-root-identity IDENTITY (both required together; not credentials)"
    );
    eprintln!(
        "bound lexical reconciliation: index PROJECT --expected-root ROOT --expected-root-identity IDENTITY --expected-sources FILE ... (exact nonempty registered policy; not credentials)"
    );
    eprintln!(
        "local sensitive-content export: --data-dir EXISTING_STORE project export PROJECT --confirm-export-local-content (stdout only; no delivery)"
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
    let command = match words
        .iter()
        .map(String::as_str)
        .collect::<Vec<_>>()
        .as_slice()
    {
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
        ["project", "sources", id, files @ ..] => {
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
        ["context", "prepare", project, query] => {
            let mut bytes = Vec::new();
            if std::io::stdin().take(4097).read_to_end(&mut bytes).is_err() || bytes.len() > 4096 {
                return failure();
            }
            let Ok(original) = String::from_utf8(bytes) else {
                return failure();
            };
            Command::PrepareContext((*project).into(), (*query).into(), original)
        }
        ["context", op @ ("add" | "update"), project, id, kind] => {
            let mut bytes = Vec::new();
            if std::io::stdin().take(4097).read_to_end(&mut bytes).is_err() || bytes.len() > 4096 {
                return failure();
            }
            let Ok(text) = String::from_utf8(bytes) else {
                return failure();
            };
            Command::WriteContext(
                (*project).into(),
                (*id).into(),
                (*kind).into(),
                text,
                *op == "update",
            )
        }
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
