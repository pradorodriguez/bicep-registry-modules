@export()
@description('Optional existing resource IDs to reuse; leave empty to create new resources.')
type ResourceIdsType = {
  // Networking
  virtualNetworkResourceId: string

  // VM & Bastion
  bastionHostResourceId: string

  // Observability
  appInsightsResourceId: string
  logAnalyticsWorkspaceResourceId: string

  // Config & secrets
  appConfigResourceId: string
  keyVaultResourceId: string

  // Data & AI
  storageAccountResourceId: string
  dbAccountResourceId: string
  searchServiceResourceId: string
  groundingServiceResourceId: string // if you ever add a Bing grounding module
  aiFoundryAccountResourceId: string
  aiFoundrySearchServiceResourceId: string
  aiFoundryCosmosDbResourceId: string
  aiFoundryProjectResourceId: string

  // Containers
  containerEnvResourceId: string
  containerRegistryResourceId: string

  // Gateways
  apimServiceResourceId: string
  applicationGatewayResourceId: string
  firewallResourceId: string
}

@export()
@description('Configuration object for the Virtual Network to be deployed.')
type VNetDefinitionType = {
  name: string?
  addressSpace: string
  ddosProtectionPlanResourceId: string?
  dnsServers: string[]?
  subnets: {
    enabled: bool
    name: string
    addressPrefix: string
    delegation: string?
  }[]
  peerVnetResourceId: string
  tags: { *: string }
}

@export()
@description('Configuration object for the Log Analytics Workspace to be created for monitoring and logging.')
type LogAnalyticsWorkspaceDefinitionType = {
  name: string?
  retention: int // Data retention period in days
  sku: 'CapacityReservation' | 'Free' | 'LACluster' | 'PerGB2018' | 'PerNode' | 'Premium' | 'Standalone' | 'Standard'
  tags: { *: string }?
}

@export()
@description('Configuration object for the Application Insights component to be created or reused.')
type AppInsightsDefinitionType = {
  name: string?
  applicationType: 'web' | 'other' // e.g. 'web'; optional, defaults to 'web' in module
  kind: 'web' | 'other' // e.g. 'web'; optional
  disableIpMasking: bool?
  tags: { *: string }?
}

@export()
@description('Configuration object for the Container App Environment to be created for GenAI services.')
type ContainerAppEnvDefinitionType = {
  name: string?
  tags: { *: string }?
  internalLoadBalancerEnabled: bool
  subnetName: string?
  zoneRedundancyEnabled: bool
  userAssignedManagedIdentityIds: string[]
  workloadProfiles: {
    name: string
    workloadProfileType: 'D4' | 'D8' | 'D16' | 'E4' | 'E8' | 'E16' | 'E32' | 'Consumption'
    minimumCount: int?
    maximumCount: int?
  }[]
  roleAssignments: {
    name: string?
    principalId: string
    roleDefinitionIdOrName: string
    principalType: 'Device' | 'ForeignGroup' | 'Group' | 'ServicePrincipal' | 'User'
    description: string?
    condition: string?
    conditionVersion: '2.0'?
    delegatedManagedIdentityResourceId: string?
  }[]
}

@export()
@description('Configuration object for the Azure Container Registry to be created for GenAI services.')
type ContainerRegistryDefinitionType = {
  dataPlaneProxy: {
    authenticationMode: string
    privateLinkDelegation: string
  }
  name: string?
  localAuthEnabled: bool
  purgeProtectionEnabled: bool
  sku: string
  softDeleteRetentionInDays: int
  tags: { *: string }
  roleAssignments: {
    name: string?
    principalId: string
    roleDefinitionIdOrName: string
    principalType: 'Device' | 'ForeignGroup' | 'Group' | 'ServicePrincipal' | 'User'
    description: string?
    condition: string?
    conditionVersion: '2.0'?
    delegatedManagedIdentityResourceId: string?
  }[]
}

@export()
@description('Definition of a single Container App to create.')
type ContainerAppDefinitionType = {
  name: string?
  service_name: string
  profile_name: string
  min_replicas: int
  max_replicas: int
}

@export()
@description('Configuration object for the Azure Cosmos DB account to be created for GenAI services.')
type GenAIAppCosmosDbDefinitionType = {
  name: string?
  secondaryRegions: { *: { location: string, zoneRedundant: bool, failoverPriority: int } }
  publicNetworkAccessEnabled: bool
  analyticalStorageEnabled: bool
  automaticFailoverEnabled: bool
  localAuthenticationDisabled: bool
  partitionMergeEnabled: bool
  multipleWriteLocationsEnabled: bool
  analyticalStorageConfig: { schemaType: string }
  consistencyPolicy: { maxIntervalInSeconds: int, maxStalenessPrefix: int, consistencyLevel: string }
  backup: { retentionInHours: int, intervalInMinutes: int, storageRedundancy: string, type: string, tier: string }
  capabilities: { *: { name: string } }
  capacity: { totalThroughputLimit: int }
  corsRule: {
    allowedHeaders: string[]
    allowedMethods: string[]
    allowedOrigins: string[]
    exposedHeaders: string[]
    maxAgeInSeconds: int
  }
}

