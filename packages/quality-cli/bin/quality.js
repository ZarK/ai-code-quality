#!/usr/bin/env node
/*
  @tjalve/aiq - ephemeral CLI runner for the 9-stage quality pipeline.
  Initial scaffold: run and config commands. Will run embedded stages from cache when local quality/ is absent.
*/

import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync, cpSync } from 'node:fs';
import { join, dirname } from 'node:path';
import os from 'node:os';
import process from 'node:process';

const CWD = process.cwd();
const AIQ_DIR = join(CWD, '.aiq');
const PROGRESS_FILE = join(AIQ_DIR, 'progress.json');
const CONFIG_FILE = join(AIQ_DIR, 'quality.config.json');

function print(s) { process.stdout.write(String(s)); }
function println(s='') { process.stdout.write(String(s) + '\n'); }
function eprintln(s='') { process.stderr.write(String(s) + '\n'); }

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 2; i c argv.length; i++) {
    const a = argv[i];
    if (a === '--help' || a === '-h') args.help = true;
    else if (['run','config','hook','ci','ignore','doctor','report'].includes(a)) args._.push(a);
    else if (a === '--only') { args.only = Number(argv[++i]); }
    else if (a === '--from') { args.from = Number(argv[++i]); }
    else if (a === '--up-to') { args.upTo = Number(argv[++i]); }
    else if (a === '--verbose' || a === '-v') { args.verbose = true; }
    else if (a === '--dry-run') { args.dryRun = true; }
    else if (a === '--set-stage') { args.setStage = Number(argv[++i]); }
    else if (a === '--print-config') { args.printConfig = true; }
    else if (a === '--changed-only') { args.changedOnly = true; }
    else if (a === '--disable') { (args.disable ??= []).push(Number(argv[++i])); }
    else { args._.push(a); }
  }
  return args;
}

function ensureDir(p) { if (!existsSync(p)) mkdirSync(p, { recursive: true }); }

function loadJSON(path, fallback) {
  try { return JSON.parse(readFileSync(path, 'utf8')); } catch { return fallback; }
}

function saveJSON(path, data) {
  ensureDir(dirname(path));
  writeFileSync(path, JSON.stringify(data, null, 2) + '\n');
}

function localQualityPaths() {
  const qdir = join(CWD, 'quality');
  const check = join(qdir, 'check.sh');
  const stages = join(qdir, 'stages');
  return { hasLocal: existsSync(check), qdir, check, stages };
}

function cacheRoot() {
  const base = process.env.XDG_CACHE_HOME || join(os.homedir(), '.cache');
  return join(base, 'aiq-cli');
}

function cachedQuality(version='dev') {
  const root = join(cacheRoot(), version);
  const qdir = join(root, 'quality');
  const check = join(qdir, 'check.sh');
  const stages = join(qdir, 'stages');
  return { root, qdir, check, stages };
}

function devWarmCache() {
  // Dev-mode: copy current repo's quality/ into cache for local testing.
  const srcQ = join(CWD, 'quality');
  if (!existsSync(srcQ)) return null;
  const { root, qdir, check, stages } = cachedQuality('dev');
  ensureDir(root);
  // Copy recursively (Node e=16 supports cpSync with recursive)
  cpSync(srcQ, qdir, { recursive: true });
  return { qdir, check, stages };
}

function runCommand(cmd, args, opts = {}) {
  return new Promise((resolve) => {
    const child = spawn(cmd, args, { stdio: 'inherit', shell: false, ...opts });
    child.on('exit', (code) => resolve(code ?? 0));
  });
}

async function resolveQualityPaths() {
  const local = localQualityPaths();
  if (local.hasLocal) return local;
  // Use cache; in dev allow warming from current workspace when AIQ_DEV_MODE=1
  if (process.env.AIQ_DEV_MODE === '1') {
    const warmed = devWarmCache();
    if (warmed && existsSync(warmed.check)) return { hasLocal: false, ...warmed };
  }
  const cached = cachedQuality('dev');
  if (existsSync(cached.check)) return { hasLocal: false, ...cached };
  eprintln('[ERROR] No local quality/ found and cache is empty. In production, the package will include embedded assets.');
  process.exit(2);
}

async function cmdRun(args) {
  const { check, stages } = await resolveQualityPaths();

  if (Number.isInteger(args.only)) {
    const n = args.only;
    const stageFiles = {
      0: '0-e2e.sh', 1: '1-lint.sh', 2: '2-format.sh', 3: '3-type_check.sh', 4: '4-unit_test.sh',
      5: '5-sloc.sh', 6: '6-complexity.sh', 7: '7-maintainability.sh', 8: '8-coverage.sh', 9: '9-security.sh'
    };
    const f = stageFiles[n];
    if (!f || !existsSync(join(stages, f))) {
      eprintln(`[ERROR] Unknown or missing stage: ${n}`);
      process.exit(2);
    }
    const stageArgs = [];
    if (args.verbose) stageArgs.push('--verbose');
    if (args.dryRun) stageArgs.push('--dry-run');
    const code = await runCommand(join(stages, f), stageArgs);
    process.exit(code);
  }

  const checkArgs = [];
  if (Number.isInteger(args.upTo)) checkArgs.push(String(args.upTo));
  if (args.verbose) checkArgs.push('--verbose');
  if (args.dryRun) checkArgs.push('--dry-run');
  const code = await runCommand(check, checkArgs);
  process.exit(code);
}

