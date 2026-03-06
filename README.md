# testinggithubapp

Simple "Hello World" Node.js web app deployed to Azure App Service.

## What This Includes

- Express web app (`src/index.js`)
- GitHub Actions workflow for deployment (`app-deploy.yml`)

## Architecture

Azure Web App runs Node.js 20 and serves a simple "Hello World" message.

## Prerequisites

- Azure subscription with a Web App created
- GitHub repository
- Node.js 20+

## Setup Steps

### 1. Create Azure Web App (Manual in Portal)

- Azure Portal → Create Web App
- Runtime: Node 20 LTS (Linux)
- SKU: F1 (Free) or B1 (Basic)

### 2. Configure GitHub for Deployment

Create Azure service principal and add credentials to GitHub repo secrets.

**GitHub repository secret:**
- `AZURE_CREDENTIALS` = JSON with clientId, clientSecret, subscriptionId, tenantId

**GitHub repository variable:**
- `AZURE_WEBAPP_NAME` = your web app name

### 3. Deploy from GitHub Actions

Push to `main` branch to trigger `Build and Deploy Web App` workflow.

## Local Development

Install dependencies:

```bash
npm install
```

Run:

```bash
npm run dev
```

Open browser: `http://localhost:3000`

## Testing

After deployment, visit: `https://<your-webapp-name>.azurewebsites.net/`

You should see "Hello World!"