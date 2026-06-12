import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Static SPA served by nginx (same as the old Flutter build). The backend URL
// is baked in at build time via VITE_BACKEND_URL.
export default defineConfig({
  plugins: [react()],
  build: { outDir: 'dist', chunkSizeWarningLimit: 1500 },
})
