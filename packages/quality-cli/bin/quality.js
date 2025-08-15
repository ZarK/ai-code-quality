#!/usr/bin/env node
/*
  @tjalve/aiq - ephemeral CLI runner for the 9-stage quality pipeline.
  Commands: run, config, hook install, ci setup, ignore write, doctor.
  Supports --diff-only to scope certain stages to changed files.
*/

import { spawn, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync, cpSync } from 'node:fs';
import { join, dirname } from 'node:path';
import os from 'node:os';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const CWD = process.cwd();
const AIQ_DIR = join(CWD, '.aiq');
const PROGRESS_FILE = join(AIQ_DIR, 'progress.json');
const CONFIG_FILE = join(AIQ_DIR, 'quality.config.json');

function println(s = '') { process.stdout.write(String(s) + '\n'); }
function eprintln(s = '') { process.stderr.write(String(s) + '\n'); }

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 2; i < argv.length; i++) {
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
    else if (a === '--diff-only' || a === '--changed-only') { args.diffOnly = true; }
    else if (a === '--disable') { (args.disable ??= []).push(Number(argv[++i])); }
    else { args._.push(a); }
  }
  return args;
}

function ensureDir(p) { if (!existsSync(p)) mkdirSync(p, { recursive: true }); }
function loadJSON(path, fallback) { try { return JSON.parse(readFileSync(path, 'utf8')); } catch { return fallback; } }
function saveJSON(path, data) { ensureDir(dirname(path)); writeFileSync(path, JSON.stringify(data, null, 2) + '\n'); }

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

function cachedQuality(version = 'dev') {
  const root = join(cacheRoot(), version);
  const qdir = join(root, 'quality');
  const check = join(qdir, 'check.sh');
  const stages = join(qdir, 'stages');
  return { root, qdir, check, stages };
}

function packageAssetsQualityDir() {
  try {
    const here = fileURLToPath(import.meta.url);
    const pkgRoot = dirname(dirname(here));
    const assetsQ = join(pkgRoot, 'assets', 'quality');
    if (existsSync(assetsQ)) return assetsQ;
  } catch {}
  return null;
}

function devWarmCache() {
  const srcQ = join(CWD, 'quality');
  if (!existsSync(srcQ)) return null;
  const { root, qdir } = cachedQuality('dev');
  ensureDir(root);
  cpSync(srcQ, qdir, { recursive: true });
  const { check, stages } = cachedQuality('dev');
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
  if (process.env.AIQ_DEV_MODE === '1') {
    const warmed = devWarmCache();
    if (warmed && existsSync(warmed.check)) return { hasLocal: false, ...warmed };
  }
  const assetsQ = packageAssetsQualityDir();
  if (assetsQ) {
    const out = cachedQuality('pkg');
    ensureDir(out.root);
    cpSync(assetsQ, out.qdir, { recursive: true });
    if (existsSync(out.check)) return { hasLocal: false, ...out };
  }
  const cached = cachedQuality('dev');
  if (existsSync(cached.check)) return { hasLocal: false, ...cached };
  eprintln('[ERROR] No quality assets available (local, cache, or embedded).');
  process.exit(2);
}

function computeStagePlan(cfg, prog, args) {
  const defaults = [0,1,2,3,4,5,6,7,8,9];
  const order = (cfg?.stages?.order ?? prog?.order ?? defaults).filter(n => defaults.includes(n));
  const disabled = new Set([...(cfg?.stages?.disabled ?? []), ...(prog?.disabled ?? [])]);
  let target = order;
  if (Number.isInteger(args.upTo)) target = order.filter(n => n <= args.upTo);
  if (Number.isInteger(args.only)) target = [args.only];
  return target.filter(n => !disabled.has(n));
}

