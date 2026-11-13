// Pure bounded orchestration. No host imports, inference, filesystem or network.
import { createHash, randomUUID } from 'node:crypto';
import { isDeepStrictEqual } from 'node:util';

export const REVIEW_MS = 30_000;
const suffix = '\n\n[Threadmark synthetic preparation — not inference]\n'
  + 'Carry out the original request above without changing its constraints or scope.';
const object = (x) => x !== null && typeof x === 'object' && !Array.isArray(x);
const fields = (x, required, optional = []) => object(x)
  && required.every((k) => Object.hasOwn(x, k))
  && Object.keys(x).every((k) => [...required, ...optional].includes(k));
const small = (x) => typeof x === 'string' && x.length > 0 && x.length <= 256;
const freeze = (x) => {
  if (object(x) || Array.isArray(x)) { Object.values(x).forEach(freeze); Object.freeze(x); }
  return x;
};
export function stableJSON(x) {
  if (Array.isArray(x)) return `[${x.map(stableJSON).join(',')}]`;
  if (object(x)) return `{${Object.keys(x).sort().map((k) => `${JSON.stringify(k)}:${stableJSON(x[k])}`).join(',')}}`;
  return JSON.stringify(x);
}
const digest = (x) => createHash('sha256').update(stableJSON(x)).digest('hex');
const reject = () => { throw new Error('Threadmark: unsupported bounded input'); };

function validate(input, scope) {
  const jsonOnly = (x) => x !== undefined && (Array.isArray(x)
    ? x.every(jsonOnly) : object(x) ? Object.values(x).every(jsonOnly) : true);
  if (!jsonOnly(input) || !jsonOnly(scope)) reject();
  if (!fields(input, ['sessionID', 'prompt', 'delivery']) || !small(input.sessionID)
    || !['steer', 'queue'].includes(input.delivery)
    || !fields(scope, ['directory', 'projectID'], ['workspaceID', 'branch', 'revision'])
    || !Object.values(scope).every(small)) reject();
  const p = input.prompt;
  if (!fields(p, ['text'], ['files', 'agents', 'skills']) || typeof p.text !== 'string'
    || !p.text.trim() || Buffer.byteLength(p.text, 'utf8') > 2048) reject();
  const mention = (m) => m === undefined || (fields(m, ['start', 'end', 'text'])
    && Number.isInteger(m.start) && Number.isInteger(m.end) && m.start >= 0
    && m.end > m.start && m.end <= p.text.length && small(m.text)
    && p.text.slice(m.start, m.end) === m.text);
  for (const [key, required, optional] of [
    ['files', ['uri'], ['source', 'name', 'description', 'mention']],
    ['agents', ['name'], ['mention']], ['skills', ['id'], ['mention']],
  ]) {
    if (p[key] === undefined && !Object.hasOwn(p, key)) continue;
    if (!Array.isArray(p[key]) || p[key].length > 4) reject();
    for (const item of p[key]) {
      if (!fields(item, required, optional) || !mention(item.mention)) reject();
      for (const [k, v] of Object.entries(item)) {
        if (!['mention', 'source'].includes(k) && !small(v)) reject();
      }
      // This spike never asks the host to fetch a URL or read a private file.
      // Inline synthetic text only; unsupported attachments fail, never disappear.
      if (key === 'files' && (!/^data:text\/plain(?:;base64)?,[\x20-\x7e]*$/.test(item.uri)
        || (Object.hasOwn(item, 'source') && !(fields(item.source, ['type'])
          && item.source.type === 'inline')))) reject();
    }
  }
  if (Buffer.byteLength(stableJSON(input), 'utf8') > 6144) reject();
}

export function prepare(input, scope) {
  validate(input, scope);
  const original = structuredClone(input);
  // Append, do not prepend: host mention offsets remain exactly valid.
  const prompt = { ...original.prompt, text: original.prompt.text + suffix };
  const binding = { scope: structuredClone(scope), sessionID: original.sessionID,
    delivery: original.delivery, resume: false, original: original.prompt, prepared: prompt };
  return freeze({ ...binding, candidateID: randomUUID(), digest: digest(binding) });
}

