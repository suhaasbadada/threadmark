//! Recognized schemas only; upgrading is an explicit, atomic owner operation.
use super::*;

const BASE: [(&str, &str); 4] = [
    (
        "projects",
        "CREATE TABLE projects(id TEXT PRIMARY KEY, root TEXT NOT NULL UNIQUE, root_identity TEXT NOT NULL, sources TEXT NOT NULL, snapshot TEXT, manifest TEXT)",
    ),
    (
        "evidence",
        "CREATE TABLE evidence(project TEXT NOT NULL, path TEXT NOT NULL, line INTEGER NOT NULL, text TEXT NOT NULL, hash TEXT NOT NULL, producer TEXT NOT NULL, PRIMARY KEY(project,path,line))",
    ),
    (
        "context",
        "CREATE TABLE context(project TEXT NOT NULL, id TEXT NOT NULL, revision INTEGER NOT NULL, kind TEXT NOT NULL, text TEXT NOT NULL, retired INTEGER NOT NULL, PRIMARY KEY(project,id,revision))",
    ),
    (
        "context_project",
        "CREATE INDEX context_project ON context(project,id,revision)",
    ),
];
const V2: [(&str, &str); 4] = [
    (
        "forgotten_context",
        "CREATE TABLE forgotten_context (project TEXT NOT NULL, id TEXT NOT NULL, PRIMARY KEY(project,id))",
    ),
    (
        "threadmark_context_insert_guard",
        "CREATE TRIGGER threadmark_context_insert_guard BEFORE INSERT ON context WHEN EXISTS(SELECT 1 FROM forgotten_context WHERE project=NEW.project AND id=NEW.id) BEGIN SELECT RAISE(ABORT,'threadmark forgotten context'); END",
    ),
    (
        "threadmark_context_update_guard",
        "CREATE TRIGGER threadmark_context_update_guard BEFORE UPDATE ON context WHEN EXISTS(SELECT 1 FROM forgotten_context WHERE project=NEW.project AND id=NEW.id) BEGIN SELECT RAISE(ABORT,'threadmark forgotten context'); END",
    ),
    (
        "threadmark_project_delete_guard",
        "CREATE TRIGGER threadmark_project_delete_guard BEFORE DELETE ON projects WHEN EXISTS(SELECT 1 FROM forgotten_context WHERE project=OLD.id) BEGIN SELECT RAISE(ABORT,'threadmark forget markers remain'); END",
    ),
];

const V3: [(&str, &str); 3] = [
    (
        "project_incarnations",
        "CREATE TABLE project_incarnations(project TEXT PRIMARY KEY, incarnation TEXT NOT NULL UNIQUE)",
    ),
    (
        "threadmark_project_incarnation_insert",
        "CREATE TRIGGER threadmark_project_incarnation_insert AFTER INSERT ON projects BEGIN INSERT INTO project_incarnations(project,incarnation) VALUES(NEW.id,lower(hex(randomblob(16)))); END",
    ),
    (
        "threadmark_project_incarnation_delete",
        "CREATE TRIGGER threadmark_project_incarnation_delete AFTER DELETE ON projects BEGIN DELETE FROM project_incarnations WHERE project=OLD.id; END",
    ),
];

pub(super) fn install_v3(db: &Connection) -> Result<()> {
    for (_, sql) in V3 {
        db.execute_batch(sql).map_err(unavailable)?;
    }
    db.execute_batch("INSERT INTO project_incarnations SELECT id,lower(hex(randomblob(16))) FROM projects; PRAGMA user_version=3;").map_err(unavailable)?;
    validate(db).map(|_| ())
}

pub(super) fn incarnation(db: &Connection, id: &str) -> Result<Option<String>> {
    if version(db)? < 3 {
        return Ok(None);
    }
    let token: String = db
        .query_row(
            "SELECT incarnation FROM project_incarnations WHERE project=?1",
            [id],
            |r| r.get(0),
        )
        .map_err(unavailable)?;
    validate_incarnation(&token)?;
    Ok(Some(token))
}

