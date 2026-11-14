//! Bounded synchronous product commands over the core store, not a service transport.

use serde_json::{Value, json};
use std::path::{Path, PathBuf};
use std::sync::atomic::AtomicBool;
use threadmark_core::Error;
use threadmark_core::knowledge::{LexicalLines, Store};

/// Typed local-owner commands. No request-supplied root can override registered policy.
pub enum Command {
    /// Approve a root and exact relative files.
    AddProject(String, PathBuf, Vec<String>),
    /// Explicitly remove this project's local data only, never source files.
    RemoveProject(String),
    /// Exact caller-bound approval; IDs and binding values are not credentials.
    RemoveProjectBound(String, String, String),
    /// Native cached removal bound to a registration nonce.
    RemoveProjectIncarnationBound(String, String, String, String),
    /// Inspect registered projects.
    Projects,
    /// Inspect one project's source policy.
    Project(String),
    /// Explicit complete-bound metadata-only lexical coverage; never Build.
    CoverageReport(threadmark_core::knowledge::Project),
    /// Explicit caller-approved sensitive local-content export, never delivery.
    ExportProject(String),
    /// Explicitly approved local export guarded by complete captured metadata.
    ExportProjectBound(threadmark_core::knowledge::Project),
    /// Revoke/replace source policy and invalidate active evidence immediately.
    Sources(String, Vec<String>),
    /// Exact captured registration and old policy, checked before mutation.
    SourcesBound(String, String, String, String, Vec<String>, Vec<String>),
    /// Explicit bounded index job.
    Index(String),
    /// Explicit manual lexical row reuse, bound to a full captured project.
    IndexIncremental(threadmark_core::knowledge::Project),
    /// Timed reconciliation bound to exact previously approved scope.
    IndexBound(String, String, String, Vec<String>),
    /// Native automatic reconciliation bound to a registration nonce.
    IndexIncarnationBound(String, String, String, Vec<String>, String),
    /// Bounded source-backed lexical inspection.
    Query(String, String),
    /// Cached read bound before source traversal to all captured metadata.
    QueryBound(threadmark_core::knowledge::Project, String),
    /// Explicit indexed source-anchor window, bound to the complete captured project.
    InspectSourceAnchor(
        threadmark_core::knowledge::Project,
        threadmark_core::knowledge::SourceAnchorInspection,
    ),
    /// Bounded human-only active latest context search; never source evidence.
    SearchContext(String, String),
    /// Opt-in human search scoped before human SQL reads (root, identity, nonce).
    SearchContextBound(String, String, String, String, String),
    /// Explicit filtered human search, mandatory captured registration.
    SearchContextKindsBound(String, String, Vec<String>, String, String, String),
    /// Explicit any-term lexical ranking; literal query/default preparation unchanged.
    QueryTerms(String, String),
    /// Cached ranked read; exact binding reaches core before traversal.
    QueryTermsBound(threadmark_core::knowledge::Project, String),
    /// Prepare a memory-only context preview (project, query, unchanged original).
    PrepareContext(String, String, String),
    /// Context selection and revalidation use the same captured project.
    PrepareContextBound(threadmark_core::knowledge::Project, String, String),
    /// Explicit any-term ranked Context; existing literal command unchanged.
    PrepareContextTerms(String, String, String),
    /// Cached ranked Context, including engine revalidation.
    PrepareContextTermsBound(threadmark_core::knowledge::Project, String, String),
    /// Create/revise human context (project, ID, kind, content, update).
    WriteContext(String, String, String, String, bool),
    /// Append a retirement revision.
    RetireContext(String, String),
    /// Cached human edit bound to a registration.
    WriteContextBound(String, String, String, String, bool, String, String, String),
    /// Cached retirement bound to a registration.
    RetireContextBound(String, String, String, String, String),
    /// Opt-in cached edit with exact latest human revision, checked atomically.
    UpdateContextRevisionBound(String, String, String, String, String, String, String, u32),
    /// Opt-in cached retirement with exact latest human revision.
    RetireContextRevisionBound(String, String, String, String, String, u32),
    /// List latest human records.
    Contexts(String),
    /// Inspect bounded edit history.
    Context(String, String),
    /// Opt-in latest metadata read scoped to a captured registration.
    ContextsBound(String, String, String, String),
    /// Opt-in history read scoped to a captured registration.
    ContextBound(String, String, String, String, String),
    /// Explicit bounded textual review: project, note, from/to, root, identity, nonce.
    CompareContextBound(String, String, u32, u32, String, String, String),
    /// Explicit compatibility-changing schema upgrade of existing storage only.
    UpgradeStore,
    /// Operator attests that all legacy workers have stopped before this migration.
    UpgradeStoreV3,
    /// Operator-attested source suppression migration.
    UpgradeStoreV4,
    /// Confirmed source authorization revocation.
    ForgetSource(String, String),
    /// Exact root, identity, incarnation and complete displayed source policy.
    ForgetSourceBound(String, String, String, String, String, Vec<String>),
    /// Inspect source suppression paths only.
    ForgottenSources(String),
    /// Registration-bound source suppression metadata, existing v4 only.
    ForgottenSourcesBound(String, String, String, String),
    /// Confirmed removal of all human revisions and same-scope suppression.
    ForgetContext(String, String),
    /// Exact root, identity, incarnation and latest-revision approval.
    ForgetContextBound(String, String, String, String, String, u32),
    /// Inspect non-content suppression markers.
    ForgottenContexts(String),
    /// Registration-bound human suppression metadata, existing v3/v4 only.
    ForgottenContextsBound(String, String, String, String),
}

