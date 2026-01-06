# Reaction-Based Deployment Workflow

## Overview

This workflow enables one-click deployment directly from issue comments using emoji reactions. When a human reacts with 🚀 to a bot comment containing parameters, the workflow automatically builds from the `production` branch and deploys to GitHub Pages.

## How It Works

### Step-by-Step Flow

1. **Bot posts comment** with full or partial parameters
2. **Human reacts with 🚀** to the comment
3. **Workflow detects reaction** and adds 👀 reaction (looking into it)
4. **Workflow builds** from `production` branch
5. **Workflow deploys** to `/beta/issue-{issue_number}/`
6. **On success**: Removes 👀, adds ✅ reaction
7. **On failure**: Removes 👀, adds ❌ reaction

### Visual Timeline

```
Bot posts comment with parameters
         ↓
Human reacts with 🚀
         ↓
Workflow adds 👀 (looking...)
         ↓
Build from production branch
         ↓
Deploy to gh-pages/beta/issue-{id}/
         ↓
Success? → Remove 👀, add ✅
Failure? → Remove 👀, add ❌
```

## File Location

```
.github/workflows/reaction-deploy.yml
```

## Configuration

### Trigger

The workflow triggers on **issue comments** when:
- Comment contains 🚀 emoji
- Comment is not from the bot itself (prevents infinite loops)

```yaml
on:
  issue_comment:
    types: [created, edited]
```

### Permissions Required

```yaml
permissions:
  contents: write        # Read production branch
  pages: write           # Deploy to Pages
  id-token: write        # OIDC for Pages
  issues: write          # Add reactions to comments
  pull-requests: write   # Support PR comments
```

## Workflow Steps

### 1. Add 👀 Reaction

When the workflow starts, it immediately adds a 👀 (eyes) reaction to show the bot is processing.

```javascript
await github.rest.reactions.createForIssueComment({
  owner: context.repo.owner,
  repo: context.repo.repo,
  comment_id: context.payload.comment.id,
  content: 'eyes'
});
```

### 2. Checkout Production Branch

Fetches the `production` branch (not main).

```yaml
- name: Checkout production branch
  uses: actions/checkout@v4
  with:
    ref: 'production'
```

### 3. Setup Node & Cache

Sets up Node.js 20 with npm caching for faster builds.

```yaml
- name: Setup Node
  uses: actions/setup-node@v4
  with:
    node-version: 20
    cache: npm
    cache-dependency-path: coming-soon/package-lock.json
```

### 4. Install Dependencies

Installs npm packages from `coming-soon/` directory.

```yaml
- name: Install dependencies
  working-directory: coming-soon
  run: npm ci || npm install
```

### 5. Build Project

Builds the project with the correct base path for the issue-specific deployment.

```yaml
- name: Build project
  working-directory: coming-soon
  env:
    VITE_BASE: /beta/issue-${{ github.event.issue.number }}/
  run: npm run build
```

**Key:** The `VITE_BASE` environment variable ensures assets are served from the correct path.

### 6. Upload Pages Artifact

Uploads the built dist folder as a Pages artifact.

```yaml
- name: Upload Pages artifact
  uses: actions/upload-pages-artifact@v3
  with:
    path: coming-soon/dist
```

### 7. Deploy to GitHub Pages

Deploys the artifact to GitHub Pages.

```yaml
- name: Deploy to GitHub Pages
  id: deployment
  uses: actions/deploy-pages@v4
```

### 8. Add Success/Failure Reactions

**On success:** Adds ✅ reaction

```yaml
- name: Add ✅ reaction
  if: success()
  uses: actions/github-script@v7
  with:
    script: |
      await github.rest.reactions.createForIssueComment({
        owner: context.repo.owner,
        repo: context.repo.repo,
        comment_id: context.payload.comment.id,
        content: '+1'
      });
```

**On failure:** Adds ❌ reaction

```yaml
- name: Add ❌ reaction on failure
  if: failure()
  uses: actions/github-script@v7
  with:
    script: |
      await github.rest.reactions.createForIssueComment({
        owner: context.repo.owner,
        repo: context.repo.repo,
        comment_id: context.payload.comment.id,
        content: '-1'
      });
```

### 9. Remove 👀 Reaction

Always removes the 👀 reaction (whether success or failure).

```yaml
- name: Remove 👀 reaction
  if: always()
  uses: actions/github-script@v7
  with:
    script: |
      const reactions = await github.rest.reactions.listForIssueComment({
        owner: context.repo.owner,
        repo: context.repo.repo,
        comment_id: context.payload.comment.id,
      });
      const eyeReaction = reactions.data.find(
        reaction => reaction.content === 'eyes' && 
                     reaction.user.login === 'github-actions[bot]'
      );
      if (eyeReaction) {
        await github.rest.reactions.deleteForIssueComment({
          owner: context.repo.owner,
          repo: context.repo.repo,
          comment_id: context.payload.comment.id,
          reaction_id: eyeReaction.id,
        });
      }
```

## Deployment Path

The workflow deploys to:

```
https://{owner}.github.io/{repo}/beta/issue-{issue_number}/
```

For example, if issue #23 is deployed:

```
https://myorg.github.io/myrepo/beta/issue-23/
```

## Usage

### Step 1: Ensure Production Branch Exists

The workflow checks out the `production` branch. Make sure it exists in your repository.

```bash
git checkout -b production
git push -u origin production
```

### Step 2: Bot Posts Comment

The bot (from the AutoUI workflow) posts a comment with parameters:

