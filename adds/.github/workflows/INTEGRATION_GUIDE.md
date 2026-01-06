# AutoUI + Reaction Deploy Integration Guide

## Overview

This guide explains how to integrate the **AutoUI workflow** with the **Reaction-Based Deployment workflow** to create a complete, end-to-end automation pipeline.

## Complete Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    COMPLETE AUTOUI PIPELINE                     │
└─────────────────────────────────────────────────────────────────┘

1. USER CREATES ISSUE
   └─ Issue with "AutoUI" label
   └─ Triggers: autoui-main.yml

2. AUTOUI ASKS QUESTIONS
   └─ AutoUI workflow asks questions in comments
   └─ User responds with answers
   └─ Workflow validates and stores answers

3. AUTOUI GENERATES PREVIEW
   └─ When all questions answered
   └─ Generates Vue components from templates
   └─ Builds project
   └─ Deploys to /beta/i-{issue_number}/
   └─ Posts comment with preview URL

4. USER REVIEWS PREVIEW
   └─ User visits preview URL
   └─ Reviews generated UI
   └─ Decides if ready for production

5. USER REACTS WITH 🚀
   └─ User reacts with 🚀 to bot comment
   └─ Triggers: reaction-deploy.yml

6. REACTION DEPLOY WORKFLOW
   └─ Adds 👀 reaction (processing)
   └─ Checks out production branch
   └─ Builds project
   └─ Deploys to /beta/issue-{issue_number}/
   └─ Removes 👀, adds ✅ or ❌

7. DEPLOYMENT COMPLETE
   └─ Site deployed to production path
   └─ User can access at final URL
   └─ Ready for review/merge
```

## Architecture

### Workflow Files

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `autoui-main.yml` | Issue events | Entry point for AutoUI |
| `autoui-reusable.yml` | Called by autoui-main | Core AutoUI logic |
| `reaction-deploy.yml` | 🚀 reaction | Build & deploy on demand |

### Data Flow

```
Issue Created
     ↓
autoui-main.yml (trigger)
     ↓
autoui-reusable.yml (operations)
     ├─ decide job: Parse issue
     ├─ ask_question job: Ask questions
     ├─ preview job: Generate preview
     └─ finalize job: Create PR
     ↓
Bot posts comment with preview URL
     ↓
User reacts with 🚀
     ↓
reaction-deploy.yml (trigger)
     ↓
Build & Deploy job (operations)
     ├─ Checkout production
     ├─ Build
     ├─ Deploy
     └─ React with status
     ↓
Deployment complete
```

## Setup Instructions

### Step 1: Copy All Workflow Files

```bash
# Copy AutoUI workflows
cp .github/workflows/refactored/autoui-main.yml .github/workflows/
cp .github/workflows/refactored/autoui-reusable.yml .github/workflows/

# Copy scripts
cp .github/scripts/parse-issue.js .github/scripts/
cp .github/scripts/generate-vue-files.js .github/scripts/

# Copy reaction deploy workflow
cp .github/workflows/reaction-deploy.yml .github/workflows/
```

### Step 2: Ensure Branches Exist

```bash
# Create production branch if it doesn't exist
git checkout -b production
git push -u origin production

# Ensure main/master branch exists
git checkout main  # or master
```

### Step 3: Configure GitHub Pages

1. Go to repository → Settings → Pages
2. Set source to "Deploy from a branch"
3. Select `gh-pages` branch
4. Click Save

### Step 4: Verify Permissions

1. Go to repository → Settings → Actions → General
2. Ensure "Read and write permissions" is enabled
3. Ensure "Allow GitHub Actions to create and approve pull requests" is enabled (optional)

### Step 5: Create Issue Template (Optional)

Create `.github/ISSUE_TEMPLATE/autoui.md`:

```markdown
---
name: AutoUI Request
about: Generate a new UI using AutoUI
labels: AutoUI
---

## UI Request

Please fill in the details below to generate your UI.

### Questions

The bot will ask you the following questions:
- Product Name
- Tagline
- Offer Type
- Primary CTA
- Brand Tone
- Chart Style
- Framework
- Chart Library
- Modal Usage

