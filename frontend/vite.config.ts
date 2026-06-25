import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

const proxyTarget = process.env.BACKEND_PROXY_TARGET ?? 'http://localhost:3001';

export default defineConfig({
  plugins: [sveltekit()],
  server: {
    host: true,
    port: 5173,
    proxy: {
      '/api': proxyTarget
    }
  }
});
