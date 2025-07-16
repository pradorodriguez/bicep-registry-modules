targetScope = 'resourceGroup'

//////////////////////////////////////////////////////////////////////////
// PARAMETERS
//////////////////////////////////////////////////////////////////////////

//
// Imports
//
import * as const from 'common/constants.bicep'
import * as types from 'common/types.bicep'

// TODO: Add terraform imports.

//
// General Configuration
//
@description('Azure region for AI Foundry resources.')
param location string = resourceGroup().location
@description('Tags applied to all deployed resources.')
param deploymentTags object = {}

//
// Naming & Tokens
//
@description('Deterministic token for resource names.')
param resourceToken string = toLower(uniqueString(subscription().id, resourceGroup().name, location))
@description('Container for all generated resource name values.')
param resourceNames types.ResourceNamesType

//
// Identity Settings
//
@description('Use User‑Assigned Managed Identities instead of System‑Assigned.')
param useUAI bool = false

//
// Network Settings
//
@description('Enable network isolation (private endpoints, no public access).')
param networkIsolation bool = false

//
// Feature Flags
//
@description('Toggle deployment of various services.')
param featureFlags types.FeatureFlagsType

//
// Reuse Existing Services
//
@description('Optional existing resource IDs to reuse; leave empty to create new resources.')
param resourceIds types.ResourceIdsType

// TODO: Add existing services logic.

//
// Container App Environment Workload Profiles
//
@description('List of Workload Profiles to create.')
param workloadProfiles types.WorkloadProfileType[]

//
// Container Apps
//
@description('List of Container Apps to create.')
param containerApps types.ContainerAppDefinitionType[]

//
// Cosmos DB
//
@description('Names of the Cosmos DB containers to create.')
param databaseContainers types.DatabaseContainerDefinitionType[]

//
// Storage Account
//
@description('Containers to create in the Storage Account.')
param storageAccountContainersList types.StorageContainerDefinitionType[]

//
// Virtual Machine
//
@secure()
@description('Admin password for the VM user.')
param vmAdminPassword string = ''
@description('VM settings and associated Key Vault configuration.')
param vmSettings types.VMSettingsType

//
// CMK params
//
// Note : Customer Managed Keys (CMK) not implemented in this module yet
// @description('Use Customer Managed Keys for Storage Account and Key Vault')
// param useCMK      bool   = false

//////////////////////////////////////////////////////////////////////////
// VARIABLES
//////////////////////////////////////////////////////////////////////////

//
// General Variables
//

var _tags = deploymentTags

//
// Reuse Existing Services Variables
//

//
// Container vars
//

var _containerDummyImageName = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

//
// Networking vars
//

#disable-next-line BCP318
var _subnetIdPeSubnet = networkIsolation ? '${virtualNetwork.outputs.resourceId}/subnets/pe-subnet' : ''

var _subnetIDCappEnvSubnet = networkIsolation
  #disable-next-line BCP318
  ? '${virtualNetwork.outputs.resourceId}/subnets/aca-environment-subnet'
  : ''

#disable-next-line BCP318
var _subnetIdJumpbxSubnet = networkIsolation ? '${virtualNetwork.outputs.resourceId}/subnets/jumpbox-subnet' : ''

#disable-next-line BCP318
var _subnetIdAgentSubnet = networkIsolation ? '${virtualNetwork.outputs.resourceId}/subnets/agent-subnet' : ''

#disable-next-line BCP318
var _subNetIdAppGwSubnet = networkIsolation ? '${virtualNetwork.outputs.resourceId}/subnets/AppGatewaySubnet' : ''

var _subnetIdAPIMgmtSubnet = networkIsolation
  #disable-next-line BCP318
  ? '${virtualNetwork.outputs.resourceId}/subnets/api-management-subnet'
  : ''

//
// VM vars
//