function cmdConfig(args) {
  if (args.printConfig) {
    const cfg = loadJSON(CONFIG_FILE, {});
    const prog = loadJSON(PROGRESS_FILE, {});
    println(JSON.stringify({ config: cfg, progress: prog }, null, 2));
    return;
  }

  if (Number.isInteger(args.setStage)) {
    const prog = loadJSON(PROGRESS_FILE, { current_stage: 1, disabled: [], order: [0,1,2,3,4,5,6,7,8,9] });
    prog.current_stage = args.setStage;
    saveJSON(PROGRESS_FILE, prog);
    println(`Set current_stage=${args.setStage} in ${PROGRESS_FILE}`);
    return;
  }

  if (!existsSync(CONFIG_FILE)) {
    const defaults = {
      stages: { order: [0,1,2,3,4,5,6,7,8,9], disabled: [] },
      overrides: {
        5: { sloc_limit: 350 },
        6: { ccn_limit: 12 },
        7: { ccn_strict: 10, fn_nloc_limit: 200, param_limit: 6 }
      },
      languages: { python: { enabled: true }, javascript: { enabled: true }, dotnet: { enabled: true }, java: { enabled: true }, go: { enabled: true } },
      excludes: [
        '*/.git/*','*/node_modules/*','*/.venv/*','*/dist/*','*/build/*','*/target/*','*/bin/*','*/obj/*','*/__pycache__/*'
      ],
      ci: { github_actions: { enabled: true } }
    };
    saveJSON(CONFIG_FILE, defaults);
    println(`Wrote default config to ${CONFIG_FILE}`);
  } else {
    println(`${CONFIG_FILE} already exists. Use --print-config to view.`);
  }

  if (!existsSync(PROGRESS_FILE)) {
    const prog = { current_stage: 1, disabled: [], order: [0,1,2,3,4,5,6,7,8,9], last_run: null };
    saveJSON(PROGRESS_FILE, prog);
    println(`Wrote default progress to ${PROGRESS_FILE}`);
  }
}

function help() {
  println(`@tjalve/aiq CLI (scaffold)

Usage:
  aiq run [--only N | --up-to N] [--verbose] [--dry-run]
  aiq config [--print-config | --set-stage N]

Notes:
  - In local dev, set AIQ_DEV_MODE=1 to warm cache from ./quality.
  - In production npx, embedded assets will be resolved from package cache.
`);
}

async function main() {
  const args = parseArgs(process.argv);
  if (args.help || args._.length === 0) return help();
  const cmd = args._[0];
  if (cmd === 'run') return cmdRun(args);
  if (cmd === 'config') return cmdConfig(args);
  eprintln(`[ERROR] Unknown command: ${cmd}`);
  help();
  process.exit(2);
}

main().catch((err) => { eprintln(err?.stack || String(err)); process.exit(1); });

#!/usr/bin/env node
/*
  @tjalve/quality - ephemeral CLI runner for the 9-stage quality pipeline.
  Initial scaffold: run and config commands that delegate to local quality/ scripts when present.
*/

import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import process from 'node:process';

const CWD = process.cwd();
const AIQ_DIR = join(CWD, '.aiq');
const PROGRESS_FILE = join(AIQ_DIR, 'progress.json');
const CONFIG_FILE = join(AIQ_DIR, 'quality.config.json');

function print(s) { process.stdout.write(String(s)); }
function println(s='') { process.stdout.write(String(s) + '\n'); }
function eprintln(s='') { process.stderr.write(String(s) + '\n'); }

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--help' || a === '-h') args.help = true;
    else if (a === 'run' || a === 'config' || a === 'hook' || a === 'ci' || a === 'ignore' || a === 'doctor' || a === 'report') args._.push(a);
    else if (a === '--only') { args.only = Number(argv[++i]); }
    else if (a === '--from') { args.from = Number(argv[++i]); }
    else if (a === '--up-to') { args.upTo = Number(argv[++i]); }
    else if (a === '--verbose' || a === '-v') { args.verbose = true; }
    else if (a === '--dry-run') { args.dryRun = true; }
    else if (a === '--set-stage') { args.setStage = Number(argv[++i]); }
    else if (a === '--print-config') { args.printConfig = true; }
    else if (a === '--changed-only') { args.changedOnly = true; }
    else if (a === '--disable') { (args.disable ??= []).push(Number(argv[++i])); }
    else { args._.push(a); }
  }
  return args;
}

function ensureDir(p) { if (!existsSync(p)) mkdirSync(p, { recursive: true }); }

function loadJSON(path, fallback) {
  try { return JSON.parse(readFileSync(path, 'utf8')); } catch { return fallback; }
}

