targetScope = 'resourceGroup'

//////////////////////////////////////////////////////////////////////////
// PARAMETERS
//////////////////////////////////////////////////////////////////////////

//
// Imports
//
import * as const from 'common/constants.bicep'
import * as types from 'common/types.bicep'

//
// General Configuration
//
@description('Azure region for AI Foundry resources.')
param location string = resourceGroup().location

@description('Tags applied to all deployed resources.')
param tags object = {}

//
// Token
//
@description('Deterministic token for resource names.')
param resourceToken string = toLower(uniqueString(subscription().id, resourceGroup().name, location))

//
// Reuse Existing Services
//
@description('Optional existing resource IDs to reuse, leave empty to create new resources.')
param resourceIds types.ResourceIdsType

//
// Virtual Network
//
@description('Virtual Network configuration.')
param vnetDefinition types.VNetDefinitionType

//
// Log Analytics Workspace
//
@description('Log Analytics Workspace configuration.')
param logAnalyticsDefinition types.LogAnalyticsWorkspaceDefinitionType

//
// Application Insights Component
//
@description('Application Insights configuration.')
param appInsightsDefinition types.AppInsightsDefinitionType

//
// Container App Environment
//
@description('Container App Environment configuration.')
param containerAppEnvDefinition types.ContainerAppEnvDefinitionType

//
// Container Registry
//
@description('Container Registry configuration.')
param containerRegistryDefinition types.ContainerRegistryDefinitionType?

//
// Container Apps
//
@description('List of container apps to create.')
param containerApps types.ContainerAppDefinitionType[]?

//
// Cosmos DB Account
//
@description('Cosmos DB account configuration.')
param cosmosDbDefinition types.GenAIAppCosmosDbDefinitionType?

//
// Key Vault
//
@description('Key Vault configuration.')
param keyVaultDefinition types.GenAIAppKeyVaultDefinitionType?

//
// Storage Account
//
@description('Storage Account configuration.')
param storageAccountDefinition types.GenAIAppStorageAccountDefinitionType?

//
// AI Search
//
@description('AI Search service configuration.')
param searchDefinition types.KSAISearchDefinitionType?

//
// Bing Grounding
//
@description('Bing Grounding service configuration.')
param groundingDefinition types.KSGroundingWithBingDefinitionType?

//
// App Configuration
//
@description('App Configuration store configuration.')
param appConfigurationDefinition types.AppConfigurationDefinitionType?

// AI Foundry
//
@description('AI Foundry project configuration.')
param aiFoundryDefinition types.AiFoundryDefinitionType?

//
// Virtual Machine
//
@secure()
@description('Admin password for the VM user.')
param vmAdminPassword string
@description('Jump VM configuration.')
param vmSettings types.JumpVmDefinitionType?

//
// Bastion
//
@description('Bastion configuration.')
param bastionDefinition types.BastionDefinitionType?

// Network Security Groups
//
@description('Network Security Groups configuration.')
param nsgDefinitions types.NSGDefinitionsType?

//
// Private DNS Zones
//
@description('Private DNS Zones configuration.')
param privateDnsDefinitions types.PrivateDNSZoneDefinitionsType?

//
// WAF Policy
//
@description('WAF Policy configuration.')
param wafPolicyDefinitions types.WafPolicyDefinitionsType?

//
// Application Gateway
//
@description('Application Gateway configuration.')
param appGatewayDefinition types.AppGatewayDefinitionType?

//
// API Management
//
@description('API Management configuration.')
param apimDefinition types.ApimDefinitionType?

//
// Firewall
//
@description('Firewall configuration.')
param firewallDefinition types.FirewallDefinitionType?

//
// Hub VNet Peering
//
@description('Hub VNet peering configuration.')
param hvnetPeeringDefinition types.HuVnetPeeringDefinitionType?

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

//
// Container vars
//

var _containerDummyImageName = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

//
// VM vars
//

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

