// Configuration du worker de MapLibre 6 pour Vite (ADR 0001 et 0008).
// `?worker&url` et non `?url` : le worker importe `maplibre-gl-shared.mjs`,
// que `?url` n'embarque pas au build de production d'après la doc MapLibre v6.
import { setWorkerUrl } from 'maplibre-gl';
import workerUrl from 'maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url';

setWorkerUrl(workerUrl);
