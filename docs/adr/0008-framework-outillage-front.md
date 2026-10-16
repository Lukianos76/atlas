# ADR 0008 — Framework et outillage du front

- **Statut** : proposé
- **Date** : 2026-10-16

## Contexte

La carte est dessinée en WebGL par MapLibre GL JS (ADR 0001), puis par deck.gl pour les flux et les densités (ADR 0002), indépendamment du framework. Le framework ne gère que l'interface autour de la carte :

- le curseur temporel ;
- le choix du point de vue, toujours explicite (`docs/modele-donnees.md`, §10.3) ;
- l'affichage des sources et des citations de chaque valeur ;
- les assertions concurrentes et la mention « non tranché » ;
- la distinction entre données originales et dérivées.

Le front est publié en fichiers statiques (ADR 0007), dans le monorepo (ADR 0005). Le projet est contributif et la performance est un critère de premier rang.

**Contrainte de performance** : pendant que le curseur temporel bouge, la carte doit être pilotée directement par l'API MapLibre (`setFilter`, `setFeatureState`), sans repasser par le cycle de rendu du framework.

Vérification faite avec Context7 (octobre 2026) : react-map-gl 8.1 (`react-map-gl/maplibre`) prend en charge MapLibre GL JS v4, v5 et v6. Avec la v6, il faut des imports nommés ou par espace de noms, et configurer le worker avec le bundler.

## Options envisagées

| Option | Points forts | Limites |
|---|---|---|
| **A. React + Vite + TypeScript**, avec `react-map-gl/maplibre` | Le plus grand écosystème et le plus de contributeurs potentiels. Compatible avec MapLibre v6. deck.gl a une intégration React officielle | Runtime plus lourd. Il faut veiller à ne pas faire passer le curseur par les re-rendus de React |
| B. Svelte 5 / SvelteKit en statique + `svelte-maplibre-gl` | Runtime léger, réactivité simple | Intégration de deck.gl à écrire à la main. Écosystème plus petit |
| C. Vue 3 + `vue-maplibre-gl` | Bon compromis, lisible | Écosystème cartographique plus mince que celui de React |
| D. TypeScript sans framework + Vite | Contrôle et performance maximaux | Toute l'interface (sources, points de vue, historique) à construire soi-même |

## Décision

*En attente de validation.* Option recommandée : **A, React + Vite + TypeScript**, avec `react-map-gl/maplibre`.

Outillage recommandé : pnpm, Vite, TypeScript en mode strict, Vitest pour les tests unitaires, Playwright pour les tests de bout en bout. Le lint et le formatage restent à choisir (Biome, ou ESLint + Prettier).

## Conséquences

Si l'option recommandée est retenue :

- le front est une application statique construite par Vite, servie depuis le stockage objet (ADR 0007) ;
- le curseur temporel et la jointure des valeurs passent par l'API impérative de MapLibre, pas par l'état React ; cette règle fait partie de la relecture du code du front ;
- deck.gl s'intègrera, quand il arrivera (ADR 0002), par son intégration React officielle ;
- le gestionnaire de paquets TypeScript laissé ouvert par l'ADR 0005 est fixé à pnpm.
