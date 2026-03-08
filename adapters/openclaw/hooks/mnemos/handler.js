/**
 * mnemos OpenClaw Hook Pack — Event Router
 *
 * Routes verified OpenClaw hook events to mnemos shell scripts.
 * Does NOT reimplement script logic — just calls the scripts with MNEMOS_VAULT set.
 *
 * Verified events (from Task 5 event verification):
 *   gateway:startup      → session-start.sh   (session init)
 *   agent:bootstrap      → session-start.sh   (session init equivalent)
 *   command:new           → session-capture.sh (pre-reset checkpoint)
 *   session:compact:before → pre-compact.sh    (safety flush before compaction)
 */

'use strict';

const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Match an event against a type/action pair.
 * Handles BOTH payload formats OpenClaw may emit:
 *   1. Object format:  { type: "gateway", action: "startup" }
 *   2. Colon-joined:   { type: "gateway:startup" }
 *
 * Exported for testability.
 */
function eventMatches(event, type, action) {
  if (event.type === type && event.action === action) return true;
  if (event.type === `${type}:${action}`) return true;
  return false;
}

/**
 * Resolve the vault path from the event context, environment, or default.
 * Precedence: plugins.entries (current) > plugins.mnemos (legacy) > env > default.
 * Auto-creates the default vault directory if needed.
 */
function resolveVaultPath(event) {
  const cfg = event.context?.cfg ?? {};
  const pluginId = 'mnemos';

  // Current OpenClaw schema: plugins.entries.<id>.config.vaultPath
  const fromEntries =
    cfg.plugins?.entries?.[pluginId]?.config?.vaultPath ||
    cfg.plugins?.entries?.[pluginId]?.vaultPath;

  // Legacy schema: plugins.<id>.config.vaultPath
  const fromLegacy =
    cfg.plugins?.[pluginId]?.config?.vaultPath ||
    cfg.plugins?.[pluginId]?.vaultPath;

  // Environment variable
  const fromEnv = process.env.MNEMOS_VAULT;

  // Pick first available
  const vault = fromEntries || fromLegacy || fromEnv;
  if (vault) return vault;

  // Default: ~/.mnemos/vault (auto-create if needed)
  const defaultVault = path.join(os.homedir(), '.mnemos', 'vault');
  try {
    if (!fs.existsSync(defaultVault)) {
      fs.mkdirSync(defaultVault, { recursive: true });
      console.log(`[mnemos] Created default vault at ${defaultVault}`);
    }
    return defaultVault;
  } catch (err) {
    console.error(
      '[mnemos] No vault path configured and failed to create default. ' +
      'Set plugins.entries.mnemos.config.vaultPath (preferred) or MNEMOS_VAULT'
    );
    return null;
  }
}

/**
 * Execute a mnemos shell script with MNEMOS_VAULT in the environment.
 * Swallows errors so a failing hook never crashes the gateway.
 */
function callScript(scriptName, vaultPath) {
  const scriptPath = path.resolve(
    __dirname,
    '../../../../core/hooks/scripts',
    scriptName
  );
  try {
    execFileSync('/bin/bash', ['-lc', scriptPath], {
      env: { ...process.env, MNEMOS_VAULT: vaultPath },
      stdio: 'inherit',
    });
  } catch (err) {
    console.error(`[mnemos] ${scriptName} failed:`, err.message);
  }
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

/**
 * OpenClaw Hook Pack handler (default export).
 * Receives every event declared in HOOK.md and routes to the correct script.
 */
async function handler(event) {
  const vaultPath = resolveVaultPath(event);
  if (!vaultPath) return; // warning already logged

  // --- Session initialisation ---
  if (eventMatches(event, 'gateway', 'startup')) {
    callScript('session-start.sh', vaultPath);
    return;
  }

  if (eventMatches(event, 'agent', 'bootstrap')) {
    callScript('session-start.sh', vaultPath);
    return;
  }

  // --- Pre-reset checkpoint ---
  if (eventMatches(event, 'command', 'new')) {
    callScript('session-capture.sh', vaultPath);
    return;
  }

  // --- Safety flush before context compaction ---
  if (eventMatches(event, 'session', 'compact:before')) {
    callScript('pre-compact.sh', vaultPath);
    return;
  }
}

// ---------------------------------------------------------------------------
// Exports (CommonJS)
// ---------------------------------------------------------------------------

module.exports.default = handler;
module.exports.eventMatches = eventMatches;