var _vmKeyVaultSecName = !empty(vmSettings.vmKeyVaultSecName) ? vmSettings.vmKeyVaultSecName : 'vmUserInitialPassword'
var _vmBaseName = !empty(vmSettings.vmName) ? vmSettings.vmName : 'testvm${resourceToken}'
var _vmName = substring(_vmBaseName, 0, 15)
var _vmUserName = !empty(vmSettings.vmUserName) ? vmSettings.vmUserName : 'tesvmuser'

//////////////////////////////////////////////////////////////////////////
// RESOURCES
//////////////////////////////////////////////////////////////////////////

// Security
///////////////////////////////////////////////////////////////////////////

// Network Watcher
// Note: Automatically provisioned when network isolation is enabled (VNet deployment)

// Azure Defender for Cloud
// Note: By default, free tier (foundational recommendations) is enabled at the subscription level.
//       To enable its advanced threat protection features, Defender plans must be explicitly configured
//       using the Microsoft.Security/pricings resource (e.g., for Storage, Key Vault, App Services).

// Purview Compliance Manager
// Note: Not applicable, it's part of Microsoft 365 Compliance Center, not Azure Resource Manager.

// Networking
///////////////////////////////////////////////////////////////////////////

// Azure DDoS Protection

// VNet
// Note on IP address sizing: https://learn.microsoft.com/en-us/azure/ai-foundry/agents/how-to/virtual-networks#known-limitations
module virtualNetwork 'br/public:avm/res/network/virtual-network:0.7.0' = if (networkIsolation) {
  name: 'virtualNetworkDeployment'
  params: {
    // VNet sized /16 to fit all subnets
    addressPrefixes: [
      '192.168.0.0/16'
    ]
    name: resourceNames.vnetName
    location: location

    tags: _tags

    subnets: [
      {
        name: 'agent-subnet'
        addressPrefix: '192.168.0.0/24' // 256 IPs for AI Foundry agents
        delegation: 'Microsoft.app/environments'
      }
      {
        name: 'pe-subnet'
        addressPrefix: '192.168.1.0/24' // 256 IPs for private endpoints
      }
      {
        name: 'gateway-subnet'
        addressPrefix: '192.168.2.0/26' // 64 IPs for VPN/ExpressRoute gateway (min /26)
      }
      {
        name: 'AzureBastionSubnet'
        addressPrefix: '192.168.2.64/26' // 64 IPs for Bastion host (min /26)
      }
      {
        name: 'AzureFirewallSubnet'
        addressPrefix: '192.168.2.128/26' // 64 IPs for Firewall (min /26)
      }
      {
        name: 'AppGatewaySubnet'
        addressPrefix: '192.168.3.0/24' // 256 IPs for Application Gateway + WAF
      }
      {
        name: 'jumpbox-subnet'
        addressPrefix: '192.168.4.0/27' // 32 IPs for jumpbox VMs
      }
      {
        name: 'api-management-subnet'
        addressPrefix: '192.168.4.32/27' // 32 IPs for API Management
      }
      {
        name: 'aca-environment-subnet'
        addressPrefix: '192.168.4.64/27' // 32 IPs for Container Apps environment
        delegation: 'Microsoft.app/environments'
      }
      {
        name: 'devops-build-agents-subnet'
        addressPrefix: '192.168.4.96/27' // 32 IPs for DevOps build agents
      }
    ]
  }
}

// Azure virtual machine creation (Jumpbox)
///////////////////////////////////////////////////////////////////////////

// Azure Bastion

//  Key Vault to store that password securely
module testVmKeyVault 'br/public:avm/res/key-vault/vault:0.13.0' = if (featureFlags.deployVM && networkIsolation) {
  name: 'vmKeyVault'
  params: {
    name: '${const.abbrs.security.keyVault}testvm-${resourceToken}'
    location: location
    publicNetworkAccess: 'Disabled'
    sku: 'standard'
    enableRbacAuthorization: true
    tags: _tags
    secrets: [
      {
        name: _vmKeyVaultSecName
        value: vmAdminPassword
      }
    ]
  }
}

