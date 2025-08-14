targetScope = 'resourceGroup'

///////////////////////////////////////////////////////////////////////////////////////////////////
// main.bicep
//
// Purpose: Landing Zone for GenAI app resources + AI Foundry pattern, network-isolated by default.
//
// How to read this file:
//   §1  PARAMETERS
//       1.1 Imports
//       1.2 General configuration (location, tags, token)
//       1.3 Reuse existing services (resourceIds)
//       1.4 Service definitions (VNet, Observability, Containers, Data/Security, App Config, PDNS IDs,
//           AI Foundry, Gateways, APIM, Firewall, Hub Peering)
//   §2  VARIABLES (globals)
//   §3  RESOURCES (grouped by domain)
//       3.1 Networking (VNet)
//       3.2 Deploy/has flags + subnet helpers
//       3.3 Private DNS Zones
//       3.4 Private Endpoints (helpers + per-service)
//       3.5 Existing resources (APIM, AGW, Firewall)
//       3.6 Observability (LAW, App Insights)
//       3.7 Container Apps Environment
//       3.8 Core App Services (ACR, Cosmos, KV, KV for AF, Storage, Search, App Config)
//       3.9 AI Foundry (AVM pattern)
//       3.10 Gateways (WAF policy, App Gateway, Azure Firewall, APIM)
//       3.11 Hub/Spoke Peering
//   §4  OUTPUTS
//
///////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////
// §1. PARAMETERS
//////////////////////////////////////////////////////////////////////////

// 1.1 Imports
import * as const from 'common/constants.bicep'
import * as types from 'common/types.bicep'

// 1.2 General Configuration
@description('Azure region for AI Foundry resources.')
param location string = resourceGroup().location

@description('Tags applied to all deployed resources.')
param tags object = {}

// 1.2.1 Token
@description('Deterministic token for resource names.')
param resourceToken string = toLower(uniqueString(subscription().id, resourceGroup().name, location))

// 1.3 Reuse Existing Services
@description('Optional existing resource IDs to reuse; leave empty to create new resources.')
param resourceIds types.ResourceIdsType = {
  // Core you already had
  virtualNetworkResourceId: ''
  logAnalyticsWorkspaceResourceId: ''
  appInsightsResourceId: ''
  containerEnvResourceId: ''
  containerRegistryResourceId: ''
  dbAccountResourceId: ''
  keyVaultResourceId: ''
  storageAccountResourceId: ''
  searchServiceResourceId: ''
  appConfigResourceId: ''
  apimServiceResourceId: ''
  applicationGatewayResourceId: ''
  bastionHostResourceId: ''
  firewallResourceId: ''
  groundingServiceResourceId: ''
}

// 1.4 Service Definitions
// 1.4.1 Virtual Network
@description('Virtual Network configuration.')
param vnetDefinition types.VNetDefinitionType = {
  name: ''
  addressSpace: '192.168.0.0/16'
  dnsServers: []
  subnets: [
    {
      enabled: true
      name: 'agent-subnet'
      addressPrefix: '192.168.0.0/24'
      delegation: 'Microsoft.app/environments'
      serviceEndpoints: ['Microsoft.CognitiveServices']
    }
    {
      enabled: true
      name: 'pe-subnet'
      addressPrefix: '192.168.1.0/24'
      serviceEndpoints: ['Microsoft.AzureCosmosDB']
    }
    {
      enabled: true
      name: 'gateway-subnet'
      addressPrefix: '192.168.2.0/26'
    }
    {
      enabled: true
      name: 'AzureBastionSubnet'
      addressPrefix: '192.168.2.64/26'
    }
    {
      enabled: true
      name: 'AzureFirewallSubnet'
      addressPrefix: '192.168.2.128/26'
    }
    {
      enabled: true
      name: 'AppGatewaySubnet'
      addressPrefix: '192.168.3.0/24'
    }
    {
      enabled: true
      name: 'jumpbox-subnet'
      addressPrefix: '192.168.4.0/27'
    }
    {
      enabled: true
      name: 'aca-environment-subnet'
      addressPrefix: '192.168.4.64/27'
      delegation: 'Microsoft.app/environments'
      serviceEndpoints: ['Microsoft.AzureCosmosDB']
    }
    {
      enabled: true
      name: 'devops-build-agents-subnet'
      addressPrefix: '192.168.4.96/27'
    }
  ]
  peerVnetResourceId: ''
  tags: {}
}

// 1.4.2 Log Analytics Workspace
@description('Log Analytics Workspace configuration.')
param logAnalyticsDefinition types.LogAnalyticsWorkspaceDefinitionType = {
  name: ''
  retention: 30
  sku: 'PerGB2018'
  tags: {}
}

// 1.4.3 Application Insights
@description('Application Insights configuration.')
param appInsightsDefinition types.AppInsightsDefinitionType = {
  name: ''
  applicationType: 'web'
  kind: 'web'
  disableIpMasking: false
  tags: {}
}

// 1.4.4 Container App Environment
@description('Container App Environment configuration.')
param containerAppEnvDefinition types.ContainerAppEnvDefinitionType = {
  name: ''
  tags: {}
  subnetName: 'aca-environment-subnet'
  internalLoadBalancerEnabled: true
  zoneRedundancyEnabled: false
  userAssignedManagedIdentityIds: []
  workloadProfiles: [
    {
      name: 'Consumption'
      workloadProfileType: 'Consumption'
    }
    {
      workloadProfileType: 'D4'
      name: 'default'
      minimumCount: 1
      maximumCount: 3
    }
  ]
  roleAssignments: []
}

// 1.4.5 Container Registry
@description('Container Registry configuration.')
param containerRegistryDefinition types.ContainerRegistryDefinitionType = {
  name: ''
  sku: 'Premium'
  tags: {}
}

// 1.4.6 Cosmos DB Account (GenAI app scope)
@description('Cosmos DB account configuration (GenAI app scope).')
param cosmosDbDefinition types.GenAIAppCosmosDbDefinitionType = {
  name: ''
  publicNetworkAccessEnabled: false
  automaticFailoverEnabled: true
}

// 1.4.7 Key Vault (GenAI app scope)
@description('Key Vault configuration (GenAI app scope).')
param keyVaultDefinition types.KeyVaultDefinitionType = {
  name: ''
  sku: 'standard'
  tenantId: subscription().tenantId
  roleAssignments: []
  tags: {}
}

// 1.4.8 Storage Account (GenAI app scope)
@description('Storage Account configuration (GenAI app scope).')
param storageAccountDefinition types.StorageAccountDefinitionType = {
  name: ''
  accountKind: 'StorageV2'
  accountTier: 'Standard'
  accountReplicationType: 'LRS'
  tags: {}
}

// 1.4.9 AI Search (GenAI app scope)
@description('AI Search service configuration (GenAI app scope).')
param searchDefinition types.KSAISearchDefinitionType = {
  name: ''
  sku: 'standard'
  publicNetworkAccessEnabled: false
  replicaCount: 1
  partitionCount: 1
  tags: {}
}

// 1.4.10 Key Vault (AI Foundry)
@description('Key Vault configuration (Ai Foundry scope).')
param keyVaultAiFoundryDefinition types.KeyVaultDefinitionType = {
  name: ''
  sku: 'standard'
  tenantId: subscription().tenantId
  roleAssignments: []
  tags: {}
}

// 1.4.11 App Configuration
@description('App Configuration store configuration.')
param appConfigurationDefinition types.AppConfigurationDefinitionType = {
  name: ''
  sku: 'standard'
  localAuthEnabled: false
  purgeProtectionEnabled: true
  softDeleteRetentionInDays: 7
  tags: {}
  roleAssignments: []
}

// 1.4.12 Private DNS Zone IDs (optional reuse)
@description('Optional existing Private DNS Zone resource IDs per service. Leave empty to create.')
param privateDnsZoneIds object = {
  cognitiveservices: ''
  openai: ''
  aiServices: ''
  search: ''
  cosmosSql: ''
  blob: ''
  keyVault: ''
  appConfig: ''
  containerApps: ''
  acr: ''
  appInsights: ''
}

// 1.4.13 AI Foundry
@description('AI Foundry project configuration.')
param aiFoundryDefinition types.AiFoundryDefinitionType = {
  aiFoundryProjectDescription: 'AI Foundry Project'
  aiModelDeployments: {
    chat: {
      name: 'chat'
      raiPolicyName: ''
      versionUpgradeOption: ''
      model: {
        format: 'OpenAI'
        name: 'gpt-4o'
        version: '2024-11-20'
      }
      scale: {
        capacity: 40
        family: ''
        size: ''
        tier: ''
        type: 'GlobalStandard'
      }
    }
    'text-embedding': {
      name: 'text-embedding'
      raiPolicyName: ''
      versionUpgradeOption: ''
      model: {
        format: 'OpenAI'
        name: 'text-embedding-3-large'
        version: '1'
      }
      scale: {
        capacity: 40
        family: ''
        size: ''
        tier: ''
        type: 'Standard'
      }
    }
  }
  createAiAgentService: false
  createProjectConnections: true
  lock: {
    kind: 'None'
    name: ''
  }
  aiFoundryResources: {
    createDependentResources: true // ignored (will infer based on the following fields)
    aiSearch: { existingResourceId: '', name: '' }
    cosmosDb: { existingResourceId: '', name: '' }
    storageAccount: { existingResourceId: '', name: '' }
    keyVault: { existingResourceId: '', name: '' }
  }
  roleAssignments: []
  tags: {}
}

