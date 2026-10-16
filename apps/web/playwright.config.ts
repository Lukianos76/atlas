import { defineConfig, devices } from '@playwright/test';

const port = 4173;

export default defineConfig({
  testDir: './e2e',
  forbidOnly: process.env.CI !== undefined,
  retries: 0,
  reporter: process.env.CI !== undefined ? 'github' : 'list',
  use: {
    baseURL: `http://127.0.0.1:${port}`,
  },
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        launchOptions: {
          // Rendu WebGL logiciel sans GPU ni écran (CI, conteneurs), demandé explicitement
          // via ANGLE. Avec Playwright 1.64, le test passe aussi sans ces options sous
          // Linux (vérifié dans mcr.microsoft.com/playwright:v1.64.1-noble), mais Chromium
          // abandonne le repli automatique sur SwiftShader : on ne s'y fie pas.
          args: [
            '--use-angle=swiftshader',
            '--enable-unsafe-swiftshader',
            '--ignore-gpu-blocklist',
          ],
        },
      },
    },
  ],
  // Les tests portent sur le build de production : c'est là qu'un worker mal
  // configuré casse le rendu (ADR 0001).
  webServer: {
    command: `pnpm exec vite build && pnpm exec vite preview --host 127.0.0.1 --port ${port} --strictPort`,
    url: `http://127.0.0.1:${port}`,
    reuseExistingServer: process.env.CI === undefined,
    timeout: 120_000,
  },
});
