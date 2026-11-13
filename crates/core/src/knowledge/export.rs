//! Project export v1: one read snapshot, no indexing and no partial publication.
use super::*;

fn valid_file_identity(identity: &str) -> bool {
    identity.split_once(':').is_some_and(|(dev, ino)| {
        !dev.is_empty()
            && !ino.is_empty()
            && dev.bytes().all(|b| b.is_ascii_digit())
            && ino.bytes().all(|b| b.is_ascii_digit())
            && dev.parse::<u64>().is_ok()
            && ino.parse::<u64>().is_ok()
    })
}

fn root_authorized(project: &Project) -> Result<()> {
    if file_identity(&directory(Path::new(&project.root))?)? != project.root_identity {
        return Err(Error::ScopeMismatch);
    }
    Ok(())
}

// Include the CLI newline. Each row is encoded once before appending, so memory
// is bounded before accumulation and accounting is linear, including escaping.
fn append(rows: &mut Vec<Value>, row: Value, bytes: &mut usize) -> Result<()> {
    let encoded = serde_json::to_vec(&row).map_err(unavailable)?;
    *bytes = bytes
        .checked_add(encoded.len() + usize::from(!rows.is_empty()))
        .ok_or(invalid())?;
    if *bytes > MAX_TOTAL {
        return Err(invalid());
    }
    rows.push(row);
    Ok(())
}

#[test]
fn inclusive_output_bound_counts_escaping_and_array_commas_before_append() {
    let row = json!({"text":"synthetic\t\n\"\\"});
    let size = serde_json::to_vec(&row).unwrap().len();
    let mut rows = Vec::new();
    // The caller's base byte count includes empty arrays and the CLI newline.
    let mut bytes = MAX_TOTAL - size;
    append(&mut rows, row.clone(), &mut bytes).unwrap();
    assert_eq!(bytes, MAX_TOTAL);
    let before = rows.clone();
    assert!(append(&mut rows, row.clone(), &mut bytes).is_err());
    assert_eq!(rows, before);
    bytes = MAX_TOTAL - size; // Existing row also requires a comma.
    assert!(append(&mut rows, row, &mut bytes).is_err());
    assert_eq!(rows, before);
}

impl Store {
    /// Export the selected project's sensitive local content, not a share/import
    /// capability. The caller must obtain explicit approval before invoking this.
    pub fn export_project(&self, id: &str, cancel: &AtomicBool) -> Result<Value> {
        self.export_project_with_progress(id, cancel, |_| {})
    }

