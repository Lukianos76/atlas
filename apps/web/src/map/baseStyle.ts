import type { StyleSpecification } from 'maplibre-gl';

// Couleur provisoire du fond sombre, validée pour le squelette. Elle sera reprise
// dans `styles/` avec le fond Protomaps recoloré (ADR 0004).
export const BACKGROUND_COLOR = '#0b0f14';

// Style minimal : aucune source, une seule couche de fond.
export const baseStyle: StyleSpecification = {
  version: 8,
  sources: {},
  layers: [
    {
      id: 'background',
      type: 'background',
      paint: { 'background-color': BACKGROUND_COLOR },
    },
  ],
};
