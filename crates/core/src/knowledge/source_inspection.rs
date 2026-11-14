//! Explicit current indexed-anchor windows. No unbound content-read convenience API.
use super::*;

/// Version-one bounded inspection selector, subordinate to a complete Project binding.
#[derive(Debug)]
pub struct SourceAnchorInspection {
    /// Relative path already admitted in the captured ordered source policy.
    pub path: String,
    /// One-based indexed anchor coordinate.
    pub line: usize,
    /// Expected exact source SHA-256 from retrieved evidence.
    pub source_hash: String,
    /// Explicit neighboring-line radius, zero through three.
    pub radius: usize,
}

/// Pure shape validation; never opens storage or caller-provided source paths.
pub fn validate_source_inspection(p: &Project, anchor: &SourceAnchorInspection) -> Result<()> {
    validate_query_binding(p, "inspect")?;
    validate_paths(std::slice::from_ref(&anchor.path))?;
    if p.snapshot.is_none()
        || !p.sources.contains(&anchor.path)
        || !(1..=4096).contains(&anchor.line)
        || anchor.radius > 3
        || anchor.source_hash.len() != 64
        || !anchor
            .source_hash
            .bytes()
            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
    {
        return Err(invalid());
    }
    Ok(())
}

impl Store {
    /// Inspect a previously retrieved indexed anchor with a complete, explicit binding.
    /// Whole output including newline is bounded to 8 KiB; errors return no content.
    pub fn inspect_source_anchor(
        &self,
        expected: &Project,
        anchor: &SourceAnchorInspection,
        cancel: &AtomicBool,
    ) -> Result<Value> {
        self.inspect_anchor_scoped(expected, anchor, cancel, || {}, || {})
    }

    fn inspect_anchor_scoped(
        &self,
        expected: &Project,
        anchor: &SourceAnchorInspection,
        cancel: &AtomicBool,
        before_sources: impl FnOnce(),
        ready: impl FnOnce(),
    ) -> Result<Value> {
        validate_source_inspection(expected, anchor)?;
        canceled(cancel)?;
        self.healthy()?;
        let tx = self.db.unchecked_transaction().map_err(unavailable)?;
        let p = self.query_project(&expected.id, Some(expected))?;
        let journal: String = tx
            .pragma_query_value(None, "journal_mode", |r| r.get(0))
            .map_err(unavailable)?;
        if journal != "delete" {
            return Err(Error::Unavailable);
        }
        // Evidence membership and caller's hash are checked before source authority
        // or traversal, not merely against an arbitrary approved filename.
        let (text, hash, producer): (String, String, String) = tx
            .query_row(
                "SELECT text,hash,producer FROM evidence WHERE project=?1 AND path=?2 AND line=?3",
                params![p.id, anchor.path, anchor.line as i64],
                |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
            )
            .map_err(unavailable)?;
        identity(&producer)?;
        if text.len() > 1024 || text.trim().is_empty() || hash != anchor.source_hash {
            return Err(invalid());
        }
        let encoded: String = tx
            .query_row("SELECT manifest FROM projects WHERE id=?1", [&p.id], |r| {
                r.get(0)
            })
            .map_err(unavailable)?;
        if encoded.len() > 32768
            || p.snapshot.as_deref() != Some(sha256(encoded.as_bytes()).as_str())
        {
            return Err(invalid());
        }
        let manifest: Vec<Source> = serde_json::from_str(&encoded).map_err(unavailable)?;
        if manifest.len() != p.sources.len()
            || manifest
                .iter()
                .zip(&p.sources)
                .any(|(s, path)| s.path != *path)
            || !manifest
                .iter()
                .any(|s| s.path == anchor.path && s.hash == anchor.source_hash)
        {
            return Err(invalid());
        }
        before_sources();
        canceled(cancel)?;
        let inputs = Self::read_sources(&p, cancel)?;
        if !manifest.iter().eq(inputs.iter().map(|(s, _)| s)) {
            return Err(Error::ScopeMismatch);
        }
        canceled(cancel)?;
        let (source, source_text) = inputs
            .iter()
            .find(|(s, _)| s.path == anchor.path)
            .ok_or(invalid())?;
        let lines: Vec<_> = source_text.lines().collect();
        if source.hash != hash || lines.get(anchor.line - 1).copied() != Some(text.as_str()) {
            return Err(invalid());
        }
        let start = (anchor.line - 1).saturating_sub(anchor.radius);
        let end = (anchor.line + anchor.radius).min(lines.len());
        let window: Vec<_> = lines[start..end]
            .iter()
            .enumerate()
            .map(|(i, text)| {
                let line = start + i + 1;
                json!({"line":line,"text":text,"is_anchor":line == anchor.line,
                "kind":if line == anchor.line {"indexed-anchor"} else {"observed-source-text"}})
            })
            .collect();
        let reply = json!({"format":"threadmark-source-anchor-inspection","version":1,
            "project":p.id,"root_identity":p.root_identity,"incarnation":p.incarnation,
            "snapshot":p.snapshot,"path":anchor.path,"source_hash":hash,"producer":producer,
            "anchor_line":anchor.line,"radius":anchor.radius,"currentness":"current-at-read","lines":window});
        if serde_json::to_vec(&reply).map_err(unavailable)?.len() + 1 > 8192 {
            return Err(invalid());
        }
        ready();
        canceled(cancel)?;
        self.healthy()?;
        let after = Self::read_sources(&p, cancel)?;
        if !inputs
            .iter()
            .map(|(s, _)| s)
            .eq(after.iter().map(|(s, _)| s))
        {
            return Err(Error::ScopeMismatch);
        }
        // Validation only: never adopt a freshly loaded project for source reads.
        self.query_project(&p.id, Some(&p))?;
        canceled(cancel)?;
        tx.commit().map_err(unavailable)?;
        canceled(cancel)?;
        Ok(reply)
    }
}

#[cfg(test)]
mod tests;
