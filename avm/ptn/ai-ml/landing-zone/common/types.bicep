@export()
@description('Container for all generated resource name values.')
type ResourceNamesType = {
  vnetName: string
  appInsightsName: string
  containerEnvName: string
  containerRegistryName: string
  aiFoundryAccountName: string
  aiFoundrySearchServiceName: string
  aiFoundryCosmosDbName: string
  aiFoundryProjectName: string
  appConfigName: string
  dbAccountName: string
  dbDatabaseName: string
  keyVaultName: string
  logAnalyticsWorkspaceName: string
  searchServiceName: string
  storageAccountName: string
}

@export()
@description('Toggle deployment of various services.')
type FeatureFlagsType = {
  deployVM: bool
  deployAppInsights: bool
  deployLogAnalytics: bool
  deploySearchService: bool
  deployStorageAccount: bool
  deployCosmosDb: bool
  deployContainerApps: bool
  deployContainerRegistry: bool
  deployContainerEnv: bool
  greenFieldDeployment: bool
  deployAppConfig: bool
  deployKeyVault: bool
}

@export()
@description('Optional existing resource IDs to reuse; leave empty to create new resources.')
type ResourceIdsType = {
  virtualNetworkResourceId: string
  appInsightsResourceId: string
  containerEnvResourceId: string
  containerRegistryResourceId: string
  aiFoundryAccountResourceId: string
  aiFoundrySearchServiceResourceId: string
  aiFoundryCosmosDbResourceId: string
  aiFoundryProjectResourceId: string
  appConfigResourceId: string
  dbAccountResourceId: string
  keyVaultResourceId: string
  logAnalyticsWorkspaceResourceId: string
  searchServiceResourceId: string
  storageAccountResourceId: string
}

@export()
@description('Definition of a single Container Apps environment workload profile.')
type WorkloadProfileType = {
  name: string
  cpu: string
  memory: string
}

@export()
@description('Definition of a single Container App to create.')
type ContainerAppDefinitionType = {
  name: string
  service_name: string
  profile_name: string
  min_replicas: int
  max_replicas: int
}

@export()
@description('Definition of a single Cosmos DB container to create.')
type DatabaseContainerDefinitionType = {
  name: string
}

@export()
@description('Definition of a single Storage Account container to create.')
type StorageContainerDefinitionType = {
  name: string
}

@export()
@secure()
@description('VM settings and associated Key Vault configuration.')
type VMSettingsType = {
  vmSize: string
  vmKeyVaultSecName: string
  vmName: string
  vmUserName: string
}
