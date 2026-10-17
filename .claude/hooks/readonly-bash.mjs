// Hook PreToolUse (Bash) des sous-agents en lecture seule (reviewer, data-verifier).
// N'autorise que des commandes git de consultation. La commande est découpée en mots,
// et chaque option doit figurer dans la liste blanche de sa sous-commande : git accepte
// les options longues abrégées (`--outp` vaut `--output`), une liste noire ne suffit pas.
// Code de sortie 2 : l'appel est bloqué et le message revient à l'agent.
import { readFileSync } from 'node:fs';

// Guillemets, échappements, jokers, substitutions, redirections, enchaînements.
const SHELL_META = /[;&|<>`$\n\r'"\\*?[\]{}~()!#]/;

// Options admises, mot pour mot ; `PREFIXES` admet en plus une valeur collée (`-U3`).
const OPTIONS = {
  diff: ['--stat', '--name-only', '--name-status', '--cached', '--staged', '--'],
  log: ['--oneline', '--stat', '--name-only', '--name-status', '--graph', '--decorate', '--'],
  show: ['--stat', '--name-only', '--name-status', '--oneline', '--'],
  status: ['--short', '-s', '--porcelain', '--branch', '-b'],
  'ls-files': ['--'],
  blame: ['--'],
  'rev-parse': ['--abbrev-ref', '--short', '--verify'],
  branch: ['--show-current', '--list', '-a', '--all', '-v'],
};
const PREFIXES = {
  diff: [/^-U\d+$/],
  log: [/^-n\d*$/, /^-\d+$/, /^--max-count=\d+$/],
  show: [],
  blame: [/^-L\d+(,\d+)?$/],
};

function allowed(command) {
  if (typeof command !== 'string' || SHELL_META.test(command)) {
    return false;
  }
  const [git, subcommand, ...rest] = command.trim().split(/\s+/);
  if (git !== 'git' || subcommand === undefined || !Object.hasOwn(OPTIONS, subcommand)) {
    return false;
  }
  const options = OPTIONS[subcommand];
  const prefixes = PREFIXES[subcommand] ?? [];
  // `git branch <nom>` crée une branche : aucun argument positionnel pour `branch`.
  if (subcommand === 'branch' && rest.some((token) => !token.startsWith('-'))) {
    return false;
  }
  return rest.every(
    (token) =>
      !token.startsWith('-') ||
      options.includes(token) ||
      prefixes.some((pattern) => pattern.test(token)),
  );
}

let command = '';
try {
  command = JSON.parse(readFileSync(0, 'utf8'))?.tool_input?.command ?? '';
} catch {
  // Entrée illisible : on bloque par prudence.
}
if (allowed(command)) {
  process.exit(0);
}
process.stderr.write(
  'Commande refusée (agent en lecture seule) : seules les consultations git, avec des options de la liste blanche, sont permises (.claude/hooks/readonly-bash.mjs).\n',
);
process.exit(2);
