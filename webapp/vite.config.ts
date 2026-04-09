import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import svgLoader from 'vite-svg-loader'
// https://vitejs.dev/config/
export default defineConfig({
  base: "/webapp/",
  // Load Vite env vars from repository root (.env), so Coolify can use one env file.
  envDir: '..',
  plugins: [
    vue({
      script: {
        defineModel: true
      }
    }),
    svgLoader({
      defaultImport: 'component',
    }),
  ],
})
