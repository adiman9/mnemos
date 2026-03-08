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

export function register(api) {
  api.registerHook(HOOK_EVENTS, handler, {
    name: 'mnemos-openclaw',
    description: '3-layer memory system - working memory capture, long-term knowledge curation, and cross-domain dream generation'
  });
  
  console.log('[mnemos] Plugin registered with events:', HOOK_EVENTS.join(', '));
}
