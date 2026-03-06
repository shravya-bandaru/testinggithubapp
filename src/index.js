const express = require("express");
const { DefaultAzureCredential } = require("@azure/identity");
const { SecretClient } = require("@azure/keyvault-secrets");
const { Octokit } = require("octokit");
const { createAppAuth } = require("@octokit/auth-app");

const app = express();
const port = process.env.PORT || 3000;

let secretClient;
const secretCache = new Map();

function normalizePrivateKey(value) {
  // Supports secrets stored with escaped new lines in env variables.
  return value ? value.replace(/\\n/g, "\n") : value;
}

function getSecretClient() {
  if (!process.env.KEY_VAULT_URL) {
    return null;
  }

  if (!secretClient) {
    const credential = new DefaultAzureCredential();
    secretClient = new SecretClient(process.env.KEY_VAULT_URL, credential);
  }

  return secretClient;
}

async function getConfigValue(secretNameEnvKey, fallbackEnvKey) {
  const fallback = process.env[fallbackEnvKey];
  const secretName = process.env[secretNameEnvKey];
  const client = getSecretClient();

  if (!client || !secretName) {
    return fallback;
  }

  if (secretCache.has(secretName)) {
    return secretCache.get(secretName);
  }

  const response = await client.getSecret(secretName);
  const value = response.value;
  secretCache.set(secretName, value);
  return value || fallback;
}

async function getGitHubAppConfig() {
  const appId = await getConfigValue("KV_SECRET_GITHUB_APP_ID", "GITHUB_APP_ID");
  const installationId = await getConfigValue(
    "KV_SECRET_GITHUB_INSTALLATION_ID",
    "GITHUB_INSTALLATION_ID"
  );
  const privateKeyRaw = await getConfigValue(
    "KV_SECRET_GITHUB_PRIVATE_KEY",
    "GITHUB_APP_PRIVATE_KEY"
  );

  const privateKey = normalizePrivateKey(privateKeyRaw);

  if (!appId || !installationId || !privateKey) {
    throw new Error(
      "Missing GitHub App configuration. Provide values in Key Vault (recommended) or fallback environment variables."
    );
  }

  return {
    appId,
    installationId,
    privateKey,
  };
}

async function createInstallationOctokit() {
  const { appId, installationId, privateKey } = await getGitHubAppConfig();

  return new Octokit({
    authStrategy: createAppAuth,
    auth: {
      appId,
      privateKey,
      installationId,
    },
  });
}

app.get("/health", async (_req, res) => {
  try {
    const hasKv = Boolean(process.env.KEY_VAULT_URL);
    res.json({ status: "ok", keyVaultConfigured: hasKv });
  } catch (error) {
    res.status(500).json({ status: "error", message: error.message });
  }
});

app.get("/github/repos", async (_req, res) => {
  try {
    const octokit = await createInstallationOctokit();
    const response = await octokit.request("GET /installation/repositories", {
      per_page: 50,
    });

    const repositories = response.data.repositories.map((repo) => ({
      id: repo.id,
      name: repo.name,
      fullName: repo.full_name,
      private: repo.private,
      url: repo.html_url,
    }));

    res.json({ total: repositories.length, repositories });
  } catch (error) {
    res.status(500).json({
      status: "error",
      message: error.message,
    });
  }
});

app.get("/", (_req, res) => {
  res.send(
    "Web app is running. Use /health and /github/repos to validate Key Vault + GitHub App integration."
  );
});

app.listen(port, () => {
  console.log(`Server listening on port ${port}`);
});
