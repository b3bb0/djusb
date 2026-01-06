# AutoUI Refactored Workflows

This directory contains the refactored AutoUI workflows with a modular, maintainable architecture that separates triggers from operations.

## Architecture Overview

The refactored workflows follow a **trigger-operation separation pattern**, making it easy to adapt triggers in the future without changing the core logic.

### File Structure

```
.github/
├── workflows/
│   └── refactored/
│       ├── autoui-main.yml          # Trigger entry point (issues-based)
│       ├── autoui-reusable.yml      # Core operations (reusable workflow)
│       └── README.md                # This file
├── scripts/
│   ├── parse-issue.js               # Issue parsing logic
│   └── generate-vue-files.js        # Vue file generation logic
└── templates/
    └── autoui/
        ├── questions.json
        ├── Landing.vue.template
        └── StatsChart.vue.template
```

## Key Improvements

### 1. **Separated Triggers from Operations**

- **`autoui-main.yml`**: Handles trigger events (issues, comments)
- **`autoui-reusable.yml`**: Contains all business logic (reusable workflow)

This separation allows you to easily change triggers without touching the core logic.

### 2. **Cleaner Conditional Logic**

Instead of repeating conditions like:
```yaml
if: ${{ steps.decide.outputs.has_label == 'true' && steps.decide.outputs.complete == 'true' }}
```

We now use **job-level conditions** with proper outputs:
```yaml
needs: decide
if: "${{ needs.decide.outputs.has_label == 'true' && needs.decide.outputs.complete == 'true' }}"
```

### 3. **Logical Chunks (Jobs)**

The workflow is split into **independent jobs**:

| Job | Purpose | Trigger |
|-----|---------|---------|
| `decide` | Parse issue and determine state | Always runs |
| `ask_question` | Comment next question | When incomplete |
| `preview` | Generate and deploy preview | When complete |
| `finalize` | Create PR from issue | When issue closed + finalize label |

### 4. **Reusable Scripts**

Common logic is extracted into Node.js scripts:

- **`parse-issue.js`**: Parses issue body/comments, extracts answers, determines next question
- **`generate-vue-files.js`**: Generates Vue components from templates and answers

This eliminates code duplication and makes testing easier.

### 5. **Issue-Based Triggers**

Changed from `discussion` events to `issue` events:

```yaml
on:
  issues:
    types: [opened, edited, labeled]
  issue_comment:
    types: [created, edited]
```

## How to Use

### 1. Enable the Workflow

Copy the files to your repository:

```bash
cp -r .github/workflows/refactored/* .github/workflows/
cp -r .github/scripts/* .github/scripts/
```

### 2. Create an Issue

Create a new issue with the `AutoUI` label. The workflow will automatically:
1. Parse the issue
2. Ask the first question as a comment
3. Wait for responses

### 3. Respond to Questions

Comment on the issue with answers in the format:
```
product_name=My Product
tagline=Best solution ever
```

### 4. Generate Preview

Once all questions are answered, the workflow will:
1. Generate Vue components
2. Build the project
3. Deploy to `gh-pages/beta/i-{issue_number}/`
4. Comment with the preview URL

### 5. Finalize to PR

Add the `AutoUI-Finalize` label and close the issue to:
1. Create a branch `ui-issue-{issue_number}`
2. Generate final files
3. Open a PR for review

## Adapting the Triggers

To change how workflows are triggered, **only modify `autoui-main.yml`**:

### Example: Trigger on Pull Request

```yaml
on:
  pull_request:
    types: [opened, synchronize]
    paths:
      - '.github/templates/autoui/**'
```

The reusable workflow will work unchanged!

### Example: Trigger on Webhook

```yaml
on:
  repository_dispatch:
    types: [autoui-start]
```

Then call it with:
```bash
curl -X POST https://api.github.com/repos/{owner}/{repo}/dispatches \
  -H "Authorization: token $GITHUB_TOKEN" \
  -d '{"event_type":"autoui-start","client_payload":{"issue_number":42}}'
```

## Job Outputs

### `decide` Job

| Output | Type | Description |
|--------|------|-------------|
| `has_label` | boolean | Whether AutoUI label is present |
| `complete` | boolean | Whether all questions are answered |
| `wants_skip` | boolean | Whether user requested skip |
| `pending_key` | string | Key of next unanswered question |
| `issue_number` | number | Issue number |

### Downstream Jobs

All downstream jobs receive outputs from `decide` via `needs.decide.outputs.*`

## Extending the Workflow

### Add a New Job

```yaml
  my_custom_job:
    needs: decide
    if: "${{ needs.decide.outputs.has_label == 'true' }}"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "Custom logic here"
```

### Add a New Script

Create `.github/scripts/my-script.js`:

```javascript
module.exports = async ({ github, context, core }) => {
  // Your logic here
};
```

Then use it in a step:

```yaml
- uses: actions/github-script@v7
  with:
    script: |
      const script = require("./.github/scripts/my-script.js");
      await script({ github, context, core });
```

## Troubleshooting

### Workflow not triggering

- Check that `autoui-main.yml` is in `.github/workflows/` (not in subdirectory)
- Verify issue has the `AutoUI` label
- Check workflow permissions in repository settings

### Parse errors

- Ensure `.github/templates/autoui/questions.json` exists
- Verify JSON format is valid
- Check that issue body/comments contain properly formatted answers

### Preview not deploying

- Verify `coming-soon/` directory structure exists
- Check that `npm run build` works locally
- Ensure `gh-pages` branch exists in repository

## Migration from Old Workflows

To migrate from the old discussion-based workflows:

1. **Backup old workflows**: `mv .github/workflows/autoui-*.yml .github/workflows/old/`
2. **Copy new workflows**: `cp -r .github/workflows/refactored/* .github/workflows/`
3. **Update issue templates**: Create issue template with `AutoUI` label pre-selected
4. **Test with a new issue**: Create test issue to verify everything works

## Future Enhancements

Potential improvements (easy to implement with this architecture):

- [ ] Support multiple AutoUI templates (not just Vue + AntV)
- [ ] Add approval workflow before preview deployment
- [ ] Support batch processing (multiple issues)
- [ ] Add metrics/analytics tracking
- [ ] Integrate with external services (Slack, Discord notifications)
- [ ] Add rollback/cleanup jobs
