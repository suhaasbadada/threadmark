//! Manual, synchronous lexical knowledge. Local IDs select policy; they are not credentials.
//! No discovery, Git subprocesses, inference, network, watcher, or listener.

use crate::{Error, Scope};
use rusqlite::{Connection, params};
use rustix::fs::{Mode, OFlags, mkdirat, open, openat};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::fs::File;
use std::io::Read;
use std::os::unix::fs::MetadataExt;
use std::path::{Component, Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};

const MAX_FILE: usize = 65_536;
const MAX_TOTAL: usize = 1_048_576;
const APP_ID: i64 = 0x544d4b31;
const FLAGS: OFlags = OFlags::RDONLY
    .union(OFlags::NOFOLLOW)
    .union(OFlags::CLOEXEC);

mod context_comparison;
mod context_revision;
mod coverage;
mod export;
mod forget;
mod human_read;
mod human_search;
mod ranked_query;
mod schema;
mod source_forget;
mod source_inspection;
pub use context_comparison::validate_context_comparison;
pub use context_revision::{ContextRevisionBinding, validate_context_kind, validate_context_text};
pub use coverage::validate_coverage_binding;
pub use forget::{ForgetBinding, ForgetStage};
pub use human_read::ContextReadBinding;
pub use human_search::{HumanSearchKinds, validate_human_search};
pub use ranked_query::validate_query_terms;
pub use schema::UpgradeStage;
pub use source_forget::{SourceForgetBinding, SourceForgetStage, validate_source_forget};
pub use source_inspection::{SourceAnchorInspection, validate_source_inspection};
#[cfg(test)]
mod tests;

type Result<T> = std::result::Result<T, Error>;
fn unavailable<T>(_: T) -> Error {
    Error::Unavailable
}
fn invalid() -> Error {
    Error::InvalidExtraction
}

fn sha256(bytes: &[u8]) -> String {
    const HEX: &[u8] = b"0123456789abcdef";
    let mut out = String::with_capacity(64);
    for byte in Sha256::digest(bytes) {
        out.push(HEX[(byte >> 4) as usize] as char);
        out.push(HEX[(byte & 15) as usize] as char);
    }
    out
}
/// Validate a registration token before opening storage or reading sources.
pub fn validate_incarnation(token: &str) -> Result<()> {
    if token.len() != 32
        || !token
            .bytes()
            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
    {
        return Err(invalid());
    }
    Ok(())
}

/// Validate explicit legacy root-only CLI approval binding.
pub fn validate_removal_binding(id: &str, root: &str, root_identity: &str) -> Result<()> {
    identity(id)?;
    if !root.starts_with('/')
        || root.len() > 4096
        || root.contains('\0')
        || root_identity.is_empty()
        || root_identity.len() > 128
        || root_identity.contains('\0')
    {
        return Err(invalid());
    }
    Ok(())
}

fn identity(id: &str) -> Result<()> {
    Scope::new(id, "local", "snapshot").map(|_| ())
}
/// Validate a complete source replacement (empty policies explicitly revoke access).
pub fn validate_sources_binding(
    id: &str,
    root: &str,
    identity: &str,
    token: &str,
    old: &[String],
    new: &[String],
) -> Result<()> {
    validate_removal_binding(id, root, identity)?;
    validate_incarnation(token)?;
    validate_paths(old)?;
    validate_paths(new)?;
    if old.iter().chain(new).any(|p| p.starts_with("--")) {
        return Err(invalid());
    }
    Ok(())
}
/// Validate automatic index scope before opening storage. This is stale-approval
/// protection, not authentication or a grant of additional source access.
pub fn validate_index_binding(
    id: &str,
    root: &str,
    identity: &str,
    sources: &[String],
) -> Result<()> {
    validate_removal_binding(id, root, identity)?;
    validate_paths(sources)?;
    if sources.is_empty() {
        return Err(invalid());
    }
    Ok(())
}
/// Validate an export selector before opening storage. IDs are not credentials.
pub fn validate_export_project(id: &str) -> Result<()> {
    identity(id)
}
fn context_kind(kind: &str) -> bool {
    matches!(
        kind,
        "note" | "decision" | "constraint" | "correction" | "pitfall"
    )
}
fn canceled(token: &AtomicBool) -> Result<()> {
    if token.load(Ordering::SeqCst) {
        Err(Error::Canceled)
    } else {
        Ok(())
    }
}

// Open each directory relative to the previous descriptor: no symlink race between
// validation and opening, including intermediate directories and the approved root.
fn directory(path: &Path) -> Result<File> {
    // All source filesystem access starts here, including export's independent
    // root recheck. Store-directory access uses the separate private-store path.
    #[cfg(test)]
    source_forget::observe_source_access();
    walk_directory(path, false)
}

// SQLite reopens paths for its journal. Every ancestor must therefore prevent
// replacement by another OS user, not merely be symlink-free at the first open.
// Root/effective-user owned sticky directories (e.g. /tmp) protect children
// owned by those users; the next descriptor's owner is checked independently.
fn store_directory(path: &Path) -> Result<File> {
    walk_directory(path, true)
}

fn private_acl(path: &Path) -> Result<()> {
    #[cfg(target_os = "macos")]
    {
        // The caller validates ancestors from / downward before this lookup.
        // Thus another OS user cannot replace the parent path while ACLs of
        // the next root/effective-user-owned object are inspected. /dev/fd is
        // deliberately not used: macOS reports that filesystem's ACL instead.
        let entries = exacl::getfacl(path, None).map_err(unavailable)?;
        if entries
            .iter()
            .any(|entry| entry.allow && !entry.perms.is_empty())
        {
            return Err(Error::ScopeMismatch);
        }
    }
    #[cfg(not(target_os = "macos"))]
    let _ = path; // POSIX named ACL permissions are bounded by the checked mode mask.
    Ok(())
}

fn walk_directory(path: &Path, trusted_store: bool) -> Result<File> {
    if !path.is_absolute() {
        return Err(Error::ScopeMismatch);
    }
    let mut fd = open("/", FLAGS | OFlags::DIRECTORY, Mode::empty()).map_err(unavailable)?;
    let mut prefix = PathBuf::from("/");
    for component in path.components() {
        match component {
            Component::RootDir => (),
            Component::Normal(name) => {
                fd = openat(&fd, name, FLAGS | OFlags::DIRECTORY, Mode::empty())
                    .map_err(unavailable)?;
                prefix.push(name);
            }
            _ => return Err(Error::ScopeMismatch),
        }
        if trusted_store {
            let metadata = File::from(fd.try_clone().map_err(unavailable)?)
                .metadata()
                .map_err(unavailable)?;
            if (metadata.uid() != 0 && metadata.uid() != rustix::process::geteuid().as_raw())
                || (metadata.mode() & 0o022 != 0 && metadata.mode() & 0o1000 == 0)
            {
                return Err(Error::ScopeMismatch);
            }
            private_acl(&prefix)?;
        }
    }
    Ok(File::from(fd))
}

