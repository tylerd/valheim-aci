@minLength(3)
@maxLength(11)
param namePrefix string

param location string = resourceGroup().location

var identityName = 'storage-msi'
var fileShareName = 'valheim-test'

var uniqueStorageName = '${toLower(namePrefix)}${uniqueString(resourceGroup().id)}'
var roleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
var roleAssignmentName = guid(identityName, roleDefinitionId)

var image = 'lloesche/valheim-server:main'
var environmentVariables = [
  {
    name: 'SERVER_NAME'
    value: 'Tyler Test'
  }
]

var ports = [
  {
    port: 2456
    protocol: 'UDP'
  }
  {
    port: 2457
    protocol: 'UDP'
  }
]

resource stg 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: uniqueStorageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
  }
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: identityName
  location: location
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: roleAssignmentName
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'createFileShare'
  location: location
  kind: 'AzurePowerShell'
  dependsOn: [
    stg
  ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: '1'
    azPowerShellVersion: '3.0'
    arguments: ' -storageAccountName ${stg.name} -fileShareName ${fileShareName} -resourceGroupName ${resourceGroup().name}'
    scriptContent: 'param([string] $storageAccountName, [string] $fileShareName, [string] $resourceGroupName) Get-AzStorageAccount -StorageAccountName $storageAccountName -ResourceGroupName $resourceGroupName | New-AzStorageShare -Name $fileShareName'
    timeout: 'PT5M'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2021-03-01' = {
  name: '${namePrefix}-ACI'
  location: location
  dependsOn: [
    deploymentScript
  ]
  properties: {
    containers: [
      {
        name: 'valheim-server'
        properties: {
          image: image
          environmentVariables: environmentVariables
          resources: {
            requests: {
              cpu: 2
              memoryInGB: 4
            }
          }
          ports: ports
        }
      }
    ]
    osType: 'Linux'
    ipAddress: {
      type: 'Public'
      ports: ports
    }
  }
}

output fileEndpoint string = stg.properties.primaryEndpoints.file