// Normalize formatting outside literals only, never predicates or messages.
fn normalized(sql: &str) -> String {
    let mut quoted = false;
    let mut pending_space = false;
    let mut previous_word = false;
    let mut normalized = String::new();
    for c in sql.trim().trim_end_matches(';').chars() {
        if !quoted && c.is_ascii_whitespace() {
            pending_space = true;
            continue;
        }
        let word = c.is_alphanumeric() || c == '_' || c == '$';
        // Optional spacing around punctuation is formatting; spacing between
        // words separates tokens and must never merge NOT NULL into NOTNULL.
        if pending_space && previous_word && word {
            normalized.push(' ');
        }
        pending_space = false;
        normalized.push(c);
        if c == '\'' {
            quoted = !quoted;
        }
        previous_word = word;
    }
    normalized
}

#[test]
fn schema_normalization_preserves_word_boundaries_and_literal_bytes() {
    let canonical = "CREATE TABLE t (id TEXT NOT NULL, PRIMARY KEY(id))";
    assert_eq!(
        normalized(canonical),
        normalized(" CREATE  TABLE t( id TEXT\nNOT\tNULL , PRIMARY KEY ( id ) ) ;")
    );
    assert_ne!(
        normalized(canonical),
        normalized("CREATE TABLE t(id TEXTNOTNULL, PRIMARY KEY(id))")
    );
    assert_ne!(normalized("SELECT 'a b'"), normalized("SELECT 'ab'"));
    assert_ne!(normalized("SELECT 'a'' b'"), normalized("SELECT 'a''b'"));
}

pub(super) fn version(db: &Connection) -> Result<i64> {
    db.pragma_query_value(None, "user_version", |r| r.get(0))
        .map_err(unavailable)
}

pub(super) fn validate(db: &Connection) -> Result<i64> {
    let version = version(db)?;
    let app: i64 = db
        .pragma_query_value(None, "application_id", |r| r.get(0))
        .map_err(unavailable)?;
    let page: i64 = db
        .pragma_query_value(None, "page_size", |r| r.get(0))
        .map_err(unavailable)?;
    if app != APP_ID || page != 4096 || !matches!(version, 1..=3) {
        return Err(Error::Unavailable);
    }
    let mut stmt = db
        .prepare("SELECT name,sql FROM sqlite_schema WHERE sql IS NOT NULL ORDER BY name LIMIT 12")
        .map_err(unavailable)?;
    let rows = stmt
        .query_map([], |r| Ok((r.get::<_, String>(0)?, r.get::<_, String>(1)?)))
        .map_err(unavailable)?;
    let expected: Vec<_> = BASE
        .iter()
        .chain(V2.iter().take(if version >= 2 { 4 } else { 0 }))
        .chain(V3.iter().take(if version == 3 { 3 } else { 0 }))
        .collect();
    let mut count = 0;
    for row in rows {
        let (name, sql) = row.map_err(unavailable)?;
        let (_, canonical) = expected
            .iter()
            .find(|(n, _)| *n == name)
            .ok_or(Error::Unavailable)?;
        if normalized(&sql) != normalized(canonical) {
            return Err(Error::Unavailable);
        }
        count += 1;
    }
    if count != expected.len() {
        return Err(Error::Unavailable);
    }
    // SQLite owns only these implicit uniqueness indexes. NULL SQL must not
    // become a loophole for admitting arbitrary extra schema objects.
    let mut stmt = db
        .prepare("SELECT type,name,tbl_name FROM sqlite_schema WHERE sql IS NULL LIMIT 8")
        .map_err(unavailable)?;
    let rows = stmt
        .query_map([], |r| {
            Ok((
                r.get::<_, String>(0)?,
                r.get::<_, String>(1)?,
                r.get::<_, String>(2)?,
            ))
        })
        .map_err(unavailable)?;
    let mut implicit = std::collections::BTreeSet::new();
    for row in rows {
        let (kind, name, table) = row.map_err(unavailable)?;
        let valid = match name.as_str() {
            "sqlite_autoindex_projects_1" | "sqlite_autoindex_projects_2" => table == "projects",
            "sqlite_autoindex_evidence_1" => table == "evidence",
            "sqlite_autoindex_context_1" => table == "context",
            "sqlite_autoindex_forgotten_context_1" => version >= 2 && table == "forgotten_context",
            "sqlite_autoindex_project_incarnations_1"
            | "sqlite_autoindex_project_incarnations_2" => {
                version == 3 && table == "project_incarnations"
            }
            _ => false,
        };
        if kind != "index" || !valid || !implicit.insert(name) {
            return Err(Error::Unavailable);
        }
    }
    if implicit.len()
        != match version {
            3 => 7,
            2 => 5,
            _ => 4,
        }
    {
        return Err(Error::Unavailable);
    }
    if version == 3 {
        let invalid: bool = db.query_row("SELECT EXISTS(SELECT 1 FROM projects p LEFT JOIN project_incarnations i ON i.project=p.id WHERE i.project IS NULL) OR EXISTS(SELECT 1 FROM project_incarnations i LEFT JOIN projects p ON p.id=i.project WHERE p.id IS NULL OR typeof(i.incarnation)!='text' OR length(CAST(i.incarnation AS BLOB))!=32 OR instr(i.incarnation,char(0))>0 OR i.incarnation GLOB '*[^0-9a-f]*')", [], |r| r.get(0)).map_err(unavailable)?;
        if invalid {
            return Err(Error::Unavailable);
        }
    }
    Ok(version)
}

