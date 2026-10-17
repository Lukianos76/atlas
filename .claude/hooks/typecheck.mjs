// Hook Stop : vérifie les types des composants modifiés pendant la réponse.
// - apps/web : tsc sur les deux projets, comme `pnpm typecheck` ;
// - pipelines : pyright strict, sur le projet entier (configuration de pyproject.toml).
// Code de sortie 2 si des erreurs subsistent : Claude reprend la main pour les corriger.
// Si Claude reprend déjà à cause d'un hook Stop (`stop_hook_active`), l'échec est
// signalé sans bloquer, pour éviter une boucle ; le composant reste marqué, et la
// réponse suivante est de nouveau vérifiée.
// Outil absent (dépendances pas encore installées, uv hors du PATH) : aucune action.
// Seuls les fichiers modifiés par Edit, Write ou MultiEdit sont marqués : une
// modification faite par une commande shell n'est vérifiée que par check.sh.
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { clearTouched, readTouched } from './touched.mjs';

const repoRoot = path.resolve(import.meta.dirname, '..', '..');
const webDir = path.join(repoRoot, 'apps', 'web');
const pipelinesDir = path.join(repoRoot, 'pipelines');

function readInput() {
  try {
    return JSON.parse(readFileSync(0, 'utf8'));
  } catch {
    return null;
  }
}

// Jamais de shell, comme dans format-lint.mjs.
function run(command, args, cwd) {
  return spawnSync(command, args, { cwd, shell: false, encoding: 'utf8' });
}

// Lanceur Node de tsc, lu dans le champ `bin` du paquet (pnpm.cmd exigerait un shell
// sous Windows). Null si TypeScript n'est pas installé.
function tscLauncher() {
  const packageDir = path.join(webDir, 'node_modules', 'typescript');
  try {
    const manifest = JSON.parse(readFileSync(path.join(packageDir, 'package.json'), 'utf8'));
    const bin = typeof manifest.bin === 'string' ? manifest.bin : manifest.bin?.tsc;
    return typeof bin === 'string' ? path.join(packageDir, bin) : null;
  } catch {
    return null;
  }
}

function checkWeb() {
  const tsc = tscLauncher();
  if (tsc === null || !existsSync(tsc)) {
    return [];
  }
  return ['tsconfig.json', 'tsconfig.node.json'].map((project) =>
    run(process.execPath, [tsc, '--pretty', 'false', '-p', project], webDir),
  );
}

function checkPipelines() {
  if (!existsSync(path.join(pipelinesDir, '.venv'))) {
    return [];
  }
  return [run('uv', ['run', '--frozen', 'pyright'], pipelinesDir)];
}

const input = readInput();
const sessionId = input?.session_id;
const touched = readTouched(sessionId);
if (touched.length === 0) {
  process.exit(0);
}

const failed = [];
let output = '';
for (const [component, check] of [
  ['web', checkWeb],
  ['pipelines', checkPipelines],
]) {
  if (!touched.includes(component)) {
    continue;
  }
  // Exécutable introuvable : outil absent, rien n'est vérifié.
  const results = check().filter((result) => result.error?.code !== 'ENOENT');
  const failures = results.filter((result) => result.status !== 0);
  if (failures.length > 0) {
    failed.push(component);
    for (const failure of failures) {
      output += `${failure.stdout ?? ''}${failure.stderr ?? ''}${failure.error?.message ?? ''}`;
    }
  } else {
    clearTouched(sessionId, component);
  }
}

if (failed.length === 0) {
  process.exit(0);
}
if (input?.stop_hook_active === true) {
  process.stdout.write(
    JSON.stringify({
      systemMessage: `Types en échec (${failed.join(', ')}) : erreurs non corrigées, voir tsc ou pyright.`,
    }),
  );
  process.exit(0);
}
process.stderr.write(`Vérification des types en échec (${failed.join(', ')}) :\n${output}`);
process.exit(2);
