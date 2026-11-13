//! Bounded, memory-only preparation, review and handoff values; never delivery.
//!
//! The host supplies a trusted [`EvidenceAuthority`] backed by core authorization
//! and currentness checks, plus explicit [`ProviderAccess`] for Refine. Caller IDs
//! and source text are never authorization. There is no concrete inference client,
//! credential discovery, persistence, logging, network or host transport here.
//!
//! Providers are cooperative: cancellation/deadline are supplied and results are
//! checked again on return. This synchronous library cannot interrupt or bound the
//! wall time/memory allocation of an arbitrary blocking provider. Run untrusted
//! implementations behind a host-owned bounded execution boundary.
//!
//! # Context integration
//!
//! The coordinator implements the trusted core port. This example adds no fake
//! authority or provider and invokes no host transport:
//!
//! ```
//! use std::time::{Duration, Instant};
//! use threadmark_refinement::*;
//!
//! fn reviewed_context(request: Request, core: &dyn EvidenceAuthority)
//!     -> Result<Handoff, Error>
//! {
//!     assert_eq!(request.data().mode, Mode::Context);
//!     let control = Control::new(Instant::now() + Duration::from_secs(30));
//!     let mut engine = Engine::new(request, control);
//!     engine.prepare(core, None)?; // No inference configuration needed.
//!     let preview = engine.preview()?; // Present original/proposed to the user.
//!     // Only after the user explicitly chooses Apply:
//!     let approval = engine.approve(ReviewChoice::UsePrepared, core)?;
//!     engine.handoff(&approval, core) // Delivery::NotAttempted, not a send.
//! }
//! ```
//!
//! For Refine, supply `Some(ProviderAccess { provider, consent })` to `prepare`.
//! Consent binds the exact frozen request, profile/model/endpoint/locality, selected
//! data scope, monotonic deadline, total call count and output budget. Use
//! [`Engine::edit`] for a validated brief edit and approve again afterwards. Use
//! [`ReviewChoice::UseOriginal`] explicitly after failure; never silently fall back.
//! Call [`Control::supersede`] on the old operation before starting a replacement.
//! Public DTOs contain private user data: hosts must not log/persist their Debug
//! output. Source strings must be displayed as plain escaped text, never HTML.

mod engine;
mod model;

pub use engine::*;
pub use model::*;
