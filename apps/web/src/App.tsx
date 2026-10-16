import { useState } from 'react';
import { Map as MapView } from 'react-map-gl/maplibre';
import { baseStyle } from './map/baseStyle';

export function App() {
  // Marqueur posé quand MapLibre émet `load` : les tests de bout en bout l'attendent.
  const [loaded, setLoaded] = useState(false);

  return (
    <div className="map-container" data-map-loaded={loaded ? 'true' : 'false'}>
      <MapView
        initialViewState={{ longitude: 7.5, latitude: 48.6, zoom: 4 }}
        mapStyle={baseStyle}
        onLoad={() => setLoaded(true)}
        style={{ width: '100%', height: '100%' }}
      />
    </div>
  );
}