@export()
@description('Configuration object for the Azure Key Vault to be created for GenAI services.')
type GenAIAppKeyVaultDefinitionType = {
  name: string?
  sku: string
  tenantId: string
  roleAssignments: {
    name: string?
    principalId: string
    roleDefinitionIdOrName: string
    principalType: 'Device' | 'ForeignGroup' | 'Group' | 'ServicePrincipal' | 'User'
    description: string?
    condition: string?
    conditionVersion: '2.0'?
    delegatedManagedIdentityResourceId: string?
  }[]
  tags: { *: string }
}

@export()
@description('Configuration object for the Azure Storage Account to be created for GenAI services.')
type GenAIAppStorageAccountDefinitionType = {
  name: string?
  accountKind: string
  accountTier: string
  accountReplicationType: string
  endpointTypes: string[]
  accessTier: string
  publicNetworkAccessEnabled: bool
  sharedAccessKeyEnabled: bool
  roleAssignments: {
    name: string?
    principalId: string
    roleDefinitionIdOrName: string
    principalType: 'Device' | 'ForeignGroup' | 'Group' | 'ServicePrincipal' | 'User'
    description: string?
    condition: string?
    conditionVersion: '2.0'?
    delegatedManagedIdentityResourceId: string?
  }[]
  tags: { *: string }
}

@export()
@description('Configuration object for the Azure AI Search service to be deployed.')
type KSAISearchDefinitionType = {
  name: string?
  sku: string
  localAuthenticationEnabled: bool
  partitionCount: int
  publicNetworkAccessEnabled: bool
  replicaCount: int
  semanticSearchSku: string
  tags: { *: string }
  roleAssignments: {
    name: string?
    principalId: string
    roleDefinitionIdOrName: string
    principalType: 'Device' | 'ForeignGroup' | 'Group' | 'ServicePrincipal' | 'User'
    description: string?
    condition: string?
    conditionVersion: '2.0'?
    delegatedManagedIdentityResourceId: string?
  }[]
  enableTelemetry: bool
}

@export()
@description('Configuration object for the Bing Grounding service to be deployed.')
type KSGroundingWithBingDefinitionType = {
  name: string?
  sku: string
  tags: { *: string }
}

@export()
@description('Configuration object for the Azure App Configuration store for GenAI app.')
type AppConfigurationDefinitionType = {
  dataPlaneProxy: { authenticationMode: string, privateLinkDelegation: string }
  name: string?
  localAuthEnabled: bool
  purgeProtectionEnabled: bool
  sku: string
  softDeleteRetentionInDays: int
  tags: { *: string }
  roleAssignments: {
    name: string?
    principalId: string
    roleDefinitionIdOrName: string
    principalType: 'Device' | 'ForeignGroup' | 'Group' | 'ServicePrincipal' | 'User'
    description: string?
    condition: string?
    conditionVersion: '2.0'?
    delegatedManagedIdentityResourceId: string?
  }[]
}

@export()
@description('Configuration object for the Azure AI Foundry project and related resources.')
type AiFoundryDefinitionType = {
  aiFoundryProjectDescription: string
  aiModelDeployments: {
    *: {
      name: string
      raiPolicyName: string
      versionUpgradeOption: string
      model: { format: string, name: string, version: string }
      scale: { capacity: int, family: string, size: string, tier: string, type: string }
    }
  }
  createAiAgentService: bool
  createProjectConnections: bool
  lock: { kind: string, name: string }
  aiFoundryResources: {
    createDependentResources: bool
    aiSearch: { existingResourceId: string, name: string }
    cosmosDb: { existingResourceId: string, name: string }
    storageAccount: { existingResourceId: string, name: string }
    keyVault: { existingResourceId: string, name: string }
  }
  roleAssignments: {
    name: string?
    principalId: string
    roleDefinitionIdOrName: string
    principalType: 'Device' | 'ForeignGroup' | 'Group' | 'ServicePrincipal' | 'User'
    description: string?
    condition: string?
    conditionVersion: '2.0'?
    delegatedManagedIdentityResourceId: string?
  }[]
  tags: { *: string }
}

