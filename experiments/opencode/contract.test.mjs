import test from 'node:test';
import assert from 'node:assert/strict';
import { createInvocation, createContextExperiment, registerExperiment, LIMITS } from './contract.mjs';

// All identities, drafts, attachment descriptors and acknowledgments are synthetic.
const fixture = () => ({
  scope: { project: 'fixture-project', worktree: 'fixture-worktree', revision: 'fixture-revision' },
  sessionID: 'fixture-session', destination: 'fixture-terminal', delivery: 'queue',
  prompt: {
    text: 'Describe the synthetic widget.',
    files: [{ uri: 'fixture:widget', mime: 'text/plain' }],
    agents: ['fixture-agent'], skills: ['fixture-skill'],
  },
  constraints: ['No execution'],
});
const clone = (x) => structuredClone(x);
const deferred = () => {
  let resolve;
  const promise = new Promise((done) => { resolve = done; });
  return { promise, resolve };
};
const never = () => new Promise(() => {});
const approve = ({ candidate }) => ({ decision: 'approve', candidate });

function harness(overrides = {}) {
  const request = fixture();
  const calls = [];
  const controller = new AbortController();
  const ports = {
    request, trustedScope: clone(request.scope), signal: controller.signal,
    daemon: { async prepare(input) {
      calls.push('prepare');
      input.prompt.text = 'Describe only the synthetic widget interface.';
      return input;
    } },
    review: { async open(input) { calls.push('review'); return approve(input); } },
    host: { async admit(input) { calls.push({ admission: input }); return { admitted: true }; } },
    ...overrides,
  };
  return { ports, calls, controller, invocation: createInvocation(ports) };
}
const admissions = (h) => h.calls.filter((x) => typeof x === 'object');
const zero = (h) => assert.equal(admissions(h).length, 0);

test('P1-A2: fake registration adds a command without admission; executor captures V2 inputs', async () => {
  let definition;
  const h = harness();
  const input = { sessionID: h.ports.request.sessionID, prompt: h.ports.request.prompt, delivery: 'queue' };
  const registration = { dispose() {} };
  const result = await registerExperiment({ command: { transform(fn) {
    fn({ add(value) { definition = value; } });
    return registration;
  } } }, (actual) => {
    assert.equal(actual, input);
    return { ...fixture(), ...actual };
  }, h.ports);
  assert.equal(result, registration);
  zero(h);
  await definition.execute(input);
  assert.equal(admissions(h).length, 1);
});

for (const delivery of ['queue', 'steer']) {
  test(`P1-A2: zero before matching approval; preserve every binding (${delivery})`, async () => {
    const entered = deferred();
    const answer = deferred();
    const request = fixture();
    request.delivery = delivery;
    let shown;
    const h = harness({ request, review: { open(input) {
      shown = input;
      entered.resolve();
      return answer.promise;
    } } });
    const before = clone(request);
    zero(h);
    const first = h.invocation.run();
    assert.equal(h.invocation.run(), first, 'duplicate continuation shares the pending run');
    await entered.promise;
    zero(h);
    assert.equal(h.invocation.receipt().status, 'reviewing');
    answer.resolve(approve(shown));
    assert.deepEqual(await first, { status: 'acknowledged', attempts: 1 });
    await h.invocation.run();
    assert.equal(admissions(h).length, 1);
    const expected = clone(before);
    expected.prompt.text = shown.candidate.prompt.text;
    assert.deepEqual(admissions(h)[0].admission, expected);
    assert.deepEqual(request, before, 'capture and persisted fixture not mutated');
    assert.deepEqual(Object.keys(h.invocation.receipt()).sort(), ['attempts', 'status']);
  });
}

for (const decision of ['cancel', 'closed', 'disconnected', undefined]) {
  test(`P1-A2: review ${decision} never approves`, async () => {
    const h = harness({ review: { open: ({ candidate }) => ({ decision, candidate }) } });
    assert.equal((await h.invocation.run()).attempts, 0);
    zero(h);
  });
}

for (const field of ['scope', 'sessionID', 'destination', 'delivery', 'constraints', 'files', 'agents', 'skills', 'text']) {
  test(`P1-A2: approval mismatch in ${field} blocks admission`, async () => {
    const h = harness({ review: { open({ candidate }) {
      if (['files', 'agents', 'skills'].includes(field)) candidate.prompt[field] = [];
      else if (field === 'text') candidate.prompt.text += ' changed';
      else candidate[field] = 'changed';
      return { decision: 'approve', candidate };
    } } });
    assert.equal((await h.invocation.run()).attempts, 0);
    zero(h);
  });
}

