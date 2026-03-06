@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Global unique Web App name')
param webAppName string

@description('Global unique Key Vault name')
param keyVaultName string

@description('App Service plan SKU')
@allowed([
  'F1'
  'B1'
  'S1'
  'P1v3'
])
param appServiceSku string = 'F1'

@description('Set to true only if the deployment identity can create RBAC role assignments')
param createRoleAssignments bool = false

var appServicePlanName = '${webAppName}-plan'
var roleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  sku: {
    name: appServiceSku
    tier: appServiceSku == 'F1' ? 'Free' : (appServiceSku == 'B1' ? 'Basic' : (appServiceSku == 'S1' ? 'Standard' : 'PremiumV3'))
  }
  properties: {
    reserved: true
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    enableRbacAuthorization: true
    enabledForTemplateDeployment: false
    softDeleteRetentionInDays: 90
    enablePurgeProtection: false
    publicNetworkAccess: 'Enabled'
  }
}

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      appSettings: [
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~20'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'KEY_VAULT_URL'
          value: 'https://${keyVault.name}.${environment().suffixes.keyvaultDns}/'
        }
        {
          name: 'KV_SECRET_GITHUB_APP_ID'
          value: 'github-app-id'
        }
        {
          name: 'KV_SECRET_GITHUB_INSTALLATION_ID'
          value: 'github-installation-id'
        }
        {
          name: 'KV_SECRET_GITHUB_PRIVATE_KEY'
          value: 'github-app-private-key'
        }
      ]
    }
    httpsOnly: true
  }
}

resource kvSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createRoleAssignments) {
  name: guid(keyVault.id, webApp.id, 'kv-secrets-user')
  scope: keyVault
  properties: {
    principalId: webApp.identity.principalId
    roleDefinitionId: roleDefinitionId
    principalType: 'ServicePrincipal'
  }
}

output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output keyVaultUri string = 'https://${keyVault.name}.${environment().suffixes.keyvaultDns}/'
