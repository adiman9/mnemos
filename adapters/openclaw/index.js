/**
 * mnemos OpenClaw Plugin Entry Point
 * 
 * Registers hooks at runtime so `openclaw plugins install` handles everything.
 * No separate `openclaw hooks install` needed.
 */

import { execSync } from 'child_process';
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
const DAILY_INTERVAL_MS = 24 * 60 * 60 * 1000; // 24 hours
const WEEKLY_INTERVAL_MS = 7 * 24 * 60 * 60 * 1000; // 7 days

const DAILY_SKILLS = '/observe && /consolidate && /dream --daily && /curiosity && /stats';
const WEEKLY_SKILLS = '/dream --weekly && /graph health && /validate all && /rethink';

function runSkills(skills, label) {
  try {
    console.log(`[mnemos] Running ${label}: ${skills}`);
    execSync(`openclaw message send --session isolated --no-deliver --message "${skills}"`, {
      stdio: 'pipe',
      timeout: 10 * 60 * 1000 // 10 minute timeout
    });
    console.log(`[mnemos] ${label} completed`);
  } catch (err) {
    console.error(`[mnemos] ${label} failed:`, err.message);
  }
}

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

  api.registerService({
    id: 'mnemos-daily-maintenance',
    start: (ctx) => {
      console.log('[mnemos] Starting daily maintenance scheduler (interval: 24h)');
      ctx._dailyTimer = setInterval(() => runSkills(DAILY_SKILLS, 'daily maintenance'), DAILY_INTERVAL_MS);
    },
    stop: (ctx) => {
      if (ctx._dailyTimer) {
        clearInterval(ctx._dailyTimer);
        console.log('[mnemos] Daily maintenance scheduler stopped');
      }
    }
  });

  api.registerService({
    id: 'mnemos-weekly-maintenance',
    start: (ctx) => {
      console.log('[mnemos] Starting weekly maintenance scheduler (interval: 7d)');
      ctx._weeklyTimer = setInterval(() => runSkills(WEEKLY_SKILLS, 'weekly maintenance'), WEEKLY_INTERVAL_MS);
    },
    stop: (ctx) => {
      if (ctx._weeklyTimer) {
        clearInterval(ctx._weeklyTimer);
        console.log('[mnemos] Weekly maintenance scheduler stopped');
      }
    }
  });
  
  console.log('[mnemos] Plugin registered with events:', HOOK_EVENTS.join(', '));
}
