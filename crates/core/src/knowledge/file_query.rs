//! Explicit output candidates, never a reduced source authorization/freshness scope.
use super::*;

/// Closed, explicit lexical algorithm. Existing default operations do not use this API.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FileQueryMode {
    /// SQLite's existing ASCII-case-insensitive substring operation.
    Literal,
    /// Existing Unicode-lowercase whitespace any-term ranking.
    RankedAnyTerms,
}

/// Owned selection, validated against a complete captured Project before use.
#[derive(Clone, Debug)]
pub struct FileQuery {
    /// Exact query bytes, at most 256 UTF-8 bytes.
    pub query: String,
    /// Explicit selection algorithm.
    pub mode: FileQueryMode,
    /// Distinct exact approved paths; canonicalized to captured policy order.
    pub selected_paths: Vec<String>,
}

impl FileQuery {
    /// Pure pre-open validation; paths grant no new authority.
    pub fn validate(&self, expected: &Project) -> Result<()> {
        validate_query_binding(expected, &self.query)?;
        validate_paths(&self.selected_paths)?;
        if self.selected_paths.is_empty()
            || self
                .selected_paths
                .iter()
                .any(|p| !expected.sources.contains(p))
        {
            return Err(invalid());
        }
        if self.mode == FileQueryMode::RankedAnyTerms {
            validate_query_terms(&expected.id, &self.query)?;
        }
        Ok(())
    }

    pub(super) fn canonical(&self, expected: &Project) -> Result<Self> {
        self.validate(expected)?;
        Ok(Self {
            query: self.query.clone(),
            mode: self.mode,
            selected_paths: expected
                .sources
                .iter()
                .filter(|p| self.selected_paths.contains(p))
                .cloned()
                .collect(),
        })
    }
}

impl Store {
    /// Select output from exact approved files while retaining FULL-policy freshness.
    /// No unbound convenience form, indexing, discovery, writes or provider delivery.
    pub fn query_files_bound(
        &self,
        expected: &Project,
        request: &FileQuery,
        cancel: &AtomicBool,
    ) -> Result<Value> {
        let request = request.canonical(expected)?;
        self.query_selected_pipeline(
            &expected.id,
            &request.query,
            cancel,
            (Some(expected), Some(&request)),
            || {},
            || {},
        )
    }
}

#[cfg(test)]
mod tests;
