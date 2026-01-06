
module.exports = async ({ github, context, core, issueNumber }) => {
  const fs = require("fs");

  const cfg = JSON.parse(fs.readFileSync(".github/templates/autoui/questions.json", "utf8"));

  const { data: issue } = await github.rest.issues.get({
    owner: context.repo.owner,
    repo: context.repo.repo,
    issue_number: issueNumber,
  });

  const { data: comments } = await github.rest.issues.listComments({
      owner: context.repo.owner,
      repo: context.repo.repo,
      issue_number: issueNumber,
  });

  const labels = issue.labels.map(l => typeof l === 'string' ? l : l.name);
  const hasLabel = labels.includes("AutoUI");

  core.setOutput("has_label", hasLabel ? "true" : "false");
  core.setOutput("issue_number", String(issueNumber));
  core.setOutput("issue_title", issue.title || "");

  if (!hasLabel) {
    core.setOutput("complete", "false");
    core.setOutput("next_question", "");
    core.setOutput("status_block", "AutoUI label missing.");
    return;
  }

  const allQuestions = cfg.sections.flatMap(s => s.questions.map(q => ({ ...q, section: s })));

  const textBlob = [
    issue.body || "",
    ...(comments || []).map(c => c.body || "")
  ].join("\n\n");

  const answers = {};
  for (const q of allQuestions) {
    const re = new RegExp(`(?:^|\\n)\\s*${q.key}\\s*(?:=|:)\\s*([^\\n]+)`, "i");
    const m = textBlob.match(re);
    if (m && m[1]) answers[q.key] = m[1].trim();
  }

  const botLogin = "github-actions[bot]";
  const lastHuman = [...(comments || [])].reverse().find(c => c.user?.login !== botLogin);
  const wantsSkip = lastHuman ? /(^|\\s)(skip|next)(\\s|$)/i.test(lastHuman.body || "") : false;

  const nextQ = allQuestions.find(q => !answers[q.key]);

  const status = cfg.sections.map(s => {
    const lines = s.questions.map(q => {
      const v = answers[q.key];
      if (!v) return '- `' + q.key + '`: ❌';
      if (String(v).toUpperCase() === "__SKIP__")
        return '- `' + q.key + '`: ⏭️ skipped';
      return '- `' + q.key + '`: ✅ ' + v ;
    });
    return `### ${s.title}\n${lines.join("\n")}`;
  }).join("\n\n");
  
  fs.writeFileSync("/tmp/autoui-answers.json", JSON.stringify(answers, null, 2));

  core.setOutput("complete", nextQ ? "false" : "true");
  core.setOutput("wants_skip", wantsSkip ? "true" : "false");
  core.setOutput("pending_key", nextQ?.key || "");
  core.setOutput("section_id", nextQ?.section?.id || "");
  core.setOutput("section_title", nextQ?.section?.title || "");
  core.setOutput("section_intro", nextQ?.section?.intro || "");
  core.setOutput("section_links", (nextQ?.section?.links || []).map(l => `- ${l}`).join("\n"));
  core.setOutput("status_block", status);

  if (nextQ) {
    const opts = (nextQ.options && nextQ.options.length)
      ? `\n\n**Options:**\n${nextQ.options.map(o => `- ${o}`).join("\n")}`
      : "";
    core.setOutput(
      "next_question",
      `${nextQ.ask}${opts}\n\nReply with:\n- \`${nextQ.key}=...\`\n- or \`skip\` / \`next\``
    );
  } else {
    core.setOutput("next_question", "");
  }
};