// Bastion Host
module testVmBastionHost 'br/public:avm/res/network/bastion-host:0.6.1' = if (featureFlags.deployVM && networkIsolation) {
  name: 'bastionHost'
  params: {
    // Bastion host name
    name: '${const.abbrs.security.bastion}testvm-${resourceToken}'
    #disable-next-line BCP318
    virtualNetworkResourceId: virtualNetwork.outputs.resourceId
    location: location
    skuName: 'Standard'
    tags: _tags

    // Configuration for the Public IP that the module will create
    publicIPAddressObject: {
      // Name for the Public IP resource
      name: '${const.abbrs.networking.publicIPAddress}bastion-${resourceToken}'
      allocationMethod: 'Static'
      skuName: 'Standard'
      skuTier: 'Regional'
      zones: [1, 2, 3]
      tags: _tags
    }
  }
}

// Test VM
module testVm 'br/public:avm/res/compute/virtual-machine:0.15.1' = if (featureFlags.deployVM && networkIsolation) {
  name: 'testVmDeployment'
  params: {
    name: _vmName
    location: location
    adminUsername: _vmUserName
    adminPassword: vmAdminPassword
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-azure-edition'
      version: 'latest'
    }
    vmSize: vmSettings.vmSize
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'StandardSSD_LRS'
      }
    }
    osType: 'Windows'
    zone: 0
    nicConfigurations: [
      {
        nicSuffix: '-nic-01'
        ipConfigurations: [
          {
            name: 'ipconfig01'
            #disable-next-line BCP318
            subnetResourceId: _subnetIdJumpbxSubnet
          }
        ]
      }
    ]
  }
  dependsOn: [
    virtualNetwork!
    testVmKeyVault
    testVmBastionHost
  ]
}

// Private DNS Zones and Endpoints.
///////////////////////////////////////////////////////////////////////////
// TODO: Create Private DNS Zones and Endpoints.

// API Management
//////////////////////////////////////////////////////////////////////////
module apiManagement 'br/public:avm/res/api-management/service:0.9.1' = if (featureFlags.greenFieldDeployment) {
  name: 'apimDeployment'
  params: {
    name: 'apimgw-${resourceToken}'
    publisherEmail: 'owner@contoso.com'
    publisherName: 'Contoso Admin'
    sku: 'Premium'
    virtualNetworkType: networkIsolation ? 'Internal' : 'None'
    subnetResourceId: _subnetIdAPIMgmtSubnet
    tags: _tags
  }
  dependsOn: [
    appGw
    virtualNetwork!
  ]
}

// Azure Application Gateway
//////////////////////////////////////////////////////////////////////////
module appGw 'br/public:avm/res/network/application-gateway:0.7.0' = if (featureFlags.greenFieldDeployment) {
  name: 'applicationGatewayDeployment'
  params: {
    name: 'appGw-${resourceToken}'
    gatewayIPConfigurations: [{ name: 'appGwIPConfig', properties: { subnet: { id: _subNetIdAppGwSubnet } } }]
    frontendIPConfigurations: [{ name: 'appGwFrontendIP', properties: { subnet: { id: _subNetIdAppGwSubnet } } }]
    frontendPorts: [{ name: 'appGwFrontendPort', properties: { port: 80 } }]
    backendAddressPools: [{ name: 'appGwBackEndPool' }]
    backendHttpSettingsCollection: [{ name: 'appGwBackEndSettings', properties: { port: 80, protocol: 'Http' } }]
    requestRoutingRules: [
      { name: 'appGwRule', properties: { ruleType: 'Basic', httpListener: { id: '' } /* placeholder */ } }
    ]
    sku: 'Standard_v2'
  }
  dependsOn: [virtualNetwork!]
}

// Azure Firewall
//////////////////////////////////////////////////////////////////////////
module azureFirewall 'br/public:avm/res/network/azure-firewall:0.7.1' = if (featureFlags.greenFieldDeployment) {
  name: 'azureFirewallDeployment'
  params: {
    name: 'azFw-${resourceToken}'
    #disable-next-line BCP318
    virtualNetworkResourceId: virtualNetwork.outputs.resourceId
    location: location
  }
  dependsOn: [
    virtualNetwork!
  ]
}