    /// Observe finite boundaries before the final source/authorization recheck.
    /// A read transaction prevents concurrent removal/writers from mixing policy,
    /// evidence and human history. Lock contention fails without implicit retries.
    pub fn export_project_with_progress(
        &self,
        id: &str,
        cancel: &AtomicBool,
        mut progress: impl FnMut(ExportStage),
    ) -> Result<Value> {
        canceled(cancel)?;
        identity(id)?;
        self.healthy()?;
        let tx = self.db.unchecked_transaction().map_err(unavailable)?;
        // project() uses the same connection and therefore this read transaction.
        let p = self.project(id)?;
        // Store opens enforce DELETE journals. Keep its reader-lock guarantee
        // explicit: an externally switched WAL connection must not let policy
        // revocation commit invisibly behind this read snapshot.
        let journal: String = tx
            .pragma_query_value(None, "journal_mode", |r| r.get(0))
            .map_err(unavailable)?;
        if journal != "delete" {
            return Err(Error::Unavailable);
        }
        root_authorized(&p)?; // Authorization failure must never become stale output.
        let encoded: Option<String> = tx
            .query_row("SELECT manifest FROM projects WHERE id=?1", [id], |r| {
                r.get(0)
            })
            .map_err(unavailable)?;
        let expected: Option<Vec<Source>> = match (&p.snapshot, encoded) {
            (None, None) => None,
            (Some(snapshot), Some(encoded)) => {
                if encoded.len() > 32768 || *snapshot != sha256(encoded.as_bytes()) {
                    return Err(invalid());
                }
                let manifest: Vec<Source> = serde_json::from_str(&encoded).map_err(unavailable)?;
                if manifest.len() != p.sources.len() {
                    return Err(invalid());
                }
                for (source, path) in manifest.iter().zip(&p.sources) {
                    if source.path != *path
                        || source.hash.len() != 64
                        || !source.hash.bytes().all(|b| b.is_ascii_hexdigit())
                        || source.identity.len() > 128
                        || !valid_file_identity(&source.identity)
                    {
                        return Err(invalid());
                    }
                }
                Some(manifest)
            }
            _ => return Err(invalid()),
        };
        let initial = match Self::read_sources(&p, cancel) {
            Ok(inputs) => Some(inputs),
            Err(Error::Canceled) => return Err(Error::Canceled),
            Err(Error::ScopeMismatch) => return Err(Error::ScopeMismatch),
            Err(_) => None, // Only approved-file content may be unavailable.
        };
        root_authorized(&p)?;
        let current = expected.as_ref().is_some_and(|expected| {
            initial
                .as_ref()
                .is_some_and(|inputs| expected.iter().eq(inputs.iter().map(|(source, _)| source)))
        });
        progress(ExportStage::Read);
        canceled(cancel)?;
        let mut reply = json!({
            "format":"threadmark-project-export", "version":1,
            "project":{"id":id,"root_identity":p.root_identity,"sources":p.sources},
            "snapshot":p.snapshot,
            "currentness":if current {"current-at-read"} else {"stale-or-unindexed"},
            "coverage":"lexical-lines-only; no semantic coverage; evidence current-at-read only; stale or unindexed evidence omitted",
            "evidence":[], "human_history":[]
        });
        let mut bytes = serde_json::to_vec(&reply).map_err(unavailable)?.len() + 1;
        let mut evidence = Vec::new();
        let mut stmt = tx.prepare("SELECT project,path,line,text,hash,producer FROM evidence WHERE project=?1 ORDER BY path,line LIMIT 16385").map_err(unavailable)?;
        let mut rows = stmt.query([id]).map_err(unavailable)?;
        let mut count = 0;
        while let Some(row) = rows.next().map_err(unavailable)? {
            canceled(cancel)?;
            count += 1;
            let project: String = row.get(0).map_err(unavailable)?;
            let path: String = row.get(1).map_err(unavailable)?;
            let line: i64 = row.get(2).map_err(unavailable)?;
            let text: String = row.get(3).map_err(unavailable)?;
            let hash: String = row.get(4).map_err(unavailable)?;
            let producer: String = row.get(5).map_err(unavailable)?;
            if count > 16384
                || project != id
                || path.len() > 240
                || !(1..=4096).contains(&line)
                || text.len() > 1024
                || text.trim().is_empty()
                || text.contains('\0')
                || hash.len() != 64
            {
                return Err(invalid());
            }
            identity(&producer)?;
            let source = expected
                .as_ref()
                .and_then(|m| m.iter().find(|s| s.path == path))
                .ok_or(invalid())?;
            if hash != source.hash {
                return Err(invalid());
            }
            if current {
                let (_, source_text) = initial
                    .as_ref()
                    .and_then(|inputs| inputs.iter().find(|(s, _)| s.path == path))
                    .ok_or(invalid())?;
                if source_text.lines().nth(line as usize - 1) != Some(text.as_str()) {
                    return Err(invalid());
                }
                append(
                    &mut evidence,
                    json!({"project":id,"path":path,"line":line,"text":text,"source_hash":hash,"producer":producer,"kind":"observed-source-line","currentness":"current-at-read"}),
                    &mut bytes,
                )?;
            }
        }
        drop(rows);
        drop(stmt);
        let mut history = Vec::new();
        let mut stmt = tx.prepare("SELECT project,id,revision,kind,text,retired FROM context WHERE project=?1 ORDER BY id,revision LIMIT 4097").map_err(unavailable)?;
        let mut rows = stmt.query([id]).map_err(unavailable)?;
        let mut previous_id = String::new();
        let mut previous_revision = 0;
        while let Some(row) = rows.next().map_err(unavailable)? {
            canceled(cancel)?;
            let project: String = row.get(0).map_err(unavailable)?;
            let context_id: String = row.get(1).map_err(unavailable)?;
            let revision: i64 = row.get(2).map_err(unavailable)?;
            let kind: String = row.get(3).map_err(unavailable)?;
            let text: String = row.get(4).map_err(unavailable)?;
            let retired: i64 = row.get(5).map_err(unavailable)?;
            identity(&context_id)?;
            if context_id != previous_id {
                previous_revision = 0;
            }
            if project != id
                || history.len() >= 4096
                || !(1..=32).contains(&revision)
                || revision != previous_revision + 1
                || !context_kind(&kind)
                || text.is_empty()
                || text.len() > 4096
                || text.contains('\0')
                || !matches!(retired, 0 | 1)
            {
                return Err(invalid());
            }
            previous_id.clone_from(&context_id);
            previous_revision = revision;
            append(
                &mut history,
                json!({"id":context_id,"revision":revision,"kind":kind,"text":text,"retired":retired == 1,"producer":"human-authored","authority":"context-not-authorization-or-observed-truth"}),
                &mut bytes,
            )?;
        }
        drop(rows);
        drop(stmt);
        reply["evidence"] = Value::Array(evidence);
        reply["human_history"] = Value::Array(history);
        progress(ExportStage::ReadyToPublish);
        canceled(cancel)?;
        self.healthy()?;
        root_authorized(&p)?;
        // Recheck even a history-only export's authority; once current, any
        // approved-file change fails rather than silently changing currentness.
        if current {
            let after = Self::read_sources(&p, cancel)?;
            if !expected
                .as_ref()
                .ok_or(invalid())?
                .iter()
                .eq(after.iter().map(|(s, _)| s))
            {
                return Err(Error::ScopeMismatch);
            }
        }
        let latest = self.project(id)?;
        if latest.root != p.root
            || latest.root_identity != p.root_identity
            || latest.sources != p.sources
            || latest.snapshot != p.snapshot
        {
            return Err(Error::ScopeMismatch);
        }
        let final_bytes = serde_json::to_vec(&reply).map_err(unavailable)?.len() + 1;
        if final_bytes > MAX_TOTAL || final_bytes != bytes {
            return Err(invalid());
        }
        canceled(cancel)?;
        tx.commit().map_err(unavailable)?;
        Ok(reply)
    }
}
