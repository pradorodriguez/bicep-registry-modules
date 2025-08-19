metadata name = 'Using only defaults.'
metadata description = 'This instance deploys the module with the minimum set of required parameters.'

targetScope = 'resourceGroup'

// ========== //
// Parameters //
// ========== //

@description('Azure region for AI Landing Zone resources.')
param location string = resourceGroup().location

@description('Tags applied to all deployed resources.')
param tags object = {}

// ============== //
// Test Execution //
// ============== //

module testDefaultDeployment '../../../main.bicep' = {
  name: 'AIALZDefaultDeployment'
  params: {
    location: location
    tags: tags
  }
}

// ======= //
// Outputs //
// ======= //

output testDefaultDeploymentOutputs object = testDefaultDeployment.outputs