// AI Foundry Standard Setup
//////////////////////////////////////////////////////////////////////////

// Custom modules are used for AI Foundry Account and Project (V2) since no published AVM module available at this time.

// 1) Replace this section by AI Foundry Pattern
// https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/ai-ml/ai-foundry

// module aiFoundry 'br/public:avm/ptn/ai-ml/ai-foundry:0.1.1' = {
//   name: 'aiFoundryDeployment'
//   params: {
//     // Required parameters
//     aiFoundryType: 'StandardPrivate'
//     contentSafetyEnabled: true
//     aiAgentSubnetId: _subnetIdAgentSubnet  (TO BE CONFIRMED)
//     name: '<name>'
//     // Non-required parameters
//     aiModelDeployments: []
//     userObjectId: '00000000-0000-0000-0000-000000000000'
//     vmAdminPasswordOrKey: vmAdminPassword
//     vmSize: 'Standard_DS4_v2'
//   }
// }

// Application Insights
//////////////////////////////////////////////////////////////////////////

module appInsights 'br/public:avm/res/insights/component:0.6.0' = if (featureFlags.deployAppInsights) {
  name: 'appInsights'
  params: {
    name: resourceNames.appInsightsName
    location: location
    #disable-next-line BCP318
    workspaceResourceId: logAnalytics.outputs.resourceId
    applicationType: 'web'
    kind: 'web'
    disableIpMasking: false
    tags: _tags
  }
}

// Container Resources
//////////////////////////////////////////////////////////////////////////

// Container Apps Environment
module containerEnv 'br/public:avm/res/app/managed-environment:0.10.0' = if (featureFlags.deployContainerEnv) {
  name: 'containerEnv'
  params: {
    name: resourceNames.containerEnvName
    location: location
    tags: _tags
    // log & insights
    #disable-next-line BCP318
    logAnalyticsWorkspaceResourceId: logAnalytics.outputs.resourceId
    #disable-next-line BCP318
    appInsightsConnectionString: appInsights.outputs.connectionString
    zoneRedundant: false

    // scale settings
    workloadProfiles: workloadProfiles

    // identity
    managedIdentities: {
      systemAssigned: useUAI ? false : true
      #disable-next-line BCP318
      userAssignedResourceIds: useUAI ? [containerEnvUAI.outputs.resourceId] : []
    }
    infrastructureSubnetId: networkIsolation ? _subnetIDCappEnvSubnet : ''
    internal: networkIsolation ? true : false
  }
}

// Container Registry
module containerRegistry 'br/public:avm/res/container-registry/registry:0.9.1' = if (featureFlags.deployContainerRegistry) {
  name: 'containerRegistry'
  params: {
    name: resourceNames.containerRegistryName
    publicNetworkAccess: networkIsolation ? 'Disabled' : 'Enabled'
    location: location
    acrSku: networkIsolation ? 'Premium' : 'Basic'
    tags: _tags
    managedIdentities: {
      systemAssigned: useUAI ? false : true
      #disable-next-line BCP318
      userAssignedResourceIds: useUAI ? [containerRegistryUAI.outputs.resourceId] : []
    }
  }
}

