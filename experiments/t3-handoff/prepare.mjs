// Disposable offline experiment. No I/O, transport, logging, or retained state.
// Source evidence and deliberately narrower policy: docs/progress/phase-1-t3.md.
export const PROMPT_LINK_LIMIT = 8000; // JS string.length, before link normalization.
const TEXT_BUDGET = 65536;
const DESTINATION_BUDGET = 4096;
const COPIED_THREAD = /^https:\/\/app\.t3\.codes\/threads\/([A-Za-z0-9_%-]+)\/([A-Za-z0-9_%-]+)$/;
const BAD_ESCAPE = /%(?![0-9A-Fa-f]{2})/;

export function parseDestination(value) {
  if (typeof value !== 'string' || value.length > DESTINATION_BUDGET) return null;
  // Match the raw string, not URL's permissive normalization of credentials,
  // whitespace, backslashes, dot segments, empty query strings or fragments.
  const match = COPIED_THREAD.exec(value);
  if (!match || match[0] !== value || BAD_ESCAPE.test(value)) return null;
  try {
    const ids = match.slice(1).map(decodeURIComponent); // Exactly once.
    // Deliberately narrower than the host: no blank/control/ambiguous dot IDs.
    if (ids.some(id => !id || id.trim() !== id || /^[.]{1,2}$/.test(id) ||
      /[\u0000-\u0020\u007f-\u009f\u200b-\u200f\u2028-\u202e\u2060-\u206f\ufeff]/u.test(id))) return null;
    return Object.freeze({ environmentId: ids[0], threadId: ids[1] });
  } catch {
    return null; // Never include the rejected input in diagnostics.
  }
}

// Derived from T3 Tools Inc.'s pinned promptLinks.ts normalization rules;
// see THIRD_PARTY_NOTICES.md. Change detection only, never substituted output.
function promptLinkWouldChange(text) {
  const hidden = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F\u00AD\u034F\u061C\u115F\u1160\u17B4\u17B5\u180B-\u180F\u200B\u200C\u200E\u200F\u202A-\u202E\u2060-\u206F\u3164\uFE00-\uFE0D\uFEFF\uFFA0\uFFF0-\uFFFB\u{1BCA0}-\u{1BCA3}\u{1D173}-\u{1D17A}\u{E0000}-\u{E0FFF}]/gu;
  const visible = Array.from(text.replace(/\r\n?|[\u2028\u2029]/g, '\n').replace(hidden, ''));
  const emojiPart = c => c !== undefined && ((c >= 0x1f000 && c <= 0x1faff) ||
    (c >= 0x2190 && c <= 0x2bff) || c === 0xfe0f);
  const normalized = visible.filter((c, i) => c !== '\u200d' ||
    (emojiPart(visible[i - 1]?.codePointAt(0)) && emojiPart(visible[i + 1]?.codePointAt(0))))
    .join('').trim();
  return normalized !== text;
}

/** Review is a synthetic caller fixture, not authenticated consent or a UI. */
export function prepareCopy(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input))
    return { status: 'rejected', reason: 'input' };
  if (input.cancelled === true) return { status: 'cancelled' };
  const { destination, content, review } = input;
  const target = parseDestination(destination);
  if (!target) return { status: 'rejected', reason: 'destination' };
  if (typeof content !== 'string' || !content.length || content.length > TEXT_BUDGET ||
    !content.trim().length) return { status: 'rejected', reason: 'content-budget-or-empty' };
  // encodeURIComponent rejects unpaired surrogates; do not replace them with U+FFFD.
  try { encodeURIComponent(content); } catch {
    return { status: 'rejected', reason: 'invalid-unicode' };
  }
  if (review?.decision !== 'copy' || review.destination !== destination || review.content !== content)
    return { status: 'needs-review', reason: 'exact-content-and-destination' };
  if (promptLinkWouldChange(content)) return { status: 'needs-review', reason: 'prompt-link-normalization' };
  return {
    status: 'copy-only',
    reason: content.length > PROMPT_LINK_LIMIT ? 'prompt-link-limit' : 'local-uri-unsupported',
    target,
    copyText: content, // Ephemeral payload, not a diagnostic or receipt. Never print.
  };
}

/** No acknowledgment can enable transport or trigger retry in this component. */
export function runtimeGate(_untrustedAcknowledgment) {
  return { status: 'unsupported', retry: false };
}
