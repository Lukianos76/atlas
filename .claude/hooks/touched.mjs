// État partagé entre les hooks : composants modifiés pendant la session.
// format-lint.mjs (PostToolUse) marque le composant de chaque fichier modifié ;
// typecheck.mjs (Stop) vérifie les types de ces composants en fin de réponse.
// L'état vit dans le répertoire temporaire du système, jamais dans le dépôt : un
// fichier vide par composant marqué, ce qui évite toute lecture-écriture concurrente
// entre deux hooks lancés en même temps.
import { existsSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const stateDir = path.join(os.tmpdir(), 'atlas-claude');
const components = ['web', 'pipelines'];

// Identifiant de session ou composant inattendu : aucun fichier n'est lu ni écrit.
function markerFile(sessionId, component) {
  if (
    typeof sessionId !== 'string' ||
    !/^[A-Za-z0-9_-]+$/.test(sessionId) ||
    !components.includes(component)
  ) {
    return null;
  }
  return path.join(stateDir, `${sessionId}.${component}`);
}

export function readTouched(sessionId) {
  return components.filter((component) => {
    const file = markerFile(sessionId, component);
    return file !== null && existsSync(file);
  });
}

export function markTouched(sessionId, component) {
  const file = markerFile(sessionId, component);
  if (file === null) {
    return;
  }
  mkdirSync(stateDir, { recursive: true });
  writeFileSync(file, '');
}

export function clearTouched(sessionId, component) {
  const file = markerFile(sessionId, component);
  if (file !== null) {
    rmSync(file, { force: true });
  }
}
