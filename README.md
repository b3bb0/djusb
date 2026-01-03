# AutoUI Discussion Bot (Vue + AntV)

## What this repo includes
- Discussion-driven Q&A bot (GitHub Actions)
- Generates a Vue + AntV (G2) landing page
- Deploys previews to GitHub Pages under:
  - `/beta/d-<discussion-number>/`
- When a discussion is marked **Answered**, it:
  - creates branch `ui-discussion-<n>`
  - commits the generated UI
  - opens a PR and requests review from the user who marked it answered

## Setup (one-time)
1. Create a label in your repo named: `AutoUI`
2. Enable GitHub Pages:
   - Settings → Pages → Deploy from branch
   - Branch: `gh-pages` and folder `/ (root)`

## How to use
1. Open a Discussion, add label `AutoUI`
2. Answer the bot’s questions (`key=value`) or reply `skip` / `next`
3. Bot posts preview URL
4. Mark the discussion **Answered** → bot opens PR + requests your review
