import { Rpc } from '@opencode/plugin';

const str = { type: 'string', minLength: 1, maxLength: 256 };
const object = (properties) => ({ type: 'object', properties,
  required: Object.keys(properties), additionalProperties: false });
// Plain JSON Schema is a documented portable RPC contract, not an SDK shim.
export const Contract = Rpc.define({
  id: 'threadmark-native-journey',
  methods: {
    pending: { input: object({ sessionID: str, owner: str }), output: {} },
    decide: { input: object({ sessionID: str, candidateID: str, digest: str,
      owner: str, claim: str, decision: { enum: ['approve', 'cancel'] } }), output: {} },
  },
  events: { reviewReady: { schema: object({ candidateID: str, sessionID: str }) } },
});