Just respond with answers in the format: `key=value`

---

*The bot will guide you through the process step by step.*
```

## Usage Walkthrough

### For End Users

#### Step 1: Create Issue

1. Go to repository → Issues
2. Click "New Issue"
3. Select "AutoUI Request" template
4. Fill in basic information
5. Click "Submit new issue"

#### Step 2: Answer Questions

1. Bot posts first question in comments
2. Reply with answer: `product_name=My Product`
3. Bot validates and asks next question
4. Repeat until all questions answered

#### Step 3: Review Preview

1. Bot posts comment with preview URL
2. Click URL to view generated UI
3. Review design and functionality
4. Decide if ready for production

#### Step 4: Deploy to Production

1. If happy with preview, react with 🚀
2. Watch for 👀 reaction (processing)
3. Wait for ✅ reaction (success) or ❌ (failure)
4. Visit production URL to see deployed site

#### Step 5: Finalize (Optional)

1. Add `AutoUI-Finalize` label to issue
2. Close the issue
3. Finalize workflow creates PR
4. Review and merge PR

### For Developers

#### Customizing Questions

Edit `.github/templates/autoui/questions.json`:

```json
{
  "sections": [
    {
      "id": "basics",
      "title": "Basic Information",
      "intro": "Let's start with the basics",
      "links": ["https://example.com/docs"],
      "questions": [
        {
          "key": "product_name",
          "ask": "What is the product name?",
          "options": []
        }
      ]
    }
  ]
}
```

#### Customizing Templates

Edit Vue templates in `.github/templates/autoui/`:

- `Landing.vue.template` - Main landing page
- `StatsChart.vue.template` - Chart component

Use `${VARIABLE_NAME}` for substitution.

#### Customizing Build

Modify `coming-soon/package.json`:

```json
{
  "scripts": {
    "build": "vite build --base=/beta/issue-{id}/"
  }
}
```

## Integration Points

### AutoUI → Reaction Deploy

The AutoUI workflow posts a comment that includes:
- Preview URL
- Parameters used
- Status of all questions

The Reaction Deploy workflow reads:
- Issue number from `github.event.issue.number`
- Production branch code
- Builds and deploys

### Reaction Deploy → Issue

The Reaction Deploy workflow:
- Adds reactions to show status
- Can post comments with deployment URL
- Can update issue with deployment status

## Advanced Scenarios

### Scenario 1: Multiple Deployments

User can react with 🚀 multiple times to deploy different versions:

```
1. First 🚀 → Deploys version 1 to /beta/issue-23/
2. User modifies production branch
3. Second 🚀 → Deploys version 2 to /beta/issue-23/ (overwrites)
4. User can see history in Actions tab
```

### Scenario 2: Parallel Workflows

Multiple issues can be processed simultaneously:

```
Issue #20 AutoUI → Preview → Deploy
Issue #21 AutoUI → Preview → Deploy
Issue #22 AutoUI → Preview → Deploy
```

Each runs independently with its own `/beta/issue-{id}/` path.

### Scenario 3: Manual Deployment

If you want to deploy without reacting, use workflow dispatch:

```bash
gh workflow run reaction-deploy.yml \
  -f issue_number=23
```

### Scenario 4: Scheduled Deployments

Create a scheduled workflow that deploys latest production:

```yaml
name: Scheduled Deploy

on:
  schedule:
    - cron: '0 9 * * MON'  # Every Monday at 9 AM

jobs:
  deploy:
    uses: ./.github/workflows/reaction-deploy.yml
    with:
      issue_number: 1  # Or fetch dynamically
```

## Monitoring & Debugging

### View AutoUI Progress

1. Go to repository → Actions
2. Select "AutoUI Main" workflow
3. Click on issue run
4. View logs for each job

### View Deployment Progress

1. Go to repository → Actions
2. Select "Deploy on Reaction 🚀" workflow
3. Click on run
4. View logs for build and deploy steps

### Check Deployed Site

```bash
# Visit the deployed site
open https://{owner}.github.io/{repo}/beta/issue-{number}/

