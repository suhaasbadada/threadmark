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
        "explicit ranked human notes: context search-terms PROJECT QUERY --kinds KIND... --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN (1-5 unique kinds; 1-8 lowercase whitespace terms, max 64 bytes/term and 256 bytes/query; mandatory binding, existing storage only; not source evidence)"
    );
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
        "human-only lexical retrieval: context search PROJECT QUERY (active latest human revisions, not source-backed facts; max 256 query UTF-8 bytes, 8 whole entries, 8192 JSON bytes including newline). Opt-in kind filter: --kinds KIND... --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN; 1-5 unique constraint/correction/decision/note/pitfall kinds, existing storage only, no unbound filtered form."
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
        "cached export: append --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-snapshot HASH|none --expected-sources [FILE ...] to the confirmed export command (all required once, exact order, list last, max 64; stale-approval guards, not credentials; JSON v1 unchanged)"
    );
    eprintln!(
        "human-history removal: context forget PROJECT ID --confirm-forget-local-history; context forgotten PROJECT [--expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN] (bound marker reads require existing schema v3/v4; active removal/suppression only, not forensic erasure; sources untouched)"
    );
    eprintln!(
        "optional exact Forget approval: --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-revision N (all four required together; N=1..32; native always binds; not credentials)"
    );
    eprintln!(
        "opt-in human revision guard v1: context update PROJECT ID KIND (bounded stdin) or context retire PROJECT ID, followed by --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-revision N (all four, exact order, N=1..32). Existing store required; stale revision appends nothing. CAS only, not semantic conflict resolution; trusted forms unchanged."
    );
    eprintln!(
        "human-context-batch-edit-v1: context batch-edit PROJECT --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN (all required once, exact order). One closed JSON document on stdin, <=65536 bytes; 2..8 distinct existing IDs, update/retire only, all expected revisions compared atomically. Human declarations, not source truth or semantic resolution; existing schema v3/v4 only."
    );
    eprintln!(
        "opt-in human reads v1: context list PROJECT, context show PROJECT ID, context search PROJECT QUERY accept --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN (all three, exact order, once; existing store only). Checked before human SQL in a coherent snapshot and rechecked before return; not an atomic external revocation lease or source-currentness check. Trusted unbound forms unchanged; metadata is not credentials."
    );
    eprintln!(
        "human-context-comparison-v1: context compare PROJECT NOTE FROM TO --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN (required once, exact order; 1 <= FROM <= TO <= 32; existing store only; no stdin). Exact textual common-prefix/suffix logical-line delta, not minimal or semantic conflict resolution; metadata is not credentials."
    );
    eprintln!(
        "explicit compatibility change: store upgrade --confirm-local-schema-upgrade (existing store only; older binaries cannot open schema v2; no automatic downgrade)"
    );
    eprintln!(
        "schema v3: store upgrade --to-version 3 --confirm-local-schema-upgrade --confirm-legacy-workers-stopped (existing store only; stop older workers first; operator attestation is not machine proof); native removal/index bindings additionally require --expected-incarnation TOKEN before --expected-sources"
    );
    eprintln!(
        "source forget PROJECT PATH --confirm-forget-source [--expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-sources FILE ...]; source forgotten PROJECT [--expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN]; requires existing schema v4; source files and human context untouched; no forensic erasure. Upgrade with store upgrade --to-version 4 --confirm-local-schema-upgrade --confirm-legacy-workers-stopped (stop all legacy workers first; not universal worker fencing)."
    );
    eprintln!("{}", local_refinement::USAGE);
    eprintln!(
        "context prepare-files PROJECT QUERY --mode literal|ranked-any-terms --selected-files FILE ... --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-snapshot HASH|none --expected-sources [FILE ...] (exact order, existing schema v3/v4, immutable full binding; nonempty original UTF-8 on stdin <=4096 bytes, no NUL; whole JSON/LF <=8192 bytes; output candidates only, ALL approved files read for freshness; no I/O avoidance/privacy/AST/performance gain; provider not invoked, approval not requested, delivery not attempted)"
    );
    eprintln!(
        "query-files PROJECT QUERY --mode literal|ranked-any-terms --selected-files FILE ... --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-snapshot HASH|none --expected-sources [FILE ...] (1..64 distinct approved output candidates only; FULL approved policy source/freshness reads remain; required exact binding/order; existing store, no stdin; whole JSON plus newline <=8192 bytes; no Context/Refine integration)"
    );
    eprintln!(
        "cached source reads: query PROJECT TEXT, query-terms PROJECT TEXT or context prepare PROJECT QUERY [--terms] (original only on bounded stdin), followed by --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-snapshot HASH|none --expected-sources [FILE ...] (exact list last, at most 64; all flags required together; current registration alone authorizes source reads, not these metadata values)"
    );
    eprintln!(
        "source inspect PROJECT PATH LINE --radius 0..3 --expected-source-hash HASH --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-snapshot HASH --expected-sources [FILE ...] (exact binding required; existing store only; indexed center and at most seven whole source lines, 8192 JSON bytes including newline; no stdin or indexing)"
    );
    eprintln!(
        "project coverage PROJECT --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-snapshot HASH|none --expected-sources [FILE ...] (required once, exact order; metadata-only lexical status of explicit approved files, not semantic completeness; existing read-only DELETE store, no stdin or Build; 65536 JSON bytes including newline)"
    );
    eprintln!(
        "index-incremental PROJECT --expected-root ROOT --expected-root-identity IDENTITY --expected-incarnation TOKEN --expected-snapshot HASH|none --expected-sources [FILE ...] (required once, exact order; existing writable schema v3/v4 store only, no stdin; validated lexical SQL-row reuse, full bounded source reads, no semantic coverage; 65536 JSON bytes including newline; ordinary index unchanged)"
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
    // Inspection has 20 fixed arguments including --data-dir/STORE, plus the
    // complete approved policy of up to 64 files. Other grammars keep their cap.
    let argument_limit = if args.get(2).is_some_and(|s| s == "query-files") {
        145 // fixed grammar plus 64 selected and 64 complete-policy paths
    } else if args.get(2).is_some_and(|s| s == "context")
        && args.get(3).is_some_and(|s| s == "prepare-files")
    {
        146
    } else if args.get(2).is_some_and(|s| s == "source")
        && args.get(3).is_some_and(|s| s == "inspect")
    {
        84
    } else {
        80
    };
    if args.len() > argument_limit {
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
        ["source", "forgotten", project, flags @ ..] => {
            if flags.is_empty() {
                Command::ForgottenSources((*project).into())
            } else {
                let Some(bound) = human_read_binding(project, flags) else {
                    return usage();
                };
                Command::ForgottenSourcesBound(
                    (*project).into(),
                    bound.root.into(),
                    bound.root_identity.into(),
                    bound.incarnation.into(),
                )
            }
        }
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
        ["context", "forgotten", project, flags @ ..] => {
            if flags.is_empty() {
                Command::ForgottenContexts((*project).into())
            } else {
                let Some(bound) = human_read_binding(project, flags) else {
                    return usage();
                };
                Command::ForgottenContextsBound(
                    (*project).into(),
                    bound.root.into(),
                    bound.root_identity.into(),
                    bound.incarnation.into(),
                )
            }
        }
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
        [
            "project",
            "export",
            id,
            "--confirm-export-local-content",
            binding @ ..,
        ] => {
            if binding
                .iter()
                .skip(1)
                .step_by(2)
                .take(4)
                .any(|v| v.starts_with("--"))
            {
                return usage();
            }
            let Some(expected) = read_binding(id, "export", binding) else {
                return usage();
            };
            Command::ExportProjectBound(expected)
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
        ["index-incremental", id, binding @ ..] => {
            let Some(expected) = read_binding(id, "incremental", binding) else {
                return usage();
            };
            if threadmark_core::knowledge::validate_incremental_binding(&expected).is_err() {
                return usage();
            }
            Command::IndexIncremental(expected)
        }
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
        [
            "source",
            "inspect",
            id,
            path,
            line,
            "--radius",
            radius,
            "--expected-source-hash",
            hash,
            binding @ ..,
        ] => {
            let Some(expected) = read_binding(id, "inspect", binding) else {
                return usage();
            };
            let Some(line) = canonical_coordinate(line) else {
                return usage();
            };
            let Some(radius) = canonical_coordinate(radius) else {
                return usage();
            };
            let anchor = threadmark_core::knowledge::SourceAnchorInspection {
                path: (*path).into(),
                line,
                radius,
                source_hash: (*hash).into(),
            };
            if threadmark_core::knowledge::validate_source_inspection(&expected, &anchor).is_err() {
                return usage();
            }
            Command::InspectSourceAnchor(expected, anchor)
        }
        ["project", "coverage", id, binding @ ..] => {
            let Some(expected) = read_binding(id, "coverage", binding) else {
                return usage();
            };
            Command::CoverageReport(expected)
        }
        ["query", id, text] => Command::Query((*id).into(), (*text).into()),
        [
            "query-files",
            id,
            text,
            "--mode",
            mode,
            "--selected-files",
            rest @ ..,
        ] => {
            use threadmark_core::knowledge::{FileQuery, FileQueryMode};
            let mode = match *mode {
                "literal" => FileQueryMode::Literal,
                "ranked-any-terms" => FileQueryMode::RankedAnyTerms,
                _ => return usage(),
            };
            let Some(end) = rest.iter().position(|w| *w == "--expected-root") else {
                return usage();
            };
            let Some(expected) = read_binding(id, text, &rest[end..]) else {
                return usage();
            };
            let request = FileQuery {
                query: (*text).into(),
                mode,
                selected_paths: rest[..end].iter().map(|p| (*p).into()).collect(),
            };
            if request.validate(&expected).is_err() {
                return usage();
            }
            Command::QueryFilesBound(expected, request)
        }
        [
            "context",
            "prepare-files",
            id,
            text,
            "--mode",
            mode,
            "--selected-files",
            rest @ ..,
        ] => {
            use threadmark_core::knowledge::{FileQuery, FileQueryMode};
            use threadmark_daemon::preparation::file_scoped::FileContextPlan;
            let mode = match *mode {
                "literal" => FileQueryMode::Literal,
                "ranked-any-terms" => FileQueryMode::RankedAnyTerms,
                _ => return usage(),
            };
            let Some(end) = rest.iter().position(|w| *w == "--expected-root") else {
                return usage();
            };
            let Some(expected) = read_binding(id, text, &rest[end..]) else {
                return usage();
            };
            let Ok(plan) = FileContextPlan::new(
                expected,
                FileQuery {
                    query: (*text).into(),
                    mode,
                    selected_paths: rest[..end].iter().map(|p| (*p).into()).collect(),
                },
            ) else {
                return usage();
            };
            let mut bytes = Vec::new();
            if std::io::stdin().take(4097).read_to_end(&mut bytes).is_err() || bytes.len() > 4096 {
                return failure();
            }
            let Ok(original) = String::from_utf8(bytes) else {
                return failure();
            };
            Command::PrepareContextFiles(plan, original)
        }
        ["query-terms", id, text, binding @ ..] if !binding.is_empty() => {
            let Some(expected) = read_binding(id, text, binding) else {
                return usage();
            };
            if threadmark_core::knowledge::validate_query_terms(id, text).is_err() {
                return usage();
            }
            Command::QueryTermsBound(expected, (*text).into())
        }
        ["query", id, text, binding @ ..] => {
            let Some(expected) = read_binding(id, text, binding) else {
                return usage();
            };
            Command::QueryBound(expected, (*text).into())
        }
        ["context", "prepare", id, query, binding @ ..]
            if !binding.is_empty() && binding != ["--terms"] =>
        {
            // Mode must precede the exact final source list. No repeated/unknown
            // flags or preflight followed by an unbound project reload.
            let (ranked, binding) = match binding {
                ["--terms", rest @ ..] => (true, rest),
                _ => (false, binding),
            };
            let Some(expected) = read_binding(id, query, binding) else {
                return usage();
            };
            if ranked && threadmark_core::knowledge::validate_query_terms(id, query).is_err() {
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
                Command::PrepareContextTermsBound(expected, (*query).into(), original)
            } else {
                Command::PrepareContextBound(expected, (*query).into(), original)
            }
        }
        [
            "context",
            "search-terms",
            project,
            query,
            "--kinds",
            rest @ ..,
        ] => {
            let Some(end) = rest.iter().position(|s| s.starts_with("--")) else {
                return usage();
            };
            let kinds: Vec<String> = rest[..end].iter().map(|s| (*s).into()).collect();
            let Ok(plan) = threadmark_core::knowledge::HumanRankedQuery::new(query, &kinds) else {
                return usage();
            };
            let Some(bound) = human_read_binding(project, &rest[end..]) else {
                return usage();
            };
            Command::SearchContextTermsBound(
                (*project).into(),
                plan,
                bound.root.into(),
                bound.root_identity.into(),
                bound.incarnation.into(),
            )
        }
        ["context", "search", project, query, flags @ ..] => {
            if let Some(rest) = flags.strip_prefix(&["--kinds"]) {
                let Some(end) = rest.iter().position(|s| s.starts_with("--")) else {
                    return usage();
                };
                let kinds: Vec<String> = rest[..end].iter().map(|s| (*s).into()).collect();
                let Ok(kinds) = threadmark_core::knowledge::HumanSearchKinds::new(&kinds) else {
                    return usage();
                };
                let Some(bound) = human_read_binding(project, &rest[end..]) else {
                    return usage();
                };
                if threadmark_core::knowledge::validate_human_search(project, query).is_err() {
                    return usage();
                }
                Command::SearchContextKindsBound(
                    (*project).into(),
                    (*query).into(),
                    kinds.kinds().to_vec(),
                    bound.root.into(),
                    bound.root_identity.into(),
                    bound.incarnation.into(),
                )
            } else if flags.is_empty() {
                Command::SearchContext((*project).into(), (*query).into())
            } else {
                let Some(bound) = human_read_binding(project, flags) else {
                    return usage();
                };
                if threadmark_core::knowledge::validate_human_search(project, query).is_err() {
                    return usage();
                }
                Command::SearchContextBound(
                    (*project).into(),
                    (*query).into(),
                    bound.root.into(),
                    bound.root_identity.into(),
                    bound.incarnation.into(),
                )
            }
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
        ["context", "batch-edit", project, flags @ ..] => {
            let Some(binding) = human_read_binding(project, flags) else {
                return usage();
            };
            let mut bytes = Vec::new();
            if std::io::stdin()
                .take(65_537)
                .read_to_end(&mut bytes)
                .is_err()
            {
                return failure();
            }
            let Ok(request) = threadmark_core::knowledge::ContextBatchEdit::parse(&bytes) else {
                return failure();
            };
            if request.validate(project, &binding).is_err() {
                return failure();
            }
            Command::EditContextBatchBound(
                (*project).into(),
                request,
                binding.root.into(),
                binding.root_identity.into(),
                binding.incarnation.into(),
            )
        }
        ["context", "update", project, id, kind, binding @ ..]
            if binding.contains(&"--expected-revision") =>
        {
            let Some(bound) = revision_binding(project, id, binding) else {
                return usage();
            };
            if threadmark_core::knowledge::validate_context_kind(kind).is_err() {
                return usage();
            }
            let mut bytes = Vec::new();
            if std::io::stdin().take(4097).read_to_end(&mut bytes).is_err() || bytes.len() > 4096 {
                return failure();
            }
            let Ok(text) = String::from_utf8(bytes) else {
                return failure();
            };
            if threadmark_core::knowledge::validate_context_text(&text).is_err() {
                return failure();
            }
            Command::UpdateContextRevisionBound(
                (*project).into(),
                (*id).into(),
                (*kind).into(),
                text,
                bound.root.into(),
                bound.root_identity.into(),
                bound.incarnation.into(),
                bound.revision,
            )
        }
        ["context", "retire", project, id, binding @ ..]
            if binding.contains(&"--expected-revision") =>
        {
            let Some(bound) = revision_binding(project, id, binding) else {
                return usage();
            };
            Command::RetireContextRevisionBound(
                (*project).into(),
                (*id).into(),
                bound.root.into(),
                bound.root_identity.into(),
                bound.incarnation.into(),
                bound.revision,
            )
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
        ["context", "list", project, flags @ ..] => {
            if flags.is_empty() {
                Command::Contexts((*project).into())
            } else {
                let Some(bound) = human_read_binding(project, flags) else {
                    return usage();
                };
                Command::ContextsBound(
                    (*project).into(),
                    bound.root.into(),
                    bound.root_identity.into(),
                    bound.incarnation.into(),
                )
            }
        }
        ["context", "compare", project, id, from, to, flags @ ..] => {
            let Some(binding) = human_read_binding(project, flags) else {
                return usage();
            };
            let parse = |word: &str| -> Option<u32> {
                if word.is_empty() || !word.bytes().all(|b| b.is_ascii_digit()) {
                    return None;
                }
                word.parse().ok()
            };
            let (Some(from), Some(to)) = (parse(from), parse(to)) else {
                return usage();
            };
            if threadmark_core::knowledge::validate_context_comparison(
                project, id, from, to, &binding,
            )
            .is_err()
            {
                return usage();
            }
            Command::CompareContextBound(
                (*project).into(),
                (*id).into(),
                from,
                to,
                binding.root.into(),
                binding.root_identity.into(),
                binding.incarnation.into(),
            )
        }
        ["context", "show", project, id, flags @ ..] => {
            if flags.is_empty() {
                Command::Context((*project).into(), (*id).into())
            } else {
                let Some(bound) = human_read_binding(project, flags) else {
                    return usage();
                };
                if threadmark_core::knowledge::validate_export_project(id).is_err() {
                    return usage();
                }
                Command::ContextBound(
                    (*project).into(),
                    (*id).into(),
                    bound.root.into(),
                    bound.root_identity.into(),
                    bound.incarnation.into(),
                )
            }
        }
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

// Closed three-flag grammar: no partial, repeated, legacy or source-scope flags.
fn human_read_binding<'a>(
    project: &str,
    words: &[&'a str],
) -> Option<threadmark_core::knowledge::ContextReadBinding<'a>> {
    let [
        "--expected-root",
        root,
        "--expected-root-identity",
        identity,
        "--expected-incarnation",
        token,
    ] = words
    else {
        return None;
    };
    let binding = threadmark_core::knowledge::ContextReadBinding {
        root,
        root_identity: identity,
        incarnation: token,
    };
    binding.validate(project).ok()?;
    Some(binding)
}

// Closed, ordered grammar rejects partial, repeated and unknown flags before stdin.
fn revision_binding<'a>(
    project: &str,
    id: &str,
    words: &[&'a str],
) -> Option<threadmark_core::knowledge::ContextRevisionBinding<'a>> {
    let [
        "--expected-root",
        root,
        "--expected-root-identity",
        identity,
        "--expected-incarnation",
        token,
        "--expected-revision",
        revision,
    ] = words
    else {
        return None;
    };
    if revision.is_empty() || !revision.bytes().all(|b| b.is_ascii_digit()) {
        return None;
    }
    let bound = threadmark_core::knowledge::ContextRevisionBinding {
        root,
        root_identity: identity,
        incarnation: token,
        revision: revision.parse().ok()?,
    };
    bound.validate(project, id).ok()?;
    Some(bound)
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

fn canonical_coordinate(text: &str) -> Option<usize> {
    if text.is_empty()
        || text.len() > 4
        || !text.bytes().all(|b| b.is_ascii_digit())
        || (text.len() > 1 && text.starts_with('0'))
    {
        return None;
    }
    text.parse().ok()
}