fn file_identity(file: &File) -> Result<String> {
    let m = file.metadata().map_err(unavailable)?;
    Ok(format!("{}:{}", m.dev(), m.ino()))
}

// One descriptor walker for all source consumers. Only coverage may downgrade
// File errors; cancellation and resource accounting are never local refusals.
enum SourceReadError {
    File(Error),
    Observed(Error, Source, usize),
    Whole(Error),
}

// Logical-line count does not require valid UTF-8. Keep observed resource usage
// available even when text admission or a later read fails. Like str::lines(),
// a terminal LF does not create an extra empty line; CRLF has the same count.
fn observed_source_lines(bytes: &[u8]) -> usize {
    bytes.iter().filter(|&&byte| byte == b'\n').count()
        + usize::from(!bytes.is_empty() && bytes.last() != Some(&b'\n'))
}

fn read_source(
    root: &File,
    path: &str,
    cancel: &AtomicBool,
    total: &mut usize,
) -> std::result::Result<(Source, String), SourceReadError> {
    use SourceReadError::{File as Local, Observed, Whole};
    canceled(cancel).map_err(Whole)?;
    let prepare = || -> Result<File> {
        let mut parent = root.try_clone().map_err(unavailable)?;
        let components: Vec<_> = path.split('/').collect();
        for part in &components[..components.len() - 1] {
            parent = File::from(
                openat(&parent, *part, FLAGS | OFlags::DIRECTORY, Mode::empty())
                    .map_err(unavailable)?,
            );
            if rustix::fs::statat(&parent, ".git", rustix::fs::AtFlags::SYMLINK_NOFOLLOW).is_ok()
                || parent.metadata().map_err(unavailable)?.dev()
                    != root.metadata().map_err(unavailable)?.dev()
            {
                return Err(Error::ScopeMismatch);
            }
        }
        Ok(File::from(
            openat(
                &parent,
                components[components.len() - 1],
                FLAGS | OFlags::NONBLOCK,
                Mode::empty(),
            )
            .map_err(unavailable)?,
        ))
    };
    let mut file = prepare().map_err(Local)?;
    let metadata = file.metadata().map_err(|e| Local(unavailable(e)))?;
    if !metadata.is_file()
        || metadata.dev() != root.metadata().map_err(|e| Local(unavailable(e)))?.dev()
        || metadata.nlink() != 1
    {
        // Internal-only fingerprint: unsafe metadata is never admitted as current
        // report metadata, but an observed change must still fence publication.
        return Err(Observed(
            invalid(),
            Source {
                path: path.into(),
                identity: format!("{}:{}", metadata.dev(), metadata.ino()),
                hash: sha256(
                    format!(
                        "{}:{}:{}:{}:{}:{}:{}",
                        metadata.mode(),
                        metadata.nlink(),
                        metadata.len(),
                        metadata.mtime(),
                        metadata.mtime_nsec(),
                        metadata.ctime(),
                        metadata.ctime_nsec()
                    )
                    .as_bytes(),
                ),
            },
            0,
        ));
    }
    if metadata.len() > MAX_FILE as u64 {
        return Err(Whole(invalid()));
    }
    let file_id = file_identity(&file).map_err(Local)?;
    let mut bytes = Vec::new();
    // Account each successful chunk before any later I/O/UTF-8 refusal. Never
    // reset total on a failed file: otherwise 64 failed files bypass 1 MiB.
    loop {
        canceled(cancel).map_err(Whole)?;
        let mut chunk = [0_u8; 4096];
        let remaining = (MAX_FILE + 1 - bytes.len()).min(chunk.len());
        let n = file.read(&mut chunk[..remaining]).map_err(|e| {
            Observed(
                unavailable(e),
                Source {
                    path: path.into(),
                    identity: file_id.clone(),
                    hash: sha256(&bytes),
                },
                observed_source_lines(&bytes),
            )
        })?;
        *total += n;
        if bytes.len() + n > MAX_FILE || *total > MAX_TOTAL {
            return Err(Whole(invalid()));
        }
        bytes.extend_from_slice(&chunk[..n]);
        #[cfg(test)]
        coverage::observe_chunk(cancel);
        canceled(cancel).map_err(Whole)?;
        if n == 0 {
            break;
        }
    }
    let hash = sha256(&bytes);
    let source = Source {
        path: path.into(),
        hash,
        identity: file_id,
    };
    if bytes.contains(&0) {
        return Err(Observed(invalid(), source, observed_source_lines(&bytes)));
    }
    let text = String::from_utf8(bytes).map_err(|e| {
        let lines = observed_source_lines(e.as_bytes());
        Observed(unavailable(e), source.clone(), lines)
    })?;
    Ok((source, text))
}

fn validate_paths(paths: &[String]) -> Result<()> {
    if paths.len() > 64 {
        return Err(invalid());
    }
    let mut seen = std::collections::BTreeSet::new();
    for path in paths {
        if path.is_empty() || path.len() > 240 || !seen.insert(path) {
            return Err(invalid());
        }
        for part in path.split('/') {
            let lower = part.to_ascii_lowercase();
            if part.is_empty()
                || part.starts_with('.')
                || !part
                    .bytes()
                    .all(|b| b.is_ascii_alphanumeric() || b"-_.".contains(&b))
                || ["credential", "secret", "password", "token"]
                    .iter()
                    .any(|s| lower.contains(s))
            {
                return Err(Error::ScopeMismatch);
            }
        }
        if !matches!(
            Path::new(path).extension().and_then(|s| s.to_str()),
            Some("rs" | "py" | "md" | "txt")
        ) {
            return Err(invalid());
        }
    }
    Ok(())
}

/// An extractor receives only bytes already admitted by the source policy.
/// Returned line numbers must resolve to exact, complete input lines.
pub trait SourceExtractor {
    /// Stable bounded producer label, persisted with source anchors.
    fn producer(&self) -> &str;
    /// Select source lines. No semantic/AST completeness is implied.
    fn extract(&mut self, text: &str, cancel: &AtomicBool) -> Result<Vec<usize>>;
}

/// Default line index: all nonempty UTF-8 lines, not structural understanding.
pub struct LexicalLines;

/// Finite manual indexing stages; observers may request cooperative cancellation.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum IndexStage {
    /// Approved inputs have been read under the source budget.
    Read,
    /// Bounded, source-resolvable anchors have been validated.
    Extracted,
    /// Replacement is staged but not committed; cancellation rolls it back.
    ReadyToCommit,
}

/// Finite local-removal stages; cancellation before commit restores every row.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RemovalStage {
    /// All project source evidence has been staged for deletion.
    EvidenceRemoved,
    /// Every human context revision has been staged for deletion.
    ContextRemoved,
    /// Project policy deletion is staged, but nothing has committed.
    ReadyToCommit,
}

