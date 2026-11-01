import { createHandler } from './worker.ts';

// The endpoint authenticates the Vault dispatch capability before any work.
Deno.serve(createHandler({ env: name => Deno.env.get(name), fetch }));
