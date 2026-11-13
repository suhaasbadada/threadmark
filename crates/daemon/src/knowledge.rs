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
    /// Inspect registered projects.
    Projects,
    /// Inspect one project's source policy.
    Project(String),
    /// Revoke/replace source policy and invalidate active evidence immediately.
    Sources(String, Vec<String>),
    /// Explicit bounded index job.
    Index(String),
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
}

/// Run one local-owner operation. Source reads, SQLite, and semantics stay in core.
/// Cancellation is supplied by the caller; no hidden background or late worker exists.
pub fn run(data_dir: &Path, command: Command, cancel: &AtomicBool) -> Result<Value, Error> {
    if cancel.load(std::sync::atomic::Ordering::SeqCst) {
        return Err(Error::Canceled);
    }
    let mut store = Store::open(data_dir)?;
    let result = match command {
        Command::AddProject(id, root, sources) => {
            store.add_project(&id, &root, sources)?;
            json!({"project":id,"registered":true})
        }
        Command::Projects => {
            serde_json::to_value(store.projects()?).map_err(|_| Error::Unavailable)?
        }
        Command::Project(id) => {
            serde_json::to_value(store.project(&id)?).map_err(|_| Error::Unavailable)?
        }
        Command::Sources(id, paths) => {
            store.set_sources(&id, paths)?;
            json!({"project":id,"source_evidence_invalidated":true})
        }
        Command::Index(id) => store.index(&id, &mut LexicalLines, cancel)?,
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
