
module.exports = async () => {
  const fs = require("fs");

  const answers = JSON.parse(fs.readFileSync("/tmp/autoui-answers.json", "utf8"));

  const productName = answers.product_name || 
  const tagline = answers.tagline || 
  const offerType = answers.offer_type || 
  const primaryCta = answers.primary_cta || 
  const brandTone = answers.brand_tone || 
  const chartStyle = answers.chart_style || 
  const framework = answers.framework || 
  const chartLib = answers.chart_lib || 
  const modalUsage = answers.modal_usage || 

  const landingTemplate = fs.readFileSync(".github/templates/autoui/Landing.vue.template", "utf8");
  const statsChartTemplate = fs.readFileSync(".github/templates/autoui/StatsChart.vue.template", "utf8");

  const landingContent = landingTemplate
    .replace(/\\[object Object\\]/g, "") // Simple template replacement
    .replace(/\${PRODUCT_NAME}/g, productName)
    .replace(/\${TAGLINE}/g, tagline)
    .replace(/\${OFFER_TYPE}/g, offerType)
    .replace(/\${PRIMARY_CTA}/g, primaryCta)
    .replace(/\${BRAND_TONE}/g, brandTone);

  const statsChartContent = statsChartTemplate
    .replace(/\\[object Object\\]/g, "") // Simple template replacement
    .replace(/\${CHART_STYLE}/g, chartStyle)
    .replace(/\${FRAMEWORK}/g, framework)
    .replace(/\${CHART_LIB}/g, chartLib)
    .replace(/\${MODAL_USAGE}/g, modalUsage);

  fs.mkdirSync("coming-soon/src/components", { recursive: true });
  fs.writeFileSync("coming-soon/src/Landing.vue", landingContent);
  fs.writeFileSync("coming-soon/src/components/StatsChart.vue", statsChartContent);

  const appVueContent = `
<script setup>
import Landing from "./Landing.vue";
</script>

<template>
  <Landing />
</template>
`;
  fs.writeFileSync("coming-soon/src/App.vue", appVueContent);
};
