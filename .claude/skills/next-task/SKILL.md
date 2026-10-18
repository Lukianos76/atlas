---
description: Prend la prochaine tâche de docs/roadmap.md, la fait planifier, attend la validation du mainteneur, puis l'implémente, la vérifie, la fait relire et met à jour le pilotage.
argument-hint: "[titre de tâche facultatif]"
disable-model-invocation: true
---

Déroule la boucle suivante. **Les points d'arrêt marqués ⏸ terminent ta réponse** : tu ne continues qu'après une réponse explicite du mainteneur.

## 1. Choisir

- Lis `docs/roadmap.md`. Si `$ARGUMENTS` est donné, prends cette tâche ; sinon, la première tâche non cochée, ni bloquée ni en cours, de la première phase non terminée. Une tâche annotée *mainteneur* n'est pas prise : signale-la comme étape qui attend le mainteneur, et passe à la suivante.
- Vérifie `git status` : arbre propre, sur `main` à jour. Sinon, signale-le et ⏸.
- Si la tâche n'a pas de spec (hors « Spec : sans objet » dans la roadmap), ou une spec au statut « proposé », propose `/new-spec` ou la validation de la spec, et ⏸.

## 2. Planifier

- Lance le sous-agent `planner` sur la tâche et sa spec.
- Présente son plan **en entier**, en tête les décisions qui reviennent au mainteneur (options et recommandation). Ajoute ce que tu contestes dans le plan.
- ⏸ Attends la validation du plan et les réponses aux décisions.

## 3. Implémenter

- Crée la branche `<type>/<sujet-court>` depuis `main` (règle 8). Annote la tâche *en cours : branche `x`* dans la roadmap.
- Implémente le plan validé. Tout écart au plan (découverte, impasse) : arrête-toi, explique, ⏸.
- Nouvelle source de données : entrée dans `docs/data-sources.md` au statut « envisagée », signalée au mainteneur.

## 4. Vérifier

- `bash check.sh` complet sur l'état final (Docker démarré si besoin ; aucune étape sautée ; en CI, voir l'exception du bac à sable dans CLAUDE.md, Mode CI). Pour un lot d'import : contrôles §10.5. Pour des tuiles : contrôles d'export de l'ADR 0004.
- Corrige et relance jusqu'à ce que tout soit OK. Si ce n'est pas possible, rapporte l'échec tel quel : la tâche n'est pas terminée.

## 5. Relire

- Lance `reviewer`. En parallèle, lance `data-verifier` si le diff touche des données, des sources, des fixtures, des pipelines d'import ou des textes affichés.
- Corrige les constats bloquants et « à corriger », puis relance `check.sh`. Les constats que tu ne corriges pas sont rapportés, avec la raison.

## 6. Mettre à jour le pilotage

- Roadmap : coche la tâche et retire l'annotation *en cours*. Spec : critères d'acceptation cochés, statut « livré ».
- Décision d'architecture prise pendant la tâche : nouvel ADR dans `docs/adr/` au format des existants, **statut « proposé »**.
- Relance `bash check.sh` si ces fichiers ont changé.

## 7. Présenter

- Résumé, résultat du récapitulatif de `check.sh`, conclusions des relecteurs, diff complet (dans un fichier du scratchpad s'il est long, chemin absolu donné).
- Message de commit proposé (conventionnel, en français, `Signed-off-by` via `git commit -s`).
- ⏸ Ne commite qu'après accord explicite. Ne pousse ni ne fusionne sans demande.