/// Synchronous export boundaries; observers cannot grant source authority.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExportStage {
    /// One database snapshot and the initial authorized source state were read.
    Read,
    /// All rows are validated and bounded; final authorization checks follow.
    ReadyToPublish,
}
impl SourceExtractor for LexicalLines {
    fn producer(&self) -> &str {
        "lexical-lines-v1"
    }
    fn extract(&mut self, text: &str, cancel: &AtomicBool) -> Result<Vec<usize>> {
        let mut lines = Vec::new();
        for (i, line) in text.lines().enumerate() {
            canceled(cancel)?;
            if i >= 4096 || line.len() > 1024 {
                return Err(invalid());
            }
            if !line.trim().is_empty() {
                lines.push(i + 1);
            }
        }
        Ok(lines)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
struct Source {
    path: String,
    hash: String,
    identity: String,
}

/// Persisted project policy. Roots and identities are registration facts, not request labels.
#[derive(Debug, Serialize)]
pub struct Project {
    /// Stable caller-chosen local identity.
    pub id: String,
    /// Explicit approved canonical root.
    pub root: String,
    /// Filesystem device/inode, distinct across registered worktrees.
    pub root_identity: String,
    /// Registration nonce on schema v3; legacy stores have no cached approval authority.
    pub incarnation: Option<String>,
    /// Exact relative file allowlist, never recursive discovery.
    pub sources: Vec<String>,
    /// Content snapshot identity (not a Git revision); absent after scope revocation.
    pub snapshot: Option<String>,
}

pub use export::validate_export_binding;

/// Validate cached source-read metadata without opening storage or source paths.
/// This is stale-approval protection, not source authorization.
pub fn validate_query_binding(expected: &Project, text: &str) -> Result<()> {
    validate_removal_binding(&expected.id, &expected.root, &expected.root_identity)?;
    validate_incarnation(
        expected
            .incarnation
            .as_deref()
            .ok_or(Error::ScopeMismatch)?,
    )?;
    validate_paths(&expected.sources)?;
    if text.is_empty()
        || text.len() > 256
        || text.contains('\0')
        || expected.snapshot.as_ref().is_some_and(|s| {
            s.len() != 64
                || !s
                    .bytes()
                    .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
        })
    {
        return Err(invalid());
    }
    Ok(())
}

/// Private SQLite store, with no ambient location or credential discovery.
pub struct Store {
    db: Connection,
    root: PathBuf,
    root_identity: String,
    db_identity: String,
}

impl Store {
    /// Open an explicit store directory. New directories are 0700 and database 0600.
    /// Existing stores must already be private, owned, regular, and schema-compatible.
    pub fn open(path: &Path) -> Result<Self> {
        Self::open_with_creation(path, true, false)
    }

    /// Open only a recognized existing private store, never create a directory or DB.
    pub fn open_existing(path: &Path) -> Result<Self> {
        Self::open_with_creation(path, false, false)
    }

    /// Open an existing store read-only for source inspection. Reject WAL before
    /// SQLite opens the database; never normalize its journal mode or create it.
    pub fn open_existing_for_inspection(path: &Path) -> Result<Self> {
        Self::open_with_creation(path, false, true)
    }

    fn open_with_creation(path: &Path, allow_creation: bool, inspection: bool) -> Result<Self> {
        if !path.is_absolute() {
            return Err(Error::ScopeMismatch);
        }
        let parent = store_directory(path.parent().ok_or(Error::ScopeMismatch)?)?;
        let name = path.file_name().ok_or(Error::ScopeMismatch)?;
        let created = if !allow_creation {
            false
        } else {
            match mkdirat(&parent, name, Mode::from_raw_mode(0o700)) {
                Ok(()) => true,
                Err(rustix::io::Errno::EXIST) => false,
                Err(e) => return Err(unavailable(e)),
            }
        };
        let dir = store_directory(path)?;
        let m = dir.metadata().map_err(unavailable)?;
        if m.mode() & 0o077 != 0 || m.uid() != rustix::process::geteuid().as_raw() {
            return Err(Error::ScopeMismatch);
        }
        let db_path = path.join("knowledge.sqlite");
        let new = match std::fs::symlink_metadata(&db_path) {
            Ok(m) => {
                if !m.is_file()
                    || m.len() > 134_217_728
                    || m.mode() & 0o077 != 0
                    || m.uid() != rustix::process::geteuid().as_raw()
                    || m.nlink() != 1
                {
                    return Err(Error::ScopeMismatch);
                }
                false
            }
            Err(e) if e.kind() == std::io::ErrorKind::NotFound && created => {
                openat(
                    &dir,
                    "knowledge.sqlite",
                    OFlags::WRONLY
                        | OFlags::CREATE
                        | OFlags::EXCL
                        | OFlags::NOFOLLOW
                        | OFlags::CLOEXEC,
                    Mode::from_raw_mode(0o600),
                )
                .map_err(unavailable)?;
                true
            }
            Err(e) => return Err(unavailable(e)),
        };
        private_acl(&db_path)?;
        // An existing directory is never adopted as a new store; unknown DBs are not initialized.
        for suffix in ["-journal", "-wal", "-shm"] {
            if let Ok(m) = std::fs::symlink_metadata(format!(
                "{}{}",
                db_path.to_str().ok_or(invalid())?,
                suffix
            )) && (!m.is_file()
                || m.mode() & 0o077 != 0
                || m.uid() != rustix::process::geteuid().as_raw()
                || m.nlink() != 1)
            {
                return Err(Error::ScopeMismatch);
            }
            let sidecar =
                PathBuf::from(format!("{}{}", db_path.to_str().ok_or(invalid())?, suffix));
            if sidecar.try_exists().map_err(unavailable)? {
                private_acl(&sidecar)?;
            }
        }
        if !new {
            // Reject foreign/forward databases before SQLite can perform writable
            // hot-journal recovery. SQL schema validation alone happens too late.
            let mut file = File::from(
                openat(
                    &dir,
                    "knowledge.sqlite",
                    FLAGS | OFlags::NONBLOCK,
                    Mode::empty(),
                )
                .map_err(unavailable)?,
            );
            let mut header = [0_u8; 100];
            file.read_exact(&mut header).map_err(unavailable)?;
            if &header[..16] != b"SQLite format 3\0"
                || (inspection && (header[18] != 1 || header[19] != 1))
                || u16::from_be_bytes([header[16], header[17]]) != 4096
                || !matches!(
                    u32::from_be_bytes(header[60..64].try_into().map_err(unavailable)?),
                    1..=4
                )
                || i64::from(u32::from_be_bytes(
                    header[68..72].try_into().map_err(unavailable)?,
                )) != APP_ID
            {
                return Err(Error::Unavailable);
            }
        }
        let access = if inspection {
            rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY
        } else {
            rusqlite::OpenFlags::SQLITE_OPEN_READ_WRITE
        };
        let mut db = Connection::open_with_flags(
            &db_path,
            access
                | rusqlite::OpenFlags::SQLITE_OPEN_NO_MUTEX
                | rusqlite::OpenFlags::SQLITE_OPEN_NOFOLLOW,
        )
        .map_err(unavailable)?;
        // Bound even malformed on-disk values before SQLite allocates returned rows.
        db.set_limit(rusqlite::limits::Limit::SQLITE_LIMIT_LENGTH, 65_536)
            .map_err(unavailable)?;
        db.set_limit(rusqlite::limits::Limit::SQLITE_LIMIT_SQL_LENGTH, 16_384)
            .map_err(unavailable)?;
        if new {
            let tx = db.transaction().map_err(unavailable)?;
            tx.execute_batch("PRAGMA application_id=1414351665; PRAGMA user_version=1;
                CREATE TABLE projects(id TEXT PRIMARY KEY, root TEXT NOT NULL UNIQUE, root_identity TEXT NOT NULL, sources TEXT NOT NULL, snapshot TEXT, manifest TEXT);
                CREATE TABLE evidence(project TEXT NOT NULL, path TEXT NOT NULL, line INTEGER NOT NULL, text TEXT NOT NULL, hash TEXT NOT NULL, producer TEXT NOT NULL, PRIMARY KEY(project,path,line));
                CREATE TABLE context(project TEXT NOT NULL, id TEXT NOT NULL, revision INTEGER NOT NULL, kind TEXT NOT NULL, text TEXT NOT NULL, retired INTEGER NOT NULL, PRIMARY KEY(project,id,revision));
                CREATE INDEX context_project ON context(project,id,revision);").map_err(unavailable)?;
            schema::install_v2(&tx)?;
            schema::install_v3(&tx)?;
            schema::install_v4(&tx)?;
            tx.commit().map_err(unavailable)?;
        }
        schema::validate(&db)?;
        if inspection {
            let mode: String = db
                .pragma_query_value(None, "journal_mode", |r| r.get(0))
                .map_err(unavailable)?;
            if !mode.eq_ignore_ascii_case("delete") {
                return Err(Error::Unavailable);
            }
            db.execute_batch("PRAGMA trusted_schema=OFF; PRAGMA foreign_keys=ON;")
                .map_err(unavailable)?;
        } else {
            db.execute_batch("PRAGMA trusted_schema=OFF; PRAGMA foreign_keys=ON; PRAGMA journal_mode=DELETE; PRAGMA synchronous=FULL; PRAGMA max_page_count=32768;").map_err(unavailable)?;
        }
        Ok(Self {
            db,
            root: path.into(),
            root_identity: file_identity(&dir)?,
            db_identity: file_identity(&File::from(
                open(&db_path, FLAGS, Mode::empty()).map_err(unavailable)?,
            ))?,
        })
    }

    fn healthy(&self) -> Result<()> {
        let dir = store_directory(&self.root)?;
        let metadata = dir.metadata().map_err(unavailable)?;
        if file_identity(&dir)? != self.root_identity
            || metadata.mode() & 0o077 != 0
            || metadata.uid() != rustix::process::geteuid().as_raw()
        {
            return Err(Error::ScopeMismatch);
        }
        let file = File::from(
            openat(
                &dir,
                "knowledge.sqlite",
                FLAGS | OFlags::NONBLOCK,
                Mode::empty(),
            )
            .map_err(unavailable)?,
        );
        let m = file.metadata().map_err(unavailable)?;
        if !m.is_file()
            || m.mode() & 0o077 != 0
            || m.uid() != rustix::process::geteuid().as_raw()
            || m.nlink() != 1
            || file_identity(&file)? != self.db_identity
        {
            return Err(Error::ScopeMismatch);
        }
        private_acl(&self.root.join("knowledge.sqlite"))?;
        for suffix in ["-journal", "-wal", "-shm"] {
            let name = format!("knowledge.sqlite{suffix}");
            match rustix::fs::statat(&dir, name.as_str(), rustix::fs::AtFlags::SYMLINK_NOFOLLOW) {
                Ok(_) => {
                    let sidecar = File::from(
                        openat(&dir, name.as_str(), FLAGS | OFlags::NONBLOCK, Mode::empty())
                            .map_err(unavailable)?,
                    );
                    let m = sidecar.metadata().map_err(unavailable)?;
                    if !m.is_file()
                        || m.mode() & 0o077 != 0
                        || m.uid() != rustix::process::geteuid().as_raw()
                        || m.nlink() != 1
                    {
                        return Err(Error::ScopeMismatch);
                    }
                    private_acl(&self.root.join(name))?;
                }
                Err(rustix::io::Errno::NOENT) => (),
                Err(e) => return Err(unavailable(e)),
            }
        }
        Ok(())
    }

    /// Register an explicit root and allowlist. IDs and roots cannot silently rebind.
    pub fn add_project(&mut self, id: &str, root: &Path, paths: Vec<String>) -> Result<()> {
        self.healthy()?;
        identity(id)?;
        validate_paths(&paths)?;
        let dir = directory(root)?;
        let canonical = root.canonicalize().map_err(unavailable)?;
        if file_identity(&directory(&canonical)?)? != file_identity(&dir)? {
            return Err(Error::ScopeMismatch);
        }
        let tx = self
            .db
            .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
            .map_err(unavailable)?;
        let count: i64 = tx
            .query_row("SELECT count(*) FROM projects", [], |r| r.get(0))
            .map_err(unavailable)?;
        if count >= 64 {
            return Err(invalid());
        }
        tx.execute(
            "INSERT INTO projects(id,root,root_identity,sources) VALUES(?1,?2,?3,?4)",
            params![
                id,
                canonical.to_str().ok_or(invalid())?,
                file_identity(&dir)?,
                serde_json::to_string(&paths).map_err(unavailable)?
            ],
        )
        .map_err(unavailable)?;
        tx.commit().map_err(unavailable)?;
        Ok(())
    }

    /// Remove only this project's local policy, evidence and all human revisions.
    /// This is not Forget/suppression or forensic erasure: SQLite free pages,
    /// sidecars, backups and exports may retain historical bytes. Sources are untouched.
    /// Re-registration explicitly authorizes rebuilding, never restores human history.
    pub fn remove_project(&mut self, id: &str, cancel: &AtomicBool) -> Result<Value> {
        self.remove_project_with_progress(id, cancel, |_| {})
    }

    /// Bind a caller's explicit approval to exactly the displayed registered root.
    /// This is a stale-approval guard, not authentication or new source authority.
    pub fn remove_project_bound(
        &mut self,
        id: &str,
        root: &str,
        root_identity: &str,
        cancel: &AtomicBool,
    ) -> Result<Value> {
        validate_removal_binding(id, root, root_identity)?;
        canceled(cancel)?;
        let project = self.project(id)?;
        if project.root != root || project.root_identity != root_identity {
            return Err(Error::ScopeMismatch);
        }
        self.remove_project_for_policy(&project, cancel, |_| {})
    }

    /// Native cached approvals must bind a validated registration incarnation.
    pub fn remove_project_incarnation_bound(
        &mut self,
        id: &str,
        root: &str,
        root_identity: &str,
        incarnation: &str,
        cancel: &AtomicBool,
    ) -> Result<Value> {
        validate_removal_binding(id, root, root_identity)?;
        validate_incarnation(incarnation)?;
        canceled(cancel)?;
        let project = self.project(id)?;
        if project.root != root
            || project.root_identity != root_identity
            || project.incarnation.as_deref() != Some(incarnation)
        {
            return Err(Error::ScopeMismatch);
        }
        self.remove_project_for_policy(&project, cancel, |_| {})
    }

    /// Observe synchronous deletion stages, including a final cancellation boundary.
    pub fn remove_project_with_progress(
        &mut self,
        id: &str,
        cancel: &AtomicBool,
        mut progress: impl FnMut(RemovalStage),
    ) -> Result<Value> {
        canceled(cancel)?;
        let project = self.project(id)?;
        self.remove_project_for_policy(&project, cancel, &mut progress)
    }

    fn remove_project_for_policy(
        &mut self,
        project: &Project,
        cancel: &AtomicBool,
        mut progress: impl FnMut(RemovalStage),
    ) -> Result<Value> {
        let id = project.id.as_str();
        let tx = self
            .db
            .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
            .map_err(unavailable)?;
        Self::require_project_root(&tx, project)?;
        canceled(cancel)?;
        tx.execute("DELETE FROM evidence WHERE project=?1", [id])
            .map_err(unavailable)?;
        progress(RemovalStage::EvidenceRemoved);
        canceled(cancel)?;
        tx.execute("DELETE FROM context WHERE project=?1", [id])
            .map_err(unavailable)?;
        progress(RemovalStage::ContextRemoved);
        canceled(cancel)?;
        if schema::version(&tx)? >= 2 {
            tx.execute("DELETE FROM forgotten_context WHERE project=?1", [id])
                .map_err(unavailable)?;
        }
        if schema::version(&tx)? == 4 {
            tx.execute("DELETE FROM forgotten_sources WHERE project=?1", [id])
                .map_err(unavailable)?;
        }
        tx.execute("DELETE FROM projects WHERE id=?1", [id])
            .map_err(unavailable)?;
        progress(RemovalStage::ReadyToCommit);
        canceled(cancel)?;
        tx.commit().map_err(unavailable)?;
        Ok(json!({"project": id, "removed": true, "retention_limits":
            "Local removal only, not Forget/suppression or forensic erasure. SQLite free pages, sidecars, backups and exports may retain historical bytes. Source files are untouched; explicit re-registration and reindexing can import source evidence again, not old human history."}))
    }

    /// Inspect policy without reading any source file.
    pub fn project(&self, id: &str) -> Result<Project> {
        self.healthy()?;
        identity(id)?;
        if schema::version(&self.db)? == 4 {
            source_forget::validate_store(&self.db)?;
        }
        let sql = if schema::version(&self.db)? >= 3 {
            "SELECT root,root_identity,sources,snapshot,incarnation FROM projects JOIN project_incarnations ON project_incarnations.project=projects.id WHERE id=?1"
        } else {
            "SELECT root,root_identity,sources,snapshot,NULL FROM projects WHERE id=?1"
        };
        let (root, root_identity, sources, snapshot, incarnation): (
            String,
            String,
            String,
            Option<String>,
            Option<String>,
        ) = self
            .db
            .query_row(sql, [id], |r| {
                Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?, r.get(4)?))
            })
            .map_err(unavailable)?;
        if sources.len() > 16384
            || root.len() > 4096
            || root_identity.len() > 128
            || snapshot
                .as_ref()
                .is_some_and(|s| s.len() != 64 || !s.bytes().all(|b| b.is_ascii_hexdigit()))
        {
            return Err(invalid());
        }
        let paths: Vec<String> = serde_json::from_str(&sources).map_err(unavailable)?;
        validate_paths(&paths)?;
        if let Some(token) = &incarnation {
            validate_incarnation(token)?;
        }
        Ok(Project {
            id: id.into(),
            root,
            root_identity,
            incarnation,
            sources: paths,
            snapshot,
        })
    }

    /// Bounded project policy listing, with no source reads.
    pub fn projects(&self) -> Result<Vec<Project>> {
        self.healthy()?;
        let mut stmt = self
            .db
            .prepare("SELECT id FROM projects ORDER BY id LIMIT 65")
            .map_err(unavailable)?;
        let ids = stmt
            .query_map([], |r| r.get::<_, String>(0))
            .map_err(unavailable)?
            .collect::<std::result::Result<Vec<_>, _>>()
            .map_err(unavailable)?;
        if ids.len() > 64 {
            return Err(invalid());
        }
        ids.iter().map(|id| self.project(id)).collect()
    }

    /// Replace consent atomically and immediately remove all active source evidence.
    /// Human context is independent and is never deleted by source policy changes.
    pub fn set_sources(&mut self, id: &str, paths: Vec<String>) -> Result<()> {
        let project = self.project(id)?;
        self.set_sources_for_policy(&project, paths)
    }

    /// Replace only the exact displayed registration and source policy.
    pub fn set_sources_bound(
        &mut self,
        id: &str,
        binding: &SourceForgetBinding<'_>,
        paths: Vec<String>,
    ) -> Result<()> {
        validate_sources_binding(
            id,
            binding.root,
            binding.root_identity,
            binding.incarnation,
            binding.sources,
            &paths,
        )?;
        let project =
            self.bound_project(id, binding.root, binding.root_identity, binding.incarnation)?;
        if project.sources != binding.sources {
            return Err(Error::ScopeMismatch);
        }
        self.set_sources_for_policy(&project, paths)
    }

    fn bound_project(
        &self,
        id: &str,
        root: &str,
        root_identity: &str,
        incarnation: &str,
    ) -> Result<Project> {
        validate_removal_binding(id, root, root_identity)?;
        validate_incarnation(incarnation)?;
        let project = self.project(id)?;
        if project.root != root
            || project.root_identity != root_identity
            || project.incarnation.as_deref() != Some(incarnation)
        {
            return Err(Error::ScopeMismatch);
        }
        Ok(project)
    }

    // A local ID can be explicitly reused after removal. Pending operations must
    // never mutate a replacement root that happened to receive the same ID.
    fn require_project_root(tx: &rusqlite::Transaction<'_>, project: &Project) -> Result<()> {
        let (root, root_identity): (String, String) = tx
            .query_row(
                "SELECT root,root_identity FROM projects WHERE id=?1",
                [&project.id],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .map_err(unavailable)?;
        if root != project.root
            || root_identity != project.root_identity
            || schema::incarnation(tx, &project.id)? != project.incarnation
        {
            return Err(Error::ScopeMismatch);
        }
        Ok(())
    }

    fn set_sources_for_policy(&mut self, project: &Project, paths: Vec<String>) -> Result<()> {
        let id = project.id.as_str();
        validate_paths(&paths)?;
        let tx = self.db.transaction().map_err(unavailable)?;
        Self::require_project_root(&tx, project)?;
        source_forget::require_allowed(&tx, id, &paths)?;
        let current: String = tx
            .query_row("SELECT sources FROM projects WHERE id=?1", [id], |r| {
                r.get(0)
            })
            .map_err(unavailable)?;
        let current: Vec<String> = serde_json::from_str(&current).map_err(unavailable)?;
        if current != project.sources {
            return Err(Error::ScopeMismatch);
        }
        tx.execute("DELETE FROM evidence WHERE project=?1", [id])
            .map_err(unavailable)?;
        tx.execute(
            "UPDATE projects SET sources=?2,snapshot=NULL,manifest=NULL WHERE id=?1",
            params![id, serde_json::to_string(&paths).map_err(unavailable)?],
        )
        .map_err(unavailable)?;
        tx.commit().map_err(unavailable)
    }

    fn read_sources(p: &Project, cancel: &AtomicBool) -> Result<Vec<(Source, String)>> {
        canceled(cancel)?;
        let root = directory(Path::new(&p.root))?;
        if file_identity(&root)? != p.root_identity {
            return Err(Error::ScopeMismatch);
        }
        let mut result = Vec::new();
        let mut total = 0;
        for path in &p.sources {
            result.push(
                read_source(&root, path, cancel, &mut total).map_err(|e| match e {
                    SourceReadError::File(e)
                    | SourceReadError::Observed(e, _, _)
                    | SourceReadError::Whole(e) => e,
                })?,
            );
        }
        // Detect a replaced/renamed approved root even though the open descriptor stayed valid.
        if file_identity(&directory(Path::new(&p.root))?)? != p.root_identity {
            return Err(Error::ScopeMismatch);
        }
        canceled(cancel)?;
        Ok(result)
    }

    /// Build a bounded snapshot, validate every anchor, reread the complete manifest,
    /// then atomically replace source evidence only. Error/cancel rolls back.
    pub fn index(
        &mut self,
        id: &str,
        extractor: &mut impl SourceExtractor,
        cancel: &AtomicBool,
    ) -> Result<Value> {
        self.index_with_progress(id, extractor, cancel, |_| {})
    }

    /// Index with finite stage notifications on this caller's thread. An observer
    /// cannot broaden access; cancellation and the manifest are rechecked afterward.
    pub fn index_with_progress(
        &mut self,
        id: &str,
        extractor: &mut impl SourceExtractor,
        cancel: &AtomicBool,
        progress: impl FnMut(IndexStage),
    ) -> Result<Value> {
        self.index_scoped(id, None, extractor, cancel, progress)
    }

    /// Reconcile only the exact previously approved project/root/file policy.
    pub fn index_bound(
        &mut self,
        id: &str,
        root: &str,
        identity: &str,
        sources: &[String],
        cancel: &AtomicBool,
    ) -> Result<Value> {
        validate_index_binding(id, root, identity, sources)?;
        self.index_scoped(
            id,
            Some((root, identity, sources)),
            &mut LexicalLines,
            cancel,
            |_| {},
        )
    }

    /// Reconcile only the exact cached native approval, before any source access.
    pub fn index_incarnation_bound(
        &mut self,
        id: &str,
        root: &str,
        root_identity: &str,
        sources: &[String],
        incarnation: &str,
        cancel: &AtomicBool,
    ) -> Result<Value> {
        validate_index_binding(id, root, root_identity, sources)?;
        validate_incarnation(incarnation)?;
        self.index_scoped_incarnation(
            id,
            Some((root, root_identity, sources)),
            Some(incarnation),
            &mut LexicalLines,
            cancel,
            |_| {},
        )
    }

    fn index_scoped(
        &mut self,
        id: &str,
        binding: Option<(&str, &str, &[String])>,
        extractor: &mut impl SourceExtractor,
        cancel: &AtomicBool,
        progress: impl FnMut(IndexStage),
    ) -> Result<Value> {
        self.index_scoped_incarnation(id, binding, None, extractor, cancel, progress)
    }

    fn index_scoped_incarnation(
        &mut self,
        id: &str,
        binding: Option<(&str, &str, &[String])>,
        expected_incarnation: Option<&str>,
        extractor: &mut impl SourceExtractor,
        cancel: &AtomicBool,
        mut progress: impl FnMut(IndexStage),
    ) -> Result<Value> {
        canceled(cancel)?;
        let p = self.project(id)?;
        if expected_incarnation.is_some_and(|token| p.incarnation.as_deref() != Some(token)) {
            return Err(Error::ScopeMismatch);
        }
        if let Some((root, identity, sources)) = binding
            && (p.root != root || p.root_identity != identity || p.sources != sources)
        {
            return Err(Error::ScopeMismatch);
        }
        let inputs = Self::read_sources(&p, cancel)?;
        progress(IndexStage::Read);
        canceled(cancel)?;
        let producer = extractor.producer().to_owned();
        identity(&producer)?;
        let mut evidence = Vec::new();
        for (source, text) in &inputs {
            canceled(cancel)?;
            let lines: Vec<_> = text.lines().collect();
            if lines.len() > 4096 {
                return Err(invalid());
            }
            let selected = extractor.extract(text, cancel)?;
            if selected.len() > 4096 {
                return Err(invalid());
            }
            let mut seen = std::collections::BTreeSet::new();
            for line in selected {
                let value = line
                    .checked_sub(1)
                    .and_then(|i| lines.get(i))
                    .ok_or(invalid())?;
                if !seen.insert(line) || value.len() > 1024 || value.trim().is_empty() {
                    return Err(invalid());
                }
                evidence.push((source, line, *value));
                if evidence.len() > 16384 {
                    return Err(invalid());
                }
            }
        }
        let manifest: Vec<_> = inputs.iter().map(|(s, _)| s.clone()).collect();
        progress(IndexStage::Extracted);
        canceled(cancel)?;
        let live = self.project(id)?;
        if live.sources != p.sources || live.incarnation != p.incarnation {
            return Err(Error::ScopeMismatch);
        }
        let after: Vec<_> = Self::read_sources(&p, cancel)?
            .into_iter()
            .map(|(s, _)| s)
            .collect();
        if manifest != after {
            return Err(Error::ScopeMismatch);
        }
        let encoded = serde_json::to_string(&manifest).map_err(unavailable)?;
        let snapshot = sha256(encoded.as_bytes());
        self.healthy()?;
        let tx = self
            .db
            .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
            .map_err(unavailable)?;
        // Serialize publication with removal and recheck the exact captured approval.
        Self::require_project_root(&tx, &p)?;
        // Recheck policy too; root identity alone cannot fence same-root reuse.
        let (root, root_identity, policy): (String, String, String) = tx
            .query_row(
                "SELECT root,root_identity,sources FROM projects WHERE id=?1",
                [id],
                |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
            )
            .map_err(unavailable)?;
        if root != p.root
            || root_identity != p.root_identity
            || serde_json::from_str::<Vec<String>>(&policy).map_err(unavailable)? != p.sources
        {
            return Err(Error::ScopeMismatch);
        }
        tx.execute("DELETE FROM evidence WHERE project=?1", [id])
            .map_err(unavailable)?;
        for (source, line, text) in &evidence {
            canceled(cancel)?;
            tx.execute(
                "INSERT INTO evidence VALUES(?1,?2,?3,?4,?5,?6)",
                params![id, source.path, *line as i64, text, source.hash, producer],
            )
            .map_err(unavailable)?;
        }
        tx.execute(
            "UPDATE projects SET snapshot=?2,manifest=?3 WHERE id=?1",
            params![id, snapshot, encoded],
        )
        .map_err(unavailable)?;
        progress(IndexStage::ReadyToCommit);
        canceled(cancel)?;
        let final_manifest: Vec<_> = Self::read_sources(&p, cancel)?
            .into_iter()
            .map(|(s, _)| s)
            .collect();
        if manifest != final_manifest {
            return Err(Error::ScopeMismatch);
        }
        canceled(cancel)?;
        tx.commit().map_err(unavailable)?;
        canceled(cancel)?;
        Ok(
            json!({"project": id, "snapshot": snapshot, "files": inputs.len(), "anchors": evidence.len(), "coverage": "lexical-lines-only; no semantic coverage", "empty": evidence.is_empty()}),
        )
    }

    /// Lexical substring retrieval with full-manifest freshness recheck; never indexes.
    /// Any stale/unreadable source suppresses the entire old snapshot conservatively.
    /// Output is JSON-escaped and capped at 8192 encoded bytes / eight anchors.
    pub fn query(&self, id: &str, text: &str, cancel: &AtomicBool) -> Result<Value> {
        self.query_scoped(id, text, cancel, None, || {})
    }

    /// Read only the exact expected registration, policy and stored snapshot.
    /// Binding checks use the same captured project passed to source traversal,
    /// not an earlier preflight whose ID could be reloaded into another scope.
    /// Expected metadata is stale-approval protection, never credentials or a
    /// grant of source access. Legacy registrations cannot authorize cached reads.
    pub fn query_bound(
        &self,
        expected: &Project,
        text: &str,
        cancel: &AtomicBool,
    ) -> Result<Value> {
        validate_query_binding(expected, text)?;
        self.query_scoped(&expected.id, text, cancel, Some(expected), || {})
    }

    fn query_scoped(
        &self,
        id: &str,
        text: &str,
        cancel: &AtomicBool,
        expected: Option<&Project>,
        before_sources: impl FnOnce(),
    ) -> Result<Value> {
        canceled(cancel)?;
        if text.is_empty() || text.len() > 256 {
            return Err(invalid());
        }
        let p = self.query_project(id, expected)?;
        before_sources();
        let current_inputs = self.current_query_inputs(&p, cancel)?;
        canceled(cancel)?;
        let mut reply = json!({"project": id, "root_identity":p.root_identity, "snapshot": p.snapshot, "currentness": if current_inputs.is_some() {"current-at-read"} else {"stale-or-unindexed"}, "coverage":"lexical-lines-only; no semantic coverage", "selection":"bounded-path-line-prefix", "truncated":false, "results": []});
        if let Some(inputs) = current_inputs {
            let mut stmt = self.db.prepare("SELECT path,line,text,hash,producer FROM evidence WHERE project=?1 AND instr(lower(text),lower(?2))>0 ORDER BY path,line LIMIT 9").map_err(unavailable)?;
            let rows = stmt
                .query_map(params![id, text], |r| {
                    Ok((
                        r.get::<_, String>(0)?,
                        r.get::<_, i64>(1)?,
                        r.get::<_, String>(2)?,
                        r.get::<_, String>(3)?,
                        r.get::<_, String>(4)?,
                    ))
                })
                .map_err(unavailable)?;
            for row in rows {
                canceled(cancel)?;
                let (path, line, text, hash, producer) = row.map_err(unavailable)?;
                if reply["results"].as_array().ok_or(invalid())?.len() == 8 {
                    reply["truncated"] = json!(true);
                    break;
                }
                if path.len() > 240 || text.len() > 1024 || hash.len() != 64 || producer.len() > 128
                {
                    return Err(invalid());
                }
                identity(&producer)?;
                let (source, current_text) = inputs
                    .iter()
                    .find(|(source, _)| source.path == path)
                    .ok_or(invalid())?;
                let coordinate = usize::try_from(line)
                    .ok()
                    .and_then(|n| n.checked_sub(1))
                    .ok_or(invalid())?;
                if hash != source.hash
                    || current_text.lines().nth(coordinate) != Some(text.as_str())
                {
                    return Err(invalid());
                }
                let results = reply["results"].as_array_mut().ok_or(invalid())?;
                results.push(json!({"project":id,"path":path,"line":line,"text":text,"source_hash":hash,"producer":producer,"kind":"observed-source-line","currentness":"current-at-read","coverage":"lexical-only"}));
                if serde_json::to_vec(&reply).map_err(unavailable)?.len() > 8192 {
                    reply["results"].as_array_mut().ok_or(invalid())?.pop();
                    reply["truncated"] = json!(true);
                    break;
                }
            }
        }
        canceled(cancel)?;
        let latest = self.project(id)?;
        if latest.root != p.root
            || latest.root_identity != p.root_identity
            || latest.incarnation != p.incarnation
            || latest.sources != p.sources
            || latest.snapshot != p.snapshot
        {
            return Err(Error::ScopeMismatch);
        }
        Ok(reply)
    }

    /// Add or revise human context. Every edit retains a bounded revision history.
    /// Human-authored text is not source truth, executable instructions, or authorization.
    pub fn write_context(
        &mut self,
        project: &str,
        id: &str,
        kind: &str,
        text: &str,
        update: bool,
    ) -> Result<()> {
        let project = self.project(project)?;
        self.write_context_for_policy(&project, id, kind, text, update)
    }

    fn write_context_for_policy(
        &mut self,
        project: &Project,
        id: &str,
        kind: &str,
        text: &str,
        update: bool,
    ) -> Result<()> {
        self.write_context_guarded(project, id, kind, text, update, None)
    }

    fn write_context_guarded(
        &mut self,
        project: &Project,
        id: &str,
        kind: &str,
        text: &str,
        update: bool,
        guard: Option<(u32, &AtomicBool)>,
    ) -> Result<()> {
        identity(id)?;
        validate_context_kind(kind)?;
        validate_context_text(text)?;
        if let Some((_, cancel)) = guard {
            canceled(cancel)?;
        }
        let tx = self
            .db
            .transaction_with_behavior(if guard.is_some() {
                rusqlite::TransactionBehavior::Immediate
            } else {
                rusqlite::TransactionBehavior::Deferred
            })
            .map_err(unavailable)?;
        Self::require_project_root(&tx, project)?;
        let project = project.id.as_str();
        forget::require_unmarked(&tx, project, id)?;
        let revision: Option<i64> = tx
            .query_row(
                "SELECT max(revision) FROM context WHERE project=?1 AND id=?2",
                params![project, id],
                |r| r.get(0),
            )
            .map_err(unavailable)?;
        if let Some((expected, _)) = guard
            && revision != Some(i64::from(expected))
        {
            return Err(Error::ScopeMismatch);
        }
        if update != revision.is_some() || revision.is_some_and(|r| !(1..32).contains(&r)) {
            return Err(invalid());
        }
        let count: i64 = tx
            .query_row(
                "SELECT count(*) FROM context WHERE project=?1",
                [project],
                |r| r.get(0),
            )
            .map_err(unavailable)?;
        if count >= 4096 {
            return Err(invalid());
        }
        tx.execute(
            "INSERT INTO context VALUES(?1,?2,?3,?4,?5,0)",
            params![project, id, revision.unwrap_or(0) + 1, kind, text],
        )
        .map_err(unavailable)?;
        if let Some((_, cancel)) = guard {
            #[cfg(test)]
            context_revision::before_commit();
            canceled(cancel)?;
        }
        tx.commit().map_err(unavailable)
    }

    /// Native cached edits must name the exact registration, not only its reusable ID.
    pub fn write_context_bound(
        &mut self,
        project: &str,
        binding: (&str, &str, &str),
        id: &str,
        kind: &str,
        text: &str,
        update: bool,
    ) -> Result<()> {
        let project = self.bound_project(project, binding.0, binding.1, binding.2)?;
        self.write_context_for_policy(&project, id, kind, text, update)
    }

    /// Retirement is also a persistent human-history mutation.
    pub fn retire_context_bound(
        &mut self,
        project: &str,
        binding: (&str, &str, &str),
        id: &str,
    ) -> Result<()> {
        let project = self.bound_project(project, binding.0, binding.1, binding.2)?;
        self.retire_context_for_policy(&project, id)
    }

    /// Retire a human note by appending a revision, never deleting source files.
    pub fn retire_context(&mut self, project: &str, id: &str) -> Result<()> {
        let project = self.project(project)?;
        self.retire_context_for_policy(&project, id)
    }

    fn retire_context_for_policy(&mut self, project: &Project, id: &str) -> Result<()> {
        self.retire_context_guarded(project, id, None)
    }

    fn retire_context_guarded(
        &mut self,
        project: &Project,
        id: &str,
        guard: Option<(u32, &AtomicBool)>,
    ) -> Result<()> {
        identity(id)?;
        if let Some((_, cancel)) = guard {
            canceled(cancel)?;
        }
        let tx = self
            .db
            .transaction_with_behavior(if guard.is_some() {
                rusqlite::TransactionBehavior::Immediate
            } else {
                rusqlite::TransactionBehavior::Deferred
            })
            .map_err(unavailable)?;
        Self::require_project_root(&tx, project)?;
        let project = project.id.as_str();
        forget::require_unmarked(&tx, project, id)?;
        let (revision,kind,text): (i64,String,String) = tx.query_row("SELECT revision,kind,text FROM context WHERE project=?1 AND id=?2 ORDER BY revision DESC LIMIT 1", params![project,id], |r| Ok((r.get(0)?,r.get(1)?,r.get(2)?))).map_err(unavailable)?;
        if let Some((expected, _)) = guard
            && revision != i64::from(expected)
        {
            return Err(Error::ScopeMismatch);
        }
        let count: i64 = tx
            .query_row(
                "SELECT count(*) FROM context WHERE project=?1",
                [project],
                |r| r.get(0),
            )
            .map_err(unavailable)?;
        if !(1..32).contains(&revision)
            || count >= 4096
            || !context_kind(&kind)
            || text.len() > 4096
        {
            return Err(invalid());
        }
        tx.execute(
            "INSERT INTO context VALUES(?1,?2,?3,?4,?5,1)",
            params![project, id, revision + 1, kind, text],
        )
        .map_err(unavailable)?;
        if let Some((_, cancel)) = guard {
            #[cfg(test)]
            context_revision::before_commit();
            canceled(cancel)?;
        }
        tx.commit().map_err(unavailable)
    }

    /// List latest revisions (including retired markers); no source-content reads.
    pub fn contexts(&self, project: &str) -> Result<Value> {
        let tx = self.db.unchecked_transaction().map_err(unavailable)?;
        self.project(project)?;
        Self::contexts_in(&tx, project)
    }

    fn contexts_in(tx: &rusqlite::Transaction<'_>, project: &str) -> Result<Value> {
        let marked = forget::markers(tx, project)?;
        let mut stmt = tx.prepare("SELECT id,revision,kind,retired FROM context c WHERE project=?1 AND revision=(SELECT max(revision) FROM context WHERE project=c.project AND id=c.id) ORDER BY id LIMIT 4097").map_err(unavailable)?;
        let rows = stmt
            .query_map([project], |r| {
                Ok((
                    r.get::<_, String>(0)?,
                    r.get::<_, i64>(1)?,
                    r.get::<_, String>(2)?,
                    r.get::<_, bool>(3)?,
                ))
            })
            .map_err(unavailable)?;
        let mut records = Vec::new();
        for (count, row) in rows.enumerate() {
            let (id, revision, kind, retired) = row.map_err(unavailable)?;
            if count >= 4096 {
                return Err(invalid());
            }
            if marked.contains(&id) {
                continue;
            }
            identity(&id)?;
            if !(1..=32).contains(&revision) || !context_kind(&kind) || records.len() >= 4096 {
                return Err(invalid());
            }
            records.push(json!({"id":id,"revision":revision,"kind":kind,"retired":retired,"producer":"human-authored","authority":"context-not-authorization-or-observed-truth"}));
        }
        Ok(json!({"project": project,"contexts":records}))
    }

    /// Inspect one note's complete bounded edit history, distinct from source evidence.
    pub fn context(&self, project: &str, id: &str) -> Result<Value> {
        let tx = self.db.unchecked_transaction().map_err(unavailable)?;
        self.project(project)?;
        identity(id)?;
        Self::context_in(&tx, project, id)
    }

    fn context_in(tx: &rusqlite::Transaction<'_>, project: &str, id: &str) -> Result<Value> {
        forget::require_unmarked(tx, project, id)?;
        let mut stmt = tx.prepare("SELECT revision,kind,text,retired FROM context WHERE project=?1 AND id=?2 ORDER BY revision LIMIT 33").map_err(unavailable)?;
        let rows = stmt
            .query_map(params![project, id], |r| {
                Ok((
                    r.get::<_, i64>(0)?,
                    r.get::<_, String>(1)?,
                    r.get::<_, String>(2)?,
                    r.get::<_, i64>(3)?,
                ))
            })
            .map_err(unavailable)?;
        let mut records = Vec::new();
        for row in rows {
            let (revision, kind, text, retired) = row.map_err(unavailable)?;
            if revision != records.len() as i64 + 1
                || !context_kind(&kind)
                || text.is_empty()
                || text.len() > 4096
                || text.contains('\0')
                || !matches!(retired, 0 | 1)
                || records.len() >= 32
            {
                return Err(invalid());
            }
            records
                .push(json!({"revision":revision,"kind":kind,"text":text,"retired":retired != 0}));
        }
        if records.is_empty() {
            return Err(invalid());
        }
        Ok(
            json!({"project":project,"id":id,"producer":"human-authored","authority":"context-not-authorization-or-observed-truth","history":records}),
        )
    }
}
