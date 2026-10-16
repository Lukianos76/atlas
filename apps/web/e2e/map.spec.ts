import { expect, test, type Worker } from '@playwright/test';

test('la carte vide se charge sur fond sombre, sans erreur', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('console', (message) => {
    if (message.type() === 'error') {
      errors.push(message.text());
    }
  });
  const workers: Worker[] = [];
  page.on('worker', (worker) => workers.push(worker));

  await page.goto('/');

  // Événement `load` de MapLibre : style chargé et premier rendu effectué.
  await expect(page.locator('[data-map-loaded="true"]')).toBeVisible({ timeout: 30_000 });

  const canvas = page.locator('canvas.maplibregl-canvas');
  await expect(canvas).toBeVisible();

  // Le canvas porte bien un contexte WebGL 2 (rendu matériel ou logiciel).
  const hasWebGl2 = await canvas.evaluate(
    (element) => element instanceof HTMLCanvasElement && element.getContext('webgl2') !== null,
  );
  expect(hasWebGl2).toBe(true);

  // Le worker de MapLibre a démarré et son module s'est exécuté : il expose
  // `registerWorkerSource`. Un worker mal configuré (ADR 0001) échoue ici.
  expect(workers.length).toBeGreaterThan(0);
  const workerReady = await Promise.all(
    workers.map((worker) => worker.evaluate(() => 'registerWorkerSource' in self)),
  );
  expect(workerReady).toContain(true);

  expect(errors).toEqual([]);
});
