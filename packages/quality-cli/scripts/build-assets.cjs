'use strict';
const { cpSync, existsSync, mkdirSync } = require('node:fs');
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
console.log('[aiq build] Copied quality/ -> packages/quality-cli/assets/quality');
