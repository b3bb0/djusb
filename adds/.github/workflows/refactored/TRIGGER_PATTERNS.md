# Trigger Patterns - Easy Adaptation Guide

This guide shows how to easily adapt the workflows to different triggers without changing the core logic.

## Core Principle

The **trigger layer** (`autoui-main.yml`) is completely separate from the **operation layer** (`autoui-reusable.yml`). Change triggers by only modifying `autoui-main.yml`.

## Pattern 1: Issue Events (Current)

**File:** `autoui-main.yml`

```yaml
name: AutoUI Main

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
    secrets: inherit
```

**Trigger:** Creates workflow run when issue is created, edited, or labeled.

---

## Pattern 2: Pull Request Events

**File:** `autoui-pr.yml`

```yaml
name: AutoUI on PR

on:
  pull_request:
    types: [opened, synchronize]
    paths:
      - '.github/templates/autoui/**'

jobs:
  run_autoui:
    uses: ./.github/workflows/refactored/autoui-reusable.yml
    with:
      issue_number: ${{ github.event.pull_request.number }}
    secrets: inherit
```

**Trigger:** Creates workflow run when PR is opened or updated.

**Note:** Uses `pull_request.number` instead of `issue.number`.

---

## Pattern 3: Repository Dispatch (Webhook)

**File:** `autoui-webhook.yml`

```yaml
name: AutoUI Webhook

on:
  repository_dispatch:
    types: [autoui-start]

jobs:
  run_autoui:
    uses: ./.github/workflows/refactored/autoui-reusable.yml
    with:
      issue_number: ${{ github.event.client_payload.issue_number }}
    secrets: inherit
```

**Trigger:** Creates workflow run via GitHub API call.

**Usage:**
```bash
curl -X POST https://api.github.com/repos/owner/repo/dispatches \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d '{
    "event_type": "autoui-start",
    "client_payload": {
      "issue_number": 42
    }
  }'
```

---

## Pattern 4: Scheduled (Cron)

**File:** `autoui-scheduled.yml`

```yaml
name: AutoUI Scheduled

on:
  schedule:
    - cron: '0 9 * * MON'  # Every Monday at 9 AM UTC

jobs:
  run_autoui:
    uses: ./.github/workflows/refactored/autoui-reusable.yml
    with:
      issue_number: 1  # Fixed issue number, or fetch dynamically
    secrets: inherit
```

**Trigger:** Creates workflow run on a schedule.

**Note:** For scheduled runs, you might need to fetch the issue number dynamically:

```yaml
jobs:
  find_issue:
    runs-on: ubuntu-latest
    outputs:
      issue_number: ${{ steps.find.outputs.issue_number }}
    steps:
      - uses: actions/github-script@v7
        id: find
        with:
          script: |
            const { data: issues } = await github.rest.issues.list({
              owner: context.repo.owner,
              repo: context.repo.repo,
              labels: 'AutoUI,pending',
              state: 'open',
              per_page: 1,
            });
            core.setOutput('issue_number', String(issues[0]?.number || 1));

  run_autoui:
    needs: find_issue
    uses: ./.github/workflows/refactored/autoui-reusable.yml
    with:
      issue_number: ${{ needs.find_issue.outputs.issue_number }}
    secrets: inherit
```

---

## Pattern 5: Manual Trigger (Workflow Dispatch)

**File:** `autoui-manual.yml`

```yaml
name: AutoUI Manual

on:
  workflow_dispatch:
    inputs:
      issue_number:
        description: 'Issue number to process'
        required: true
        type: number

jobs:
  run_autoui:
    uses: ./.github/workflows/refactored/autoui-reusable.yml
    with:
      issue_number: ${{ inputs.issue_number }}
    secrets: inherit
```

**Trigger:** Creates workflow run manually from GitHub Actions UI.

**Usage:** Go to Actions → AutoUI Manual → Run workflow → Enter issue number

---

## Pattern 6: Multiple Triggers (Combined)

**File:** `autoui-combined.yml`

```yaml
name: AutoUI Combined

on:
  issues:
    types: [opened, edited, labeled]
  issue_comment:
    types: [created, edited]
  pull_request:
    types: [opened, synchronize]
  workflow_dispatch:
    inputs:
      issue_number:
        description: 'Issue number to process'
        required: true
        type: number

jobs:
  determine_issue:
    runs-on: ubuntu-latest
    outputs:
      issue_number: ${{ steps.determine.outputs.issue_number }}
    steps:
      - id: determine
        run: |
          if [[ "${{ github.event_name }}" == "issues" || "${{ github.event_name }}" == "issue_comment" ]]; then
            echo "issue_number=${{ github.event.issue.number }}" >> $GITHUB_OUTPUT
          elif [[ "${{ github.event_name }}" == "pull_request" ]]; then
            echo "issue_number=${{ github.event.pull_request.number }}" >> $GITHUB_OUTPUT
          else
            echo "issue_number=${{ inputs.issue_number }}" >> $GITHUB_OUTPUT
          fi

  run_autoui:
    needs: determine_issue
    uses: ./.github/workflows/refactored/autoui-reusable.yml
    with:
      issue_number: ${{ needs.determine_issue.outputs.issue_number }}
    secrets: inherit
```

