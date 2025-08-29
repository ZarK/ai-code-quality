'use strict';
const { cpSync, existsSync, mkdirSync, chmodSync } = require('node:fs');
const { join, resolve } = require('node:path');

const repoRoot = resolve(__dirname, '..', '..', '..');
const src = join(repoRoot, 'quality');
const dest = join(__dirname, '..', 'assets', 'quality');

if (!existsSync(src)) {
  console.error('[aiq build] quality/ directory not found in repo root');
  process.exit(2);
}
mkdirSync(dest, { recursive: true });
cpSync(src, dest, { recursive: true });
// Ensure key scripts are executable in the packaged assets
try { chmodSync(join(dest, 'check.sh'), 0o755); } catch {}
try { chmodSync(join(dest, 'bin', 'run_checks.sh'), 0o755); } catch {}
console.log('[aiq build] Copied quality/ -> packages/quality-cli/assets/quality');