# Or check GitHub Pages deployment
gh api repos/{owner}/{repo}/pages/builds
```

### Debug Reactions

If reactions don't appear:

1. Check workflow logs for reaction API calls
2. Verify bot has `issues: write` permission
3. Check that comment ID is correct
4. Try manually adding reaction to verify API works

## Troubleshooting

### AutoUI Workflow Not Starting

**Problem:** Issue created but AutoUI workflow doesn't run

**Solutions:**
1. Verify issue has `AutoUI` label
2. Check workflow file is in `.github/workflows/`
3. Verify permissions are set correctly
4. Check repository settings allow workflows

### Questions Not Being Asked

**Problem:** AutoUI workflow runs but doesn't ask questions

**Solutions:**
1. Check `.github/templates/autoui/questions.json` exists
2. Verify JSON format is valid
3. Check that `AutoUI` label is present
4. Review parse-issue.js logs

### Preview Not Generating

**Problem:** All questions answered but no preview

**Solutions:**
1. Check `coming-soon/` directory exists
2. Verify `npm run build` works locally
3. Check package.json has build script
4. Review build logs in Actions

### Deployment Not Triggering

**Problem:** React with 🚀 but workflow doesn't run

**Solutions:**
1. Verify 🚀 emoji is in comment
2. Check comment is from human (not bot)
3. Verify workflow file exists
4. Check repository allows workflows

### Reactions Not Appearing

**Problem:** Workflow runs but reactions don't show

**Solutions:**
1. Check `issues: write` permission
2. Verify bot can add reactions
3. Check comment ID is correct
4. Review reaction API calls in logs

## Best Practices

### For Users

1. **Answer questions clearly** - Use format `key=value`
2. **Review preview thoroughly** - Check all aspects before deploying
3. **Use meaningful issue titles** - Helps track deployments
4. **Add labels as needed** - Use `AutoUI-Finalize` when ready for PR

### For Developers

1. **Keep templates updated** - Update Vue templates as design changes
2. **Version your questions** - Track changes to questions.json
3. **Test locally first** - Run `npm run build` locally before pushing
4. **Monitor deployments** - Check Actions tab for failures
5. **Clean up old deployments** - Remove old `/beta/issue-{id}/` paths periodically

## Performance Tips

1. **Enable npm caching** - Already enabled in reaction-deploy.yml
2. **Use shallow clone** - Reduces checkout time
3. **Parallel jobs** - AutoUI jobs run in parallel when possible
4. **Concurrency control** - Prevents multiple deployments at once

## Security Considerations

1. **Bot permissions** - Only give necessary permissions
2. **Branch protection** - Protect production branch
3. **Review PRs** - Always review generated PRs before merging
4. **Secrets** - Don't commit API keys or tokens
5. **Access control** - Limit who can create issues/react

## Next Steps

1. Copy all workflow files
2. Create production branch
3. Configure GitHub Pages
4. Create first issue with AutoUI label
5. Follow the walkthrough above
6. Monitor and iterate

## Support & Questions

For detailed information:
- See `.github/workflows/refactored/README.md` for AutoUI details
- See `.github/workflows/REACTION_DEPLOY_GUIDE.md` for deployment details
- Check workflow logs in Actions tab
- Review GitHub Actions documentation

## Complete File Checklist

- [ ] `.github/workflows/autoui-main.yml`
- [ ] `.github/workflows/autoui-reusable.yml`
- [ ] `.github/workflows/reaction-deploy.yml`
- [ ] `.github/scripts/parse-issue.js`
- [ ] `.github/scripts/generate-vue-files.js`
- [ ] `.github/templates/autoui/questions.json`
- [ ] `.github/templates/autoui/Landing.vue.template`
- [ ] `.github/templates/autoui/StatsChart.vue.template`
- [ ] `.github/ISSUE_TEMPLATE/autoui.md` (optional)
- [ ] `coming-soon/` directory with project files
- [ ] `production` branch created

All set! You now have a complete end-to-end automation pipeline. 🚀
