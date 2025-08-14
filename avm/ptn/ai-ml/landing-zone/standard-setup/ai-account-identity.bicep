param accountName string
param location string
param modelDeployments array
param networkIsolation bool = false
param agentSubnetId string

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: accountName
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: accountName
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    publicNetworkAccess: networkIsolation ? 'Disabled' : 'Enabled'
    #disable-next-line BCP036
    networkInjections: ((networkIsolation)
      ? [
          {
            scenario: 'agent'
            subnetArmId: agentSubnetId
            useMicrosoftManagedNetwork: false
          }
        ]
      : null)

    // API-key based auth is not supported for the Agent service
    disableLocalAuth: false
  }
}

// Model Deployments Resource

// @batchSize(1)
// resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = [
//   for deployment in modelDeployments: {
//     parent: account
//     name: deployment.name
//     sku: {
//       name: deployment.type
//       capacity: deployment.capacity
//     }
//     properties: {
//       model: {
//         name: deployment.model
//         format: deployment.modelFormat
//         version: deployment.version
//       }
//     }
//   }
// ]

@batchSize(1)
resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = [
  for deployment in modelDeployments: {
    parent: account
    name: deployment.name

    // use nested "scale"
    sku: {
      name: deployment.scale.type
      capacity: deployment.scale.capacity
    }

    properties: {
      // use nested "model"
      model: {
        name: deployment.model.name
        format: deployment.model.format
        version: deployment.model.version
      }

      // pass-through when present (optional)
      ...(!empty(deployment.raiPolicyName)
        ? {
            raiPolicyName: deployment.raiPolicyName
          }
        : {})
      ...(!empty(deployment.versionUpgradeOption)
        ? {
            versionUpgradeOption: deployment.versionUpgradeOption
          }
        : {})
    }
  }
]

output accountName string = account.name
output accountID string = account.id
output accountTarget string = account.properties.endpoint
output accountPrincipalId string = account.identity.principalId
