---
name: project-status
description: Résume l'état du projet — fait, en cours, bloqué, décisions en attente, prochaines étapes — à partir de la roadmap, des specs, des ADR et de git.
disable-model-invocation: true
allowed-tools: Read Grep Glob Bash(git status *) Bash(git log *) Bash(git branch *)
---

Lis `docs/roadmap.md`, `docs/specs/`, les ADR au statut « proposé », les fiches au statut `proposée` de `docs/data-sources.md`, les révisions proposées des documents de référence, et l'état git (`git branch --show-current`, `git status --short`, `git log --oneline -15`, `git branch`). Ne modifie rien.

Rends, en français et brièvement :

- **Fait** : jalons et tâches cochés, les plus récents d'abord.
- **En cours** : tâches `(en cours)`, branches ouvertes, modifications non commitées.
- **Bloqué** : la tâche et sa cause (prérequis, décision attendue, source manquante).
- **Décisions en attente** : ce qui attend la validation du mainteneur (ADR proposés, sources `proposée`, révisions de documents).
- **Prochaines étapes** : les trois prochaines tâches dans l'ordre de la roadmap, en signalant celles qui n'ont pas de spec.