// 1.4.14 WAF Policy
@description('WAF Policy configuration.')
param wafPolicyDefinition types.WafPolicyDefinitionsType = {
  name: ''
  policySettings: {
    state: 'Enabled'
    mode: 'Prevention'
    requestBodyCheck: true
    maxRequestBodySizeInKb: 128
    fileUploadLimitInMb: 100
  }
  managedRules: {
    exclusion: {}
    managedRuleSet: {
      defaultSet: {
        type: 'OWASP'
        version: '3.2'
        ruleGroupOverride: {}
      }
    }
  }
  tags: {}
}

// 1.4.15 Application Gateway
@description('Application Gateway configuration.')
param appGatewayDefinition types.AppGatewayDefinitionType = {
  name: ''
  http2Enable: false
  authenticationCertificate: {}
  sku: { name: 'Standard_v2', tier: 'Standard_v2', capacity: 1 }
  autoscaleConfiguration: { minCapacity: 1, maxCapacity: 2 }
  backendAddressPools: {
    defaultPool: { name: 'defaultPool', fqdns: [], ipAddresses: [] }
  }
  backendHttpSettings: {
    defaultSetting: {
      cookieBasedAffinity: 'Disabled'
      name: 'defaultSetting'
      port: 80
      protocol: 'Http'
      affinityCookieName: ''
      hostName: ''
      path: ''
      pickHostNameFromBackendAddress: false
      probeName: ''
      requestTimeout: 30
      trustedRootCertificateNames: []
      authenticationCertificate: []
      connectionDraining: { enabled: false, drainTimeoutSec: 0 }
    }
  }
  frontendPorts: { port80: { name: 'port80', port: 80 } }
  httpListeners: {
    defaultListener: {
      name: 'defaultListener'
      frontendPortName: 'port80'
      frontendIpConfigurationName: 'privateFrontend'
      firewallPolicyId: ''
      requireSni: false
      hostName: ''
      hostNames: []
      sslCertificateName: ''
      sslProfileName: ''
      customErrorConfiguration: []
    }
  }
  probeConfigurations: {}
  redirectConfiguration: {
    defaultRedirect: {
      includePath: true
      includeQueryString: true
      name: 'defaultRedirect'
      redirectType: 'Permanent'
      targetListenerName: ''
      targetUrl: 'https://example.com'
    }
  }
  requestRoutingRules: {
    defaultRule: {
      name: 'defaultRule'
      ruleType: 'Basic'
      httpListenerName: 'defaultListener'
      backendAddressPoolName: ''
      priority: 100
      urlPathMapName: ''
      backendHttpSettingsName: ''
      redirectConfigurationName: 'defaultRedirect'
      rewriteRuleSetName: ''
    }
  }
  rewriteRuleSet: {}
  sslCertificates: {}
  sslPolicy: {
    cipherSuites: []
    disabledProtocols: []
    minProtocolVersion: 'TLSv1_2'
    policyName: ''
    policyType: 'Custom'
  }
  sslProfile: {}
  trustedClientCertificate: {}
  trustedRootCertificate: {}
  urlPathMapConfigurations: {}
  tags: {}
  roleAssignments: []
}

// 1.4.16 API Management
@description('API Management configuration.')
param apimDefinition types.ApimDefinitionType = {
  name: ''
  publisherEmail: 'admin@example.com'
  publisherName: 'Contoso'
  additionalLocations: {}
  certificate: {}
  clientCertificateEnabled: false
  hostnameConfiguration: { management: {}, portal: {}, developerPortal: {}, proxy: {}, scm: {} }
  minApiVersion: '2019-12-01'
  notificationSenderEmail: 'apimgmt-noreply@azure.com'
  protocols: { enableHttp2: true }
  roleAssignments: []
  signIn: { enabled: true }
  signUp: { enabled: false, termsOfService: { consentRequired: false, enabled: false, text: '' } }
  skuRoot: 'Developer'
  skuCapacity: 1
  tags: {}
  tenantAccess: { enabled: true }
}

// 1.4.17 Azure Firewall
@description('Azure Firewall configuration.')
param firewallDefinition types.FirewallDefinitionType = {
  name: ''
  sku: 'AZFW_VNet'
  tier: 'Standard'
  zones: []
  tags: {}
}

// 1.4.18 Hub VNet Peering
@description('Hub VNet peering configuration.')
param hubVnetPeeringDefinition types.HuVnetPeeringDefinitionType = {
  name: ''
  peerVnetResourceId: ''
  firewallIpAddress: ''
  allowForwardedTraffic: true
  allowGatewayTransit: false
  allowVirtualNetworkAccess: true
  createReversePeering: true
  reverseAllowForwardedTraffic: true
  reverseAllowGatewayTransit: false
  reverseAllowVirtualNetworkAccess: true
  reverseName: ''
  reverseUseRemoteGateways: false
  useRemoteGateways: false
}

//////////////////////////////////////////////////////////////////////////
// §2. VARIABLES (globals)
//////////////////////////////////////////////////////////////////////////

// Tags merged once for reuse
var _tags = union(tags, vnetDefinition.tags! ?? {})

// Whether we’re in a network-isolated posture (toggle as needed)
var _networkIsolation = true

// Container vars
var _containerDummyImageName = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

//////////////////////////////////////////////////////////////////////////
// §3. RESOURCES
//////////////////////////////////////////////////////////////////////////

// ──────────────────────────────────────────────────────────────────────
// 3.1 Networking — VNet (reuse or create)
// ─────────────────────────────────────────────────────────────────────-
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
    tags: _tags
    addressPrefixes: [vnetDefinition.addressSpace]
    dnsServers: vnetDefinition.dnsServers!
    // Only deploy enabled subnets
    subnets: [
      for s in vnetDefinition.subnets: {
        name: s.name
        addressPrefix: s.addressPrefix
        ...(contains(s, 'delegation') && !empty(s.delegation!) ? { delegation: s.delegation! } : {})
        ...(contains(s, 'serviceEndpoints') && !empty(s.serviceEndpoints!)
          ? { serviceEndpoints: s.serviceEndpoints! }
          : {})
      }
    ]
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

// VNet resourceId that works for both reuse/new
var _vnetResourceId = empty(resourceIds.virtualNetworkResourceId) ? virtualNetwork.outputs.resourceId : existingVNet.id

// ──────────────────────────────────────────────────────────────────────
// 3.2 Deploy/Reuse flags & “has” flags + AGW/FW subnet helpers
// ─────────────────────────────────────────────────────────────────────-
@description('Deploy GenAI app core; if null, defaults to true.')
param deployGenAiAppCore bool = true

// Decoupled deploy flags: GenAI-app stack is independent of AI Foundry
var _deploySa = empty(resourceIds.storageAccountResourceId) && deployGenAiAppCore
var _deployCosmos = empty(resourceIds.dbAccountResourceId) && deployGenAiAppCore
var _deploySearch = empty(resourceIds.searchServiceResourceId) && deployGenAiAppCore
var _deployKv = empty(resourceIds.keyVaultResourceId) && deployGenAiAppCore
var _deployContainerAppEnv = empty(resourceIds.containerEnvResourceId) && deployGenAiAppCore
var _deployAppConfig = empty(resourceIds.appConfigResourceId)
var _deployAcr = empty(resourceIds.containerRegistryResourceId) && deployGenAiAppCore
var _deployApim = empty(resourceIds.apimServiceResourceId)
var _deployAppGateway = empty(resourceIds.applicationGatewayResourceId)
var _deployFirewall = empty(resourceIds.firewallResourceId)

// “has” reflects presence (existing or will be created here) for GenAI-app stack
var _hasStorage = (!empty(resourceIds.storageAccountResourceId)) || (_deploySa)
var _hasCosmos = (!empty(resourceIds.dbAccountResourceId)) || (_deployCosmos)
var _hasSearch = (!empty(resourceIds.searchServiceResourceId)) || (_deploySearch)
var _hasKv = (!empty(resourceIds.keyVaultResourceId)) || (_deployKv)
var _hasContainerEnv = (!empty(resourceIds.containerEnvResourceId)) || (_deployContainerAppEnv)
var _hasAppConfig = (!empty(resourceIds.appConfigResourceId)) || (_deployAppConfig)
var _hasAcr = (!empty(resourceIds.containerRegistryResourceId)) || (_deployAcr)

// App Insights PDNS creation dependency
var _deployAppInsights = empty(resourceIds.appInsightsResourceId)
var _hasAppInsights = (!empty(resourceIds.appInsightsResourceId)) || (_deployAppInsights)

// Helpers for AGW/FW subnets
var _agwSubnetName = 'AppGatewaySubnet'
var _agwSubnetId = empty(resourceIds.virtualNetworkResourceId)
  ? virtualNetwork.outputs.subnetResourceIds[indexOf(virtualNetwork.outputs.subnetNames, _agwSubnetName)]
  : '${existingVNet.id}/subnets/${_agwSubnetName}'

var _afwSubnetName = 'AzureFirewallSubnet'
var _afwSubnetId = empty(resourceIds.virtualNetworkResourceId)
  ? virtualNetwork.outputs.subnetResourceIds[indexOf(virtualNetwork.outputs.subnetNames, _afwSubnetName)]
  : '${existingVNet.id}/subnets/${_afwSubnetName}'

// ──────────────────────────────────────────────────────────────────────
// 3.3 Private DNS Zones (create when isolated AND per-zone ID not provided)
// ─────────────────────────────────────────────────────────────────────-
var _useExistingPdz = {
  cognitiveservices: !empty(privateDnsZoneIds.cognitiveservices)
  openai: !empty(privateDnsZoneIds.openai)
  aiServices: !empty(privateDnsZoneIds.aiServices)
  search: !empty(privateDnsZoneIds.search)
  cosmosSql: !empty(privateDnsZoneIds.cosmosSql)
  blob: !empty(privateDnsZoneIds.blob)
  keyVault: !empty(privateDnsZoneIds.keyVault)
  appConfig: !empty(privateDnsZoneIds.appConfig)
  containerApps: !empty(privateDnsZoneIds.containerApps)
  acr: !empty(privateDnsZoneIds.acr)
  appInsights: !empty(privateDnsZoneIds.appInsights)
}

