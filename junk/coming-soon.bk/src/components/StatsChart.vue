<template>
  <div ref="el" style="width: 100%; height: 240px;"></div>
</template>

<script setup>
import { onMounted, onBeforeUnmount, ref } from "vue";
import { Chart } from "@antv/g2";

const el = ref(null);
let chart;

onMounted(() => {
  chart = new Chart({ container: el.value, autoFit: true, height: 240 });
  chart.data([
    { metric: "Backups", value: 80 },
    { metric: "Verified", value: 90 },
    { metric: "Restores", value: 70 }
  ]);
  chart.interval().encode("x", "metric").encode("y", "value");
  chart.render();
});

onBeforeUnmount(() => {
  chart?.destroy();
});
</script>
