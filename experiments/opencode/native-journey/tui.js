import { Plugin } from '@opencode/plugin/tui';
import { Contract } from './rpc.js';

export default Plugin.define({
  id: 'threadmark-native-journey',
  async setup(ctx) {
    const rpc = ctx.client.rpc(Contract);
    const owner = globalThis.crypto.randomUUID();
    const controller = new AbortController();
    const location = ctx.location;
    let active;
    let disposed = false;
    const options = { location, signal: controller.signal };
    const destination = () => {
      const route = ctx.ui.router.current();
      return route.type === 'session' ? route.sessionID : undefined;
    };
    const review = async (sessionID) => {
      if (disposed || active || !location || destination() !== sessionID) return;
      // Latch before RPC: event and manual recovery cannot open two dialogs.
      active = { sessionID };
      try {
        const pending = await rpc.pending({ sessionID, owner }, options);
        if (!pending || disposed) return;
        const c = pending.candidate;
        const binding = { sessionID, candidateID: c.candidateID, digest: c.digest,
          owner, claim: pending.claim };
        active = binding;
        let approved = false;
        try {
          approved = await ctx.ui.dialog.confirm({
            title: 'Threadmark review — synthetic preparation only',
            message: `Admission only; agent loop stays stopped (resume=false).\nDestination / delivery / scope:\n${JSON.stringify({ sessionID, delivery: c.delivery, scope: c.scope })}`
              + `\n\nOriginal (unchanged):\n${c.original.text}`
              + `\n\nExact prepared text:\n${c.prepared.text}`
              + `\n\nExact attachment/agent/skill metadata:\n${JSON.stringify({ files: c.prepared.files, agents: c.prepared.agents, skills: c.prepared.skills })}`
              + `\n\nCandidate: ${c.candidateID}\nDigest: ${c.digest}`,
            label: { confirm: 'Approve once', cancel: 'Cancel' },
          }) === true;
        } finally {
          if (!disposed) {
            const result = await rpc.decide({ ...binding,
              decision: approved && destination() === sessionID ? 'approve' : 'cancel' }, options);
            ctx.ui.toast.show({ title: 'Threadmark inbox admission only',
              message: `${result.status}; attempts=${result.attempts}${result.receiptID ? `; receipt=${result.receiptID}` : ''}`,
              variant: result.status.startsWith('inbox-receipt') ? 'info' : 'warning' });
          }
        }
      } catch {
        if (!disposed) ctx.ui.toast.show({ message: 'Threadmark unavailable or outcome unknown. Do not retry; inspect inbox.', variant: 'warning' });
      } finally { active = undefined; }
    };
    const unsubscribe = rpc.events.on('reviewReady', (event) => {
      if (event.location?.directory === location?.directory) return review(event.data.sessionID);
    }, { signal: controller.signal });
    const cleanup = async () => {
      disposed = true;
      unsubscribe();
      controller.abort();
      if (active?.claim) {
        // Best effort only: server's 30-second expiry remains the disconnect gate.
        const cancel = new AbortController();
        const timer = setTimeout(() => cancel.abort(), 1000);
        try { await rpc.decide({ ...active, decision: 'cancel' }, { location, signal: cancel.signal }); }
        catch { /* A disconnected client cannot prove cancellation delivery. */ }
        finally { clearTimeout(timer); }
      }
    };
    try {
      // OpenCode owns layer lifecycle; deactivation removes its reactive owner.
      ctx.keymap.layer(() => ({ commands: [{ id: 'threadmark-review', title: 'Threadmark: review pending preparation',
        palette: true, slash: { name: 'threadmark-review' }, run: async () => {
          const sessionID = destination();
          if (sessionID) await review(sessionID);
        } }] }));
    } catch (error) { await cleanup(); throw error; }
    return cleanup;
  },
});