// PDNS needs: create zone if GenAI-app needs it OR AI Foundry will create its own dep
// In this template Foundry will always have dependencies (Standard setup)
var _foundryNeedsCosmosPdns = true
var _foundryNeedsBlobPdns = true
var _foundryNeedsSearchPdns = true
var _foundryNeedsKvPdns = true

var _appNeedsCosmosPdns = _hasCosmos
var _appNeedsBlobPdns = _hasStorage
var _appNeedsSearchPdns = _hasSearch
var _appNeedsKvPdns = _hasKv

var _needCosmosPdns = _appNeedsCosmosPdns || _foundryNeedsCosmosPdns
var _needBlobPdns = _appNeedsBlobPdns || _foundryNeedsBlobPdns
var _needSearchPdns = _appNeedsSearchPdns || _foundryNeedsSearchPdns
var _needKvPdns = _appNeedsKvPdns || _foundryNeedsKvPdns

// Cognitiveservices
module privateDnsZoneCogSvcs 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (_networkIsolation && !_useExistingPdz.cognitiveservices) {
  name: 'dep-cogsvcs-private-dns-zone'
  params: {
    name: 'privatelink.cognitiveservices.azure.com'
    location: 'global'
    tags: _tags
    virtualNetworkLinks: [
      {
        name: '${_vnetName}-cogsvcs-link'
        registrationEnabled: false
        virtualNetworkResourceId: _vnetResourceId
      }
    ]
  }
}

// OpenAI
module privateDnsZoneOpenAi 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (_networkIsolation && !_useExistingPdz.openai) {
  name: 'dep-openai-private-dns-zone'
  params: {
    name: 'privatelink.openai.azure.com'
    location: 'global'
    tags: _tags
    virtualNetworkLinks: [
      {
        name: '${_vnetName}-openai-link'
        registrationEnabled: false
        virtualNetworkResourceId: _vnetResourceId
      }
    ]
  }
}

// AI Services
module privateDnsZoneAiService 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (_networkIsolation && !_useExistingPdz.aiServices) {
  name: 'dep-aiservices-private-dns-zone'
  params: {
    name: 'privatelink.services.ai.azure.com'
    location: 'global'
    tags: _tags
    virtualNetworkLinks: [
      {
        name: '${_vnetName}-aiservices-link'
        registrationEnabled: false
        virtualNetworkResourceId: _vnetResourceId
      }
    ]
  }
}

// Search (needed by GenAI app and/or AF)
module privateDnsZoneSearch 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (_networkIsolation && !_useExistingPdz.search && _needSearchPdns) {
  name: 'dep-search-std-private-dns-zone'
  params: {
    name: 'privatelink.search.windows.net'
    location: 'global'
    tags: _tags
    virtualNetworkLinks: [
      {
        name: '${_vnetName}-search-std-link'
        registrationEnabled: false
        virtualNetworkResourceId: _vnetResourceId
      }
    ]
  }
}

// Cosmos (SQL) (needed by GenAI app and/or AF)
module privateDnsZoneCosmos 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (_networkIsolation && !_useExistingPdz.cosmosSql && _needCosmosPdns) {
  name: 'dep-cosmos-std-private-dns-zone'
  params: {
    name: 'privatelink.documents.azure.com'
    location: 'global'
    tags: _tags
    virtualNetworkLinks: [
      {
        name: '${_vnetName}-cosmos-std-link'
        registrationEnabled: false
        virtualNetworkResourceId: _vnetResourceId
      }
    ]
  }
}

// Blob (needed by GenAI app and/or AF)
module privateDnsZoneBlob 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (_networkIsolation && !_useExistingPdz.blob && _needBlobPdns) {
  name: 'dep-blob-std-private-dns-zone'
  params: {
    name: 'privatelink.blob.${environment().suffixes.storage}'
    location: 'global'
    tags: _tags
    virtualNetworkLinks: [
      {
        name: '${_vnetName}-blob-std-link'
        registrationEnabled: false
        virtualNetworkResourceId: _vnetResourceId
      }
    ]
  }
}

// Key Vault (tie creation to whether ANY stack needs KV)
module privateDnsZoneKeyVault 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (_networkIsolation && !_useExistingPdz.keyVault && _needKvPdns) {
  name: 'kv-private-dns-zone'
  params: {
    name: 'privatelink.vaultcore.azure.net'
    location: 'global'
    tags: _tags
    virtualNetworkLinks: [
      {
        name: '${_vnetName}-kv-link'
        registrationEnabled: false
        virtualNetworkResourceId: _vnetResourceId
      }
    ]
  }
}

// App Configuration
module privateDnsZoneAppConfig 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (_networkIsolation && !_useExistingPdz.appConfig && _hasAppConfig) {
  name: 'appconfig-private-dns-zone'
  params: {
    name: 'privatelink.azconfig.io'
    location: 'global'
    tags: _tags
    virtualNetworkLinks: [
      {
        name: '${_vnetName}-appcfg-link'
        registrationEnabled: false
        virtualNetworkResourceId: _vnetResourceId
      }
    ]
  }
}

// Container Apps (regional PDNS zone)
module privateDnsZoneContainerApps 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (_networkIsolation && !_useExistingPdz.containerApps && _hasContainerEnv) {
  name: 'dep-containerapps-env-private-dns-zone'
  params: {
    name: 'privatelink.${location}.azurecontainerapps.io'
    location: 'global'
    tags: _tags
    virtualNetworkLinks: [
      {
        name: '${_vnetName}-containerapps-link'
        registrationEnabled: false
        virtualNetworkResourceId: _vnetResourceId
      }
    ]
  }
}

// Container Registry PDNS
module privateDnsZoneAcr 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (_networkIsolation && !_useExistingPdz.acr && _hasAcr) {
  name: 'acr-private-dns-zone'
  params: {
    name: 'privatelink.azurecr.io'
    location: 'global'
    tags: _tags
    virtualNetworkLinks: [
      {
        name: '${_vnetName}-acr-link'
        registrationEnabled: false
        virtualNetworkResourceId: _vnetResourceId
      }
    ]
  }
}

// App Insights PDNS
module privateDnsZoneInsights 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (_networkIsolation && !_useExistingPdz.appInsights && _hasAppInsights) {
  name: 'ai-private-dns-zone'
  params: {
    name: 'privatelink.applicationinsights.io'
    location: 'global'
    tags: _tags
    virtualNetworkLinks: [
      {
        name: '${_vnetName}-ai-link'
        registrationEnabled: false
        virtualNetworkResourceId: _vnetResourceId
      }
    ]
  }
}

// ─────────────────────────────────────────────────────────────────────-
// 3.4 Private Endpoints (helpers + per-service)
// ─────────────────────────────────────────────────────────────────────-
var _peSubnetName = 'pe-subnet'

var _peSubnetId = empty(resourceIds.virtualNetworkResourceId)
  ? virtualNetwork.outputs.subnetResourceIds[indexOf(virtualNetwork.outputs.subnetNames, _peSubnetName)]
  : '${existingVNet.id}/subnets/${_peSubnetName}'

// App Configuration
module privateEndpointAppConfig 'br/public:avm/res/network/private-endpoint:0.11.0' = if (_networkIsolation && _hasAppConfig) {
  name: 'appconfig-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${resourceToken}-appcs'
    location: location
    tags: tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'appConfigConnection'
        properties: {
          privateLinkServiceId: empty(resourceIds.appConfigResourceId)
            ? configurationStore.outputs.resourceId
            : existingAppConfig.id
          groupIds: ['configurationStores']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'appConfigDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'appConfigARecord'
          privateDnsZoneResourceId: !_useExistingPdz.appConfig
            ? privateDnsZoneAppConfig.outputs.resourceId
            : privateDnsZoneIds.appConfig
        }
      ]
    }
  }
}

// Container Apps Environment
module privateEndpointContainerAppsEnv 'br/public:avm/res/network/private-endpoint:0.11.0' = if (_networkIsolation && _hasContainerEnv) {
  name: 'containerapps-env-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${resourceToken}-cae'
    location: location
    tags: tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'ccaConnection'
        properties: {
          privateLinkServiceId: empty(resourceIds.containerEnvResourceId)
            ? containerEnv.outputs.resourceId
            : existingContainerEnv.id
          groupIds: ['managedEnvironments']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'ccaDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'ccaARecord'
          privateDnsZoneResourceId: !_useExistingPdz.containerApps
            ? privateDnsZoneContainerApps.outputs.resourceId
            : privateDnsZoneIds.containerApps
        }
      ]
    }
  }
}

// Azure Container Registry
module privateEndpointAcr 'br/public:avm/res/network/private-endpoint:0.11.0' = if (_networkIsolation && _hasAcr) {
  name: 'acr-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${resourceToken}-acr'
    location: location
    tags: tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'acrConnection'
        properties: {
          privateLinkServiceId: empty(resourceIds.containerRegistryResourceId)
            ? registry.outputs.resourceId
            : existingAcr.id
          groupIds: ['registry']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'acrDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'acrARecord'
          privateDnsZoneResourceId: !_useExistingPdz.acr ? privateDnsZoneAcr.outputs.resourceId : privateDnsZoneIds.acr
        }
      ]
    }
  }
}

