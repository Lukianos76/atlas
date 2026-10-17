---
description: Résume l'état du projet à partir de docs/roadmap.md, des specs, du backlog et de git (fait, en cours, bloqué, prochaines étapes).
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(git status:*), Bash(git log:*), Bash(git branch:*)
---

Lecture seule. Lis `docs/roadmap.md`, `docs/backlog.md`, l'index et les statuts de `docs/specs/`, les ADR au statut « proposé », `docs/data-sources.md` (sources « envisagées » ou « à vérifier »). Puis `git status`, `git branch --list`, `git log --oneline -15`.

Réponds en français, de façon concise :

- **Fait** : jalons et tâches cochés récemment (avec le commit quand c'est possible).
- **En cours** : tâches marquées en cours, branches ouvertes, modifications non commitées.
- **Bloqué** : tâches bloquées, en précisant par quoi ; specs, ADR ou sources en attente de validation.
- **Décisions en attente** : ce qui revient au mainteneur.
- **Prochaines étapes** : les deux ou trois prochaines tâches de la roadmap, et ce qu'il leur manque pour démarrer (spec, validation, prérequis).

N'invente aucun état : ce qui n'est pas écrit dans les fichiers ou dans git est « inconnu ».