@export()
@description('Configuration object for the Jump VM to be created for managing the implementation services.')
type JumpVmDefinitionType = {
  name: string?
  sku: string
  vmKeyVaultSecName: string
  tags: { *: string }
  enableTelemetry: bool
}

@export()
@description('Configuration object for the Azure Bastion service to be deployed.')
type BastionDefinitionType = {
  name: string?
  sku: string
  tags: { *: string }
  zones: string[]
}

@export()
@description('Configuration object for Network Security Groups (NSGs) to be deployed.')
type NSGDefinitionsType = {
  name: string?
  securityRules: {
    *: {
      access: string
      description: string
      destinationAddressPrefix: string
      destinationAddressPrefixes: string[]
      destinationApplicationSecurityGroupIds: string[]
      estinationPortRange: string
      destinationPortRanges: string[]
      direction: string
      name: string
      priority: int
      protocol: string
      sourceAddressPrefix: string
      sourceAddressPrefixes: string[]
      sourceApplicationSecurityGroupIds: string[]
      sourcePortRange: string
      sourcePortRanges: string[]
      timeouts: { create: string, delete: string, read: string, update: string }
    }
  }
}

@export()
@description('Configuration object for Private DNS Zones and their network links.')
type PrivateDNSZoneDefinitionsType = {
  existingZonesSubscriptionId: string
  existingZonesResourceGroupName: string
  networkLinks: { *: { vnetLinkName: string, vnetId: string, autoRegistration: bool } }
}

@export()
@description('Configuration object for the Web Application Firewall (WAF) Policy to be deployed.')
type WafPolicyDefinitionsType = {
  name: string?
  policySettings: {
    enabled: bool
    mode: string
    requestBodyCheck: bool
    maxRequestBodySizeKb: int
    fileUploadLimitMb: int
  }
  managedRules: {
    exclusion: {
      *: {
        matchVariable: string
        selector: string
        selectorMatchOperator: string
        excludedRuleSet: { type: string, version: string, ruleGroup: string[] }
      }
    }
    managedRuleSet: {
      *: {
        type: string
        version: string
        ruleGroupOverride: { *: { ruleGroupName: string, rule: { action: string, enabled: bool, id: string }[] } }
      }
    }
  }
  tags: { *: string }
}

@export()
@description('Configuration object for the Azure Application Gateway to be deployed.')
type AppGatewayDefinitionType = {
  name: string?
  http2Enable: bool
  authenticationCertificate: { *: { name: string, data: string } }
  sku: { name: string, tier: string, capacity: int }
  autoscaleConfiguration: { maxCapacity: int, minCapacity: int }
  backendAddressPools: { *: { name: string, fqdns: string[], ipAddresses: string[] } }
  backendHttpSettings: {
    *: {
      cookieBasedAffinity: string
      name: string
      port: int
      protocol: string
      affinityCookieName: string
      hostName: string
      path: string
      pickHostNameFromBackendAddress: bool
      probeName: string
      requestTimeout: int
      trustedRootCertificateNames: string[]
      authenticationCertificate: string[]
      connectionDraining: { enabled: bool, drainTimeoutSec: int }
    }
  }
  frontendPorts: { *: { name: string, port: int } }
  httpListeners: {
    *: {
      name: string
      frontendPortName: string
      frontendIpConfigurationName: string
      firewallPolicyId: string
      requireSni: bool
      hostName: string
      hostNames: string[]
      sslCertificateName: string
      sslProfileName: string
      customErrorConfiguration: object[]
    }
  }
  probeConfigurations: {
    *: {
      name: string
      host: string
      interval: int
      timeout: int
      unhealthyThreshold: int
      protocol: string
      port: int
      path: string
      pickHostNameFromBackendHttpSettings: bool
      minimumServers: int
      match: object
    }
  }
  redirectConfiguration: {
    *: {
      includePath: bool
      includeQueryString: bool
      name: string
      redirectType: string
      targetListenerName: string
      targetUrl: string
    }
  }
  requestRoutingRules: {
    *: {
      name: string
      ruleType: string
      httpListenerName: string
      backendAddressPoolName: string
      priority: int
      urlPathMapName: string
      backendHttpSettingsName: string
      redirectConfigurationName: string
      rewriteRuleSetName: string
    }
  }
  rewriteRuleSet: { *: { name: string, rewriteRules: { *: object } } }
  sslCertificates: { *: { name: string, data: string, password: string, keyVaultSecretId: string } }
  sslPolicy: {
    cipherSuites: string[]
    disabledProtocols: string[]
    minProtocolVersion: string
    policyName: string
    policyType: string
  }
  sslProfile: {
    *: {
      name: string
      trustedClientCertificateNames: string[]
      verifyClientCertIssuerDn: bool
      verifyClientCertificateRevocation: string
      sslPolicy: {
        cipherSuites: string[]
        disabledProtocols: string[]
        minProtocolVersion: string
        policyName: string
        policyType: string
      }
    }
  }
  trustedClientCertificate: { *: { data: string, name: string } }
  trustedRootCertificate: { *: { data: string, keyVaultSecretId: string, name: string } }
  urlPathMapConfigurations: {
    *: {
      name: string
      defaultRedirectConfigurationName: string
      defaultRewriteRuleSetName: string
      defaultBackendHttpSettingsName: string
      defaultBackendAddressPoolName: string
      pathRules: {
        *: {
          name: string
          paths: string[]
          backendAddressPoolName: string
          backendHttpSettingsName: string
          redirectConfigurationName: string
          rewriteRuleSetName: string
        }
      }
    }
  }
  tags: { *: string }
  roleAssignments: {
    name: string?
    principalId: string
    roleDefinitionIdOrName: string
    principalType: 'Device' | 'ForeignGroup' | 'Group' | 'ServicePrincipal' | 'User'
    description: string?
    condition: string?
    conditionVersion: '2.0'?
    delegatedManagedIdentityResourceId: string?
  }[]
}