// Storage (blob)
module privateEndpointStorageBlob 'br/public:avm/res/network/private-endpoint:0.11.0' = if (_networkIsolation && _hasStorage) {
  name: 'blob-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${resourceToken}-stg'
    location: location
    tags: tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'blobConnection'
        properties: {
          privateLinkServiceId: empty(resourceIds.storageAccountResourceId)
            ? storageAccount.outputs.resourceId
            : existingStorage.id
          groupIds: ['blob']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'blobDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'blobARecord'
          privateDnsZoneResourceId: !_useExistingPdz.blob
            ? privateDnsZoneBlob.outputs.resourceId
            : privateDnsZoneIds.blob
        }
      ]
    }
  }
}

// Cosmos DB (SQL)
module privateEndpointCosmos 'br/public:avm/res/network/private-endpoint:0.11.0' = if (_networkIsolation && _hasCosmos) {
  name: 'cosmos-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${resourceToken}-cosmos'
    location: location
    tags: tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'cosmosConnection'
        properties: {
          privateLinkServiceId: empty(resourceIds.dbAccountResourceId)
            ? databaseAccount.outputs.resourceId
            : existingCosmos.id
          groupIds: ['Sql']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'cosmosDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'cosmosARecord'
          privateDnsZoneResourceId: !_useExistingPdz.cosmosSql
            ? privateDnsZoneCosmos.outputs.resourceId
            : privateDnsZoneIds.cosmosSql
        }
      ]
    }
  }
}

// Azure AI Search
module privateEndpointSearch 'br/public:avm/res/network/private-endpoint:0.11.0' = if (_networkIsolation && _hasSearch) {
  name: 'search-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${resourceToken}-srch'
    location: location
    tags: tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'searchConnection'
        properties: {
          privateLinkServiceId: empty(resourceIds.searchServiceResourceId)
            ? searchService.outputs.resourceId
            : existingSearch.id
          groupIds: ['searchService']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'searchDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'searchARecord'
          privateDnsZoneResourceId: !_useExistingPdz.search
            ? privateDnsZoneSearch.outputs.resourceId
            : privateDnsZoneIds.search
        }
      ]
    }
  }
}

// Key Vault (GenAI)
module privateEndpointKeyVault 'br/public:avm/res/network/private-endpoint:0.11.0' = if (_networkIsolation && _hasKv) {
  name: 'kv-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${resourceToken}-kv'
    location: location
    tags: tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'kvConnection'
        properties: {
          privateLinkServiceId: empty(resourceIds.keyVaultResourceId) ? vault.outputs.resourceId : existingVault.id
          groupIds: ['vault']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'kvDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'kvARecord'
          privateDnsZoneResourceId: !_useExistingPdz.keyVault
            ? privateDnsZoneKeyVault.outputs.resourceId
            : privateDnsZoneIds.keyVault
        }
      ]
    }
  }
}

// Key Vault (AI Foundry)
module privateEndpointKeyVaultAiFoundry 'br/public:avm/res/network/private-endpoint:0.11.0' = if (_networkIsolation && _hasKvAiFoundry) {
  name: 'kv-private-endpoint-aifoundry'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${resourceToken}-aif-kv'
    location: location
    tags: tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'kvConnection'
        properties: {
          privateLinkServiceId: _deployKvAiFoundry ? vaultAiFoundry.outputs.resourceId : existingVaultAiFoundry.id
          groupIds: ['vault']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'kvDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'kvARecord'
          privateDnsZoneResourceId: !_useExistingPdz.keyVault
            ? privateDnsZoneKeyVault.outputs.resourceId
            : privateDnsZoneIds.keyVault
        }
      ]
    }
  }
}

// Storage (AI Foundry)
module privateEndpointStorageBlobAiFoundry 'br/public:avm/res/network/private-endpoint:0.11.0' = if (_networkIsolation) {
  name: 'blob-private-endpoint-aifoundry'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${resourceToken}-aif-stg'
    location: location
    tags: tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'blobConnection'
        properties: {
          privateLinkServiceId: aiFoundryDependencies.outputs.azureStorageId
          groupIds: ['blob']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'blobDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'blobARecord'
          privateDnsZoneResourceId: !_useExistingPdz.blob
            ? privateDnsZoneBlob.outputs.resourceId
            : privateDnsZoneIds.blob
        }
      ]
    }
  }
}

// Cosmos DB (AI Foundry)
module privateEndpointCosmosAiFoundry 'br/public:avm/res/network/private-endpoint:0.11.0' = if (_networkIsolation) {
  name: 'cosmos-private-endpoint-aifoundry'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${resourceToken}-aif-cosmos'
    location: location
    tags: tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'cosmosConnection'
        properties: {
          privateLinkServiceId: aiFoundryDependencies.outputs.cosmosDBId
          groupIds: ['Sql']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'cosmosDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'cosmosARecord'
          privateDnsZoneResourceId: !_useExistingPdz.cosmosSql
            ? privateDnsZoneCosmos.outputs.resourceId
            : privateDnsZoneIds.cosmosSql
        }
      ]
    }
  }
}

// Azure AI Search (AI Foundry)
module privateEndpointSearchAiFoundry 'br/public:avm/res/network/private-endpoint:0.11.0' = if (_networkIsolation) {
  name: 'search-private-endpoint-aifoundry'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${resourceToken}-aif-srch'
    location: location
    tags: tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'searchConnection'
        properties: {
          privateLinkServiceId: aiFoundryDependencies.outputs.aiSearchID
          groupIds: ['searchService']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'searchDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'searchARecord'
          privateDnsZoneResourceId: !_useExistingPdz.search
            ? privateDnsZoneSearch.outputs.resourceId
            : privateDnsZoneIds.search
        }
      ]
    }
  }
}

// ─────────────────────────────────────────────────────────────────────-
// 3.5 Existing Resources (APIM, AGW, Firewall)
// ─────────────────────────────────────────────────────────────────────-
// Existing APIM
var _apimIdSegments = empty(resourceIds.apimServiceResourceId) ? [''] : split(resourceIds.apimServiceResourceId, '/')
var _apimSub = length(_apimIdSegments) >= 3 ? _apimIdSegments[2] : ''
var _apimRg = length(_apimIdSegments) >= 5 ? _apimIdSegments[4] : ''
var _apimNameExisting = length(_apimIdSegments) >= 1 ? last(_apimIdSegments) : ''
resource existingApim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = if (!empty(resourceIds.apimServiceResourceId)) {
  name: _apimNameExisting
  scope: resourceGroup(_apimSub, _apimRg)
}

// Existing App Gateway
var _agwIdSegments = empty(resourceIds.applicationGatewayResourceId)
  ? ['']
  : split(resourceIds.applicationGatewayResourceId, '/')
var _agwSub = length(_agwIdSegments) >= 3 ? _agwIdSegments[2] : ''
var _agwRg = length(_agwIdSegments) >= 5 ? _agwIdSegments[4] : ''
var _agwNameExisting = length(_agwIdSegments) >= 1 ? last(_agwIdSegments) : ''
resource existingAppGateway 'Microsoft.Network/applicationGateways@2024-07-01' existing = if (!empty(resourceIds.applicationGatewayResourceId)) {
  name: _agwNameExisting
  scope: resourceGroup(_agwSub, _agwRg)
}

// Existing Firewall
var _afwIdSegments = empty(resourceIds.firewallResourceId) ? [''] : split(resourceIds.firewallResourceId, '/')
var _afwSub = length(_afwIdSegments) >= 3 ? _afwIdSegments[2] : ''
var _afwRg = length(_afwIdSegments) >= 5 ? _afwIdSegments[4] : ''
var _afwNameExisting = length(_afwIdSegments) >= 1 ? last(_afwIdSegments) : ''
resource existingFirewall 'Microsoft.Network/azureFirewalls@2024-07-01' existing = if (!empty(resourceIds.firewallResourceId)) {
  name: _afwNameExisting
  scope: resourceGroup(_afwSub, _afwRg)
}

// ─────────────────────────────────────────────────────────────────────-
// 3.6 Observability (LAW, App Insights)
// ─────────────────────────────────────────────────────────────────────-
// Log Analytics (helper vars before existing)
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
    managedIdentities: { systemAssigned: true }
  }
}

// App Insights
var _aiIdSegments = empty(resourceIds.appInsightsResourceId) ? [''] : split(resourceIds.appInsightsResourceId, '/')
var _existingAISubscriptionId = length(_aiIdSegments) >= 3 ? _aiIdSegments[2] : ''
var _existingAIResourceGroupName = length(_aiIdSegments) >= 5 ? _aiIdSegments[4] : ''
var _existingAIName = length(_aiIdSegments) >= 1 ? last(_aiIdSegments) : ''

resource existingAppInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(resourceIds.appInsightsResourceId)) {
  name: _existingAIName
  scope: resourceGroup(_existingAISubscriptionId, _existingAIResourceGroupName)
}

module appInsights 'br/public:avm/res/insights/component:0.6.0' = if (_deployAppInsights) {
  name: 'deployAppInsights'
  params: {
    name: empty(appInsightsDefinition.name!)
      ? '${const.abbrs.managementGovernance.applicationInsights}${resourceToken}'
      : appInsightsDefinition.name!
    location: location
    workspaceResourceId: empty(resourceIds.logAnalyticsWorkspaceResourceId)
      ? logAnalytics.outputs.resourceId
      : resourceIds.logAnalyticsWorkspaceResourceId
    applicationType: appInsightsDefinition.applicationType ?? 'web'
    kind: appInsightsDefinition.kind ?? 'web'
    disableIpMasking: appInsightsDefinition.disableIpMasking! ?? false
    tags: union(tags, appInsightsDefinition.tags! ?? {})
  }
}

