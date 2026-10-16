// Le worker doit être configuré avant toute création de carte.
import './map/worker';
import 'maplibre-gl/dist/maplibre-gl.css';
import './index.css';
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './App';

const root = document.getElementById('root');
if (root === null) {
  throw new Error('Élément #root introuvable');
}
createRoot(root).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
