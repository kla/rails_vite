import { defineConfig } from 'vite'
import { fileURLToPath } from 'url'
import { dirname } from 'path'

const base = '/vite'
const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

// https://vite.dev/config/
export default defineConfig({
  root: `${__dirname}/app/javascript`,
  base,
  server: {
    allowedHosts: ['localhost'],
    port: 5173,
    host: '0.0.0.0',
    watch: {
      ignored: ['**/vite.config.ts']
    }
  },
  build: {
    outDir: `${__dirname}/public/${base}`,
    emptyOutDir: true,
    rollupOptions: {
      input: 'app/javascript/application.ts'
    },
    assetsInlineLimit: 0,
    sourcemap: true,
    manifest: true,
  }
})
