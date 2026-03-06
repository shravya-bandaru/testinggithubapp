# testinggithubapp

Node.js web app deployed to Azure App Service, using Azure Key Vault for secrets and GitHub App authentication.

## What This Starter Includes

- Express web app (`src/index.js`)
- GitHub App auth with Octokit (`@octokit/auth-app`)
- Azure Key Vault secret retrieval (`@azure/keyvault-secrets`, `@azure/identity`)
- Azure infrastructure as code with Bicep (`infra/main.bicep`)
- GitHub Actions workflows:
  - `infra-deploy.yml` for infrastructure deployment
  - `app-deploy.yml` for app deployment

## Architecture

1. Azure Web App runs Node.js 20 and has a system-assigned managed identity.
2. Key Vault stores GitHub App credentials.
3. Web App identity has `Key Vault Secrets User` role on Key Vault.
4. App reads these secrets at runtime:
	- `github-app-id`
	- `github-installation-id`
	- `github-app-private-key`
5. App uses GitHub App installation authentication to call GitHub APIs.

## Prerequisites

- Azure subscription
- A resource group
- GitHub repository
- A GitHub App (created in GitHub settings)
- Azure CLI installed locally (for first-time setup)
- Node.js 20+

## 1. Create and Configure GitHub App

In GitHub:

1. Go to `Settings` -> `Developer settings` -> `GitHub Apps` -> `New GitHub App`.
2. Set permissions required by your app. For repository listing, give `Metadata: Read-only`.
3. Install the app on your account or org.
4. Record:
	- App ID
	- Installation ID
	- Private key (download `.pem`)

## 2. Deploy Azure Infrastructure

Edit `infra/main.bicepparam` and set unique values:

- `webAppName`
- `keyVaultName`

Deploy:

```bash
az login
az account set --subscription "<subscription-id>"
az deployment group create --resource-group <resource-group-name> --parameters infra/main.bicepparam
```

## 3. Add GitHub App Secrets to Key Vault

Add secrets:

```bash
az keyvault secret set --vault-name <keyVaultName> --name github-app-id --value "<app-id>"
az keyvault secret set --vault-name <keyVaultName> --name github-installation-id --value "<installation-id>"
az keyvault secret set --vault-name <keyVaultName> --name github-app-private-key --file <path-to-private-key-pem>
```

The app expects these names by default (configured in Bicep app settings).

## 4. Configure GitHub OIDC for Azure Deployment

Create an Entra ID app registration and service principal (or reuse one), then add a federated credential for your GitHub repo/branch.

Required GitHub repository secrets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

Required GitHub repository variables:

- `AZURE_RG` (resource group for infra workflow)
- `AZURE_WEBAPP_NAME` (web app name for app deploy workflow)

## 5. Deploy from GitHub Actions

- Run `Deploy Azure Infrastructure` workflow once (manual dispatch), or deploy infra via CLI.
- Push to `main` to trigger `Build and Deploy Web App`.

## 6. Local Development

Install dependencies:

```bash
npm install
```

Create local env from sample:

```bash
copy .env.example .env
```

For local-only testing, you can set fallback env variables directly in `.env`:

- `GITHUB_APP_ID`
- `GITHUB_INSTALLATION_ID`
- `GITHUB_APP_PRIVATE_KEY` (use escaped newlines: `\n`)

Run:

```bash
npm run dev
```

Endpoints:

- `GET /health`
- `GET /github/repos`

## Notes

- In Azure, `DefaultAzureCredential` will use the Web App managed identity.
- Locally, it can use Azure CLI login credentials.
- If Key Vault settings are missing, app falls back to local env values.