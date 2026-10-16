# styles — styles de carte MapLibre

Ce dossier accueillera les styles MapLibre de l'atlas (ADR 0001) :

- le **fond de carte sombre**, Protomaps Basemaps auto-hébergé et recoloré par un style propre à l'atlas (ADR 0004) ;
- les couches thématiques natives MapLibre : aplats et cercles proportionnels joints par `feature-state` (ADR 0002).

Les couleurs, palettes et seuils relèvent de la politique éditoriale (`docs/politique-editoriale.md`, §5). Ils sont proposés, jamais appliqués sans validation (CLAUDE.md, règle 2).

En attendant, l'application affiche un fond uni provisoire `#0b0f14`, défini dans `apps/web/src/map/baseStyle.ts`.
