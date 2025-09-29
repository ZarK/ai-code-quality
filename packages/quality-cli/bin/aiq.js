#!/usr/bin/env node
/*
  @tjalve/aiq - ephemeral CLI runner for the 9-stage quality pipeline.
  Commands: run, config, hook install, ci setup, ignore write, doctor, install-tools.
  Supports --diff-only to scope certain stages to changed files.
*/

import { spawn, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync, cpSync, chmodSync, unlinkSync } from 'node:fs';
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
    else if (['run','config','hook','ci','ignore','doctor','report','install-tools'].includes(a)) args._.push(a);
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

function packageRootDir() {
  const here = fileURLToPath(import.meta.url);
  return dirname(dirname(here));
}

function packageVersion() {
  try {
    const pkgJson = readFileSync(join(packageRootDir(), 'package.json'), 'utf8');
    const pkg = JSON.parse(pkgJson);
    return String(pkg.version || 'dev');
  } catch { return 'dev'; }
}

function cachedQuality(version) {
  const ver = version || packageVersion();
  const root = join(cacheRoot(), ver);
  const qdir = join(root, 'quality');
  const check = join(qdir, 'check.sh');
  const stages = join(qdir, 'stages');
  return { root, qdir, check, stages, ver };
}

function packageAssetsQualityDir() {
  try {
    const assetsQ = join(packageRootDir(), 'assets', 'quality');
    if (existsSync(assetsQ)) return assetsQ;
  } catch {}
  return null;
}

function devWarmCache() {
  const srcQ = join(CWD, 'quality');
  if (!existsSync(srcQ)) return null;
  const out = cachedQuality('dev');
  ensureDir(out.root);
  cpSync(srcQ, out.qdir, {
    recursive: true,
    filter: (src, dest) => !src.includes('node_modules')
  });
  // ensure executable bits for scripts
  try { chmodSync(join(out.qdir, 'check.sh'), 0o755); } catch {}
  try { chmodSync(join(out.qdir, 'bin', 'run_checks.sh'), 0o755); } catch {}
  return { qdir: out.qdir, check: out.check, stages: out.stages };
}

function runCommand(cmd, args, opts = {}) {
  return new Promise((resolve) => {
    const child = spawn(cmd, args, { stdio: 'inherit', shell: false, ...opts });
    child.on('exit', (code) => resolve(code ?? 0));
  });
}

async function resolveQualityPaths() {
  // Prioritize packaged assets over local quality directories
  // This ensures we test the packaged version, not local development versions
  if (process.platform === 'win32') {
    eprintln('[WARN] Windows detected. aiq requires Bash (Git Bash/WSL) to run the embedded quality scripts.');
  }

  if (process.env.AIQ_DEV_MODE === '1') {
    const warmed = devWarmCache();
    if (warmed && existsSync(warmed.check)) return { hasLocal: false, ...warmed };
  }
  const assetsQ = packageAssetsQualityDir();
  if (assetsQ) {
    const out = cachedQuality();
    ensureDir(out.root);
    // Force fresh copy by removing existing cache
    if (existsSync(out.qdir)) {
      // Use rmSync to remove existing cache
      const { rmSync } = await import('node:fs');
      rmSync(out.qdir, { recursive: true, force: true });
    }
    // Ensure destination directory exists
    ensureDir(out.qdir);
    // Copy assets
    cpSync(assetsQ, out.qdir, { recursive: true });
    if (existsSync(out.check)) return { hasLocal: false, qdir: out.qdir, check: out.check, stages: out.stages };
  }
  const cached = cachedQuality();
  if (existsSync(cached.check)) return { hasLocal: false, qdir: cached.qdir, check: cached.check, stages: cached.stages };

  // Only fall back to local quality directory if no packaged assets are available
  const local = localQualityPaths();
  if (local.hasLocal) {
    eprintln('[INFO] Using local quality directory (no packaged assets found)');
    return local;
  }

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
  // Subtle tip when invoked without explicit command
  if ((args._.length === 0) && !args.help) {
    println('Tip: run "aiq help" for more info.');
  }
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

    // Provide debugging help if the stage failed
    if (code !== 0) {
      eprintln('');
      eprintln('To debug this stage with verbose output:');
      eprintln(`  aiq run --only ${n} --verbose`);
      eprintln('');
      eprintln('To run all stages:');
      eprintln('  aiq run');
    }

    process.exit(code);
  }

  // For full runs, use phase_checks.sh for consistent timing output
  const checkArgs = [];
  if (Number.isInteger(args.upTo)) checkArgs.push(String(args.upTo));
  if (args.verbose) checkArgs.push('--verbose');
  if (args.dryRun) checkArgs.push('--dry-run');

  // Create temp file for failed stages to avoid printing them directly
  const failedStagesFile = join(os.tmpdir(), `aiq-failed-stages-${Date.now()}-${Math.random().toString(36).substr(2, 9)}.txt`);

  const phaseChecks = join(dirname(check), 'bin', 'phase_checks.sh');
  const code = await runCommand(phaseChecks, checkArgs, {
    env: {
      ...process.env,
      ...envOverrides,
      FAILED_STAGES_FILE: failedStagesFile
    }
  });

  // If check.sh failed, provide specific debugging commands for failed stages
  if (code !== 0) {
    const failedStagesContent = existsSync(failedStagesFile) ? readFileSync(failedStagesFile, 'utf8').trim() : '';
    const failedStages = failedStagesContent ? failedStagesContent.split('\n').map(s => s.trim()).filter(Boolean) : [];

    if (failedStages.length > 0) {
      eprintln('');
      eprintln('To debug failed stages:');
      for (const stage of failedStages) {
        const stageNum = parseInt(stage, 10);
        const name = stageFiles[stageNum]?.replace(/^\d+-|\.sh$/g, '') || 'unknown';
        eprintln(`  aiq run --only ${stageNum} --verbose  # Debug stage ${stageNum} (${name})`);
      }
      eprintln('');
    }
  }

  // Clean up temp file
  try { unlinkSync(failedStagesFile); } catch {}

  process.exit(code);
}

