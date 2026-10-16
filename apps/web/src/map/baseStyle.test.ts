import { validateStyleMin } from '@maplibre/maplibre-gl-style-spec';
import { describe, expect, it } from 'vitest';
import { BACKGROUND_COLOR, baseStyle } from './baseStyle';

describe('baseStyle', () => {
  it('est un style MapLibre valide', () => {
    expect(validateStyleMin(baseStyle)).toEqual([]);
  });

  it('ne contient que la couche de fond, sans source', () => {
    expect(Object.keys(baseStyle.sources)).toEqual([]);
    expect(baseStyle.layers).toEqual([
      { id: 'background', type: 'background', paint: { 'background-color': BACKGROUND_COLOR } },
    ]);
  });
});