@export()
@description('Configuration object for the Azure API Management service to be deployed.')
type ApimDefinitionType = {
  name: string?
  publisherEmail: string
  publisherName: string
  additionalLocations: {
    *: {
      location: string
      capacity: int
      zones: int[]
      publicIpAddressId: string
      gatewayDisabled: bool
      virtualNetworkConfiguration: { subnetId: string }
    }
  }
  certificate: { *: { encodedCertificate: string, storeName: string, certificatePassword: string } }
  clientCertificateEnabled: bool
  hostnameConfiguration: {
    management: {
      *: {
        hostName: string
        keyVaultId: string
        certificate: string
        certificatePassword: string
        negotiateClientCertificate: bool
        sslKeyvaultIdentityClientId: string
        defaultSslBinding: bool
      }
    }
    portal: {
      *: {
        hostName: string
        keyVaultId: string
        certificate: string
        certificatePassword: string
        negotiateClientCertificate: bool
        sslKeyvaultIdentityClientId: string
        defaultSslBinding: bool
      }
    }
    developerPortal: {
      *: {
        hostName: string
        keyVaultId: string
        certificate: string
        certificatePassword: string
        negotiateClientCertificate: bool
        sslKeyvaultIdentityClientId: string
        defaultSslBinding: bool
      }
    }
    proxy: {
      *: {
        hostName: string
        keyVaultId: string
        certificate: string
        certificatePassword: string
        negotiateClientCertificate: bool
        sslKeyvaultIdentityClientId: string
        defaultSslBinding: bool
      }
    }
    scm: {
      *: {
        hostName: string
        keyVaultId: string
        certificate: string
        certificatePassword: string
        negotiateClientCertificate: bool
        sslKeyvaultIdentityClientId: string
        defaultSslBinding: bool
      }
    }
  }
  minApiVersion: string
  notificationSenderEmail: string
  protocols: { enableHttp2: bool }
  roleAssignments: {
    name: string?
    principalId: string
    roleDefinitionIdOrName: string
    principalType: 'Device' | 'ForeignGroup' | 'Group' | 'ServicePrincipal' | 'User'
    description: string?
    condition: string?
    conditionVersion: '2.0'?
    delegatedManagedIdentityResourceId: string?
  }[]
  signIn: { enabled: bool }
  signUp: { enabled: bool, termsOfService: { consentRequired: bool, enabled: bool, text: string } }
  skuRoot: string
  skuCapacity: int
  tags: { *: string }
  tenantAccess: { enabled: bool }
}

@export()
@description('Configuration object for the Azure Firewall to be deployed.')
type FirewallDefinitionType = {
  name: string?
  sku: string
  tier: string
  zones: string[]
  tags: { *: string }
}

@export()
@description('Configuration object for VNet peering with a hub network.')
type HuVnetPeeringDefinitionType = {
  peerVnetResourceId: string
  firewallIpAddress: string
  name: string?
  allowForwardedTraffic: bool
  allowGatewayTransit: bool
  allowVirtualNetworkAccess: bool
  createReversePeering: bool
  reverseAllowForwardedTraffic: bool
  reverseAllowGatewayTransit: bool
  reverseAllowVirtualNetworkAccess: bool
  reverseName: string
  reverseUseRemoteGateways: bool
  useRemoteGateways: bool
}