for (const field of ['scope', 'sessionID', 'destination', 'delivery', 'constraints', 'files', 'agents', 'skills']) {
  test(`P1-A2: daemon may not change ${field}`, async () => {
    let reviewed = false;
    const h = harness({ daemon: { prepare(input) {
      if (['files', 'agents', 'skills'].includes(field)) input.prompt[field] = [];
      else input[field] = 'changed';
      return input;
    } }, review: { open() { reviewed = true; } } });
    assert.equal((await h.invocation.run()).status, 'blocked');
    assert.equal(reviewed, false);
    zero(h);
  });
}

test('P1-A2: input scope is checked before preparation', async () => {
  const h = harness({ trustedScope: { ...fixture().scope, revision: 'other' } });
  assert.equal((await h.invocation.run()).status, 'blocked');
  assert.deepEqual(h.calls, []);
});

for (const bad of [null, {}, { prompt: 'malformed' }, 'unexpected', undefined]) {
  test(`P1-A2: malformed daemon response (${JSON.stringify(bad)})`, async () => {
    const h = harness({ daemon: { prepare: () => bad } });
    assert.equal((await h.invocation.run()).status, 'blocked');
    zero(h);
  });
}

test('P1-A5: limits reject oversized UTF-8 input/output and unsupported mention metadata', async () => {
  for (const kind of ['input', 'output', 'mention', 'attachments']) {
    const request = fixture();
    if (kind === 'input') request.prompt.text = '界'.repeat(LIMITS.inputBytes / 2);
    if (kind === 'mention') request.prompt.files[0].mention = { start: 0, end: 4 };
    if (kind === 'attachments') request.prompt.files = Array(5).fill(request.prompt.files[0]);
    const h = harness({ request, daemon: { prepare(input) {
      input.prompt.text = '界'.repeat(LIMITS.outputBytes / 2);
      return input;
    } } });
    assert.equal((await h.invocation.run()).status, 'blocked');
    zero(h);
  }
});

test('P1-A5: exact byte limits are inclusive; one byte beyond is blocked', async () => {
  const size = (x) => Buffer.byteLength(JSON.stringify(x), 'utf8');
  for (const extra of [0, 1]) {
    const request = fixture();
    request.prompt.text += 'x'.repeat(LIMITS.inputBytes - size(request) + extra);
    const h = harness({ request });
    assert.equal((await h.invocation.run()).attempts, extra === 0 ? 1 : 0);
    if (extra) zero(h);
    const output = harness({ daemon: { prepare(input) {
      input.prompt.text += 'x'.repeat(LIMITS.outputBytes - size(input) + extra);
      return input;
    } } });
    assert.equal((await output.invocation.run()).attempts, extra === 0 ? 1 : 0);
    if (extra) zero(output);
  }
  assert.doesNotThrow(() => createContextExperiment({ scope: fixture().scope, turn: 'turn', evidence: 'x'.repeat(LIMITS.contextBytes) }));
  assert.throws(() => createContextExperiment({ scope: fixture().scope, turn: 'turn', evidence: 'x'.repeat(LIMITS.contextBytes + 1) }));
});

test('P1-A2: cyclic and non-JSON daemon output fail closed without logging content', async () => {
  for (const kind of ['cycle', 'bigint', 'extra-field']) {
    const h = harness({ daemon: { prepare(input) {
      if (kind === 'cycle') input.cycle = input;
      if (kind === 'bigint') input.extra = 1n;
      if (kind === 'extra-field') input.extra = 'unexpected';
      return input;
    } } });
    assert.deepEqual(await h.invocation.run(), { status: 'blocked', attempts: 0 });
    zero(h);
  }
});