// Container Apps
@batchSize(1)
module containerApplications 'br/public:avm/res/app/container-app:0.18.1' = [
  for (app, index) in containerApps: if (featureFlags.deployContainerApps) {
    name: empty(app.name) ? '${const.abbrs.containers.containerApp}${resourceToken}-${app.service_name}' : app.name
    params: {
      name: empty(app.name) ? '${const.abbrs.containers.containerApp}${resourceToken}-${app.service_name}' : app.name
      location: location
      #disable-next-line BCP318
      environmentResourceId: containerEnv.outputs.resourceId
      workloadProfileName: app.profile_name

      ingressExternal: networkIsolation ? false : true
      ingressTargetPort: 80
      ingressTransport: 'auto'
      ingressAllowInsecure: false

      dapr: {
        enabled: true
        appId: app.service_name
        appPort: 80
        appProtocol: 'http'
      }

      managedIdentities: {
        systemAssigned: (useUAI) ? false : true
        #disable-next-line BCP318
        userAssignedResourceIds: (useUAI) ? [containerAppsUAI[index].outputs.resourceId] : []
      }

      scaleSettings: {
        minReplicas: app.min_replicas
        maxReplicas: app.max_replicas
      }

      containers: [
        {
          name: app.service_name
          image: _containerDummyImageName
          resources: {
            cpu: '0.5'
            memory: '1.0Gi'
          }
          env: [
            {
              name: 'APP_CONFIG_ENDPOINT'
              value: 'https://${resourceNames.appConfigName}.azconfig.io'
            }
            {
              name: 'AZURE_TENANT_ID'
              value: subscription().tenantId
            }
            {
              name: 'AZURE_CLIENT_ID'
              #disable-next-line BCP318
              value: useUAI ? containerAppsUAI[index].outputs.clientId : ''
            }
          ]
        }
      ]

      tags: union(_tags, {
        'azd-service-name': app.service_name
      })
    }
  }
]

// Cosmos DB Account and Database
//////////////////////////////////////////////////////////////////////////

module cosmosDBAccount 'br/public:avm/res/document-db/database-account:0.13.0' = if (featureFlags.deployCosmosDb) {
  name: 'CosmosDBAccount'
  params: {
    name: resourceNames.dbAccountName
    location: location
    managedIdentities: {
      systemAssigned: useUAI ? false : true
      #disable-next-line BCP318
      userAssignedResourceIds: useUAI ? [cosmosUAI.outputs.resourceId] : []
    }

    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    defaultConsistencyLevel: 'Session'
    capabilitiesToAdd: ['EnableServerless']
    networkRestrictions: {
      publicNetworkAccess: 'Enabled'
    }
    tags: _tags
    sqlDatabases: [
      {
        name: resourceNames.dbDatabaseName
        throughput: 400
        containers: [
          for container in databaseContainers: {
            name: container.name
            paths: ['/id']
            defaultTtl: -1
            throughput: 400
          }
        ]
      }
    ]
  }
}

// Key Vault
//////////////////////////////////////////////////////////////////////////

module keyVault 'br/public:avm/res/key-vault/vault:0.13.0' = if (featureFlags.deployKeyVault) {
  name: 'keyVault'
  params: {
    name: resourceNames.keyVaultName
    location: location
    publicNetworkAccess: 'Enabled'
    sku: 'standard'
    enableRbacAuthorization: true
    tags: _tags
  }
}

// Log Analytics Workspace
//////////////////////////////////////////////////////////////////////////

module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.12.0' = if (featureFlags.deployLogAnalytics) {
  name: 'logAnalytics'
  params: {
    name: resourceNames.logAnalyticsWorkspaceName
    location: location
    skuName: 'PerGB2018'
    dataRetention: 30
    tags: _tags
    managedIdentities: {
      systemAssigned: true
    }
  }
}

// AI Search
//////////////////////////////////////////////////////////////////////////

module searchService 'br/public:avm/res/search/search-service:0.11.0' = if (featureFlags.deploySearchService) {
  name: 'searchService'
  params: {
    name: resourceNames.searchServiceName
    location: location
    publicNetworkAccess: networkIsolation ? 'Disabled' : 'Enabled'
    tags: _tags

    // SKU & capacity
    sku: 'standard'
    replicaCount: 1
    semanticSearch: 'disabled'

    // Identity & Auth
    managedIdentities: {
      systemAssigned: useUAI ? false : true
      #disable-next-line BCP318
      userAssignedResourceIds: useUAI ? [searchServiceUAI.outputs.resourceId] : []
    }

    disableLocalAuth: false
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    sharedPrivateLinkResources: networkIsolation
      ? [
          // Storage (blob)
          {
            groupId: 'blob'
            #disable-next-line BCP318
            privateLinkResourceId: storageAccount.outputs.resourceId
            requestMessage: 'Automated link for Storage'
            provisioningState: 'Succeeded'
            status: 'Approved'
          }
          // AI Foundry Account
          // {
          //   groupId: 'account'
          //   #disable-next-line BCP318
          //   privateLinkResourceId: aiFoundryAccount.outputs.accountID
          //   requestMessage: 'Automated link for AI Foundry Account'
          //   provisioningState: 'Succeeded'
          //   status: 'Approved'
          // }
        ]
      : []
  }
  dependsOn: [
    containerEnv!
    // aiFoundryAccount!
    storageAccount!
  ]
}

