# Refactoring Guide: Before & After

This document explains the refactoring changes and how they improve maintainability.

## Problem Statement

The original workflows had several issues:

1. **Repetitive if conditions** across multiple steps
2. **Code duplication** (parsing and generation logic repeated)
3. **Discussion-based triggers** (hard to adapt to other event types)
4. **Mixed concerns** (validation, parsing, generation, deployment in one file)
5. **Difficult to test** (logic embedded in workflow YAML)

## Solution: Modular Architecture

### Before: Monolithic Workflow

```
autoui-preview-bot.yml (253 lines)
├── Trigger: discussion events
├── Step 1: Checkout
├── Step 2: Verify templates
├── Step 3: Parse discussion (inline script)
├── Step 4: Persist skip marker (if condition)
├── Step 5: Render reply (if condition)
├── Step 6: Comment question (if condition)
├── Step 7: Setup Node (if condition)
├── Step 8: Generate Vue (if condition)
├── Step 9: Install & Build (if condition)
├── Step 10: Deploy (if condition)
└── Step 11: Comment URL (if condition)

autoui-finalize.yml (221 lines)
├── Trigger: discussion answered
├── Step 1: Checkout
├── Step 2: Setup Node
├── Step 3: Verify templates
├── Step 4: Parse discussion (inline script - DUPLICATE)
├── Step 5: Comment params
├── Step 6: Create branch
├── Step 7: Generate Vue (DUPLICATE)
├── Step 8: Commit & push
├── Step 9: Create PR
└── Step 10: Comment PR link
```

### After: Modular Architecture

```
autoui-main.yml (11 lines)
└── Trigger: issue events
    └── Calls: autoui-reusable.yml

autoui-reusable.yml (120 lines)
├── Job: decide
│   └── Calls: parse-issue.js
├── Job: ask_question (if incomplete)
├── Job: preview (if complete)
└── Job: finalize (if closed + label)

parse-issue.js (80 lines)
└── Reusable parsing logic

generate-vue-files.js (40 lines)
└── Reusable generation logic
```

## Key Changes

### 1. Trigger Separation

**Before:**
```yaml
# autoui-preview-bot.yml
on:
  discussion:
    types: [created, labeled, edited]
  discussion_comment:
    types: [created, edited]

jobs:
  autoui_preview:
    runs-on: ubuntu-latest
    steps:
      - name: Parse discussion + decide
        uses: actions/github-script@v7
        with:
          script: |
            const discussionId = context.payload.discussion.node_id
            # 50+ lines of inline script
```

**After:**
```yaml
# autoui-main.yml
on:
  issues:
    types: [opened, edited, labeled]
  issue_comment:
    types: [created, edited]

jobs:
  run_autoui:
    uses: ./.github/workflows/refactored/autoui-reusable.yml
    with:
      issue_number: ${{ github.event.issue.number }}
```

**Benefits:**
- ✅ Trigger logic is isolated in one file
- ✅ Easy to change triggers without touching core logic
- ✅ Can create multiple trigger files (e.g., `autoui-webhook.yml`) that call the same reusable workflow

### 2. Conditional Logic

**Before:**
```yaml
- name: Persist skip marker
  if: ${{ steps.decide.outputs.has_label == 'true' && steps.decide.outputs.wants_skip == 'true' && steps.decide.outputs.pending_key != '' }}
  uses: actions/github-script@v7
  with:
    script: |
      # ...

- name: Render reply
  if: ${{ steps.decide.outputs.has_label == 'true' && steps.decide.outputs.complete == 'false' }}
  shell: bash
  run: |
    # ...

- name: Comment next question
  if: ${{ steps.decide.outputs.has_label == 'true' && steps.decide.outputs.complete == 'false' }}
  uses: actions/github-script@v7
  with:
    script: |
      # ...

- name: Setup Node
  if: ${{ steps.decide.outputs.has_label == 'true' && steps.decide.outputs.complete == 'true' }}
  uses: actions/setup-node@v4
  with:
    node-version: 20

# ... 5 more steps with the same conditions
```

**After:**
```yaml
jobs:
  decide:
    runs-on: ubuntu-latest
    outputs:
      has_label: ${{ steps.parse.outputs.has_label }}
      complete: ${{ steps.parse.outputs.complete }}
    steps:
      - uses: actions/checkout@v4
      - id: parse
        uses: actions/github-script@v7
        with:
          script: |
            const script = require("./.github/scripts/parse-issue.js");
            await script({ github, context, core, issueNumber: ${{ inputs.issue_number }} });

  ask_question:
    needs: decide
    if: "${{ needs.decide.outputs.has_label == 'true' && needs.decide.outputs.complete == 'false' }}"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Render and comment
        uses: actions/github-script@v7
        with:
          script: |
            # Only this job runs when incomplete

  preview:
    needs: decide
    if: "${{ needs.decide.outputs.has_label == 'true' && needs.decide.outputs.complete == 'true' }}"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      # Only this job runs when complete
```