function envFromOverrides(cfg) {
  const env = {};
  const o5 = cfg?.overrides?.[5];
  const o6 = cfg?.overrides?.[6];
  const o7 = cfg?.overrides?.[7];
  if (o5?.sloc_limit) env.LIZARD_SLOC_LIMIT = String(o5.sloc_limit);
  if (o6?.ccn_limit) env.LIZARD_CCN_LIMIT = String(o6.ccn_limit);
  if (o7?.ccn_strict) env.LIZARD_CCN_STRICT = String(o7.ccn_strict);
  if (o7?.fn_nloc_limit) env.LIZARD_FN_NLOC_LIMIT = String(o7.fn_nloc_limit);
  if (o7?.param_limit) env.LIZARD_PARAM_LIMIT = String(o7.param_limit);
  return env;
}

function gitChangedFiles(baseRef) {
  try {
    const base = baseRef || 'origin/main';
    const mb = spawnSync('git', ['merge-base', 'HEAD', base], { cwd: CWD, encoding: 'utf8' });
    const baseSha = (mb.stdout || '').trim();
    if (!baseSha) return [];
    const diff = spawnSync('git', ['diff', '--name-only', baseSha, 'HEAD'], { cwd: CWD, encoding: 'utf8' });
    return (diff.stdout || '').split('\n').map(s => s.trim()).filter(Boolean);
  } catch { return []; }
}

async function cmdRun(args) {
  const { check, stages } = await resolveQualityPaths();
  const cfg = loadJSON(CONFIG_FILE, {});
  let changedListPath = null;
  if (args.diffOnly) {
    const files = gitChangedFiles(cfg?.diff?.base);
    if (files.length) {
      changedListPath = join(os.tmpdir(), `aiq-changed-${Date.now()}.txt`);
      writeFileSync(changedListPath, files.join('\n'));
    }
  }
  const prog = loadJSON(PROGRESS_FILE, {});
  const plan = computeStagePlan(cfg, prog, args);
  const envOverrides = envFromOverrides(cfg);
  if (changedListPath) {
    envOverrides.AIQ_CHANGED_ONLY = '1';
    envOverrides.AIQ_CHANGED_FILELIST = changedListPath;
  }

  const stageFiles = {
    0: '0-e2e.sh', 1: '1-lint.sh', 2: '2-format.sh', 3: '3-type_check.sh', 4: '4-unit_test.sh',
    5: '5-sloc.sh', 6: '6-complexity.sh', 7: '7-maintainability.sh', 8: '8-coverage.sh', 9: '9-security.sh'
  };

  if (Number.isInteger(args.only)) {
    const n = args.only;
    const f = stageFiles[n];
    if (!f || !existsSync(join(stages, f))) {
      eprintln(`[ERROR] Unknown or missing stage: ${n}`);
      process.exit(2);
    }
    const stageArgs = [];
    if (args.verbose) stageArgs.push('--verbose');
    if (args.dryRun) stageArgs.push('--dry-run');
    const code = await runCommand(join(stages, f), stageArgs, { env: { ...process.env, ...envOverrides } });
    process.exit(code);
  }

  if (plan && plan.length) {
    for (const n of plan) {
      const f = stageFiles[n];
      if (!f || !existsSync(join(stages, f))) continue;
      const stageArgs = [];
      if (args.verbose) stageArgs.push('--verbose');
      if (args.dryRun) stageArgs.push('--dry-run');
      const code = await runCommand(join(stages, f), stageArgs, { env: { ...process.env, ...envOverrides } });
      if (code !== 0) process.exit(code);
    }
    process.exit(0);
  }

  const checkArgs = [];
  if (Number.isInteger(args.upTo)) checkArgs.push(String(args.upTo));
  if (args.verbose) checkArgs.push('--verbose');
  if (args.dryRun) checkArgs.push('--dry-run');
  const code = await runCommand(check, checkArgs, { env: { ...process.env, ...envOverrides } });
  process.exit(code);
}

async function cmdHook(args) {
  const hookDir = join(CWD, '.git', 'hooks');
  const hookPath = join(hookDir, 'pre-commit');
  ensureDir(hookDir);
  const prog = loadJSON(PROGRESS_FILE, { current_stage: 1 });
  const upTo = Number.isInteger(prog.current_stage) ? prog.current_stage : 1;
  const script = `#!/usr/bin/env bash\nset -euo pipefail\n# aiq pre-commit hook\nAIQ_BIN=aiq\nif command -v npx > /dev/null 2>&1; then\n  npx @tjalve/aiq run --up-to ${upTo}\nelse\n  $AIQ_BIN run --up-to ${upTo}\nfi\n`;
  writeFileSync(hookPath, script, { mode: 0o755 });
  println(`Installed pre-commit hook -> ${hookPath}`);
}

