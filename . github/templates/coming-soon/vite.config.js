import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";

export default defineConfig({
  plugins: [vue()],
  // For GitHub Pages project sites use "/<repo>/"
  base: process.env.BASE_PATH ?? "/",
});