// ─────────────────────────────────────────────────────────────────────-
// 3.7 Container Apps Environment (reuse or create)
// ─────────────────────────────────────────────────────────────────────-
var _envIdSegments = empty(resourceIds.containerEnvResourceId) ? [''] : split(resourceIds.containerEnvResourceId, '/')
var _existingEnvSubscriptionId = length(_envIdSegments) >= 3 ? _envIdSegments[2] : ''
var _existingEnvResourceGroup = length(_envIdSegments) >= 5 ? _envIdSegments[4] : ''
var _existingEnvName = length(_envIdSegments) >= 1 ? last(_envIdSegments) : ''

resource existingContainerEnv 'Microsoft.App/managedEnvironments@2025-02-02-preview' existing = if (!empty(resourceIds.containerEnvResourceId)) {
  name: _existingEnvName
  scope: resourceGroup(_existingEnvSubscriptionId, _existingEnvResourceGroup)
}

var _subnetIDCappEnvSubnet = empty(resourceIds.virtualNetworkResourceId)
  ? virtualNetwork.outputs.subnetResourceIds[indexOf(
      virtualNetwork.outputs.subnetNames,
      containerAppEnvDefinition.subnetName!
    )]
  : '${existingVNet.id}/subnets/${containerAppEnvDefinition.subnetName!}'