// sharedPrivateLinkResources: [
//   {
//     groupId: 'blob'
//     privateLinkResourceId: '<privateLinkResourceId>'
//     requestMessage: 'Please approve this request'
//     resourceRegion: '<resourceRegion>'
//   }
//   {
//     groupId: 'vault'
//     privateLinkResourceId: '<privateLinkResourceId>'
//     requestMessage: 'Please approve this request'
//   }
// ]

// Storage Accounts
//////////////////////////////////////////////////////////////////////////

// Storage Account
module storageAccount 'br/public:avm/res/storage/storage-account:0.25.0' = if (featureFlags.deployStorageAccount) {
  name: 'storageAccountSolution'
  params: {
    name: resourceNames.storageAccountName
    location: location
    publicNetworkAccess: 'Enabled'
    skuName: 'Standard_LRS'
    kind: 'StorageV2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      defaultAction: 'Allow'
    }
    tags: _tags
    blobServices: {
      automaticSnapshotPolicyEnabled: true
      containerDeleteRetentionPolicyDays: 10
      containerDeleteRetentionPolicyEnabled: true
      containers: [
        for container in storageAccountContainersList: {
          name: container.name
          publicAccess: 'None'
        }
      ]
      deleteRetentionPolicyDays: 7
      deleteRetentionPolicyEnabled: true
      lastAccessTimeTrackingPolicyEnabled: true
    }
  }
}

//////////////////////////////////////////////////////////////////////////
// User Managed Identities
//////////////////////////////////////////////////////////////////////////

//AI Foundry Account User Managed Identity
module aiFoundryUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = if (useUAI) {
  name: '${const.abbrs.security.managedIdentity}${resourceNames.aiFoundryAccountName}'
  params: {
    name: '${const.abbrs.security.managedIdentity}${resourceNames.aiFoundryAccountName}'
    location: location
  }
}

//AI Foundry Search User Managed Identity
module aiFoundrySearchServiceNameUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = if (useUAI) {
  name: '${const.abbrs.security.managedIdentity}${resourceNames.aiFoundrySearchServiceName}'
  params: {
    name: '${const.abbrs.security.managedIdentity}${resourceNames.aiFoundrySearchServiceName}'
    location: location
  }
}

//AI Foundry Cosmos User Managed Identity
module aiFoundryCosmosDbNameUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = if (useUAI) {
  name: '${const.abbrs.security.managedIdentity}${resourceNames.aiFoundryCosmosDbName}'
  params: {
    name: '${const.abbrs.security.managedIdentity}${resourceNames.aiFoundryCosmosDbName}'
    location: location
  }
}

// AI Foundry Project User Managed Identity
module aiFoundryProjectUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = if (useUAI) {
  name: '${const.abbrs.security.managedIdentity}${resourceNames.aiFoundryProjectName}'
  params: {
    name: '${const.abbrs.security.managedIdentity}${resourceNames.aiFoundryProjectName}'
    location: location
  }
}

//Container Apps Env User Managed Identity
module containerEnvUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = if (useUAI) {
  name: '${const.abbrs.security.managedIdentity}${resourceNames.containerEnvName}'
  params: {
    name: '${const.abbrs.security.managedIdentity}${resourceNames.containerEnvName}'
    location: location
  }
}

//Container Registry User Managed Identity
module containerRegistryUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = if (useUAI) {
  name: '${const.abbrs.security.managedIdentity}${resourceNames.containerRegistryName}'
  params: {
    name: '${const.abbrs.security.managedIdentity}${resourceNames.containerRegistryName}'
    location: location
  }
}

