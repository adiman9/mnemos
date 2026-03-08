/**
 * mnemos OpenClaw Hook Pack — Event Router
 *
 * Routes OpenClaw hook events to mnemos memory operations.
 *
 * Events handled:
 *   gateway:startup        → session-start.sh (session init, boot context injection)
 *   message:received       → Inline capture (inbound user message)
 *   message:sent           → Inline capture (outbound assistant message)
 *   agent:bootstrap        → session-start.sh (session init equivalent)
 *   command:new            → session-capture.sh (pre-reset checkpoint)
 *   session:compact:before → pre-compact.sh (safety flush before compaction)
 *
 * Message events use inline capture to avoid script path resolution issues
 * when installed as a managed hook (scripts aren't bundled in ~/.openclaw/hooks/).
 */

'use strict';

const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

const MAX_CONTENT_LENGTH = 2000;
const DEBUG = process.env.MNEMOS_DEBUG === '1';

function debug(...args) {
  if (DEBUG) {
    console.log('[mnemos:debug]', ...args);
  }
}

/**
 * Match an event against a type/action pair.
 * Handles BOTH payload formats OpenClaw may emit:
 *   1. Object format:  { type: "message", action: "received" }
 *   2. Colon-joined:   { type: "message:received" }
 */
function eventMatches(event, type, action) {
  if (event.type === type && event.action === action) return true;
  if (event.type === `${type}:${action}`) return true;
  return false;
}

/**
 * Resolve the vault path from the event context, environment, or default.
 */
function resolveVaultPath(event) {
  const cfg = event.context?.cfg ?? {};
  const pluginId = 'mnemos';

  const fromEntries =
    cfg.plugins?.entries?.[pluginId]?.config?.vaultPath ||
    cfg.plugins?.entries?.[pluginId]?.vaultPath;

  const fromLegacy =
    cfg.plugins?.[pluginId]?.config?.vaultPath ||
    cfg.plugins?.[pluginId]?.vaultPath;

  const fromEnv = process.env.MNEMOS_VAULT;

  const vault = fromEntries || fromLegacy || fromEnv;
  if (vault) {
    debug('Resolved vault path:', vault);
    return vault;
  }

  const defaultVault = path.join(os.homedir(), '.mnemos', 'vault');
  try {
    if (!fs.existsSync(defaultVault)) {
      initializeVault(defaultVault);
      console.log(`[mnemos] Initialized default vault at ${defaultVault}`);
    }
    return defaultVault;
  } catch (err) {
    console.error(
      '[mnemos] No vault path configured and failed to create default. ' +
      'Set plugins.entries.mnemos.config.vaultPath or MNEMOS_VAULT'
    );
    return null;
  }
}

function initializeVault(vaultPath) {
  const dirs = [
    'self',
    'notes',
    'memory/daily',
    'memory/sessions',
    'memory/.dreams',
    'ops/queue',
    'ops/observations',
    'ops/logs',
    'inbox',
    'templates',
  ];
  for (const dir of dirs) {
    fs.mkdirSync(path.join(vaultPath, dir), { recursive: true });
  }

  const files = {
    'self/identity.md': `# Identity

Who you are and how you work. Update this as you develop preferences and patterns.

## Core Identity

[Describe your role, domain, and working style]

## Working Preferences

[Capture preferences discovered through experience]
`,
    'self/methodology.md': `# Methodology

How you process information, make decisions, and maintain knowledge. This evolves through use.

## Principles

[Capture working principles as you discover them]

## Patterns

[Note recurring patterns in your workflow]
`,
    'self/goals.md': `# Goals

Current objectives and active threads. Update at session end.

## Active

[Current work threads]

## Completed

[Recently completed objectives]

## Parked

[On hold — with reason]
`,
    'memory/MEMORY.md': `# Memory Boot Context

This file is auto-generated. It provides orientation at session start.

## Current Goals

See self/goals.md

## Recent Activity

No observations yet. Run /observe to begin capturing.

## Active Topics

No topic maps yet. They will emerge as notes/ grows.
`,
    'ops/config.yaml': `# mnemos vault configuration
processing:
  depth: standard
  chaining: suggested
  extraction:
    selectivity: moderate

maintenance:
  orphan_threshold: 1
  topic_map_max: 40
  inbox_stale_days: 3
`,
  };

  for (const [filePath, content] of Object.entries(files)) {
    const fullPath = path.join(vaultPath, filePath);
    if (!fs.existsSync(fullPath)) {
      fs.writeFileSync(fullPath, content);
    }
  }
}

function findScriptsDir() {
  const candidates = [
    path.resolve(__dirname, '../../../../core/hooks/scripts'),
    path.resolve(__dirname, '../../scripts'),
    process.env.MNEMOS_SCRIPTS_DIR,
  ].filter(Boolean);

  for (const candidate of candidates) {
    if (fs.existsSync(path.join(candidate, 'session-start.sh'))) {
      debug('Found scripts dir:', candidate);
      return candidate;
    }
  }

  debug('No scripts directory found. Checked:', candidates);
  return null;
}