module containerEnv 'br/public:avm/res/app/managed-environment:0.11.2' = if (empty(resourceIds.containerEnvResourceId)) {
  name: 'deployContainerEnv'
  params: {
    name: empty(containerAppEnvDefinition.name!)
      ? '${const.abbrs.containers.containerAppsEnvironment}${resourceToken}'
      : containerAppEnvDefinition.name!
    location: location
    tags: union(tags, containerAppEnvDefinition.tags! ?? {})

    appInsightsConnectionString: empty(resourceIds.appInsightsResourceId)
      ? appInsights.outputs.connectionString
      : existingAppInsights.properties.ConnectionString

    zoneRedundant: containerAppEnvDefinition.zoneRedundancyEnabled
    workloadProfiles: containerAppEnvDefinition.workloadProfiles

    managedIdentities: {
      systemAssigned: empty(containerAppEnvDefinition.userAssignedManagedIdentityIds)
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

// ─────────────────────────────────────────────────────────────────────-
// 3.8 Core App Services — GenAI app scope (reuse or create)
// ─────────────────────────────────────────────────────────────────────-
// -------- ACR
var _acrIdSegments = empty(resourceIds.containerRegistryResourceId)
  ? ['']
  : split(resourceIds.containerRegistryResourceId, '/')
var _existingAcrSub = length(_acrIdSegments) >= 3 ? _acrIdSegments[2] : ''
var _existingAcrRg = length(_acrIdSegments) >= 5 ? _acrIdSegments[4] : ''
var _existingAcrName = length(_acrIdSegments) >= 1 ? last(_acrIdSegments) : ''

resource existingAcr 'Microsoft.ContainerRegistry/registries@2025-05-01-preview' existing = if (!empty(resourceIds.containerRegistryResourceId)) {
  name: _existingAcrName
  scope: resourceGroup(_existingAcrSub, _existingAcrRg)
}

var _acrEffectiveSku = !empty(containerRegistryDefinition.sku) ? containerRegistryDefinition.sku : 'Premium'
var _acrNameEffective = !empty(containerRegistryDefinition.name)
  ? containerRegistryDefinition.name
  : '${const.abbrs.containers.containerRegistry}${resourceToken}'

module registry 'br/public:avm/res/container-registry/registry:0.9.1' = if (_deployAcr) {
  name: 'registryDeployment'
  params: {
    name: _acrNameEffective!
    acrSku: _acrEffectiveSku
    location: location
    publicNetworkAccess: 'Disabled'
    managedIdentities: { systemAssigned: true }
    tags: union(tags, containerRegistryDefinition.tags! ?? {})
  }
}

// -------- Cosmos DB (GenAI)
var _cosmosIdSegments = empty(resourceIds.dbAccountResourceId) ? [''] : split(resourceIds.dbAccountResourceId, '/')
var _existingCosmosSub = length(_cosmosIdSegments) >= 3 ? _cosmosIdSegments[2] : ''
var _existingCosmosRg = length(_cosmosIdSegments) >= 5 ? _cosmosIdSegments[4] : ''
var _existingCosmosName = length(_cosmosIdSegments) >= 1 ? last(_cosmosIdSegments) : ''

resource existingCosmos 'Microsoft.DocumentDB/databaseAccounts@2023-03-15' existing = if (!empty(resourceIds.dbAccountResourceId)) {
  name: _existingCosmosName
  scope: resourceGroup(_existingCosmosSub, _existingCosmosRg)
}

var _cosmosDef = cosmosDbDefinition ?? {
  name: ''
}
module databaseAccount 'br/public:avm/res/document-db/database-account:0.15.0' = if (_deployCosmos) {
  name: 'databaseAccountDeployment'
  params: {
    name: empty(_cosmosDef.name!) ? '${const.abbrs.databases.cosmosDBDatabase}${resourceToken}' : _cosmosDef.name!
    zoneRedundant: false
  }
}

// -------- Key Vault (GenAI)
var _kvIdSegments = empty(resourceIds.keyVaultResourceId) ? [''] : split(resourceIds.keyVaultResourceId, '/')
var _existingKvSub = length(_kvIdSegments) >= 3 ? _kvIdSegments[2] : ''
var _existingKvRg = length(_kvIdSegments) >= 5 ? _kvIdSegments[4] : ''
var _existingKvName = length(_kvIdSegments) >= 1 ? last(_kvIdSegments) : ''

resource existingVault 'Microsoft.KeyVault/vaults@2024-12-01-preview' existing = if (!empty(resourceIds.keyVaultResourceId)) {
  name: _existingKvName
  scope: resourceGroup(_existingKvSub, _existingKvRg)
}

module vault 'br/public:avm/res/key-vault/vault:0.13.0' = if (_deployKv) {
  name: 'vaultDeployment'
  params: {
    name: empty(keyVaultDefinition.name!)
      ? '${const.abbrs.security.keyVault}${resourceToken}'
      : keyVaultDefinition.name!
    enablePurgeProtection: true
    tags: union(tags, keyVaultDefinition.tags! ?? {})
  }
}

// -------- Key Vault (AI Foundry)
var _kvAifIdSegments = empty(aiFoundryDefinition.aiFoundryResources.keyVault.existingResourceId)
  ? ['']
  : split(aiFoundryDefinition.aiFoundryResources.keyVault.existingResourceId, '/')
var _existingKvAifSub = length(_kvAifIdSegments) >= 3 ? _kvAifIdSegments[2] : ''
var _existingKvAifRg = length(_kvAifIdSegments) >= 5 ? _kvAifIdSegments[4] : ''
var _existingKvAifName = length(_kvAifIdSegments) >= 1 ? last(_kvAifIdSegments) : ''

resource existingVaultAiFoundry 'Microsoft.KeyVault/vaults@2024-12-01-preview' existing = if (!empty(aiFoundryDefinition.aiFoundryResources.keyVault.existingResourceId)) {
  name: _existingKvAifName
  scope: resourceGroup(_existingKvAifSub, _existingKvAifRg)
}

// Add near other deploy/has flags
var _deployKvAiFoundry = empty(aiFoundryDefinition.aiFoundryResources.keyVault.existingResourceId)
var _hasKvAiFoundry = _deployKvAiFoundry || !empty(aiFoundryDefinition.aiFoundryResources.keyVault.existingResourceId)

// Use for module creation
module vaultAiFoundry 'br/public:avm/res/key-vault/vault:0.13.0' = if (_deployKvAiFoundry) {
  name: 'vaultDeployment-aiFoundry'
  params: {
    name: empty(keyVaultAiFoundryDefinition.name!)
      ? '${const.abbrs.security.keyVault}aif-${resourceToken}'
      : keyVaultAiFoundryDefinition.name!
    enablePurgeProtection: true
    tags: union(tags, keyVaultAiFoundryDefinition.tags! ?? {})
  }
}

// -------- Storage Account (GenAI)
var _saIdSegments = empty(resourceIds.storageAccountResourceId)
  ? ['']
  : split(resourceIds.storageAccountResourceId, '/')
var _existingSaSub = length(_saIdSegments) >= 3 ? _saIdSegments[2] : ''
var _existingSaRg = length(_saIdSegments) >= 5 ? _saIdSegments[4] : ''
var _existingSaName = length(_saIdSegments) >= 1 ? last(_saIdSegments) : ''

resource existingStorage 'Microsoft.Storage/storageAccounts@2022-09-01' existing = if (!empty(resourceIds.storageAccountResourceId)) {
  name: _existingSaName
  scope: resourceGroup(_existingSaSub, _existingSaRg)
}

var _storageAccountDef = storageAccountDefinition ?? {
  name: ''
  publicNetworkAccessEnabled: false
  tags: {}
}
module storageAccount 'br/public:avm/res/storage/storage-account:0.25.1' = if (_deploySa) {
  name: 'storageAccountDeployment'
  params: {
    name: empty(_storageAccountDef.name!)
      ? '${const.abbrs.storage.storageAccount}${resourceToken}'
      : _storageAccountDef.name!
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    tags: union(tags, _storageAccountDef.tags! ?? {})
  }
}

// -------- AI Search (GenAI)
var _searchIdSegments = empty(resourceIds.searchServiceResourceId)
  ? ['']
  : split(resourceIds.searchServiceResourceId, '/')
var _existingSearchSub = length(_searchIdSegments) >= 3 ? _searchIdSegments[2] : ''
var _existingSearchRg = length(_searchIdSegments) >= 5 ? _searchIdSegments[4] : ''
var _existingSearchName = length(_searchIdSegments) >= 1 ? last(_searchIdSegments) : ''

resource existingSearch 'Microsoft.Search/searchServices@2021-04-01' existing = if (!empty(resourceIds.searchServiceResourceId)) {
  name: _existingSearchName
  scope: resourceGroup(_existingSearchSub, _existingSearchRg)
}

var _searchDef = searchDefinition ?? {
  name: ''
  tags: {}
}
module searchService 'br/public:avm/res/search/search-service:0.11.0' = if (_deploySearch) {
  name: 'searchServiceDeployment'
  params: {
    name: empty(_searchDef.name!) ? '${const.abbrs.ai.aiSearch}${resourceToken}' : _searchDef.name!
    tags: union(tags, _searchDef.tags! ?? {})
  }
}

// -------- App Configuration
var _appcsIdSegments = empty(resourceIds.appConfigResourceId) ? [''] : split(resourceIds.appConfigResourceId, '/')
var _existingAppcsSub = length(_appcsIdSegments) >= 3 ? _appcsIdSegments[2] : ''
var _existingAppcsRg = length(_appcsIdSegments) >= 5 ? _appcsIdSegments[4] : ''
var _existingAppcsName = length(_appcsIdSegments) >= 1 ? last(_appcsIdSegments) : ''

resource existingAppConfig 'Microsoft.AppConfiguration/configurationStores@2022-05-01' existing = if (!empty(resourceIds.appConfigResourceId)) {
  name: _existingAppcsName
  scope: resourceGroup(_existingAppcsSub, _existingAppcsRg)
}

var _appConfigDef = appConfigurationDefinition ?? {
  name: ''
}
module configurationStore 'br/public:avm/res/app-configuration/configuration-store:0.7.0' = if (_deployAppConfig) {
  name: 'configurationStoreDeployment'
  params: {
    name: empty(_appConfigDef.name!)
      ? '${const.abbrs.configuration.appConfiguration}${resourceToken}'
      : _appConfigDef.name!
    enablePurgeProtection: true
  }
}

// ─────────────────────────────────────────────────────────────────────-
// 3.9 AI Foundry (AVM Pattern Module)
// ─────────────────────────────────────────────────────────────────────-
@description('The name of the project capability host to be used for the AI Foundry project.')
param projectCapHost string = 'caphostproj'

@description('Use user-assigned identities for AI Foundry dependent resources (Search/Cosmos).')
param useUAI bool = false

@description('Create a Bing Grounding connection for the AI Foundry project.')
param deployBingGrounding bool = false

@description('Bing Grounding resource name if deployBingGrounding = true.')
param bingSearchName string = '${const.abbrs.ai.bing}${resourceToken}'

// Effective names/IDs for the AF account & project
var _afAccountName = '${const.abbrs.ai.aiFoundry}${resourceToken}'
var _afProjectName = '${const.abbrs.ai.aiFoundryProject}${resourceToken}'
var _afProjectDisplayName = _afProjectName

// Description
var _afProjectDescription = aiFoundryDefinition == null
  ? 'AI Foundry project'
  : (contains(aiFoundryDefinition, 'aiFoundryProjectDescription') && !empty(string(aiFoundryDefinition.aiFoundryProjectDescription)))
      ? string(aiFoundryDefinition.aiFoundryProjectDescription)
      : 'AI Foundry project'

// ------- Search
var _afSearchExistingId = !empty(aiFoundryDefinition.aiFoundryResources.aiSearch.existingResourceId)
  ? string(aiFoundryDefinition.aiFoundryResources.aiSearch.existingResourceId)
  : ''
var _afSearchName = !empty(aiFoundryDefinition.aiFoundryResources.aiSearch.name)
  ? string(aiFoundryDefinition.aiFoundryResources.aiSearch.name)
  : '${const.abbrs.ai.aiSearch}aif-${resourceToken}'

// ------- Cosmos
var _afCosmosExistingId = !empty(aiFoundryDefinition.aiFoundryResources.cosmosDb.existingResourceId)
  ? string(aiFoundryDefinition.aiFoundryResources.cosmosDb.existingResourceId)
  : ''
var _afCosmosName = !empty(aiFoundryDefinition.aiFoundryResources.cosmosDb.name)
  ? string(aiFoundryDefinition.aiFoundryResources.cosmosDb.name)
  : '${const.abbrs.databases.cosmosDBDatabase}aif-${resourceToken}'

// ------- Storage
var _afStorageExistingId = !empty(aiFoundryDefinition.aiFoundryResources.storageAccount.existingResourceId)
  ? string(aiFoundryDefinition.aiFoundryResources.storageAccount.existingResourceId)
  : ''
var _afStorageName = !empty(aiFoundryDefinition.aiFoundryResources.storageAccount.name)
  ? string(aiFoundryDefinition.aiFoundryResources.storageAccount.name)
  : '${const.abbrs.storage.storageAccount}aif${resourceToken}'

var _afCreateConnections = aiFoundryDefinition.createProjectConnections

// Agent subnet (used by networkInjections) — looks for 'agent-subnet' from your vnetDefinition
var _agentSubnetName = 'agent-subnet'
var _agentSubnetIdx = empty(resourceIds.virtualNetworkResourceId)
  ? indexOf(virtualNetwork.outputs.subnetNames, _agentSubnetName)
  : -1
var _agentSubnetId = empty(resourceIds.virtualNetworkResourceId)
  ? (_agentSubnetIdx >= 0 ? virtualNetwork.outputs.subnetResourceIds[_agentSubnetIdx] : '')
  : '${existingVNet.id}/subnets/${_agentSubnetName}'

// 1) Get entries (or [] if missing/empty)
var _afModelEntries = (contains(aiFoundryDefinition, 'aiModelDeployments') && !empty(aiFoundryDefinition.aiModelDeployments))
  ? items(aiFoundryDefinition.aiModelDeployments)
  : []

// 2) Build the array AVM expects
var _afModelDeployments = [
  for md in _afModelEntries: {
    name: string(md.value.name ?? md.key)
    raiPolicyName: md.value.raiPolicyName
    versionUpgradeOption: md.value.versionUpgradeOption
    model: {
      format: md.value.model.format
      name: md.value.model.name
      version: md.value.model.version
    }
    scale: {
      type: md.value.scale.type
      capacity: md.value.scale.capacity
      family: md.value.scale.family
      size: md.value.scale.size
      tier: md.value.scale.tier
    }
  }
]

// Effective App Insights name (for optional connection)
var _appInsightsNameEffective = empty(appInsightsDefinition.name!)
  ? '${const.abbrs.managementGovernance.applicationInsights}${resourceToken}'
  : appInsightsDefinition.name!

// ─────────────────────────────────────────────────────────────────────
// AI Foundry Standard Setup
// ─────────────────────────────────────────────────────────────────────

// Validate existing AF-dependent resources (IDs may be empty)
module aiFoundryValidateExistingResources 'standard-setup/validate-existing-resources.bicep' = {
  name: 'validate-existing-resources-${resourceToken}-deployment'
  params: {
    aiSearchResourceId: _afSearchExistingId
    azureStorageAccountResourceId: _afStorageExistingId
    azureCosmosDBAccountResourceId: _afCosmosExistingId
    existingDnsZones: {}
    dnsZoneNames: []
  }
}

// Create or reuse AF-dependent resources (Search, Storage, Cosmos)
module aiFoundryDependencies 'standard-setup/standard-dependent-resources.bicep' = {
  name: 'dependencies-${_afAccountName}-${resourceToken}-deployment'
  params: {
    location: location

    aiSearchName: _afSearchName
    aiSearchResourceId: _afSearchExistingId
    aiSearchExists: aiFoundryValidateExistingResources.outputs.aiSearchExists

    azureStorageName: _afStorageName
    azureStorageAccountResourceId: _afStorageExistingId
    azureStorageExists: aiFoundryValidateExistingResources.outputs.azureStorageExists

    cosmosDBName: _afCosmosName
    cosmosDBResourceId: _afCosmosExistingId
    cosmosDBExists: aiFoundryValidateExistingResources.outputs.cosmosDBExists

    networkIsolation: _networkIsolation

    // identity knobs (optional)
    useUAI: useUAI
    searchIdentityId: ''
    cosmosIdentityId: ''
  }
}

// Create the AI Services account & model deployments
module aiFoundryAccount 'standard-setup/ai-account-identity.bicep' = {
  name: 'ai-${_afAccountName}-${resourceToken}-deployment'
  params: {
    accountName: _afAccountName
    location: location
    modelDeployments: _afModelDeployments
    networkIsolation: _networkIsolation
    agentSubnetId: _agentSubnetId
  }
  dependsOn: [aiFoundryDependencies]
}

// Create AF project bound to the deps above
module aiFoundryProject 'standard-setup/ai-project-identity.bicep' = {
  name: 'ai-${_afProjectName}-${resourceToken}-deployment'
  params: {
    projectName: _afProjectName
    projectDescription: _afProjectDescription
    displayName: _afProjectDisplayName
    location: location

    aiSearchName: aiFoundryDependencies.outputs.aiSearchName
    aiSearchServiceResourceGroupName: aiFoundryDependencies.outputs.aiSearchServiceResourceGroupName
    aiSearchServiceSubscriptionId: aiFoundryDependencies.outputs.aiSearchServiceSubscriptionId

    cosmosDBName: aiFoundryDependencies.outputs.cosmosDBName
    cosmosDBSubscriptionId: aiFoundryDependencies.outputs.cosmosDBSubscriptionId
    cosmosDBResourceGroupName: aiFoundryDependencies.outputs.cosmosDBResourceGroupName

    azureStorageName: aiFoundryDependencies.outputs.azureStorageName
    azureStorageSubscriptionId: aiFoundryDependencies.outputs.azureStorageSubscriptionId
    azureStorageResourceGroupName: aiFoundryDependencies.outputs.azureStorageResourceGroupName

    accountName: aiFoundryAccount.outputs.accountName
  }
  dependsOn: [aiFoundryAccount]
}

// WorkspaceId -> GUID format (used by container-scoped RBAC)
module aiFoundryFormatProjectWorkspaceId 'standard-setup/format-project-workspace-id.bicep' = {
  name: 'format-project-workspace-id-${resourceToken}-deployment'
  params: {
    projectWorkspaceId: aiFoundryProject.outputs.projectWorkspaceId
  }
}

// RBAC — Search
module assignSearchAiFoundryProject 'standard-setup/ai-search-role-assignments.bicep' = {
  name: 'assign-search-rbac-${resourceToken}'
  params: {
    aiSearchName: aiFoundryDependencies.outputs.aiSearchName
    projectPrincipalId: aiFoundryProject.outputs.projectPrincipalId
  }
}

// RBAC — Cosmos (account level)
module assignCosmosDBAiFoundryProject 'standard-setup/cosmosdb-account-role-assignment.bicep' = {
  name: 'assign-cosmos-account-rbac-${resourceToken}'
  params: {
    cosmosDBName: aiFoundryDependencies.outputs.cosmosDBName
    projectPrincipalId: aiFoundryProject.outputs.projectPrincipalId
  }
}

// RBAC — Storage (account + scoped)
module assignStorageAccountAiFoundryProject 'standard-setup/azure-storage-account-role-assignment.bicep' = {
  name: 'assign-storage-account-rbac-${resourceToken}'
  params: {
    azureStorageName: aiFoundryDependencies.outputs.azureStorageName
    projectPrincipalId: aiFoundryProject.outputs.projectPrincipalId
  }
}

// Capability Host (Agents) — after RBAC/Deps
module aiFoundryAddProjectCapabilityHost 'standard-setup/add-project-capability-host.bicep' = {
  name: 'capabilityHost-configuration-${resourceToken}-deployment'
  params: {
    accountName: aiFoundryAccount.outputs.accountName
    projectName: aiFoundryProject.outputs.projectName
    cosmosDBConnection: aiFoundryProject.outputs.cosmosDBConnection
    azureStorageConnection: aiFoundryProject.outputs.azureStorageConnection
    aiSearchConnection: aiFoundryProject.outputs.aiSearchConnection
    projectCapHost: projectCapHost
  }
  dependsOn: [
    assignSearchAiFoundryProject
    assignCosmosDBAiFoundryProject
    assignStorageAccountAiFoundryProject
    // assignCosmosContainerRoles
    // assignBlobContainerRoles
  ]
}

// RBAC — Cosmos (containers in enterprise_memory DB) AFTER capability host
module assignCosmosContainerRoles 'standard-setup/cosmos-container-role-assignments.bicep' = {
  name: 'assign-cosmos-container-rbac-${resourceToken}'
  params: {
    cosmosAccountName: aiFoundryDependencies.outputs.cosmosDBName
    projectPrincipalId: aiFoundryProject.outputs.projectPrincipalId
    projectWorkspaceId: aiFoundryFormatProjectWorkspaceId.outputs.projectWorkspaceIdGuid
  }
  dependsOn: [
    aiFoundryAddProjectCapabilityHost
  ]
}

// RBAC — Storage (scoped to blob containers) AFTER capability host
module assignBlobContainerRoles 'standard-setup/blob-storage-container-role-assignments.bicep' = {
  name: 'assign-blob-container-rbac-${resourceToken}'
  params: {
    storageName: aiFoundryDependencies.outputs.azureStorageName
    aiProjectPrincipalId: aiFoundryProject.outputs.projectPrincipalId
    workspaceId: aiFoundryFormatProjectWorkspaceId.outputs.projectWorkspaceIdGuid
  }
  dependsOn: [
    aiFoundryAddProjectCapabilityHost
  ]
}

// Optional: Bing Grounding tool connection (at Account scope)
module aiFoundryBingConnection 'standard-setup/ai-foundry-bing-search-tool.bicep' = if (deployBingGrounding) {
  name: '${bingSearchName}-connection'
  params: {
    account_name: aiFoundryAccount.outputs.accountName
    project_name: aiFoundryProject.outputs.projectName
    bingSearchName: bingSearchName
  }
}

// Optional: Connect AF Account to Search/AppInsights/Storage (using effective names)
module aiFoundryConnectionSearch 'standard-setup/connection-ai-search.bicep' = if (_afCreateConnections) {
  name: 'connection-ai-search-${resourceToken}'
  params: {
    aiFoundryName: aiFoundryAccount.outputs.accountName
    aiProjectName: aiFoundryProject.outputs.projectName
    connectedResourceName: aiFoundryDependencies.outputs.aiSearchName
  }
}

module aiFoundryConnectionInsights 'standard-setup/connection-application-insights.bicep' = if (_afCreateConnections && _hasAppInsights) {
  name: 'connection-appinsights-${resourceToken}'
  params: {
    aiFoundryName: aiFoundryAccount.outputs.accountName
    connectedResourceName: empty(resourceIds.appInsightsResourceId) ? _appInsightsNameEffective : _existingAIName
  }
}

module aiFoundryConnectionStorage 'standard-setup/connection-storage-account.bicep' = if (_afCreateConnections) {
  name: 'connection-storage-account-${resourceToken}'
  params: {
    aiFoundryName: aiFoundryAccount.outputs.accountName
    connectedResourceName: aiFoundryDependencies.outputs.azureStorageName
  }
}

// var _afDepsAllExisting = !empty(aiFoundryDefinition.aiFoundryResources.aiSearch.existingResourceId) && !empty(aiFoundryDefinition.aiFoundryResources.cosmosDb.existingResourceId) && !empty(aiFoundryDefinition.aiFoundryResources.storageAccount.existingResourceId) && !empty(aiFoundryDefinition.aiFoundryResources.keyVault.existingResourceId)
// var _afWantsDeps = !_afDepsAllExisting
// AI Foundry (AVM Pattern Module)
// var _afBaseName = substring(resourceToken, 0, 12)
// module aiFoundry 'br/public:avm/ptn/ai-ml/ai-foundry:0.2.0' = {
//   name: 'aiFoundryDeployment'
//   params: {
//     // Keep names deterministic with your token
//     baseName: _afBaseName
//     // Networking (use your PDNS zones that you already create/reuse above)
//     aiFoundryConfiguration: {
//       networking: {
//         aiServicesPrivateDnsZoneId: !_useExistingPdz.aiServices
//           ? privateDnsZoneAiService.outputs.resourceId
//           : privateDnsZoneIds.aiServices
//         cognitiveServicesPrivateDnsZoneId: !_useExistingPdz.cognitiveservices
//           ? privateDnsZoneCogSvcs.outputs.resourceId
//           : privateDnsZoneIds.cognitiveservices
//         openAiPrivateDnsZoneId: !_useExistingPdz.openai
//           ? privateDnsZoneOpenAi.outputs.resourceId
//           : privateDnsZoneIds.openai
//       }
//     }

//     // Let the module create Search/Cosmos/Storage/KV when needed
//     includeAssociatedResources: _afWantsDeps

//     // Bind AF-associated resources to your zones explicitly
//     aiSearchConfiguration: {
//       privateDnsZoneId: !_useExistingPdz.search ? privateDnsZoneSearch.outputs.resourceId : privateDnsZoneIds.search
//     }
//     cosmosDbConfiguration: {
//       privateDnsZoneId: !_useExistingPdz.cosmosSql
//         ? privateDnsZoneCosmos.outputs.resourceId
//         : privateDnsZoneIds.cosmosSql
//     }
//     keyVaultConfiguration: {
//       privateDnsZoneId: !_useExistingPdz.keyVault
//         ? privateDnsZoneKeyVault.outputs.resourceId
//         : privateDnsZoneIds.keyVault
//     }
//     storageAccountConfiguration: {
//       blobPrivateDnsZoneId: !_useExistingPdz.blob ? privateDnsZoneBlob.outputs.resourceId : privateDnsZoneIds.blob
//     }

//     // AVM module will create private endpoints for AF into this subnet
//     privateEndpointSubnetId: _peSubnetId

//     // Optional: pass model deployments (keeping empty by default is safest)
//     aiModelDeployments: _afModelDeployments
//   }
// }

// ─────────────────────────────────────────────────────────────────────-
// 3.10 Gateways (WAF policy, App Gateway, Azure Firewall, APIM)
// ─────────────────────────────────────────────────────────────────────-
var _wafName = empty(wafPolicyDefinition.name!) ? 'waf-${resourceToken}' : wafPolicyDefinition.name!

module wafPolicy 'br/public:avm/res/network/application-gateway-web-application-firewall-policy:0.2.0' = {
  name: 'wafPolicyDeployment'
  params: {
    name: _wafName
    location: location
    tags: union(tags, wafPolicyDefinition.tags! ?? {})
    policySettings: wafPolicyDefinition.policySettings
    managedRules: {
      managedRuleSets: [
        // keep it simple; you can extend with overrides/exclusions from your param if needed
        { ruleSetType: 'OWASP', ruleSetVersion: '3.2' }
      ]
      exclusions: []
    }
    customRules: []
  }
}

var _wafPolicyResourceId = resourceId('Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies', _wafName)

var _agwName = empty(appGatewayDefinition.name!) ? 'agw-${resourceToken}' : appGatewayDefinition.name!

var agwName = _agwName
var agwId = resourceId('Microsoft.Network/applicationGateways', agwName)
var agwSubnet = _agwSubnetId

module applicationGateway 'br/public:avm/res/network/application-gateway:0.7.0' = if (_deployAppGateway) {
  name: 'applicationGatewayDeployment'
  params: {
    name: agwName
    location: location
    sku: 'WAF_v2'
    firewallPolicyResourceId: _wafPolicyResourceId

    gatewayIPConfigurations: [
      { name: 'appGatewayIpConfig', properties: { subnet: { id: agwSubnet } } }
    ]

    frontendIPConfigurations: [
      {
        name: 'publicFrontend'
        properties: {
          publicIPAddress: { id: appGatewayPip.outputs.resourceId }
        }
      }
      {
        name: 'privateFrontend'
        properties: {
          privateIPAllocationMethod: 'Static' // or 'Dynamic'
          privateIPAddress: '192.168.3.10'
          subnet: { id: agwSubnet }
        }
      }
    ]

    frontendPorts: [
      { name: 'port80', properties: { port: 80 } }
    ]

    backendAddressPools: [
      { name: 'defaultPool' }
    ]

    backendHttpSettingsCollection: [
      {
        name: 'defaultSetting'
        properties: {
          cookieBasedAffinity: 'Disabled'
          port: 80
          protocol: 'Http'
        }
      }
    ]

    // keep listener on the private frontend
    httpListeners: [
      {
        name: 'defaultListener'
        properties: {
          frontendIPConfiguration: { id: '${agwId}/frontendIPConfigurations/privateFrontend' }
          frontendPort: { id: '${agwId}/frontendPorts/port80' }
          protocol: 'Http'
        }
      }
    ]

    requestRoutingRules: [
      {
        name: 'defaultRule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: { id: '${agwId}/httpListeners/defaultListener' }
          backendAddressPool: { id: '${agwId}/backendAddressPools/defaultPool' }
          backendHttpSettings: { id: '${agwId}/backendHttpSettingsCollection/defaultSetting' }
        }
      }
    ]
  }
}

module appGatewayPip 'br/public:avm/res/network/public-ip-address:0.9.0' = {
  name: 'appGatewayPipDeployment'
  params: {
    name: '${const.abbrs.networking.publicIPAddress}${resourceToken}-agw'
    location: location
    skuName: 'Standard' // required by v2
    publicIPAllocationMethod: 'Static'
    tags: tags
  }
}

var _afwName = empty(firewallDefinition.name!) ? 'afw-${resourceToken}' : firewallDefinition.name!

module firewallPip 'br/public:avm/res/network/public-ip-address:0.9.0' = if (_deployFirewall) {
  name: 'firewallPipDeployment'
  params: {
    name: '${const.abbrs.networking.publicIPAddress}${resourceToken}-afw'
    location: location
    skuName: 'Standard'
    publicIPAllocationMethod: 'Static'
    tags: tags
  }
}

module azureFirewall 'br/public:avm/res/network/azure-firewall:0.8.0' = if (_deployFirewall) {
  name: 'azureFirewallDeployment'
  params: {
    name: _afwName
    location: location
    tags: union(tags, firewallDefinition.tags! ?? {})
    azureSkuTier: firewallDefinition.tier
    availabilityZones: firewallDefinition.zones

    // This is enough for the module to attach to the AzureFirewallSubnet in your VNet
    virtualNetworkResourceId: _vnetResourceId

    // OPTIONAL: only for EXTRA public IPs
    // additionalPublicIpConfigurations: [
    //   { name: 'pip-extra-1', publicIpAddressResourceId: firewallPip.outputs.resourceId }
    // ]
  }
}

var _apimName = empty(apimDefinition.name!) ? 'apim-${resourceToken}' : apimDefinition.name!

module apim 'br/public:avm/res/api-management/service:0.9.1' = if (_deployApim) {
  name: 'apimDeployment'
  params: {
    name: _apimName
    location: location
    tags: union(tags, apimDefinition.tags! ?? {})

    // AVM expects these:
    sku: apimDefinition.skuRoot // Developer | Basic | Standard | Premium | Consumption
    skuCapacity: apimDefinition.skuCapacity

    publisherEmail: apimDefinition.publisherEmail
    publisherName: apimDefinition.publisherName

    // Non-VNet posture by omission (don't pass subnetResourceId)
    // virtualNetworkType param isn't exposed by AVM; default is None when no subnet is supplied.

    // Enable HTTP/2 via customProperties (string "true"/"false")
    customProperties: apimDefinition.protocols != null && apimDefinition.protocols.enableHttp2
      ? { 'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'true' }
      : {}

    // Optional (only if you want them):
    // minApiVersion: apimDefinition.minApiVersion
    // notificationSenderEmail: apimDefinition.notificationSenderEmail
    // hostnameConfigurations: apimDefinition.hostnameConfiguration  // <- make sure this is PLURAL in your object
    // additionalLocations: apimDefinition.additionalLocations
  }
}

// ─────────────────────────────────────────────────────────────────────-
// 3.11 Hub/Spoke Peering
// ─────────────────────────────────────────────────────────────────────-
// Hub -> Spoke
// Parse peer VNet ID
var _peerVnetId = hubVnetPeeringDefinition.peerVnetResourceId
var _peerParts = split(_peerVnetId, '/')
var _peerSub = length(_peerParts) >= 3 ? _peerParts[2] : ''
var _peerRg = length(_peerParts) >= 5 ? _peerParts[4] : ''
var _peerVnetName = length(_peerParts) >= 9 ? _peerParts[8] : ''

resource peerVnet 'Microsoft.Network/virtualNetworks@2024-07-01' existing = if (!empty(_peerVnetId)) {
  name: _peerVnetName
  scope: resourceGroup(_peerSub, _peerRg)
}

// Spoke -> Hub
resource vnetPeeringToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-07-01' = if (!empty(_peerVnetId)) {
  name: '${_vnetName}/${empty(hubVnetPeeringDefinition.name!) ? 'to-hub' : hubVnetPeeringDefinition.name!}'
  properties: {
    allowForwardedTraffic: hubVnetPeeringDefinition.allowForwardedTraffic
    allowGatewayTransit: hubVnetPeeringDefinition.allowGatewayTransit
    allowVirtualNetworkAccess: hubVnetPeeringDefinition.allowVirtualNetworkAccess
    remoteVirtualNetwork: { id: _peerVnetId }
    useRemoteGateways: hubVnetPeeringDefinition.useRemoteGateways
  }
}

// Hub -> Spoke (reverse)
// resource vnetPeeringFromHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-07-01' = if (!empty(_peerVnetId) && hubVnetPeeringDefinition.createReversePeering) {
//   name: '${_peerVnetName}/${empty(hubVnetPeeringDefinition.reverseName) ? 'to-spoke' : hubVnetPeeringDefinition.reverseName}'
//   parent: peerVnet
//   properties: {
//     allowForwardedTraffic: hubVnetPeeringDefinition.reverseAllowForwardedTraffic
//     allowGatewayTransit: hubVnetPeeringDefinition.reverseAllowGatewayTransit
//     allowVirtualNetworkAccess: hubVnetPeeringDefinition.reverseAllowVirtualNetworkAccess
//     remoteVirtualNetwork: { id: _vnetResourceId }
//     useRemoteGateways: hubVnetPeeringDefinition.reverseUseRemoteGateways
//   }
// }

//////////////////////////////////////////////////////////////////////////
// §4. OUTPUTS
//////////////////////////////////////////////////////////////////////////

// General
output tenantId string = tenant().tenantId
output subscriptionId string = subscription().subscriptionId
output resourceGroupName string = resourceGroup().name
output location string = location

// VNet
output virtualNetworkResourceId string = empty(resourceIds.virtualNetworkResourceId)
  ? virtualNetwork.outputs.resourceId
  : existingVNet.id

// Log Analytics
output logAnalyticsWorkspaceResourceId string = empty(resourceIds.logAnalyticsWorkspaceResourceId)
  ? logAnalytics.outputs.resourceId
  : existingLogAnalytics.id

// App Insights
output applicationInsightsResourceId string = _deployAppInsights
  ? appInsights.outputs.resourceId
  : existingAppInsights.id

// Container Apps Environment
output containerEnvResourceId string = empty(resourceIds.containerEnvResourceId)
  ? containerEnv.outputs.resourceId
  : existingContainerEnv.id

// ACR
output containerRegistryResourceId string = _deployAcr
  ? resourceId('Microsoft.ContainerRegistry/registries', _acrNameEffective!)
  : existingAcr.id

// Storage
output storageAccountResourceId string = _deploySa ? storageAccount.outputs.resourceId : existingStorage.id

// Key Vault
output keyVaultResourceId string = _deployKv ? vault.outputs.resourceId : existingVault.id

// Cosmos
output dbAccountResourceId string = _deployCosmos ? databaseAccount.outputs.resourceId : existingCosmos.id

// Search
output searchServiceResourceId string = _deploySearch ? searchService.outputs.resourceId : existingSearch.id

// App Configuration
output appConfigResourceId string = _deployAppConfig ? configurationStore.outputs.resourceId : existingAppConfig.id

// APIM
output apimServiceResourceId string = _deployApim
  ? resourceId('Microsoft.ApiManagement/service', _apimName)
  : existingApim.id

// Application Gateway
output applicationGatewayResourceId string = _deployAppGateway
  ? resourceId('Microsoft.Network/applicationGateways', _agwName)
  : existingAppGateway.id

// Azure Firewall
output firewallResourceId string = _deployFirewall
  ? resourceId('Microsoft.Network/azureFirewalls', _afwName)
  : existingFirewall.id

// WAF Policy
output wafPolicyResourceId string = _wafPolicyResourceId