/// Run one local-owner operation. Source reads, SQLite, and semantics stay in core.
/// Cancellation is supplied by the caller; no hidden background or late worker exists.
pub fn run(data_dir: &Path, command: Command, cancel: &AtomicBool) -> Result<Value, Error> {
    if cancel.load(std::sync::atomic::Ordering::SeqCst) {
        return Err(Error::Canceled);
    }
    if let Command::RemoveProjectBound(id, root, identity) = &command {
        threadmark_core::knowledge::validate_removal_binding(id, root, identity)?;
    }
    if let Command::ExportProjectBound(expected) = &command {
        threadmark_core::knowledge::validate_export_binding(expected)?;
    }
    match &command {
        Command::SearchContextKindsBound(project, query, kinds, root, identity, token) => {
            threadmark_core::knowledge::validate_human_search(project, query)?;
            threadmark_core::knowledge::HumanSearchKinds::new(kinds)?;
            threadmark_core::knowledge::ContextReadBinding {
                root,
                root_identity: identity,
                incarnation: token,
            }
            .validate(project)?;
        }
        Command::CompareContextBound(project, id, from, to, root, identity, token) => {
            threadmark_core::knowledge::validate_context_comparison(
                project,
                id,
                *from,
                *to,
                &threadmark_core::knowledge::ContextReadBinding {
                    root,
                    root_identity: identity,
                    incarnation: token,
                },
            )?;
        }
        Command::ContextsBound(project, root, identity, token)
        | Command::ForgottenContextsBound(project, root, identity, token)
        | Command::ForgottenSourcesBound(project, root, identity, token)
        | Command::ContextBound(project, _, root, identity, token)
        | Command::SearchContextBound(project, _, root, identity, token) => {
            threadmark_core::knowledge::ContextReadBinding {
                root,
                root_identity: identity,
                incarnation: token,
            }
            .validate(project)?;
            match &command {
                Command::ContextBound(_, id, ..) => {
                    threadmark_core::knowledge::validate_export_project(id)?;
                }
                Command::SearchContextBound(_, query, ..) => {
                    threadmark_core::knowledge::validate_human_search(project, query)?;
                }
                _ => {}
            }
        }
        Command::UpdateContextRevisionBound(
            project,
            id,
            kind,
            text,
            root,
            identity,
            token,
            revision,
        ) => {
            threadmark_core::knowledge::validate_context_kind(kind)?;
            threadmark_core::knowledge::validate_context_text(text)?;
            threadmark_core::knowledge::ContextRevisionBinding {
                root,
                root_identity: identity,
                incarnation: token,
                revision: *revision,
            }
            .validate(project, id)?;
        }
        Command::RetireContextRevisionBound(project, id, root, identity, token, revision) => {
            threadmark_core::knowledge::ContextRevisionBinding {
                root,
                root_identity: identity,
                incarnation: token,
                revision: *revision,
            }
            .validate(project, id)?;
        }
        Command::QueryTermsBound(expected, query)
        | Command::PrepareContextTermsBound(expected, query, _) => {
            threadmark_core::knowledge::validate_query_binding(expected, query)?;
            threadmark_core::knowledge::validate_query_terms(&expected.id, query)?;
        }
        Command::InspectSourceAnchor(expected, anchor) => {
            threadmark_core::knowledge::validate_source_inspection(expected, anchor)?;
        }
        Command::CoverageReport(expected) => {
            threadmark_core::knowledge::validate_coverage_binding(expected)?;
        }
        Command::IndexIncremental(expected) => {
            threadmark_core::knowledge::validate_incremental_binding(expected)?;
        }
        Command::QueryBound(expected, query) | Command::PrepareContextBound(expected, query, _) => {
            threadmark_core::knowledge::validate_query_binding(expected, query)?;
        }
        Command::SearchContext(project, query) => {
            threadmark_core::knowledge::validate_human_search(project, query)?;
        }
        Command::QueryTerms(id, query) => {
            threadmark_core::knowledge::validate_query_terms(id, query)?;
        }
        Command::PrepareContextTerms(id, query, _) => {
            threadmark_core::knowledge::validate_query_terms(id, query)?;
        }
        Command::SourcesBound(id, root, identity, token, old, new) => {
            threadmark_core::knowledge::validate_sources_binding(
                id, root, identity, token, old, new,
            )?;
        }
        Command::WriteContextBound(id, _, _, _, _, root, identity, token)
        | Command::RetireContextBound(id, _, root, identity, token) => {
            threadmark_core::knowledge::validate_removal_binding(id, root, identity)?;
            threadmark_core::knowledge::validate_incarnation(token)?;
        }
        _ => {}
    }
    if let Command::PrepareContextBound(_, _, original)
    | Command::PrepareContextTermsBound(_, _, original) = &command
        && (original.is_empty() || original.len() > 4096 || original.contains('\0'))
    {
        return Err(Error::InvalidExtraction);
    }
    if let Command::IndexBound(id, root, identity, sources) = &command {
        threadmark_core::knowledge::validate_index_binding(id, root, identity, sources)?;
    }
    if let Command::RemoveProjectIncarnationBound(id, root, identity, token) = &command {
        threadmark_core::knowledge::validate_removal_binding(id, root, identity)?;
        threadmark_core::knowledge::validate_incarnation(token)?;
    }
    if let Command::IndexIncarnationBound(id, root, identity, sources, token) = &command {
        threadmark_core::knowledge::validate_index_binding(id, root, identity, sources)?;
        threadmark_core::knowledge::validate_incarnation(token)?;
    }
    if let Command::ForgetContextBound(project, id, root, identity, token, revision) = &command {
        threadmark_core::knowledge::ForgetBinding {
            root,
            root_identity: identity,
            incarnation: token,
            revision: *revision,
        }
        .validate(project, id)?;
    }
    if let Command::ForgetSource(project, path) = &command {
        threadmark_core::knowledge::validate_source_forget(project, path)?;
    }
    if let Command::ForgottenSources(project) = &command {
        threadmark_core::knowledge::validate_export_project(project)?;
    }
    if let Command::ForgetSourceBound(project, path, root, root_identity, incarnation, sources) =
        &command
    {
        threadmark_core::knowledge::SourceForgetBinding {
            root,
            root_identity,
            incarnation,
            sources,
        }
        .validate(project, path)?;
    }
    let mut store = if matches!(
        &command,
        Command::InspectSourceAnchor(..) | Command::CoverageReport(..)
    ) {
        Store::open_existing_for_inspection(data_dir)?
    } else if let Command::ExportProject(id) = &command {
        threadmark_core::knowledge::validate_export_project(id)?;
        Store::open_existing(data_dir)?
    } else if matches!(
        &command,
        Command::IndexBound(..)
            | Command::IndexIncremental(..)
            | Command::ExportProjectBound(..)
            | Command::ContextsBound(..)
            | Command::ForgottenContextsBound(..)
            | Command::ForgottenSourcesBound(..)
            | Command::ContextBound(..)
            | Command::CompareContextBound(..)
            | Command::SearchContextBound(..)
            | Command::SearchContextKindsBound(..)
            | Command::UpdateContextRevisionBound(..)
            | Command::RetireContextRevisionBound(..)
            | Command::QueryBound(..)
            | Command::QueryTermsBound(..)
            | Command::PrepareContextTermsBound(..)
            | Command::PrepareContextBound(..)
            | Command::QueryTerms(..)
            | Command::PrepareContextTerms(..)
            | Command::SourcesBound(..)
            | Command::WriteContextBound(..)
            | Command::RetireContextBound(..)
            | Command::IndexIncarnationBound(..)
            | Command::RemoveProjectIncarnationBound(..)
            | Command::UpgradeStore
            | Command::UpgradeStoreV3
            | Command::UpgradeStoreV4
            | Command::ForgetSource(..)
            | Command::ForgetSourceBound(..)
            | Command::ForgottenSources(..)
            | Command::ForgetContext(..)
            | Command::ForgetContextBound(..)
            | Command::ForgottenContexts(..)
            | Command::SearchContext(..)
    ) {
        // Reconciliation and explicit lifecycle operations require existing
        // storage; none may recreate a missing store as a side effect.
        Store::open_existing(data_dir)?
    } else {
        Store::open(data_dir)?
    };
    let result = match command {
        Command::CompareContextBound(project, id, from, to, root, identity, token) => store
            .context_comparison_bound(
                &project,
                &id,
                from,
                to,
                &threadmark_core::knowledge::ContextReadBinding {
                    root: &root,
                    root_identity: &identity,
                    incarnation: &token,
                },
                cancel,
            )?,
        Command::ForgottenContextsBound(project, root, identity, token) => store
            .forgotten_contexts_bound(
                &project,
                &threadmark_core::knowledge::ContextReadBinding {
                    root: &root,
                    root_identity: &identity,
                    incarnation: &token,
                },
                cancel,
            )?,
        Command::ForgottenSourcesBound(project, root, identity, token) => store
            .forgotten_sources_bound(
                &project,
                &threadmark_core::knowledge::ContextReadBinding {
                    root: &root,
                    root_identity: &identity,
                    incarnation: &token,
                },
                cancel,
            )?,
        Command::ContextsBound(project, root, identity, token) => store.contexts_bound(
            &project,
            &threadmark_core::knowledge::ContextReadBinding {
                root: &root,
                root_identity: &identity,
                incarnation: &token,
            },
            cancel,
        )?,
        Command::ContextBound(project, id, root, identity, token) => store.context_bound(
            &project,
            &id,
            &threadmark_core::knowledge::ContextReadBinding {
                root: &root,
                root_identity: &identity,
                incarnation: &token,
            },
            cancel,
        )?,
        Command::SearchContextKindsBound(project, query, kinds, root, identity, token) => store
            .search_context_kinds_bound(
                &project,
                &query,
                &threadmark_core::knowledge::HumanSearchKinds::new(&kinds)?,
                &threadmark_core::knowledge::ContextReadBinding {
                    root: &root,
                    root_identity: &identity,
                    incarnation: &token,
                },
                cancel,
            )?,
        Command::SearchContextBound(project, query, root, identity, token) => store
            .search_context_bound(
                &project,
                &query,
                &threadmark_core::knowledge::ContextReadBinding {
                    root: &root,
                    root_identity: &identity,
                    incarnation: &token,
                },
                cancel,
            )?,
        Command::UpdateContextRevisionBound(
            project,
            id,
            kind,
            text,
            root,
            identity,
            token,
            revision,
        ) => {
            store.update_context_revision_bound(
                &project,
                &id,
                &kind,
                &text,
                &threadmark_core::knowledge::ContextRevisionBinding {
                    root: &root,
                    root_identity: &identity,
                    incarnation: &token,
                    revision,
                },
                cancel,
            )?;
            // Core's final cancellation check precedes commit. A late cancel
            // must not turn a committed append into an apparent failed write.
            return Ok(json!({"project":project,"id":id,"saved":true,"producer":"human-authored"}));
        }
        Command::RetireContextRevisionBound(project, id, root, identity, token, revision) => {
            store.retire_context_revision_bound(
                &project,
                &id,
                &threadmark_core::knowledge::ContextRevisionBinding {
                    root: &root,
                    root_identity: &identity,
                    incarnation: &token,
                    revision,
                },
                cancel,
            )?;
            return Ok(json!({"project":project,"id":id,"retired":true}));
        }
        // Core's final cancellation boundary precedes commit. Do not turn an
        // authoritative committed Forget/upgrade into a misleading cancel error.
        Command::UpgradeStore => return store.upgrade(cancel),
        Command::UpgradeStoreV3 => return store.upgrade_to_v3(cancel),
        Command::UpgradeStoreV4 => return store.upgrade_to_with_progress(4, cancel, |_| {}),
        Command::ForgetSource(project, path) => {
            return store.forget_source(&project, &path, cancel);
        }
        Command::ForgetSourceBound(project, path, root, root_identity, incarnation, sources) => {
            return store.forget_source_with_progress(
                &project,
                &path,
                Some(&threadmark_core::knowledge::SourceForgetBinding {
                    root: &root,
                    root_identity: &root_identity,
                    incarnation: &incarnation,
                    sources: &sources,
                }),
                cancel,
                |_| {},
            );
        }
        Command::ForgottenSources(project) => store.forgotten_sources(&project)?,
        Command::ForgetContext(project, id) => return store.forget_context(&project, &id, cancel),
        Command::ForgetContextBound(project, id, root, identity, token, revision) => {
            return store.forget_context_bound(
                &project,
                &id,
                &threadmark_core::knowledge::ForgetBinding {
                    root: &root,
                    root_identity: &identity,
                    incarnation: &token,
                    revision,
                },
                cancel,
                |_| {},
            );
        }
        Command::ForgottenContexts(project) => store.forgotten_contexts(&project)?,
        Command::AddProject(id, root, sources) => {
            store.add_project(&id, &root, sources)?;
            json!({"project":id,"registered":true})
        }
        Command::RemoveProject(id) => store.remove_project(&id, cancel)?,
        Command::RemoveProjectIncarnationBound(id, root, identity, token) => {
            store.remove_project_incarnation_bound(&id, &root, &identity, &token, cancel)?
        }
        Command::RemoveProjectBound(id, root, identity) => {
            store.remove_project_bound(&id, &root, &identity, cancel)?
        }
        Command::Projects => {
            serde_json::to_value(store.projects()?).map_err(|_| Error::Unavailable)?
        }
        Command::Project(id) => {
            serde_json::to_value(store.project(&id)?).map_err(|_| Error::Unavailable)?
        }
        Command::ExportProject(id) => store.export_project(&id, cancel)?,
        Command::ExportProjectBound(expected) => store.export_project_bound(&expected, cancel)?,
        Command::Sources(id, paths) => {
            store.set_sources(&id, paths)?;
            json!({"project":id,"source_evidence_invalidated":true})
        }
        Command::SourcesBound(id, root, identity, token, old, paths) => {
            store.set_sources_bound(
                &id,
                &threadmark_core::knowledge::SourceForgetBinding {
                    root: &root,
                    root_identity: &identity,
                    incarnation: &token,
                    sources: &old,
                },
                paths,
            )?;
            json!({"project":id,"source_evidence_invalidated":true})
        }
        Command::Index(id) => store.index(&id, &mut LexicalLines, cancel)?,
        Command::IndexIncremental(expected) => {
            // Successful commit is authoritative; no post-commit cancel error.
            return store.index_incremental(&expected, cancel);
        }
        Command::IndexIncarnationBound(id, root, identity, sources, token) => {
            store.index_incarnation_bound(&id, &root, &identity, &sources, &token, cancel)?
        }
        Command::IndexBound(id, root, identity, sources) => {
            store.index_bound(&id, &root, &identity, &sources, cancel)?
        }
        Command::Query(id, text) => store.query(&id, &text, cancel)?,
        Command::QueryBound(expected, text) => store.query_bound(&expected, &text, cancel)?,
        Command::CoverageReport(expected) => store.coverage_report(&expected, cancel)?,
        Command::InspectSourceAnchor(expected, anchor) => {
            store.inspect_source_anchor(&expected, &anchor, cancel)?
        }
        Command::PrepareContextBound(expected, query, original) => {
            crate::preparation::context_bound(&store, &expected, &query, original, cancel)?
        }
        Command::SearchContext(project, query) => store.search_context(&project, &query, cancel)?,
        Command::QueryTerms(id, text) => store.query_terms(&id, &text, cancel)?,
        Command::QueryTermsBound(expected, text) => {
            store.query_terms_bound(&expected, &text, cancel)?
        }
        Command::PrepareContextTermsBound(expected, query, original) => {
            crate::preparation::context_bound_with_retrieval(
                &store,
                &expected,
                &query,
                original,
                cancel,
                crate::preparation::RetrievalMode::RankedTerms,
            )?
        }
        Command::PrepareContextTerms(id, query, original) => {
            crate::preparation::context_with_retrieval(
                &store,
                &id,
                &query,
                original,
                cancel,
                crate::preparation::RetrievalMode::RankedTerms,
            )?
        }
        Command::PrepareContext(id, query, original) => {
            crate::preparation::context(&store, &id, &query, original, cancel)?
        }
        Command::WriteContext(project, id, kind, text, update) => {
            store.write_context(&project, &id, &kind, &text, update)?;
            json!({"project":project,"id":id,"saved":true,"producer":"human-authored"})
        }
        Command::RetireContext(project, id) => {
            store.retire_context(&project, &id)?;
            json!({"project":project,"id":id,"retired":true})
        }
        Command::WriteContextBound(project, id, kind, text, update, root, identity, token) => {
            store.write_context_bound(
                &project,
                (&root, &identity, &token),
                &id,
                &kind,
                &text,
                update,
            )?;
            json!({"project":project,"id":id,"saved":true,"producer":"human-authored"})
        }
        Command::RetireContextBound(project, id, root, identity, token) => {
            store.retire_context_bound(&project, (&root, &identity, &token), &id)?;
            json!({"project":project,"id":id,"retired":true})
        }
        Command::Contexts(project) => store.contexts(&project)?,
        Command::Context(project, id) => store.context(&project, &id)?,
    };
    if cancel.load(std::sync::atomic::Ordering::SeqCst) {
        return Err(Error::Canceled);
    }
    Ok(result)
}
