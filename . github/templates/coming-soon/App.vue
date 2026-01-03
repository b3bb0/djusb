<template>
  <main class="wrap">
    <section class="card">
      <p class="badge">Coming Soon</p>
      <h1>{{ title }}</h1>
      <p class="sub">
        We’re building something new. Leave your email and we’ll let you know when it’s live.
      </p>

      <form class="form" @submit.prevent="submitted = true">
        <input v-model="email" type="email" required placeholder="you@example.com" />
        <button type="submit">Notify me</button>
      </form>

      <p v-if="submitted" class="ok">Thanks! We’ll be in touch.</p>

      <footer class="footer">
        <span>© {{ new Date().getFullYear() }} {{ brand }}</span>
        <span class="dot">•</span>
        <a :href="socialUrl" target="_blank" rel="noreferrer">Social</a>
      </footer>
    </section>
  </main>
</template>

<script setup>
import { ref } from "vue";

const brand = "YourBrand";
const title = "A better way to do X";
const socialUrl = "https://example.com";

const email = ref("");
const submitted = ref(false);
</script>

<style scoped>
.wrap { min-height: 100vh; display: grid; place-items: center; padding: 24px; font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif; }
.card { width: min(680px, 100%); border: 1px solid #e6e6e6; border-radius: 18px; padding: 28px; }
.badge { display: inline-block; padding: 6px 10px; border: 1px solid #ddd; border-radius: 999px; font-size: 12px; margin: 0 0 10px; }
h1 { margin: 6px 0 10px; font-size: 42px; line-height: 1.1; }
.sub { margin: 0 0 18px; color: #444; }
.form { display: flex; gap: 10px; margin: 10px 0 8px; }
input { flex: 1; padding: 12px 12px; border-radius: 12px; border: 1px solid #ccc; }
button { padding: 12px 14px; border-radius: 12px; border: 1px solid #999; background: white; cursor: pointer; }
.ok { margin: 10px 0 0; color: #0a7a2f; }
.footer { margin-top: 18px; display: flex; gap: 10px; align-items: center; color: #666; font-size: 14px; }
.dot { opacity: 0.6; }
a { color: inherit; }
</style>