// IDs/owner/claim are correlation only, NOT authentication. Host-authenticated,
// location-scoped RPC is the trust boundary. One TUI claims a candidate once.
export function createJourney({ scope, prompt, notify, reviewMs = REVIEW_MS }) {
  const sessions = new Map();
  let disposed = false;
  const summary = (e) => ({ status: e.status, attempts: e.attempts,
    ...(e.receiptID ? { receiptID: e.receiptID } : {}) });
  const finish = (e, status) => {
    if (e.done) return;
    e.done = true; e.status = status; clearTimeout(e.timer);
    e.candidate = undefined; e.resolve(summary(e));
    if (status !== 'unknown') sessions.delete(e.sessionID);
  };
  const matches = (e, x) => e?.candidate && x.candidateID === e.candidate.candidateID
    && x.digest === e.candidate.digest && x.owner === e.owner && x.claim === e.claim;
  return {
    async run(input) {
      if (disposed || sessions.has(input.sessionID) || sessions.size >= 32) return { status: 'blocked', attempts: 0 };
      const candidate = prepare(input, scope);
      let resolve;
      const result = new Promise((r) => { resolve = r; });
      const e = { sessionID: input.sessionID, candidate, resolve, result, attempts: 0, status: 'reviewing', done: false };
      sessions.set(input.sessionID, e);
      e.timer = setTimeout(() => finish(e, e.attempts ? 'unknown' : 'expired'), reviewMs);
      // Notification is a hint, never a send. Manual review recovers a missed event.
      Promise.resolve().then(() => notify({ candidateID: candidate.candidateID,
        sessionID: candidate.sessionID })).catch(() => finish(e, e.attempts ? 'unknown' : 'unavailable'));
      return result;
    },
    pending(x, signal) {
      if (!fields(x, ['sessionID', 'owner']) || !small(x.owner) || signal?.aborted || disposed) return null;
      const e = sessions.get(x.sessionID);
      if (!e || e.status !== 'reviewing' || (e.owner && e.owner !== x.owner)) return null;
      e.owner ??= x.owner; e.claim ??= randomUUID();
      return { candidate: structuredClone(e.candidate), owner: e.owner, claim: e.claim };
    },
    async decide(x, signal) {
      if (!fields(x, ['sessionID', 'candidateID', 'digest', 'owner', 'claim', 'decision'])
        || !['approve', 'cancel'].includes(x.decision)) return { status: 'rejected', attempts: 0 };
      const e = sessions.get(x.sessionID);
      if (disposed || !matches(e, x) || e.status !== 'reviewing') return { status: 'rejected', attempts: 0 };
      if (signal?.aborted || x.decision !== 'approve') {
        finish(e, 'canceled'); return summary(e);
      }
      // No await between approval, cancellation check and irreversible latch.
      e.attempts = 1; e.status = 'unknown';
      const c = e.candidate;
      // Return the same bounded waiter even if the host prompt promise hangs.
      void (async () => { try {
        // Documented admission-only path: never schedule the agent loop in this spike.
        const receipt = await prompt({ ...structuredClone(c.prepared), sessionID: c.sessionID,
          delivery: c.delivery, resume: false });
        if (!e.done && receipt?.type === 'user' && small(receipt.id)
          && receipt.sessionID === c.sessionID && receipt.delivery === c.delivery
          && receipt.payload?.text === c.prepared.text
          && isDeepStrictEqual(receipt.payload.agents, c.prepared.agents)
          && isDeepStrictEqual(receipt.payload.skills?.map(({ id, mention }) => ({ id, ...(mention ? { mention } : {}) })),
            c.prepared.skills)
          && (c.prepared.files?.length || !receipt.payload.files?.length)) {
          // Files are resolved by OpenCode; never claim byte equivalence from metadata.
          e.receiptID = receipt.id;
          finish(e, c.prepared.skills?.length ? 'inbox-receipt-attachments-unverified'
            : c.prepared.files?.length ? 'inbox-receipt-files-unverified' : 'inbox-receipt');
        } else finish(e, 'unknown');
      } catch { finish(e, 'unknown'); } })(); // Ambiguous admission: NEVER retry.
      return e.result;
    },
    dispose() {
      disposed = true;
      for (const e of sessions.values()) finish(e, e.attempts ? 'unknown' : 'unloaded');
      sessions.clear();
    },
  };
}
