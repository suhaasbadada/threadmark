//! A privately frozen selection inspected under one DELETE reader transaction.
use super::*;

/// Closed source coordinate; caller data is not evidence or read authority.
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SourceInspectionAnchor {
    /// Exact approved relative path.
    pub path: String,
    /// One-based indexed coordinate (1..4096).
    pub line: usize,
    /// Expected lowercase source SHA-256.
    pub source_hash: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Document {
    version: String,
    anchors: Vec<SourceInspectionAnchor>,
}

/// Immutable owned, purely admitted complete capture. No unchecked constructor.
#[derive(Debug)]
pub struct SourceInspectionSet {
    project: Project,
    radius: usize,
    anchors: Vec<SourceAnchorInspection>,
}

impl SourceInspectionSet {
    /// Pure pre-stdin admission of flags; never touches storage or sources.
    pub fn validate_binding(project: &Project, radius: usize) -> Result<()> {
        validate_query_binding(project, "inspect-set")?;
        if project.snapshot.is_none() || project.sources.is_empty() || radius > 3 {
            return Err(invalid());
        }
        Ok(())
    }

    /// Freeze the full capture and canonicalize by policy position then line.
    pub fn new(
        project: Project,
        radius: usize,
        anchors: Vec<SourceInspectionAnchor>,
    ) -> Result<Self> {
        Self::validate_binding(&project, radius)?;
        if !(2..=8).contains(&anchors.len()) {
            return Err(invalid());
        }
        let mut coordinates = std::collections::BTreeSet::new();
        let mut admitted = Vec::with_capacity(anchors.len());
        for anchor in anchors {
            if !coordinates.insert((anchor.path.clone(), anchor.line)) {
                return Err(invalid());
            }
            let anchor = SourceAnchorInspection {
                path: anchor.path,
                line: anchor.line,
                source_hash: anchor.source_hash,
                radius,
            };
            validate_source_inspection(&project, &anchor)?;
            admitted.push(anchor);
        }
        admitted.sort_by_key(|a| (project.sources.iter().position(|p| *p == a.path), a.line));
        Ok(Self {
            project,
            radius,
            anchors: admitted,
        })
    }

    /// Strict bounded single-document stdin parser; derived structs reject duplicate
    /// (including escaped aliases) and unknown keys, and non-integer coordinates.
    pub fn parse(project: Project, radius: usize, bytes: &[u8]) -> Result<Self> {
        Self::validate_binding(&project, radius)?;
        if bytes.len() > 65_536 || bytes.contains(&0) {
            return Err(invalid());
        }
        std::str::from_utf8(bytes).map_err(unavailable)?;
        let document: Document = serde_json::from_slice(bytes).map_err(unavailable)?;
        if document.version != "source-inspection-set-v1" {
            return Err(invalid());
        }
        Self::new(project, radius, document.anchors)
    }
}

impl Store {
    /// Inspect every selected anchor coherently, or return no content at all.
    pub fn inspect_source_set(
        &self,
        plan: &SourceInspectionSet,
        cancel: &AtomicBool,
    ) -> Result<Value> {
        self.inspect_set_scoped(plan, cancel, |_| {})
    }

    fn inspect_set_scoped(
        &self,
        plan: &SourceInspectionSet,
        cancel: &AtomicBool,
        mut boundary: impl FnMut(InspectionSetStage),
    ) -> Result<Value> {
        canceled(cancel)?;
        self.healthy()?;
        let tx = self.db.unchecked_transaction().map_err(unavailable)?;
        let p = self.query_project(&plan.project.id, Some(&plan.project))?;
        let journal: String = tx
            .pragma_query_value(None, "journal_mode", |r| r.get(0))
            .map_err(unavailable)?;
        if journal != "delete" {
            return Err(Error::Unavailable);
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
        {
            return Err(invalid());
        }
        let mut indexed = Vec::with_capacity(plan.anchors.len());
        // Admit ALL membership before read_sources (including its authorization).
        for anchor in &plan.anchors {
            canceled(cancel)?;
            let (text, hash, producer): (String, String, String) = tx.query_row(
                "SELECT text,hash,producer FROM evidence WHERE project=?1 AND path=?2 AND line=?3",
                params![p.id, anchor.path, anchor.line as i64],
                |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
            ).map_err(unavailable)?;
            identity(&producer)?;
            if text.len() > 1024
                || text.trim().is_empty()
                || hash != anchor.source_hash
                || !manifest
                    .iter()
                    .any(|s| s.path == anchor.path && s.hash == hash)
            {
                return Err(invalid());
            }
            indexed.push((text, hash, producer));
        }
        boundary(InspectionSetStage::AllMembership);
        canceled(cancel)?;
        let inputs = Self::read_sources(&p, cancel)?;
        if !manifest.iter().eq(inputs.iter().map(|(s, _)| s)) {
            return Err(Error::ScopeMismatch);
        }
        boundary(InspectionSetStage::SourcesRead);
        let mut inspections = Vec::with_capacity(plan.anchors.len());
        for (i, (anchor, (text, hash, producer))) in plan.anchors.iter().zip(&indexed).enumerate() {
            canceled(cancel)?;
            let lines = source_inspection::inspection_window(anchor, &inputs, text, hash)?;
            inspections.push(
                json!({"path":anchor.path,"source_hash":hash,"producer":producer,
                "anchor_line":anchor.line,"lines":lines}),
            );
            boundary(InspectionSetStage::Window(i + 1));
        }
        let reply = json!({"format":"threadmark-source-inspection-set","version":1,
            "project":p.id,"root_identity":p.root_identity,"incarnation":p.incarnation,
            "snapshot":p.snapshot,"radius":plan.radius,"currentness":"current-at-read",
            "inspections":inspections});
        if serde_json::to_vec(&reply).map_err(unavailable)?.len() + 1 > 8192 {
            return Err(invalid());
        }
        boundary(InspectionSetStage::Publication);
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
        // Validation only: never adopt a replacement capture for source access.
        self.query_project(&p.id, Some(&p))?;
        canceled(cancel)?;
        tx.commit().map_err(unavailable)?;
        canceled(cancel)?;
        Ok(reply)
    }
}

// Private deterministic test seams; never caller-controlled authority.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum InspectionSetStage {
    AllMembership,
    SourcesRead,
    Window(usize),
    Publication,
}

#[cfg(test)]
mod tests;