// Split the full resource ID if passed in
var _vnetIdSegments = empty(resourceIds.virtualNetworkResourceId)
  ? ['']
  : split(resourceIds.virtualNetworkResourceId, '/')
var _existingVNetSubscriptionId = length(_vnetIdSegments) >= 3 ? _vnetIdSegments[2] : ''
var _existingVNetResourceGroupName = length(_vnetIdSegments) >= 5 ? _vnetIdSegments[4] : ''
var _existingVNetName = length(_vnetIdSegments) >= 1 ? last(_vnetIdSegments) : ''

resource existingVNet 'Microsoft.Network/virtualNetworks@2024-07-01' existing = if (!empty(resourceIds.virtualNetworkResourceId)) {
  name: _existingVNetName
  scope: resourceGroup(_existingVNetSubscriptionId, _existingVNetResourceGroupName)
}

var _vnetName = empty(vnetDefinition.name!)
  ? '${const.abbrs.networking.virtualNetwork}${resourceToken}'
  : vnetDefinition.name!

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.7.0' = if (empty(resourceIds.virtualNetworkResourceId)) {
  name: 'virtualNetworkDeployment'
  params: {
    name: _vnetName
    location: location
    tags: union(tags, vnetDefinition.tags! ?? {})
    addressPrefixes: [vnetDefinition.addressSpace]
    ddosProtectionPlanResourceId: vnetDefinition.ddosProtectionPlanResourceId!
    dnsServers: vnetDefinition.dnsServers!
    subnets: vnetDefinition.subnets
    peerings: empty(vnetDefinition.peerVnetResourceId)
      ? []
      : [
          {
            name: '${_vnetName}-to-peer'
            remoteVirtualNetworkResourceId: vnetDefinition.peerVnetResourceId
          }
        ]
  }
}

// Log Analytics Workspace

// Split the full resource ID if passed in
var _lawIdSegments = empty(resourceIds.logAnalyticsWorkspaceResourceId)
  ? ['']
  : split(resourceIds.logAnalyticsWorkspaceResourceId, '/')
var _existingLawSubscriptionId = length(_lawIdSegments) >= 3 ? _lawIdSegments[2] : ''
var _existingLawResourceGroupName = length(_lawIdSegments) >= 5 ? _lawIdSegments[4] : ''
var _existingLawName = length(_lawIdSegments) >= 1 ? last(_lawIdSegments) : ''

resource existingLogAnalytics 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = if (!empty(resourceIds.logAnalyticsWorkspaceResourceId)) {
  name: _existingLawName
  scope: resourceGroup(_existingLawSubscriptionId, _existingLawResourceGroupName)
}

module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.12.0' = if (empty(resourceIds.logAnalyticsWorkspaceResourceId)) {
  name: 'deployLogAnalytics'
  params: {
    name: empty(logAnalyticsDefinition.name!)
      ? '${const.abbrs.managementGovernance.logAnalyticsWorkspace}${resourceToken}'
      : logAnalyticsDefinition.name!
    location: location
    skuName: logAnalyticsDefinition.sku
    dataRetention: logAnalyticsDefinition.retention
    tags: union(tags, logAnalyticsDefinition.tags! ?? {})
    managedIdentities: {
      systemAssigned: true
    }
  }
}

// Application Insights

// Split the full resource ID if passed in
var _aiIdSegments = empty(resourceIds.appInsightsResourceId) ? [''] : split(resourceIds.appInsightsResourceId, '/')
var _existingAISubscriptionId = length(_aiIdSegments) >= 3 ? _aiIdSegments[2] : ''
var _existingAIResourceGroupName = length(_aiIdSegments) >= 5 ? _aiIdSegments[4] : ''
var _existingAIName = length(_aiIdSegments) >= 1 ? last(_aiIdSegments) : ''

resource existingAppInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(resourceIds.appInsightsResourceId)) {
  name: _existingAIName
  scope: resourceGroup(_existingAISubscriptionId, _existingAIResourceGroupName)
}

