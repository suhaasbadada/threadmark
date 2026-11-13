import { Plugin } from '@opencode/plugin';
import { Contract } from './rpc.js';
import { createJourney } from './kernel.js';

export default Plugin.define({
  id: 'threadmark-native-journey',
  async setup(ctx) {
    let rpc;
    const journey = createJourney({
      scope: { directory: ctx.location.directory, projectID: ctx.location.project.id,
        ...(ctx.location.workspaceID ? { workspaceID: ctx.location.workspaceID } : {}) },
      prompt: (input) => ctx.session.prompt(input),
      notify: (data) => rpc.events.emit('reviewReady', data),
    });
    let command;
    try {
      rpc = await ctx.rpc.register(Contract, {
        pending: async (input, context) => journey.pending(input, context.signal),
        decide: async (input, context) => journey.decide(input, context.signal),
      });
      command = await ctx.command.transform((editor) => editor.add({
        name: 'threadmark-refine',
        description: 'Review bounded synthetic preparation; no inference',
        execute: async (input) => { await journey.run(input); },
      }));
    } catch (error) {
      journey.dispose();
      await rpc?.dispose();
      throw error;
    }
    return async () => {
      journey.dispose();
      await Promise.allSettled([command.dispose(), rpc.dispose()]);
    };
  },
});