**Benefits:**
- ✅ Conditions are at job level, not step level
- ✅ No repeated conditions across multiple steps
- ✅ Each job has a single responsibility
- ✅ Easier to read and understand flow

### 3. Code Extraction

**Before:**
```yaml
# autoui-preview-bot.yml - 50 lines of inline script
- name: Parse discussion + decide next question
  id: decide
  uses: actions/github-script@v7
  with:
    script: |
      const fs = require("fs");
      const cfg = JSON.parse(fs.readFileSync(".github/templates/autoui/questions.json", "utf8"));
      const discussionId = context.payload.discussion.node_id;
      # ... 40 more lines ...

# autoui-finalize.yml - SAME 50 lines of script DUPLICATED
- name: Parse discussion answers (authoritative)
  id: parse
  uses: actions/github-script@v7
  with:
    script: |
      const fs = require("fs");
      const cfg = JSON.parse(fs.readFileSync(".github/templates/autoui/questions.json", "utf8"));
      const discussionId = context.payload.discussion.node_id;
      # ... 40 more lines (DUPLICATE) ...
```

**After:**
```yaml
# .github/scripts/parse-issue.js
module.exports = async ({ github, context, core, issueNumber }) => {
  const fs = require("fs");
  const cfg = JSON.parse(fs.readFileSync(".github/templates/autoui/questions.json", "utf8"));
  const { data: issue } = await github.rest.issues.get({
    owner: context.repo.owner,
    repo: context.repo.repo,
    issue_number: issueNumber,
  });
  # ... logic ...
};

# autoui-reusable.yml - SINGLE REFERENCE
- id: parse
  uses: actions/github-script@v7
  with:
    script: |
      const script = require("./.github/scripts/parse-issue.js");
      await script({ github, context, core, issueNumber: ${{ inputs.issue_number }} });
```

**Benefits:**
- ✅ Single source of truth for parsing logic
- ✅ Easy to test and debug (can run script locally)
- ✅ Reusable across multiple workflows
- ✅ Easier to maintain and update

### 4. Job Outputs

**Before:**
```yaml
# Had to pass outputs through context.payload
- name: Comment next question
  if: ${{ steps.decide.outputs.has_label == 'true' && steps.decide.outputs.complete == 'false' }}
  uses: actions/github-script@v7
  with:
    script: |
      # Had to manually extract from context
      const d = context.payload.discussion.number;
```

**After:**
```yaml
jobs:
  decide:
    outputs:
      has_label: ${{ steps.parse.outputs.has_label }}
      complete: ${{ steps.parse.outputs.complete }}
      issue_number: ${{ steps.parse.outputs.issue_number }}

  ask_question:
    needs: decide
    steps:
      - name: Comment
        uses: actions/github-script@v7
        with:
          script: |
            # Clean, explicit access to outputs
            const issue_number = ${{ needs.decide.outputs.issue_number }};
```

**Benefits:**
- ✅ Explicit job dependencies
- ✅ Clear data flow between jobs
- ✅ Type-safe (outputs are declared)
- ✅ Easier to debug

## Comparison Table

| Aspect | Before | After |
|--------|--------|-------|
| **Total Lines** | 474 | 280 |
| **Code Duplication** | ~100 lines | 0 lines |
| **Conditional Logic** | Step-level (messy) | Job-level (clean) |
| **Reusability** | None | High (scripts + reusable workflow) |
| **Testability** | Hard (embedded in YAML) | Easy (standalone scripts) |
| **Trigger Flexibility** | Fixed (discussion) | Flexible (any event) |
| **Maintainability** | Low | High |

## Migration Checklist

- [ ] Backup old workflows
- [ ] Copy new workflow files
- [ ] Update repository settings (if needed)
- [ ] Test with a new issue
- [ ] Verify preview deployment
- [ ] Verify PR creation
- [ ] Delete old workflows
- [ ] Update documentation

## Testing the Refactored Workflows

### Local Testing

Test the parsing script locally:

```bash
# Copy templates to local directory
mkdir -p .github/templates/autoui
cp your-templates/* .github/templates/autoui/

# Run parsing script
node .github/scripts/parse-issue.js
```

### GitHub Actions Testing

1. Create a test issue with `AutoUI` label
2. Monitor workflow runs in Actions tab
3. Check logs for any errors
4. Verify comments are posted correctly

### Rollback Plan

If issues occur:

```bash
# Restore old workflows
mv .github/workflows/old/autoui-*.yml .github/workflows/

# Disable new workflows
rm .github/workflows/refactored/autoui-main.yml
```

## Future Improvements

With this modular architecture, you can easily:

1. **Add new triggers** without changing core logic
2. **Add new jobs** (e.g., approval, notifications)
3. **Extract more logic** into reusable scripts
4. **Create workflow variants** (e.g., for different templates)
5. **Add comprehensive testing** (unit tests for scripts)
6. **Integrate with external services** (Slack, Discord, etc.)

## Questions?

Refer to the main README.md for more details on usage and configuration.