function callScript(scriptName, vaultPath) {
  const scriptsDir = findScriptsDir();
  if (!scriptsDir) {
    console.error(`[mnemos] Cannot find scripts directory. ${scriptName} skipped.`);
    console.error('[mnemos] Set MNEMOS_SCRIPTS_DIR to the path containing session-start.sh');
    return;
  }

  const scriptPath = path.join(scriptsDir, scriptName);
  if (!fs.existsSync(scriptPath)) {
    console.error(`[mnemos] Script not found: ${scriptPath}`);
    return;
  }

  try {
    debug('Executing script:', scriptPath);
    execFileSync('/bin/bash', ['-lc', scriptPath], {
      env: { ...process.env, MNEMOS_VAULT: vaultPath },
      stdio: 'inherit',
    });
  } catch (err) {
    console.error(`[mnemos] ${scriptName} failed:`, err.message);
  }
}

// ---------------------------------------------------------------------------
// Message Capture (for message:received / message:sent events)
// ---------------------------------------------------------------------------

function isoNow() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
}

function truncate(str) {
  if (!str || str.length <= MAX_CONTENT_LENGTH) return str;
  return str.slice(0, MAX_CONTENT_LENGTH) + '[truncated]';
}

/**
 * Capture a single message event to the session transcript.
 * 
 * OpenClaw message event payload (from docs):
 * {
 *   type: 'message',
 *   action: 'received' | 'sent',
 *   sessionKey: string,
 *   timestamp: Date,
 *   context: {
 *     from: string,        // (received) sender identifier
 *     to: string,          // (sent) recipient identifier
 *     content: string,     // message text
 *     channelId: string,   // e.g., "whatsapp", "telegram"
 *     conversationId: string,
 *   }
 * }
 */
function captureMessage(event, vaultPath) {
  const sessionsDir = path.join(vaultPath, 'memory', 'sessions');
  fs.mkdirSync(sessionsDir, { recursive: true });

  const action = event.action || (event.type?.split(':')[1]);
  const ctx = event.context || {};
  
  const sessionId = event.sessionKey || 
                    ctx.conversationId || 
                    ctx.sessionId ||
                    `openclaw-${Date.now()}`;
  
  const ts = event.timestamp ? new Date(event.timestamp).toISOString() : isoNow();
  const content = ctx.content || ctx.body || ctx.bodyForAgent || '';
  
  if (!content) {
    debug('Empty message content, skipping');
    return;
  }

  const outputFile = path.join(sessionsDir, `${sessionId}.jsonl`);
  const metaFile = path.join(sessionsDir, `${sessionId}.meta.json`);

  if (!fs.existsSync(metaFile)) {
    const meta = {
      session_id: sessionId,
      harness: 'openclaw',
      channel: ctx.channelId || 'unknown',
      start_time: ts,
      vault_path: vaultPath,
    };
    fs.writeFileSync(metaFile, JSON.stringify(meta) + '\n');
    debug('Created meta file:', metaFile);
  }

  let line;
  if (action === 'received') {
    line = {
      ts,
      role: 'user',
      content: truncate(content),
      session_id: sessionId,
    };
    if (ctx.from) line.from = ctx.from;
    if (ctx.channelId) line.channel = ctx.channelId;
  } else if (action === 'sent') {
    line = {
      ts,
      role: 'assistant',
      content: truncate(content),
      session_id: sessionId,
    };
    if (ctx.to) line.to = ctx.to;
    if (ctx.channelId) line.channel = ctx.channelId;
  } else {
    debug('Unknown message action:', action);
    return;
  }

  fs.appendFileSync(outputFile, JSON.stringify(line) + '\n');
  debug(`Captured ${action} message to ${outputFile}`);
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

async function handler(event) {
  const eventType = event.type || 'unknown';
  const eventAction = event.action || '';
  debug(`Received event: ${eventType}${eventAction ? ':' + eventAction : ''}`);

  const vaultPath = resolveVaultPath(event);
  if (!vaultPath) return;

  if (eventMatches(event, 'gateway', 'startup')) {
    console.log('[mnemos] Gateway startup — initializing session');
    callScript('session-start.sh', vaultPath);
    return;
  }

  if (eventMatches(event, 'agent', 'bootstrap')) {
    console.log('[mnemos] Agent bootstrap — initializing session');
    callScript('session-start.sh', vaultPath);
    return;
  }

  if (eventMatches(event, 'message', 'received')) {
    debug('Capturing inbound message');
    try {
      captureMessage(event, vaultPath);
    } catch (err) {
      console.error('[mnemos] Message capture failed:', err.message);
      debug('Error details:', err.stack);
    }
    return;
  }

  if (eventMatches(event, 'message', 'sent')) {
    debug('Capturing outbound message');
    try {
      captureMessage(event, vaultPath);
    } catch (err) {
      console.error('[mnemos] Message capture failed:', err.message);
      debug('Error details:', err.stack);
    }
    return;
  }

  if (eventMatches(event, 'command', 'new')) {
    console.log('[mnemos] Command /new — capturing session before reset');
    callScript('session-capture.sh', vaultPath);
    return;
  }

  if (eventMatches(event, 'session', 'compact:before')) {
    console.log('[mnemos] Pre-compaction — flushing session data');
    callScript('pre-compact.sh', vaultPath);
    return;
  }

  debug(`Unhandled event: ${eventType}:${eventAction}`);
}

// OpenClaw expects direct function export, not .default
module.exports = handler;
module.exports.eventMatches = eventMatches;
module.exports.captureMessage = captureMessage;