//Container Apps User Managed Identity
module containerAppsUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = [
  for app in containerApps: if (useUAI) {
    name: '${const.abbrs.security.managedIdentity}${app.service_name}'
    params: {
      name: '${const.abbrs.security.managedIdentity}${const.abbrs.containers.containerApp}${resourceToken}-${app.service_name}'
      location: location
    }
  }
]

//Cosmos User Managed Identity
module cosmosUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = if (useUAI) {
  name: '${const.abbrs.security.managedIdentity}${resourceNames.dbAccountName}'
  params: {
    name: '${const.abbrs.security.managedIdentity}${resourceNames.dbAccountName}'
    location: location
  }
}

//Search Service User Managed Identity
module searchServiceUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = if (useUAI) {
  name: '${const.abbrs.security.managedIdentity}${resourceNames.searchServiceName}'
  params: {
    name: '${const.abbrs.security.managedIdentity}${resourceNames.searchServiceName}'
    location: location
  }
}

// //////////////////////////////////////////////////////////////////////////
// // ROLE ASSIGNMENTS
// //////////////////////////////////////////////////////////////////////////

// // Role assignments are centralized in this section to make it easier to view all permissions granted in this template.
// // Custom modules are used for role assignments since no published AVM module available for this at the time we created this template.

// TODO: Create Role Assignments.

//////////////////////////////////////////////////////////////////////////
// App Configuration Settings Service
//////////////////////////////////////////////////////////////////////////

// App Configuration Store
//////////////////////////////////////////////////////////////////////////

module appConfig 'br/public:avm/res/app-configuration/configuration-store:0.7.0' = if (featureFlags.deployAppConfig) {
  name: 'appConfig'
  params: {
    name: resourceNames.appConfigName
    location: location
    sku: 'Standard'
    managedIdentities: {
      systemAssigned: true
    }
    tags: _tags
    dataPlaneProxy: {
      authenticationMode: 'Pass-through'
      privateLinkDelegation: 'Disabled'
    }
  }
}

//////////////////////////////////////////////////////////////////////////
// OUTPUTS
//////////////////////////////////////////////////////////////////////////

// ──────────────────────────────────────────────────────────────────────
// General / Deployment
// ──────────────────────────────────────────────────────────────────────
output TENANT_ID string = tenant().tenantId
output SUBSCRIPTION_ID string = subscription().subscriptionId
output RESOURCE_GROUP_NAME string = resourceGroup().name
output LOCATION string = location
output DEPLOYMENT_NAME string = deployment().name
output RESOURCE_TOKEN string = resourceToken
output NETWORK_ISOLATION bool = networkIsolation

// ──────────────────────────────────────────────────────────────────────
// Feature flagging
// ──────────────────────────────────────────────────────────────────────
output DEPLOY_APP_CONFIG bool = featureFlags.deployAppConfig
output DEPLOY_KEY_VAULT bool = featureFlags.deployKeyVault
output DEPLOY_LOG_ANALYTICS bool = featureFlags.deployLogAnalytics
output DEPLOY_APP_INSIGHTS bool = featureFlags.deployAppInsights
output DEPLOY_SEARCH_SERVICE bool = featureFlags.deploySearchService
output DEPLOY_STORAGE_ACCOUNT bool = featureFlags.deployStorageAccount
output DEPLOY_COSMOS_DB bool = featureFlags.deployCosmosDb
output DEPLOY_CONTAINER_APPS bool = featureFlags.deployContainerApps
output DEPLOY_CONTAINER_REGISTRY bool = featureFlags.deployContainerRegistry
output DEPLOY_CONTAINER_ENV bool = featureFlags.deployContainerEnv

// ──────────────────────────────────────────────────────────────────────
// Endpoints / URIs
// ──────────────────────────────────────────────────────────────────────
#disable-next-line BCP318
output APP_CONFIG_ENDPOINT string = appConfig.outputs.endpoint
