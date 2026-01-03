import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";

export default defineConfig({
  plugins: [vue()],
  // Set by workflow: VITE_BASE="/beta/d-123/"
  base: process.env.VITE_BASE || "/beta/"
});
