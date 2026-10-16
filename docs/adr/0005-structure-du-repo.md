# ADR 0005 — Structure du repo

- **Statut** : accepté
- **Date** : 2026-10-16

## Contexte

Le projet comprend plusieurs composants :

- une application web en TypeScript (MapLibre GL JS et deck.gl, ADR 0001 et 0002) ;
- le schéma PostGIS et ses migrations (ADR 0003) ;
- les pipelines d'import de données (ADR 0006) ;
- la génération des tuiles (ADR 0004) ;
- les styles de carte ;
- la documentation (vision, modèle de données, ADR).

Le schéma de la base est le **contrat commun** entre ces composants : un changement du modèle touche souvent le schéma, les pipelines et l'application en même temps.

Le projet sera contributif : il faut un point d'entrée clair et une intégration continue unique. Les **données** elles-mêmes vivent dans la base et dans les archives de tuiles, pas dans git.

## Options envisagées

| Option | Points forts | Limites |
|---|---|---|
| **A. Monorepo** | Un changement de schéma, du pipeline et du front se fait dans une seule PR. Une CI, une documentation, un seul lieu où contribuer | Outillage mixte (TypeScript et Python). CI à découper par chemin |
| B. Plusieurs repos (app, pipelines, schéma, styles) | Droits et cycles de version séparés | Contrat de schéma à synchroniser entre repos. Contribution dispersée. Surcoût pour un petit projet |
| C. Monorepo pour le code + repo séparé pour les déclarations d'import (procédures de lots, correspondances de variables) | Les contributeurs « données » n'ont pas à toucher au code | Séparation prématurée tant que le format de ces déclarations n'est pas stabilisé |

## Décision

On retient un **monorepo**, organisé ainsi :

```
apps/web/     application web (TypeScript)
db/           schéma et migrations PostGIS
pipelines/    pipelines d'import (Python)
tiles/        génération des tuiles
styles/       styles de carte MapLibre
docs/         vision, modèle de données, ADR
```

Chaque écosystème a ses propres espaces de travail : un pour TypeScript (front), un pour Python (pipelines).

## Conséquences

- Une évolution du modèle se fait en une seule PR qui couvre le schéma, les pipelines et l'application.
- La CI doit être découpée par chemin, pour ne lancer que les vérifications des composants touchés.
- Deux outillages coexistent dans le repo. Le gestionnaire de paquets côté TypeScript reste à choisir ; côté Python, il découle de l'ADR 0006.
- Un repo séparé pour les déclarations d'import sera **reconsidéré** quand leur format sera stable et que la contribution de données aura commencé.
