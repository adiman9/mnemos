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
const MAINTENANCE_CHECK_MS = 60 * 60 * 1000; // 1 hour

const HOURLY_SKILLS = '/ingest';
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

function shouldRunDaily(lastDaily) {
  const now = new Date();
  const hour = now.getHours();
  if (hour !== 9) return false; // Only run at 9am local time
  if (lastDaily && (now - lastDaily) < 23 * 60 * 60 * 1000) return false; // Not within 23h of last run
  return true;
}

function shouldRunWeekly(lastWeekly) {
  const now = new Date();
  const day = now.getDay();
  const hour = now.getHours();
  if (day !== 0 || hour !== 3) return false; // Only run Sunday 3am local time
  if (lastWeekly && (now - lastWeekly) < 6 * 24 * 60 * 60 * 1000) return false; // Not within 6 days of last run
  return true;
}

function shouldRunHourly(lastHourly) {
  if (!lastHourly) return true;
  const now = new Date();
  return (now - lastHourly) >= 55 * 60 * 1000; // At least 55 mins since last run
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
    id: 'mnemos-maintenance-scheduler',
    start: (ctx) => {
      console.log('[mnemos] Starting maintenance scheduler (hourly queue processing, daily@9am, weekly@Sun 3am local time)');
      
      let lastHourly = null;
      let lastDaily = null;
      let lastWeekly = null;
      
      const checkMaintenance = () => {
        if (shouldRunHourly(lastHourly)) {
          lastHourly = new Date();
          runSkills(HOURLY_SKILLS, 'hourly queue processing');
        }
        if (shouldRunDaily(lastDaily)) {
          lastDaily = new Date();
          runSkills(DAILY_SKILLS, 'daily maintenance');
        }
        if (shouldRunWeekly(lastWeekly)) {
          lastWeekly = new Date();
          runSkills(WEEKLY_SKILLS, 'weekly maintenance');
        }
      };
      
      ctx._maintenanceTimer = setInterval(checkMaintenance, MAINTENANCE_CHECK_MS);
    },
    stop: (ctx) => {
      if (ctx._maintenanceTimer) {
        clearInterval(ctx._maintenanceTimer);
        console.log('[mnemos] Maintenance scheduler stopped');
      }
    }
  });
  
  console.log('[mnemos] Plugin registered with events:', HOOK_EVENTS.join(', '));
}
