# Updated Workflow Logic Guide

This document details the significant logic updates made to the AutoUI and Reaction-Based Deployment workflows based on your latest requirements.

## 1. AutoUI Workflow (`autoui-reusable.yml`)

The primary change is a more robust process when all questions are answered. Instead of just creating a preview, the workflow now manages branches, creates a persistent PR, and deploys a preview.

### New Job: `build_and_deploy_pr`

This new job replaces the old `preview` and `finalize` jobs, combining their logic into a single, streamlined process that runs when `has_label == 'true'` and `complete == 'true'`.

#### Step-by-Step Logic:

1.  **Checkout `master` Branch**: The process starts by checking out the `master` branch to ensure it has the latest code as a baseline.

2.  **Handle Branch (`ui-bot/issue-{id}`)**: This is the core of the new logic.
    *   **If `ui-bot/issue-{id}` exists**: The workflow checks it out, pulls the latest changes from the remote, and then merges the latest `master` into it. This keeps the feature branch up-to-date.
    *   **If `ui-bot/issue-{id}` does NOT exist**: The workflow creates this new branch from the latest `master`.

3.  **Generate Vue Files**: The `generate-vue-files.js` script runs to create the UI components based on the user's answers.

4.  **Commit and Push**: The newly generated or updated files are committed to the `ui-bot/issue-{id}` branch and pushed to the remote repository. A `--force` push is used to ensure the branch is always overwritten with the latest generated code, preventing complex merge conflicts from previous generations.

5.  **Install & Build for Preview**: The workflow installs dependencies and builds the project. Crucially, the `VITE_BASE` environment variable is set to `/beta/issue-${{ issue_number }}/` to ensure the preview assets load correctly.

6.  **Deploy to GitHub Pages**: The built `dist` directory is deployed to the `gh-pages` branch, making the preview available at the beta URL.

7.  **Create Draft PR & Comment**: This final step automates the communication loop:
    *   A **Draft Pull Request** is created from the `ui-bot/issue-{id}` branch to `master`. This PR is linked to the original issue.
    *   A **comment is posted** back to the issue thread, providing direct links to both the live **preview URL** and the newly created **Draft PR**.

### Visual Flow of `build_and_deploy_pr`

```mermaid
graph TD
    A[All Questions Answered] --> B{Branch `ui-bot/issue-{id}` Exists?};
    B -- Yes --> C[Checkout Branch & Merge Master];
    B -- No --> D[Create Branch from Master];
    C --> E[Generate Vue Files];
    D --> E;
    E --> F[Commit & Push to Branch];
    F --> G[Build Project for Preview];
    G --> H[Deploy to gh-pages];
    H --> I[Create Draft PR];
    I --> J[Comment on Issue with Links];
```

## 2. Reaction-Based Deployment (`reaction-deploy.yml`)

This workflow has been simplified and made safer based on your feedback.

### Key Changes:

1.  **Requires `AutoUI` Label**: The workflow will now **only** run if the issue associated with the comment has the `AutoUI` label. This prevents accidental or unauthorized deployments on issues not related to this process.

    ```yaml
    if: "... && contains(github.event.issue.labels.*.name, 'AutoUI')"
    ```

2.  **Preview Only (No Git Changes)**: The workflow's sole responsibility is to generate a temporary preview. It **does not** create or modify any git branches or create pull requests. It simply checks out the `production` branch, builds the project, and deploys it to the `/beta/issue-{id}/` path on `gh-pages`.

### Clarified Purpose

*   **AutoUI Workflow (on completion)**: The official, persistent process. Creates a branch and a PR for merging.
*   **Reaction Workflow (on 🚀)**: An on-demand, temporary preview generator. It's a quick way to see how the latest code on the `production` branch looks with the current issue's parameters, without creating any permanent git history.

This separation ensures a clear and predictable path for features while still providing flexibility for quick previews.