module appInsights 'br/public:avm/res/insights/component:0.6.0' = if (empty(resourceIds.appInsightsResourceId)) {
  name: 'deployAppInsights'
  params: {
    name: empty(appInsightsDefinition.name!)
      ? '${const.abbrs.managementGovernance.applicationInsights}${resourceToken}'
      : appInsightsDefinition.name!
    location: location
    #disable-next-line BCP318
    workspaceResourceId: empty(resourceIds.logAnalyticsWorkspaceResourceId)
      #disable-next-line BCP318
      ? logAnalytics.outputs.resourceId
      : resourceIds.logAnalyticsWorkspaceResourceId
    applicationType: appInsightsDefinition.applicationType ?? 'web'
    kind: appInsightsDefinition.kind ?? 'web'
    disableIpMasking: appInsightsDefinition.disableIpMasking! ?? false
    tags: union(tags, appInsightsDefinition.tags! ?? {})
  }
}

// Container Apps Environment

// Compute the subnet ID for "aca-environment-subnet"
var _subnetIDCappEnvSubnet = empty(resourceIds.virtualNetworkResourceId)
  #disable-next-line BCP318
  ? virtualNetwork.outputs.subnetResourceIds[indexOf(
      #disable-next-line BCP318
      virtualNetwork.outputs.subnetNames,
      containerAppEnvDefinition.subnetName!
    )]
  : '${existingVNet.id}/subnets/${containerAppEnvDefinition.subnetName!}'

// Split the full resource ID if passed in
var _envIdSegments = empty(resourceIds.containerEnvResourceId) ? [''] : split(resourceIds.containerEnvResourceId, '/')
var _existingEnvSubscriptionId = length(_envIdSegments) >= 3 ? _envIdSegments[2] : ''
var _existingEnvResourceGroup = length(_envIdSegments) >= 5 ? _envIdSegments[4] : ''
var _existingEnvName = length(_envIdSegments) >= 1 ? last(_envIdSegments) : ''

resource existingContainerEnv 'Microsoft.App/managedEnvironments@2025-02-02-preview' existing = if (!empty(resourceIds.containerEnvResourceId)) {
  name: _existingEnvName
  scope: resourceGroup(_existingEnvSubscriptionId, _existingEnvResourceGroup)
}

// Create Container App Environment if not provided
module containerEnv 'br/public:avm/res/app/managed-environment:0.11.2' = if (empty(resourceIds.containerEnvResourceId)) {
  name: 'deployContainerEnv'
  params: {
    name: empty(containerAppEnvDefinition.name!)
      ? '${const.abbrs.containers.containerAppsEnvironment}${resourceToken}'
      : containerAppEnvDefinition.name!
    location: location
    tags: union(tags, containerAppEnvDefinition.tags! ?? {})

    appInsightsConnectionString: !empty(resourceIds.containerEnvResourceId)
      #disable-next-line BCP318
      ? existingAppInsights.properties.ConnectionString
      #disable-next-line BCP318
      : appInsights.outputs.connectionString

    zoneRedundant: containerAppEnvDefinition.zoneRedundancyEnabled

    workloadProfiles: containerAppEnvDefinition.workloadProfiles

    managedIdentities: {
      systemAssigned: !empty(containerAppEnvDefinition.userAssignedManagedIdentityIds) ? false : true
      userAssignedResourceIds: containerAppEnvDefinition.userAssignedManagedIdentityIds
    }

    infrastructureSubnetResourceId: containerAppEnvDefinition.internalLoadBalancerEnabled ? _subnetIDCappEnvSubnet : ''
    internal: containerAppEnvDefinition.internalLoadBalancerEnabled

    roleAssignments: [
      for ra in containerAppEnvDefinition.roleAssignments: {
        name: ra.name! ?? guid(resourceIds.containerEnvResourceId, ra.principalId)
        principalId: ra.principalId
        roleDefinitionIdOrName: ra.roleDefinitionIdOrName
        principalType: ra.principalType
        description: ra.description!
        condition: ra.condition!
        conditionVersion: ra.conditionVersion!
        delegatedManagedIdentityResourceId: ra.delegatedManagedIdentityResourceId!
      }
    ]
  }
}