function saveJSON(path, data) {
  ensureDir(dirname(path));
  writeFileSync(path, JSON.stringify(data, null, 2) + '\n');
}

function localQualityPaths() {
  const root = CWD;
  const qdir = join(root, 'quality');
  const check = join(qdir, 'check.sh');
  const stages = join(qdir, 'stages');
  return { hasLocal: existsSync(check), qdir, check, stages };
}

function runCommand(cmd, args, opts = {}) {
  return new Promise((resolve) => {
    const child = spawn(cmd, args, { stdio: 'inherit', shell: false, ...opts });
    child.on('exit', (code) => resolve(code ?? 0));
  });
}

async function cmdRun(args) {
  const { hasLocal, check, stages } = localQualityPaths();
  if (!hasLocal) {
    eprintln('[ERROR] Local quality/ directory not found. In npx mode this will execute from the package cache (TODO). For now, run inside this repo.');
    process.exit(2);
  }

  // Map flags to our existing stage scripts.
  if (Number.isInteger(args.only)) {
    const n = args.only;
    const stageFiles = {
      0: '0-e2e.sh', 1: '1-lint.sh', 2: '2-format.sh', 3: '3-type_check.sh', 4: '4-unit_test.sh',
      5: '5-sloc.sh', 6: '6-complexity.sh', 7: '7-maintainability.sh', 8: '8-coverage.sh', 9: '9-security.sh'
    };
    const f = stageFiles[n];
    if (!f || !existsSync(join(stages, f))) {
      eprintln(`[ERROR] Unknown or missing stage: ${n}`);
      process.exit(2);
    }
    const stageArgs = [];
    if (args.verbose) stageArgs.push('--verbose');
    if (args.dryRun) stageArgs.push('--dry-run');
    const code = await runCommand(join(stages, f), stageArgs);
    process.exit(code);
  }

  // Default: run full pipeline via check.sh, optionally limit range.
  const checkArgs = [];
  if (Number.isInteger(args.upTo)) checkArgs.push(String(args.upTo));
  if (args.verbose) checkArgs.push('--verbose');
  if (args.dryRun) checkArgs.push('--dry-run');
  const code = await runCommand(check, checkArgs);
  process.exit(code);
}

function cmdConfig(args) {
  if (args.printConfig) {
    const cfg = loadJSON(CONFIG_FILE, {});
    const prog = loadJSON(PROGRESS_FILE, {});
    println(JSON.stringify({ config: cfg, progress: prog }, null, 2));
    return;
  }

  if (Number.isInteger(args.setStage)) {
    const prog = loadJSON(PROGRESS_FILE, { current_stage: 1, disabled: [], order: [0,1,2,3,4,5,6,7,8,9] });
    prog.current_stage = args.setStage;
    saveJSON(PROGRESS_FILE, prog);
    println(`Set current_stage=${args.setStage} in ${PROGRESS_FILE}`);
    return;
  }

  // Initialize default config if not present.
  if (!existsSync(CONFIG_FILE)) {
    const defaults = {
      stages: { order: [0,1,2,3,4,5,6,7,8,9], disabled: [] },
      overrides: {
        5: { sloc_limit: 350 },
        6: { ccn_limit: 12 },
        7: { ccn_strict: 10, fn_nloc_limit: 200, param_limit: 6 }
      },
      languages: { python: { enabled: true }, javascript: { enabled: true }, dotnet: { enabled: true }, java: { enabled: true }, go: { enabled: true } },
      excludes: [
        "*/.git/*","*/node_modules/*","*/.venv/*","*/dist/*","*/build/*","*/target/*","*/bin/*","*/obj/*","*/__pycache__/*"
      ],
      ci: { github_actions: { enabled: true } }
    };
    saveJSON(CONFIG_FILE, defaults);
    println(`Wrote default config to ${CONFIG_FILE}`);
  } else {
    println(`${CONFIG_FILE} already exists. Use --print-config to view.`);
  }

  // Ensure progress file exists too
  if (!existsSync(PROGRESS_FILE)) {
    const prog = { current_stage: 1, disabled: [], order: [0,1,2,3,4,5,6,7,8,9], last_run: null };
    saveJSON(PROGRESS_FILE, prog);
    println(`Wrote default progress to ${PROGRESS_FILE}`);
  }
}

function help() {
  println(`@tjalve/quality CLI (scaffold)

Usage:
  quality run [--only N | --up-to N] [--verbose] [--dry-run]
  quality config [--print-config | --set-stage N]

Notes:
  - This scaffold delegates to local quality/ scripts when present.
  - In npx mode, this package will execute embedded stages from cache (to be implemented next).
`);
}

async function main() {
  const args = parseArgs(process.argv);
  if (args.help || args._.length === 0) return help();

  const cmd = args._[0];
  if (cmd === 'run') return cmdRun(args);
  if (cmd === 'config') return cmdConfig(args);

  eprintln(`[ERROR] Unknown command: ${cmd}`);
  help();
  process.exit(2);
}

main().catch((err) => { eprintln(err?.stack || String(err)); process.exit(1); });