async function cmdHook(args) {
  const hookDir = join(CWD, '.git', 'hooks');
  const hookPath = join(hookDir, 'pre-commit');
  ensureDir(hookDir);
  const prog = loadJSON(PROGRESS_FILE, { current_stage: 1 });
  const upTo = Number.isInteger(prog.current_stage) ? prog.current_stage : 1;
  const script = `#!/usr/bin/env bash\nset -euo pipefail\n# aiq pre-commit hook\nAIQ_BIN=aiq\nif command -v bunx > /dev/null 2>&1; then\n  bunx @tjalve/aiq run --up-to ${upTo}\nelif command -v npx > /dev/null 2>&1; then\n  npx @tjalve/aiq run --up-to ${upTo}\nelse\n  $AIQ_BIN run --up-to ${upTo}\nfi\n`;
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

async function cmdInstallTools(args) {
  const { check, stages, qdir } = await resolveQualityPaths();
  const installer = join(qdir, 'bin', 'install_tools.sh');
  if (!existsSync(installer)) {
    eprintln('[ERROR] install_tools.sh not found in embedded assets.');
    process.exit(2);
  }
  const code = await runCommand('bash', [installer], { env: process.env });
  process.exit(code);
}

function help() {
  println(`@tjalve/aiq CLI\n\nUsage:\n  aiq run [--only N | --up-to N] [--verbose] [--dry-run] [--diff-only]\n  aiq config [--print-config | --set-stage N]\n  aiq hook install\n  aiq ci setup\n  aiq ignore write\n  aiq doctor\n  aiq install-tools\n\nNotes:\n  - Default: \"aiq\" runs \"aiq run\" and prints a tip for help.\n  - Embedded quality assets are cached under ~/.cache/aiq-cli/<version>/quality.\n  - In local dev, set AIQ_DEV_MODE=1 to warm cache from ./quality.\n  - Windows requires Bash (Git Bash/WSL) for the staged shell scripts.\n`);
}

async function main() {
  const args = parseArgs(process.argv);
  // Default to run if no command provided
  if (!args.help && args._.length === 0) {
    println('Tip: run "aiq help" for more info.');
    args._.push('run');
  }
  if (args.help) return help();

  const [cmd, sub] = args._;
  if (cmd === 'run') return cmdRun(args);
  if (cmd === 'config') return cmdConfig(args);
  if (cmd === 'hook' && sub === 'install') return cmdHook(args);
  if (cmd === 'ci' && sub === 'setup') return cmdCI(args);
  if (cmd === 'ignore' && sub === 'write') return cmdIgnore(args);
  if (cmd === 'doctor') return cmdDoctor(args);
  if (cmd === 'install-tools') return cmdInstallTools(args);
  eprintln(`[ERROR] Unknown command: ${args._.join(' ')}`);
  help();
  process.exit(2);
}

main().catch((err) => { eprintln(err?.stack || String(err)); process.exit(1); });