// Container Registry

// Create Container Registry if not provided
module registry 'br/public:avm/res/container-registry/registry:0.9.1' = {
  name: 'registryDeployment'
  params: {
    // Required parameters
    name: empty(containerRegistryDefinition.name!)
      ? '${const.abbrs.containers.containerRegistry}${resourceToken}'
      : containerRegistryDefinition.name!
    // Non-required parameters
    acrSku: containerRegistryDefinition.sku ?? null
    location: location
    tags: union(tags, containerRegistryDefinition.tags! ?? {})
  }
}

// Cosmos DB Account

// Create CosmosDB if not provided

module databaseAccount 'br/public:avm/res/document-db/database-account:0.15.0' = {
  name: 'databaseAccountDeployment'
  params: {
    // Required parameters
    name: empty(cosmosDbDefinition.name!)
      ? '${const.abbrs.databases.cosmosDBDatabase}${resourceToken}'
      : cosmosDbDefinition.name!
    // Non-required parameters
    zoneRedundant: false
  }
}

// Key Vault

// Create Key Vault if not provided
module vault 'br/public:avm/res/key-vault/vault:0.13.0' = {
  name: 'vaultDeployment'
  params: {
    // Required parameters
    name: empty(keyVaultDefinition.name!)
      ? '${const.abbrs.security.keyVault}${resourceToken}'
      : keyVaultDefinition.name!
    // Non-required parameters
    enablePurgeProtection: false
    tags: union(tags, keyVaultDefinition.tags! ?? {})
  }
}

// Storage Account

// Create Storage Account if not provided
module storageAccount 'br/public:avm/res/storage/storage-account:0.25.1' = {
  name: 'storageAccountDeployment'
  params: {
    // Required parameters
    name: empty(storageAccountDefinition.name!)
      ? '${const.abbrs.storage.storageAccount}${resourceToken}'
      : storageAccountDefinition.name!
    // Non-required parameters
    allowBlobPublicAccess: storageAccountDefinition.publicNetworkAccessEnabled ?? false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    tags: union(tags, storageAccountDefinition.tags! ?? {})
  }
}

// AI Search

// Create AI Search if not provided
module searchService 'br/public:avm/res/search/search-service:0.11.0' = {
  name: 'searchServiceDeployment'
  params: {
    name: empty(searchDefinition.name!)
      ? '${const.abbrs.ai.aiSearch}${resourceToken}'
      : searchDefinition.name!
    tags: union(tags, searchDefinition.tags! ?? {})
  }
}

//////////////////////////////////////////////////////////////////////////
// OUTPUTS
//////////////////////////////////////////////////////////////////////////

// ──────────────────────────────────────────────────────────────────────
// General / Deployment
// ──────────────────────────────────────────────────────────────────────
output tenantId string = tenant().tenantId
output subscriptionId string = subscription().subscriptionId
output resourceGroupName string = resourceGroup().name
output location string = location

// ──────────────────────────────────────────────────────────────────────
// Resource IDs
// ──────────────────────────────────────────────────────────────────────
output virtualNetworkResourceId string = empty(resourceIds.virtualNetworkResourceId)
  #disable-next-line BCP318
  ? virtualNetwork.outputs.resourceId
  : existingVNet.id

output logAnalyticsWorkspaceResourceId string = empty(resourceIds.logAnalyticsWorkspaceResourceId)
  #disable-next-line BCP318
  ? logAnalytics.outputs.resourceId
  : existingLogAnalytics.id

output applicationInsightsResourceId string = empty(resourceIds.appInsightsResourceId)
  #disable-next-line BCP318
  ? appInsights.outputs.resourceId
  : existingAppInsights.id

output containerEnvResourceId string = empty(resourceIds.containerEnvResourceId)
  #disable-next-line BCP318
  ? containerEnv.outputs.resourceId
  : existingContainerEnv.id