**Trigger:** Works with issues, PRs, and manual dispatch.

---

## Pattern 7: Conditional Trigger (Label-Based)

**File:** `autoui-conditional.yml`

```yaml
name: AutoUI Conditional

on:
  issues:
    types: [labeled]

jobs:
  check_label:
    if: ${{ github.event.label.name == 'AutoUI' }}
    runs-on: ubuntu-latest
    outputs:
      issue_number: ${{ steps.get.outputs.issue_number }}
    steps:
      - id: get
        run: echo "issue_number=${{ github.event.issue.number }}" >> $GITHUB_OUTPUT

  run_autoui:
    needs: check_label
    uses: ./.github/workflows/refactored/autoui-reusable.yml
    with:
      issue_number: ${{ needs.check_label.outputs.issue_number }}
    secrets: inherit
```

**Trigger:** Only runs when `AutoUI` label is added.

---

## Pattern 8: External Service Trigger (Webhook)

**File:** `autoui-external.yml`

```yaml
name: AutoUI External

on:
  repository_dispatch:
    types: [autoui-from-external]

jobs:
  run_autoui:
    runs-on: ubuntu-latest
    steps:
      - name: Validate payload
        run: |
          if [ -z "${{ github.event.client_payload.issue_number }}" ]; then
            echo "Missing issue_number in payload"
            exit 1
          fi

      - uses: ./.github/workflows/refactored/autoui-reusable.yml
        with:
          issue_number: ${{ github.event.client_payload.issue_number }}
        secrets: inherit
```

**Trigger:** Called from external service (e.g., Zapier, IFTTT, custom app).

**Usage from external service:**
```
POST https://api.github.com/repos/owner/repo/dispatches
Authorization: Bearer $GITHUB_TOKEN
Content-Type: application/json

{
  "event_type": "autoui-from-external",
  "client_payload": {
    "issue_number": 42
  }
}
```

---

## Comparison Table

| Pattern | Trigger | Pros | Cons |
|---------|---------|------|------|
| **Issue Events** | Issue created/edited | Simple, native | Limited to issues |
| **PR Events** | PR opened/updated | Works with PRs | Different context |
| **Repository Dispatch** | API call | Flexible, external | Requires API token |
| **Scheduled** | Cron expression | Automated | Needs issue lookup |
| **Manual** | UI button | Full control | Manual execution |
| **Combined** | Multiple events | Versatile | Complex logic |
| **Conditional** | Label-based | Selective | More conditions |
| **External** | Webhook | Integrated | External dependency |

---

## Quick Start: Add a New Trigger

1. **Copy `autoui-main.yml`** to `autoui-{trigger-name}.yml`
2. **Change the `on:` section** to your trigger
3. **Update the `with:` section** to extract `issue_number` from the new event
4. **Push to `.github/workflows/`**
5. **Test the trigger**

Example: Add Slack command trigger

```yaml
name: AutoUI Slack

on:
  repository_dispatch:
    types: [slack-autoui]

jobs:
  run_autoui:
    uses: ./.github/workflows/refactored/autoui-reusable.yml
    with:
      issue_number: ${{ github.event.client_payload.issue_number }}
    secrets: inherit
```

Then configure your Slack app to send:
```
POST /repos/owner/repo/dispatches
{
  "event_type": "slack-autoui",
  "client_payload": {
    "issue_number": 42
  }
}
```

---

## Troubleshooting Triggers

### Workflow not running

1. Check workflow is in `.github/workflows/` (not subdirectory)
2. Verify trigger condition matches your event
3. Check repository settings allow workflow execution
4. Review workflow logs for errors

### Wrong issue number passed

1. Verify event payload contains the correct field
2. Use `github.event` context to debug:
   ```yaml
   - run: echo "${{ toJSON(github.event) }}"
   ```
3. Adjust extraction logic if needed

### Multiple workflows running

1. Ensure only one trigger file matches your event
2. Use `if:` conditions to prevent duplicate runs
3. Consider consolidating into Pattern 6 (Combined)

---

## Next Steps

- Choose a trigger pattern that fits your workflow
- Create the trigger file in `.github/workflows/`
- Test with a real event
- Monitor logs for any issues
- Iterate as needed

For more details, see the main README.md.
