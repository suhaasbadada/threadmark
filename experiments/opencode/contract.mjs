// Disposable offline model, NOT an installable OpenCode plugin or SDK shim.
import { isDeepStrictEqual } from 'node:util';

export const LIMITS = Object.freeze({
  inputBytes: 4096, outputBytes: 8192, contextBytes: 1024,
  prepareMs: 100, reviewMs: 100, admissionMs: 100, attachments: 4,
});
const copy = (value) => structuredClone(value);
const keys = (value, expected) => value && typeof value === 'object'
  && !Array.isArray(value)
  && isDeepStrictEqual(Object.keys(value).sort(), [...expected].sort());
const text = (value) => typeof value === 'string' && value.length > 0;
const bytes = (value) => Buffer.byteLength(JSON.stringify(value), 'utf8');

function validate(request, limit) {
  if (bytes(request) > limit
    || !keys(request, ['scope', 'sessionID', 'destination', 'delivery', 'prompt', 'constraints'])
    || !keys(request.scope, ['project', 'worktree', 'revision'])
    || !Object.values(request.scope).every(text)
    || !text(request.sessionID) || !text(request.destination)
    || !['steer', 'queue'].includes(request.delivery)
    || !keys(request.prompt, ['text', 'files', 'agents', 'skills'])
    || !text(request.prompt.text)
    || !Array.isArray(request.prompt.files) || request.prompt.files.length > LIMITS.attachments
    || !request.prompt.files.every((file) => keys(file, ['uri', 'mime']) && text(file.uri) && text(file.mime))
    || !Array.isArray(request.prompt.agents) || !request.prompt.agents.every(text)
    || !Array.isArray(request.prompt.skills) || !request.prompt.skills.every(text)
    || !Array.isArray(request.constraints) || !request.constraints.every(text)) {
    throw new Error('invalid bounded fixture');
  }
}

// Each injected operation gets a local signal. Non-cooperating late completions
// cannot continue this flow. This is not process containment or secure erasure.
async function bounded(operation, ms, signal) {
  const controller = new AbortController();
  let timer;
  let onAbort;
  try {
    return await Promise.race([
      new Promise((_, reject) => {
        onAbort = () => { controller.abort(); reject(new Error('canceled')); };
        signal.addEventListener('abort', onAbort, { once: true });
        timer = setTimeout(() => { controller.abort(); reject(new Error('timeout')); }, ms);
        if (signal.aborted) onAbort();
      }),
      Promise.resolve().then(() => {
        if (controller.signal.aborted) throw new Error('canceled');
        return operation(controller.signal);
      }),
    ]);
  } finally {
    clearTimeout(timer);
    signal.removeEventListener('abort', onAbort);
  }
}

// trustedScope and the review port are trusted test inputs, NOT authentication.
// One instance is one deliberate invocation. A fresh instance is NOT deduplicated.
export function createInvocation({ request, trustedScope, daemon, review, host, signal = new AbortController().signal }) {
  let original = copy(request);
  const scope = copy(trustedScope);
  let candidate;
  let running;
  let status = 'new';
  let attempts = 0;
  const receipt = () => Object.freeze({ status, attempts });
  const execute = async () => {
    try {
      validate(original, LIMITS.inputBytes);
      if (!isDeepStrictEqual(original.scope, scope)) throw new Error('scope mismatch');
      status = 'preparing';
      candidate = await bounded((localSignal) => daemon.prepare(copy(original), localSignal), LIMITS.prepareMs, signal);
      validate(candidate, LIMITS.outputBytes);
      const expected = copy(original);
      expected.prompt.text = candidate.prompt.text;
      if (!isDeepStrictEqual(candidate, expected)) throw new Error('binding mismatch');
      candidate = copy(candidate);
      status = 'reviewing';
      const approval = await bounded((localSignal) => review.open({
        original: copy(original), candidate: copy(candidate),
      }, localSignal), LIMITS.reviewMs, signal);
      if (!keys(approval, ['decision', 'candidate']) || approval.decision !== 'approve'
        || !isDeepStrictEqual(approval.candidate, candidate) || signal.aborted) {
        status = 'not-approved';
        return receipt();
      }
      // No await between the final approval/cancel check and the attempt latch.
      attempts = 1;
      status = 'unknown';
      try {
        const result = await bounded((localSignal) => host.admit(copy(candidate), localSignal), LIMITS.admissionMs, signal);
        // Abstract fixture acknowledgment, not a claim about SDK result shape.
        if (result?.admitted === true) status = 'acknowledged';
      } catch {
        // Timeout/cancel/disconnect may follow admission. Never retry or fall back.
      }
    } catch {
      status = 'blocked';
    } finally {
      original = undefined;
      candidate = undefined;
    }
    return receipt();
  };
  return {
    run() { running ??= execute(); return running; },
    receipt,
  };
}

// V2 registration shape, fake ctx only. capture is NOT a guessed SDK method.
export async function registerExperiment(ctx, capture, ports) {
  return ctx.command.transform((editor) => editor.add({
    name: 'threadmark-feasibility',
    description: 'Offline feasibility fixture only',
    execute: async (input) => {
      await createInvocation({ ...ports, request: capture(input) }).run();
    },
  }));
}

// Outgoing system array only. WeakSet ownership does not survive serialization;
// this is a runtime verification blocker, not an invented SDK metadata contract.
export function createContextExperiment({ scope, turn, evidence }) {
  if (!text(evidence) || Buffer.byteLength(evidence, 'utf8') > LIMITS.contextBytes) {
    throw new Error('invalid context fixture');
  }
  const binding = copy(scope);
  const owned = new WeakSet();
  return ({ enabled, currentScope, currentTurn, system }) => {
    const result = system.filter((part) => !owned.has(part));
    if (!enabled || currentTurn !== turn || !isDeepStrictEqual(binding, currentScope)) return result;
    const part = { type: 'text', text: evidence };
    owned.add(part);
    return [...result, part];
  };
}