for (const stage of ['prepare', 'review']) {
  for (const failure of ['unavailable', 'timeout', 'canceled']) {
    test(`P1-A2: ${stage} ${failure}: zero sends, no fallback`, async () => {
      const entered = deferred();
      let localSignal;
      const operation = (_input, signal) => {
        localSignal = signal;
        entered.resolve();
        if (failure === 'unavailable') throw new Error('fixture unavailable');
        return never();
      };
      const h = harness(stage === 'prepare' ? { daemon: { prepare: operation } } : { review: { open: operation } });
      const pending = h.invocation.run();
      await entered.promise;
      if (failure === 'canceled') h.controller.abort();
      assert.equal((await pending).attempts, 0);
      if (failure !== 'unavailable') assert.equal(localSignal.aborted, true);
      zero(h);
    });
  }
}

test('P1-A2: late review approval after cancellation cannot admit', async () => {
  const entered = deferred();
  const answer = deferred();
  let shown;
  const h = harness({ review: { open(input) { shown = input; entered.resolve(); return answer.promise; } } });
  const pending = h.invocation.run();
  await entered.promise;
  h.controller.abort();
  assert.equal((await pending).attempts, 0);
  answer.resolve(approve(shown));
  await Promise.resolve();
  await h.invocation.run();
  zero(h);
});

test('P1-A2: pre-canceled invocation never prepares', async () => {
  const h = harness();
  h.controller.abort();
  await h.invocation.run();
  assert.deepEqual(h.calls, []);
});

for (const failure of ['disconnect', 'timeout', 'unrecognized-ack', 'cancel']) {
  test(`P1-A2: unknown admission (${failure}) never blindly retried`, async () => {
    let count = 0;
    const entered = deferred();
    const h = harness({ host: { admit() {
      count++;
      entered.resolve();
      if (failure === 'disconnect') throw new Error('ack lost');
      if (failure === 'unrecognized-ack') return {};
      return never();
    } } });
    const pending = h.invocation.run();
    await entered.promise;
    if (failure === 'cancel') h.controller.abort();
    assert.deepEqual(await pending, { status: 'unknown', attempts: 1 });
    await h.invocation.run();
    assert.equal(count, 1);
  });
}

test('P1-A2: dependency recovery requires a fresh deliberate invocation and approval', async () => {
  const failed = harness({ daemon: { prepare() { throw new Error('offline'); } } });
  await failed.invocation.run();
  zero(failed);
  const recovered = harness();
  assert.equal((await recovered.invocation.run()).status, 'acknowledged');
  assert.equal(admissions(recovered).length, 1);
});

test('P1-A2/P1-A5: opt-in context is snapshot-local, owner-only, turn/scope bound on tool continuations', () => {
  const request = fixture();
  const persisted = clone(request);
  const permissions = [{ action: 'edit', effect: 'deny' }];
  const permissionBefore = clone(permissions);
  const foreign = { type: 'text', text: 'synthetic evidence' };
  const hook = createContextExperiment({ scope: request.scope, turn: 'fixture-turn', evidence: foreign.text });
  const call = (system, extra = {}) => hook({ enabled: true, currentScope: request.scope, currentTurn: 'fixture-turn', system, ...extra });
  const first = call([foreign]);
  assert.equal(first.length, 2, 'identical foreign content must not be deduplicated');
  const repeated = call(first);
  assert.equal(repeated.length, 2);
  assert.equal(repeated[0], foreign);
  const continuation = call([foreign, { type: 'text', text: 'fixture tool result' }]);
  assert.equal(continuation.length, 3, 'fresh tool continuation gets its own evidence');
  assert.deepEqual(call(first, { enabled: false }), [foreign]);
  assert.deepEqual(call(first, { currentTurn: 'different-turn' }), [foreign]);
  assert.deepEqual(call(first, { currentScope: { ...request.scope, revision: 'other' } }), [foreign]);
  assert.deepEqual(request, persisted);
  assert.deepEqual(permissions, permissionBefore);
  assert.equal(first.length, 2, 'input snapshot unchanged');
  assert.throws(() => createContextExperiment({ scope: request.scope, turn: 'fixture-turn', evidence: '界'.repeat(1024) }));
});

test('P1-A5: serialized owned context is an explicit unsupported boundary, not exactly-once evidence', () => {
  const request = fixture();
  const hook = createContextExperiment({ scope: request.scope, turn: 'turn', evidence: 'fixture evidence' });
  const input = { enabled: true, currentScope: request.scope, currentTurn: 'turn', system: [] };
  const first = hook(input);
  assert.equal(hook({ ...input, system: clone(first) }).length, 2,
    'ownership cannot be inferred from matching text; runtime must establish snapshot identity');
});