```
✅ **AutoUI preview ready**

Preview: https://myorg.github.io/myrepo/beta/issue-23/

When you're happy, mark the discussion as **Answered** and I'll open a PR.

🚀 React with rocket to deploy to production!
```

### Step 3: Human Reacts with 🚀

Click the 🚀 emoji on the bot's comment.

### Step 4: Watch the Workflow

The workflow will:
1. Add 👀 reaction
2. Build the project
3. Deploy to gh-pages
4. Add ✅ or ❌ reaction
5. Remove 👀 reaction

### Step 5: View Deployed Site

Visit the deployment URL (posted in the comment or visible in Actions logs).

## Reaction Meanings

| Reaction | Meaning |
|----------|---------|
| 👀 | Bot is processing (building & deploying) |
| ✅ | Deployment successful! Site is live |
| ❌ | Deployment failed - check logs |

## Troubleshooting

### Workflow Not Triggering

**Problem:** Workflow doesn't run when you react with 🚀

**Solutions:**
1. Verify the comment contains 🚀 emoji
2. Check that the comment is from a human (not the bot)
3. Ensure workflow file is in `.github/workflows/`
4. Check repository settings allow workflow execution

### Build Fails

**Problem:** Build step fails with errors

**Solutions:**
1. Check that `coming-soon/` directory exists
2. Verify `npm run build` works locally
3. Check `package.json` has a `build` script
4. Review build logs in Actions tab

### Deploy Fails

**Problem:** Deploy step fails

**Solutions:**
1. Ensure `gh-pages` branch exists
2. Check repository settings allow Pages deployment
3. Verify Pages is enabled in repository settings
4. Check that `coming-soon/dist` is created by build

### Reactions Not Appearing

**Problem:** Reactions (👀, ✅, ❌) don't appear

**Solutions:**
1. Check workflow has `issues: write` permission
2. Verify bot account has permission to add reactions
3. Check that comment ID is correct
4. Review reaction API calls in logs

## Advanced Configuration

### Custom Build Command

To use a different build command, modify the build step:

```yaml
- name: Build project
  working-directory: coming-soon
  env:
    VITE_BASE: /beta/issue-${{ github.event.issue.number }}/
  run: npm run build:prod  # Change this
```

### Custom Deployment Path

To change the deployment path from `/beta/issue-{id}/`:

```yaml
- name: Deploy to GitHub Pages
  uses: peaceiris/actions-gh-pages@v4
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    publish_branch: gh-pages
    publish_dir: coming-soon/dist
    destination_dir: custom/path/issue-${{ github.event.issue.number }}
```

### Different Branch

To deploy from a different branch (e.g., `main` instead of `production`):

```yaml
- name: Checkout branch
  uses: actions/checkout@v4
  with:
    ref: 'main'  # Change this
```

### Additional Environment Variables

Add environment variables for the build:

```yaml
- name: Build project
  working-directory: coming-soon
  env:
    VITE_BASE: /beta/issue-${{ github.event.issue.number }}/
    CUSTOM_VAR: value
    API_URL: https://api.example.com
  run: npm run build
```

## Integration with AutoUI Workflow

This workflow pairs perfectly with the AutoUI workflow. The AutoUI bot posts a comment when the preview is ready, and users can react with 🚀 to deploy to production.

### Flow

1. User creates issue with `AutoUI` label
2. AutoUI workflow asks questions
3. User answers questions
4. AutoUI workflow generates preview and posts comment
5. User reviews preview
6. User reacts with 🚀 to deploy
7. This workflow builds and deploys to `/beta/issue-{id}/`

## Concurrency

The workflow uses concurrency control to prevent multiple deployments at the same time:

```yaml
concurrency:
  group: "pages"
  cancel-in-progress: true
```

This ensures only one deployment happens at a time, and newer deployments cancel older ones.

## Permissions

The workflow requires these permissions:

| Permission | Purpose |
|-----------|---------|
| `contents: write` | Read production branch |
| `pages: write` | Deploy to GitHub Pages |
| `id-token: write` | OIDC authentication for Pages |
| `issues: write` | Add reactions to issue comments |
| `pull-requests: write` | Support PR comments |

## Monitoring

### View Workflow Runs

1. Go to repository → Actions tab
2. Select "Deploy on Reaction 🚀" workflow
3. Click on a run to see logs

### View Deployment Status

1. Go to repository → Actions tab
2. Look for "pages build and deployment" workflow
3. Check deployment status and URL

### View Deployed Site

Visit: `https://{owner}.github.io/{repo}/beta/issue-{number}/`

## FAQ

### Can I deploy without reacting with 🚀?

No, the workflow only triggers on 🚀 reaction. This prevents accidental deployments.

### Can I deploy from a different branch?

Yes, modify the `ref:` in the checkout step to use a different branch.

### Can I change the deployment path?

Yes, modify the `destination_dir:` in the deploy step or the `VITE_BASE` environment variable.

### What if the build takes a long time?

The workflow has npm caching enabled to speed up builds. First build may take longer.

### Can I add more reactions?

Yes, add more reaction steps with different emoji codes. See [GitHub Reactions API](https://docs.github.com/en/rest/reactions).

## Next Steps

1. Copy `reaction-deploy.yml` to `.github/workflows/`
2. Ensure `production` branch exists
3. Test by reacting with 🚀 to a bot comment
4. Monitor the workflow run
5. Verify deployment at the generated URL

## Support

For issues or questions:
- Check the troubleshooting section above
- Review workflow logs in Actions tab
- Check GitHub Pages deployment status
- Verify all permissions are set correctly
