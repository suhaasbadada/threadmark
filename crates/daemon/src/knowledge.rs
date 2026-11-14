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
    /// Explicit caller-approved sensitive local-content export, never delivery.
    ExportProject(String),
    /// Revoke/replace source policy and invalidate active evidence immediately.
    Sources(String, Vec<String>),
    /// Explicit bounded index job.
    Index(String),
    /// Timed reconciliation bound to exact previously approved scope.
    IndexBound(String, String, String, Vec<String>),
    /// Native automatic reconciliation bound to a registration nonce.
    IndexIncarnationBound(String, String, String, Vec<String>, String),
    /// Bounded source-backed lexical inspection.
    Query(String, String),
    /// Prepare a memory-only context preview (project, query, unchanged original).
    PrepareContext(String, String, String),
    /// Create/revise human context (project, ID, kind, content, update).
    WriteContext(String, String, String, String, bool),
    /// Append a retirement revision.
    RetireContext(String, String),
    /// List latest human records.
    Contexts(String),
    /// Inspect bounded edit history.
    Context(String, String),
    /// Explicit compatibility-changing schema upgrade of existing storage only.
    UpgradeStore,
    /// Operator attests that all legacy workers have stopped before this migration.
    UpgradeStoreV3,
    /// Confirmed removal of all human revisions and same-scope suppression.
    ForgetContext(String, String),
    /// Inspect non-content suppression markers.
    ForgottenContexts(String),
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
    let mut store = if let Command::ExportProject(id) = &command {
        threadmark_core::knowledge::validate_export_project(id)?;
        Store::open_existing(data_dir)?
    } else if matches!(
        &command,
        Command::IndexBound(..)
            | Command::IndexIncarnationBound(..)
            | Command::RemoveProjectIncarnationBound(..)
            | Command::UpgradeStore
            | Command::UpgradeStoreV3
            | Command::ForgetContext(..)
            | Command::ForgottenContexts(..)
    ) {
        // Reconciliation and explicit lifecycle operations require existing
        // storage; none may recreate a missing store as a side effect.
        Store::open_existing(data_dir)?
    } else {
        Store::open(data_dir)?
    };
    let result = match command {
        // Core's final cancellation boundary precedes commit. Do not turn an
        // authoritative committed Forget/upgrade into a misleading cancel error.
        Command::UpgradeStore => return store.upgrade(cancel),
        Command::UpgradeStoreV3 => return store.upgrade_to_v3(cancel),
        Command::ForgetContext(project, id) => return store.forget_context(&project, &id, cancel),
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
        Command::Sources(id, paths) => {
            store.set_sources(&id, paths)?;
            json!({"project":id,"source_evidence_invalidated":true})
        }
        Command::Index(id) => store.index(&id, &mut LexicalLines, cancel)?,
        Command::IndexIncarnationBound(id, root, identity, sources, token) => {
            store.index_incarnation_bound(&id, &root, &identity, &sources, &token, cancel)?
        }
        Command::IndexBound(id, root, identity, sources) => {
            store.index_bound(&id, &root, &identity, &sources, cancel)?
        }
        Command::Query(id, text) => store.query(&id, &text, cancel)?,
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
        Command::Contexts(project) => store.contexts(&project)?,
        Command::Context(project, id) => store.context(&project, &id)?,
    };
    if cancel.load(std::sync::atomic::Ordering::SeqCst) {
        return Err(Error::Canceled);
    }
    Ok(result)
}
