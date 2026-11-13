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
fn identity(id: &str) -> Result<()> {
    Scope::new(id, "local", "snapshot").map(|_| ())
}
fn context_kind(kind: &str) -> bool {
    matches!(kind, "decision" | "constraint" | "correction" | "pitfall")
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
    /// Exact relative file allowlist, never recursive discovery.
    pub sources: Vec<String>,
    /// Content snapshot identity (not a Git revision); absent after scope revocation.
    pub snapshot: Option<String>,
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
        if !path.is_absolute() {
            return Err(Error::ScopeMismatch);
        }
        let parent = store_directory(path.parent().ok_or(Error::ScopeMismatch)?)?;
        let name = path.file_name().ok_or(Error::ScopeMismatch)?;
        let created = match mkdirat(&parent, name, Mode::from_raw_mode(0o700)) {
            Ok(()) => true,
            Err(rustix::io::Errno::EXIST) => false,
            Err(e) => return Err(unavailable(e)),
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
                || u16::from_be_bytes([header[16], header[17]]) != 4096
                || u32::from_be_bytes(header[60..64].try_into().map_err(unavailable)?) != 1
                || i64::from(u32::from_be_bytes(
                    header[68..72].try_into().map_err(unavailable)?,
                )) != APP_ID
            {
                return Err(Error::Unavailable);
            }
        }
        let mut db = Connection::open_with_flags(
            &db_path,
            rusqlite::OpenFlags::SQLITE_OPEN_READ_WRITE
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
            tx.commit().map_err(unavailable)?;
        }
        let app: i64 = db
            .pragma_query_value(None, "application_id", |r| r.get(0))
            .map_err(unavailable)?;
        let version: i64 = db
            .pragma_query_value(None, "user_version", |r| r.get(0))
            .map_err(unavailable)?;
        if app != APP_ID || version != 1 {
            return Err(Error::Unavailable);
        }
        // Validate the v1 shape before changing persistent journal settings. There
        // is no guessed repair/migration of unknown application databases.
        let page_size: i64 = db
            .pragma_query_value(None, "page_size", |r| r.get(0))
            .map_err(unavailable)?;
        if page_size != 4096 {
            return Err(Error::Unavailable);
        }
        let objects: i64 = db.query_row("SELECT count(*) FROM sqlite_schema WHERE (type NOT IN ('table','index')) OR (type='table' AND name NOT IN ('projects','evidence','context'))",[],|r|r.get(0)).map_err(unavailable)?;
        if objects != 0 {
            return Err(Error::Unavailable);
        }
        for sql in [
            "SELECT id,root,root_identity,sources,snapshot,manifest FROM projects LIMIT 0",
            "SELECT project,path,line,text,hash,producer FROM evidence LIMIT 0",
            "SELECT project,id,revision,kind,text,retired FROM context LIMIT 0",
        ] {
            db.prepare(sql).map_err(unavailable)?;
        }
        db.execute_batch("PRAGMA trusted_schema=OFF; PRAGMA foreign_keys=ON; PRAGMA journal_mode=DELETE; PRAGMA synchronous=FULL; PRAGMA max_page_count=32768;").map_err(unavailable)?;
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

    /// Inspect policy without reading any source file.
    pub fn project(&self, id: &str) -> Result<Project> {
        self.healthy()?;
        identity(id)?;
        let (root, root_identity, sources, snapshot): (String, String, String, Option<String>) =
            self.db
                .query_row(
                    "SELECT root,root_identity,sources,snapshot FROM projects WHERE id=?1",
                    [id],
                    |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?)),
                )
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
        Ok(Project {
            id: id.into(),
            root,
            root_identity,
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
        self.project(id)?;
        validate_paths(&paths)?;
        let tx = self.db.transaction().map_err(unavailable)?;
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
            canceled(cancel)?;
            let mut parent = root.try_clone().map_err(unavailable)?;
            let components: Vec<_> = path.split('/').collect();
            for part in &components[..components.len() - 1] {
                parent = File::from(
                    openat(&parent, *part, FLAGS | OFlags::DIRECTORY, Mode::empty())
                        .map_err(unavailable)?,
                );
                // Nested repositories/submodules require their own explicit project root.
                if rustix::fs::statat(&parent, ".git", rustix::fs::AtFlags::SYMLINK_NOFOLLOW)
                    .is_ok()
                {
                    return Err(Error::ScopeMismatch);
                }
                if parent.metadata().map_err(unavailable)?.dev()
                    != root.metadata().map_err(unavailable)?.dev()
                {
                    return Err(Error::ScopeMismatch);
                }
            }
            let file = File::from(
                openat(
                    &parent,
                    components[components.len() - 1],
                    FLAGS | OFlags::NONBLOCK,
                    Mode::empty(),
                )
                .map_err(unavailable)?,
            );
            let metadata = file.metadata().map_err(unavailable)?;
            if !metadata.is_file()
                || metadata.len() > MAX_FILE as u64
                || metadata.dev() != root.metadata().map_err(unavailable)?.dev()
                || metadata.nlink() != 1
            {
                return Err(invalid());
            }
            let file_id = file_identity(&file)?;
            let mut bytes = Vec::new();
            file.take((MAX_FILE + 1) as u64)
                .read_to_end(&mut bytes)
                .map_err(unavailable)?;
            total += bytes.len();
            if bytes.len() > MAX_FILE || total > MAX_TOTAL || bytes.contains(&0) {
                return Err(invalid());
            }
            let hash = sha256(&bytes);
            let text = String::from_utf8(bytes).map_err(unavailable)?;
            result.push((
                Source {
                    path: path.clone(),
                    hash,
                    identity: file_id,
                },
                text,
            ));
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
        mut progress: impl FnMut(IndexStage),
    ) -> Result<Value> {
        canceled(cancel)?;
        let p = self.project(id)?;
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
        let tx = self.db.transaction().map_err(unavailable)?;
        // Protect against a second local process revoking consent during extraction.
        let policy: String = tx
            .query_row("SELECT sources FROM projects WHERE id=?1", [id], |r| {
                r.get(0)
            })
            .map_err(unavailable)?;
        if serde_json::from_str::<Vec<String>>(&policy).map_err(unavailable)? != p.sources {
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
        canceled(cancel)?;
        if text.is_empty() || text.len() > 256 {
            return Err(invalid());
        }
        let p = self.project(id)?;
        let stored: Option<String> = self
            .db
            .query_row("SELECT manifest FROM projects WHERE id=?1", [id], |r| {
                r.get(0)
            })
            .map_err(unavailable)?;
        let current_inputs = match (stored, Self::read_sources(&p, cancel)) {
            (Some(encoded), Ok(inputs)) if encoded.len() <= 32768 => {
                let expected: Vec<Source> = serde_json::from_str(&encoded).map_err(unavailable)?;
                if p.snapshot.as_ref() == Some(&sha256(encoded.as_bytes()))
                    && expected == inputs.iter().map(|(s, _)| s.clone()).collect::<Vec<_>>()
                {
                    Some(inputs)
                } else {
                    None
                }
            }
            _ => None,
        };
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
        if latest.sources != p.sources || latest.snapshot != p.snapshot {
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
        self.project(project)?;
        identity(id)?;
        if !context_kind(kind) || text.is_empty() || text.len() > 4096 || text.contains('\0') {
            return Err(invalid());
        }
        let tx = self.db.transaction().map_err(unavailable)?;
        let revision: Option<i64> = tx
            .query_row(
                "SELECT max(revision) FROM context WHERE project=?1 AND id=?2",
                params![project, id],
                |r| r.get(0),
            )
            .map_err(unavailable)?;
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
        tx.commit().map_err(unavailable)
    }

    /// Retire a human note by appending a revision, never deleting source files.
    pub fn retire_context(&mut self, project: &str, id: &str) -> Result<()> {
        self.project(project)?;
        identity(id)?;
        let tx = self.db.transaction().map_err(unavailable)?;
        let (revision,kind,text): (i64,String,String) = tx.query_row("SELECT revision,kind,text FROM context WHERE project=?1 AND id=?2 ORDER BY revision DESC LIMIT 1", params![project,id], |r| Ok((r.get(0)?,r.get(1)?,r.get(2)?))).map_err(unavailable)?;
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
        tx.commit().map_err(unavailable)
    }

    /// List latest revisions (including retired markers); no source-content reads.
    pub fn contexts(&self, project: &str) -> Result<Value> {
        self.project(project)?;
        let mut stmt = self.db.prepare("SELECT id,revision,kind,retired FROM context c WHERE project=?1 AND revision=(SELECT max(revision) FROM context WHERE project=c.project AND id=c.id) ORDER BY id LIMIT 4097").map_err(unavailable)?;
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
        for row in rows {
            let (id, revision, kind, retired) = row.map_err(unavailable)?;
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
        self.project(project)?;
        identity(id)?;
        let mut stmt = self.db.prepare("SELECT revision,kind,text,retired FROM context WHERE project=?1 AND id=?2 ORDER BY revision LIMIT 33").map_err(unavailable)?;
        let rows = stmt
            .query_map(params![project, id], |r| {
                Ok((
                    r.get::<_, i64>(0)?,
                    r.get::<_, String>(1)?,
                    r.get::<_, String>(2)?,
                    r.get::<_, bool>(3)?,
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
                || records.len() >= 32
            {
                return Err(invalid());
            }
            records.push(json!({"revision":revision,"kind":kind,"text":text,"retired":retired}));
        }
        if records.is_empty() {
            return Err(invalid());
        }
        Ok(
            json!({"project":project,"id":id,"producer":"human-authored","authority":"context-not-authorization-or-observed-truth","history":records}),
        )
    }
}