pub(super) fn install_v2(db: &Connection) -> Result<()> {
    for (_, sql) in V2 {
        db.execute_batch(sql).map_err(unavailable)?;
    }
    db.pragma_update(None, "user_version", 2)
        .map_err(unavailable)
}

/// Explicit migration boundaries; cancellation before commit preserves schema v1.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UpgradeStage {
    /// Recognized schema validated inside the immediate transaction.
    Validated,
    /// Table, guards and version staged, not committed.
    ReadyToCommit,
}

impl Store {
    /// Explicitly upgrade an existing store; older binaries cannot read schema v2.
    pub fn upgrade(&mut self, cancel: &AtomicBool) -> Result<Value> {
        self.upgrade_with_progress(cancel, |_| {})
    }

    /// Observe migration without exposing data or enabling implicit repair.
    pub fn upgrade_with_progress(
        &mut self,
        cancel: &AtomicBool,
        mut progress: impl FnMut(UpgradeStage),
    ) -> Result<Value> {
        self.upgrade_to_with_progress(2, cancel, &mut progress)
    }

    /// Explicit owner-attested v3 migration; callers must stop legacy workers first.
    pub fn upgrade_to_v3(&mut self, cancel: &AtomicBool) -> Result<Value> {
        self.upgrade_to_with_progress(3, cancel, |_| {})
    }

    /// Atomic migration with synthetic fault/cancellation observation boundaries.
    pub fn upgrade_to_with_progress(
        &mut self,
        target: i64,
        cancel: &AtomicBool,
        mut progress: impl FnMut(UpgradeStage),
    ) -> Result<Value> {
        if !matches!(target, 2 | 3) {
            return Err(invalid());
        }
        canceled(cancel)?;
        self.healthy()?;
        let tx = self
            .db
            .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
            .map_err(unavailable)?;
        let old = validate(&tx)?;
        progress(UpgradeStage::Validated);
        canceled(cancel)?;
        if old == 1 {
            install_v2(&tx)?;
        }
        if target == 3 && old < 3 {
            install_v3(&tx)?;
        }
        let actual = version(&tx)?;
        progress(UpgradeStage::ReadyToCommit);
        canceled(cancel)?;
        tx.commit().map_err(unavailable)?;
        Ok(
            json!({"schema_version":actual,"upgraded":old != actual,"compatibility":format!("Older binaries cannot open schema v{actual}; no automatic downgrade.")}),
        )
    }
}
