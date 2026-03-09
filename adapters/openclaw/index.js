/**
 * mnemos OpenClaw Plugin Entry Point
 * 
 * Registers hooks at runtime so `openclaw plugins install` handles everything.
 * No separate `openclaw hooks install` needed.
 */

import handler from './hooks/mnemos-openclaw/handler.js';

const HOOK_EVENTS = [
  'gateway:startup',
  'gateway:heartbeat',
  'message:received', 
  'message:sent',
  'session:start',
  'command:new',
  'agent:bootstrap',
  'session:compact:before'
];

const SYNC_INTERVAL_MS = 5 * 60 * 1000; // 5 minutes

export function register(api) {
  api.registerHook(HOOK_EVENTS, handler, {
    name: 'mnemos-openclaw',
    description: '3-layer memory system - working memory capture, long-term knowledge curation, and cross-domain dream generation'
  });
  
  api.registerService({
    id: 'mnemos-sync-worker',
    start: (ctx) => {
      console.log('[mnemos] Starting background sync worker (interval: 5m)');
      
      const runSync = async () => {
        try {
          await handler({ type: 'gateway:heartbeat' });
        } catch (err) {
          console.error('[mnemos] Background sync failed:', err.message);
        }
      };
      
      runSync();
      ctx._mnemosTimer = setInterval(runSync, SYNC_INTERVAL_MS);
    },
    stop: (ctx) => {
      if (ctx._mnemosTimer) {
        clearInterval(ctx._mnemosTimer);
        console.log('[mnemos] Background sync worker stopped');
      }
    }
  });
  
  console.log('[mnemos] Plugin registered with events:', HOOK_EVENTS.join(', '));
}
