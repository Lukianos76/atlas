---
name: next-task
description: Mène la prochaine tâche de docs/roadmap.md de bout en bout — plan par planner, validation du mainteneur, implémentation, vérifications, relecture, mise à jour de la roadmap.
argument-hint: "[identifiant de tâche, ex. T2.3]"
disable-model-invocation: true
---

Tâche demandée : $ARGUMENTS (vide : la suivante).

## 1. Choisir la tâche

- `git status` et `git branch --show-current` : signale toute modification non commitée, sans y toucher.
- Dans `docs/roadmap.md`, prends la tâche indiquée ; sinon, la première case non cochée du premier jalon non terminé dont les dépendances sont cochées. Une tâche « bloquée » est sautée et signalée.
- Sans spec liée : arrête-toi et propose `/new-spec`.

## 2. Planifier

Lance le sous-agent `planner` avec l'identifiant de la tâche et le chemin de sa spec. Relis son plan contre la spec et les documents de référence.

## 3. Présenter et ATTENDRE

Présente le plan, les vérifications prévues, la branche proposée (`feat/…`, `fix/…`, `docs/…` ou `chore/…`, depuis `main`) et les **décisions qui reviennent au mainteneur**, chacune avec une option recommandée.

**Arrête-toi là et termine ton tour.** Ne poursuis qu'après une approbation explicite du plan, dans un nouveau message. Une réponse partielle ou une question n'est pas une approbation. N'écris jamais qu'un élément est « validé » sans cette approbation.

## 4. Implémenter (après approbation)

- Crée la branche. Marque la tâche `(en cours)` dans la roadmap.
- Implémente étape par étape, selon `CLAUDE.md` et les documents de référence. Une décision nouvelle surgit : arrête-toi et demande.

## 5. Vérifier

Lance `bash check.sh` avec les options des composants touchés (règle 4), plus les contrôles du §10.5 ou de l'ADR 0004 s'ils s'appliquent. Corrige et relance. Une vérification qui échoue ou qui n'a pas été lancée est rapportée telle quelle : la tâche n'est pas terminée.

## 6. Relire

- Lance `reviewer`. Si le diff touche des données (extraits de test, `db/reference/`, citations, `docs/data-sources.md`, fichiers de valeurs), lance aussi `data-verifier`.
- Corrige les constats bloquants et à corriger, relance les vérifications, puis une seconde relecture si des corrections ont été faites. Les suggestions écartées sont listées avec leur raison.

## 7. Clore

- Coche la tâche dans `docs/roadmap.md` et les critères atteints de la spec.
- Si une décision d'architecture a été prise : rédige un ADR dans `docs/adr/` (gabarit `docs/adr/_gabarit.md`, numéro suivant), au statut **proposé**.
- Présente : résumé, résultat de chaque vérification, constats des relecteurs et leur traitement, **diff complet**, message de commit proposé (`git commit -s`). Ne commite qu'après approbation explicite.