async function cmdCI(args) {
  const wfDir = join(CWD, '.github', 'workflows');
  const wfPath = join(wfDir, 'quality.yml');
  ensureDir(wfDir);
  const yaml = `name: Quality\n\non:\n  pull_request:\n  push:\n    branches: [ main, develop ]\n\njobs:\n  quality:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v4\n      - name: Setup Node\n        uses: actions/setup-node@v4\n        with:\n          node-version: 'lts/*'\n          cache: 'npm'\n      - name: Run quality\n        run: npx @tjalve/aiq run\n`;
  writeFileSync(wfPath, yaml);
  println(`Wrote workflow -> ${wfPath}`);
}

async function cmdIgnore(args) {
  const giPath = join(CWD, '.gitignore');
  const blockStart = '# aiq-ignore-start';
  const blockEnd = '# aiq-ignore-end';
  const entries = [
    'node_modules/', '.venv/', 'dist/', 'build/', 'target/', 'bin/', 'obj/', '__pycache__/'
  ];
  let content = existsSync(giPath) ? readFileSync(giPath, 'utf8') : '';
  const block = `${blockStart}\n${entries.join('\n')}\n${blockEnd}\n`;
  if (!content.includes(blockStart)) {
    content += (content.endsWith('\n') ? '' : '\n') + block;
    writeFileSync(giPath, content);
    println(`Appended ignore block to ${giPath}`);
  } else {
    println('aiq ignore block already present in .gitignore');
  }
}

async function cmdDoctor(args) {
  println('Environment diagnostics:');
  const checks = [
    ['node', ['--version']],
    ['bunx', ['--version']],
    ['npx', ['--version']],
    ['uvx', ['--version']],
    ['dotnet', ['--info']],
  ];
  for (const [cmd, cargs] of checks) {
    println(`- ${cmd}:`);
    try {
      const code = await runCommand(cmd, cargs);
      if (code !== 0) eprintln(`  ${cmd} returned ${code}`);
    } catch {
      eprintln(`  ${cmd} not available`);
    }
  }
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
  println(`@tjalve/aiq CLI

Usage:
  aiq run [--only N | --up-to N] [--verbose] [--dry-run] [--diff-only]
  aiq config [--print-config | --set-stage N]
  aiq hook install
  aiq ci setup
  aiq ignore write
  aiq doctor

Notes:
  - In local dev, set AIQ_DEV_MODE=1 to warm cache from ./quality.
  - In production npx, embedded assets will be resolved from package cache.
`);
}

async function main() {
  const args = parseArgs(process.argv);
  if (args.help || args._.length === 0) return help();
  const [cmd, sub] = args._;
  if (cmd === 'run') return cmdRun(args);
  if (cmd === 'config') return cmdConfig(args);
  if (cmd === 'hook' && sub === 'install') return cmdHook(args);
  if (cmd === 'ci' && sub === 'setup') return cmdCI(args);
  if (cmd === 'ignore' && sub === 'write') return cmdIgnore(args);
  if (cmd === 'doctor') return cmdDoctor(args);
  eprintln(`[ERROR] Unknown command: ${args._.join(' ')}`);
  help();
  process.exit(2);
}

main().catch((err) => { eprintln(err?.stack || String(err)); process.exit(1); });
  if (cmd === 'run') return cmdRun(args);
  if (cmd === 'config') return cmdConfig(args);
  if (cmd === 'hook' && sub === 'install') return cmdHook(args);
  if (cmd === 'ci' && sub === 'setup') return cmdCI(args);
  if (cmd === 'ignore' && sub === 'write') return cmdIgnore(args);
  if (cmd === 'doctor') return cmdDoctor(args);
  eprintln(`[ERROR] Unknown command: ${args._.join(' ')}`);
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
