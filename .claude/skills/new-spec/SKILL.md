---
name: new-spec
description: Interroge le mainteneur sur une fonctionnalité, rédige sa spec dans docs/specs/ et l'inscrit dans docs/roadmap.md.
argument-hint: "[fonctionnalité]"
disable-model-invocation: true
---

Fonctionnalité : $ARGUMENTS

1. Lis `docs/roadmap.md`, les specs existantes et les documents de référence du sujet (table de `CLAUDE.md`), pour ne poser que les questions que les documents ne tranchent pas.
2. Interroge le mainteneur (AskUserQuestion, quatre questions au plus par série) : objectif et public, comportement attendu, données et sources envisagées, critères d'acceptation vérifiables, hors périmètre, dépendances, place dans la roadmap. Propose une réponse recommandée quand les documents en suggèrent une.
3. Rédige la spec selon `docs/specs/_gabarit.md`. Aucune donnée, source ni licence inventée : ce qui n'est pas connu est écrit « à déterminer » et devient une question ouverte.
4. Présente la spec et l'entrée de roadmap proposée (jalon, position, identifiant). **Arrête-toi et attends l'approbation.**
5. Après approbation : écris `docs/specs/NNN-<slug>.md` (numéro suivant) et ajoute la tâche à la roadmap, avec le lien vers la spec.
