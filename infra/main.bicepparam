using './main.bicep'

param location = 'eastus'
param webAppName = 'replace-with-unique-webapp-name'
param keyVaultName = 'replace-with-unique-kv-name'
param appServiceSku = 'F1'
param createRoleAssignments = false
