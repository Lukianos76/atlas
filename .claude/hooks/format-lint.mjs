// Hook PostToolUse (Edit, Write, MultiEdit) : formate et lint le fichier modifié.
// - apps/web : Biome (TypeScript, JavaScript, JSON, CSS) ;
// - pipelines : Ruff (formatage puis lint avec corrections automatiques).
// Code de sortie 2 si des erreurs subsistent : le message revient à Claude pour correction.
// Outil absent (dépendances pas encore installées) : aucune action.
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';

const repoRoot = path.resolve(import.meta.dirname, '..', '..');

function readInput() {
  try {
    return JSON.parse(readFileSync(0, 'utf8'));
  } catch {
    return null;
  }
}

// Jamais de shell : le chemin du fichier est passé tel quel dans argv, sans
// interprétation possible de métacaractères.
function run(command, args, cwd) {
  return spawnSync(command, args, { cwd, shell: false, encoding: 'utf8' });
}

function report(results) {
  const failures = results.filter((result) => result.status !== 0);
  if (failures.length === 0) {
    process.exit(0);
  }
  for (const failure of failures) {
    process.stderr.write(`${failure.stdout ?? ''}${failure.stderr ?? ''}`);
  }
  process.exit(2);
}

const input = readInput();
const filePath = input?.tool_input?.file_path;
if (typeof filePath !== 'string' || !existsSync(filePath)) {
  process.exit(0);
}

const absolute = path.resolve(filePath);
// Chemin inattendu (option déguisée, caractères de contrôle) : on ne fait rien.
if (path.basename(absolute).startsWith('-') || /[\u0000-\u001f]/.test(absolute)) {
  process.exit(0);
}
const relative = path.relative(repoRoot, absolute).split(path.sep).join('/');
const extension = path.extname(absolute);

const webDir = path.join(repoRoot, 'apps', 'web');
const pipelinesDir = path.join(repoRoot, 'pipelines');

if (
  relative.startsWith('apps/web/') &&
  ['.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.json', '.jsonc', '.css'].includes(extension)
) {
  // Lanceur Node de Biome, appelé directement (pnpm.cmd exigerait un shell sous Windows).
  const biome = path.join(webDir, 'node_modules', '@biomejs', 'biome', 'bin', 'biome');
  if (!existsSync(biome)) {
    process.exit(0);
  }
  const target = path.relative(webDir, absolute);
  report([
    run(
      process.execPath,
      [biome, 'check', '--write', '--no-errors-on-unmatched', target],
      webDir,
    ),
  ]);
} else if (relative.startsWith('pipelines/') && ['.py', '.pyi'].includes(extension)) {
  if (!existsSync(path.join(pipelinesDir, '.venv'))) {
    process.exit(0);
  }
  const target = path.relative(pipelinesDir, absolute);
  const format = run('uv', ['run', '--frozen', 'ruff', 'format', '--', target], pipelinesDir);
  const lint = run('uv', ['run', '--frozen', 'ruff', 'check', '--fix', '--', target], pipelinesDir);
  report([format, lint]);
}
process.exit(0);
