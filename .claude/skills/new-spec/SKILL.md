---
description: Interroge le mainteneur sur une fonctionnalité, rédige sa spec dans docs/specs/ et l'ajoute à docs/roadmap.md.
argument-hint: "[fonctionnalité]"
disable-model-invocation: true
---

1. **Contexte** : lis `CLAUDE.md`, `docs/roadmap.md`, `docs/specs/README.md`, et les documents de référence du sujet `$ARGUMENTS`. Repère ce qu'ils tranchent déjà : tu ne reposes pas une question qu'un document a déjà tranchée, tu la cites.
2. **Entretien** : pose tes questions avec AskUserQuestion, quatre au plus par tour, options concrètes et recommandation en premier. Couvre : objectif et public, critères d'acceptation vérifiables, hors périmètre, données et sources (avec leur licence), choix éditoriaux (règle 2), dépendances, phase et position dans la roadmap. Continue tant qu'un critère d'acceptation reste invérifiable.
3. **Rédaction** : depuis `main` à jour, crée la branche `docs/spec-<sujet>` (règle 8). Écris `docs/specs/<sujet-en-kebab-case>.md` selon le gabarit de `docs/specs/README.md`, **statut « proposé »**. Ajoute la spec à l'index du README.
4. **Roadmap** : ajoute la tâche (ou les tâches) à la phase et à la position choisies, avec le lien vers la spec. Une nouvelle source va dans `docs/data-sources.md` au statut « envisagée ».
5. **Présentation** : montre la spec et le diff de la roadmap. ⏸ Arrête-toi : le mainteneur valide ou corrige. Passe la spec à « validé » seulement sur son accord explicite pour ce contenu. Pas de commit sans accord ; après accord, `bash check.sh`, `git commit -s`, puis fusion dans `main` avant tout `/next-task` sur cette spec.
