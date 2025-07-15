# ai-foundry `[AiMl/AiLandingZone]`

Creates an AI Landing Zone.

## Navigation

- [Resource Types](#Resource-Types)
- [Usage examples](#Usage-examples)
- [Parameters](#Parameters)
- [Outputs](#Outputs)
- [Cross-referenced modules](#Cross-referenced-modules)
- [Data Collection](#Data-Collection)

## Resource Types

The following Azure resource types are deployed by this module, along with their corresponding API versions:

| Resource Type                                               | API Version                                                                                                                                                           |
| :---------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Microsoft.Network/virtualNetworks`                         | [2024-07-01](https://learn.microsoft.com/en-us/azure/templates/microsoft.network/virtualnetworks?api-version=2024-07-01)                      |
| `Microsoft.Network/bastionHosts`                            | [2024-07-01](https://learn.microsoft.com/en-us/azure/templates/microsoft.network/bastionhosts?api-version=2024-07-01)                         |
| `Microsoft.Network/applicationGateways`                     | [2024-07-01](https://learn.microsoft.com/en-us/azure/templates/microsoft.network/applicationgateways?api-version=2024-07-01)                   |
| `Microsoft.Network/azureFirewalls`                          | [2024-07-01](https://learn.microsoft.com/en-us/azure/templates/microsoft.network/azurefirewalls?api-version=2024-07-01)                        |
| `Microsoft.Network/privateDnsZones`                         | [2024-06-01](https://learn.microsoft.com/en-us/azure/templates/microsoft.network/privatednszones?api-version=2024-06-01)                       |
| `Microsoft.Network/privateEndpoints`                        | [2024-07-01](https://learn.microsoft.com/en-us/azure/templates/microsoft.network/privateendpoints?api-version=2024-07-01)                      |
| `Microsoft.Network/privateLinkServices`                     | [2024-07-01](https://learn.microsoft.com/en-us/azure/templates/microsoft.network/privatelinkservices?api-version=2024-07-01)                   |
| `Microsoft.Compute/virtualMachines`                         | [2024-11-01](https://learn.microsoft.com/en-us/azure/templates/microsoft.compute/virtualmachines?api-version=2024-11-01)                       |
| `Microsoft.ApiManagement/service`                           | [2024-06-01-preview](https://learn.microsoft.com/en-us/azure/templates/microsoft.apimanagement/service?api-version=2024-06-01-preview)         |
| `Microsoft.App/managedEnvironments`                         | [2025-02-02-preview](https://learn.microsoft.com/en-us/azure/templates/microsoft.app/managedenvironments?api-version=2025-02-02-preview)        |
| `Microsoft.App/containerApps`                               | [2025-02-02-preview](https://learn.microsoft.com/en-us/azure/templates/microsoft.app/containerapps?api-version=2025-02-02-preview)              |
| `Microsoft.ContainerRegistry/registries`                    | [2025-05-01-preview](https://learn.microsoft.com/en-us/azure/templates/microsoft.containerregistry/registries?api-version=2025-05-01-preview)   |
| `Microsoft.Storage/storageAccounts`                         | [2022-09-01](https://learn.microsoft.com/en-us/azure/templates/microsoft.storage/storageaccounts?api-version=2022-09-01)                        |
| `Microsoft.DocumentDB/databaseAccounts`                     | [2023-03-15](https://learn.microsoft.com/en-us/azure/templates/microsoft.documentdb/databaseaccounts?api-version=2023-03-15)                    |
| `Microsoft.KeyVault/vaults`                                 | [2024-12-01-preview](https://learn.microsoft.com/en-us/azure/templates/microsoft.keyvault/vaults?api-version=2024-12-01-preview)                |
| `Microsoft.OperationalInsights/workspaces`                  | [2025-02-01](https://learn.microsoft.com/en-us/azure/templates/microsoft.operationalinsights/workspaces?api-version=2025-02-01)                 |
| `Microsoft.Insights/components`                             | [2020-02-02](https://learn.microsoft.com/en-us/azure/templates/microsoft.insights/components?api-version=2020-02-02)                            |
| `Microsoft.Search/searchServices`                           | [2021-04-01](https://learn.microsoft.com/en-us/azure/templates/microsoft.search/searchservices?api-version=2021-04-01)                          |
| `Microsoft.CognitiveServices/accounts`                      | [2025-04-01-preview](https://learn.microsoft.com/en-us/azure/templates/microsoft.cognitiveservices/accounts?api-version=2025-04-01-preview)     |
| `Microsoft.CognitiveServices/accounts/capabilityHosts`      | [2025-04-01-preview](https://learn.microsoft.com/en-us/azure/templates/microsoft.cognitiveservices/accounts/capabilityhosts?api-version=2025-04-01-preview)           |
| `Microsoft.CognitiveServices/accounts/deployments`          | [2025-04-01-preview](https://learn.microsoft.com/en-us/azure/templates/microsoft.cognitiveservices/accounts/deployments?api-version=2025-04-01-preview)               |
| `Microsoft.CognitiveServices/accounts/projects`             | [2025-04-01-preview](https://learn.microsoft.com/en-us/azure/templates/microsoft.cognitiveservices/accounts/projects?api-version=2025-04-01-preview)                  |
| `Microsoft.CognitiveServices/accounts/projects/connections` | [2025-04-01-preview](https://learn.microsoft.com/en-us/azure/templates/microsoft.cognitiveservices/accounts/projects/connections?api-version=2025-04-01-preview)      |
| `Microsoft.AppConfiguration/configurationStores`            | [2022-05-01](https://learn.microsoft.com/en-us/azure/templates/microsoft.appconfiguration/configurationstores?api-version=2022-05-01)           |
| `Microsoft.Authorization/roleAssignments`                   | [2022-04-01](https://learn.microsoft.com/en-us/azure/templates/microsoft.authorization/roleassignments?api-version=2022-04-01)                  |

---

The following section provides usage examples for the module, which were used to validate and deploy the module successfully. For a full reference, please review the module's test folder in its repository.

>**Note**: Each example lists all the required parameters first, followed by the rest - each in alphabetical order.

>**Note**: To reference the module, please use the following syntax `br/public:avm/ptn/ai-ml/landing-zone:<version>`.

- [Using only defaults](#example-1-using-only-defaults)
- [WAF-aligned](#example-2-waf-aligned)

### Example 1: _Using only defaults_

Creates an AI Landing Zone with basic services and no network isolation.

<details>

<summary>via Bicep module</summary>

```bicep
TBD
```

</details>
<p>

<details>

<summary>via JSON parameters file</summary>

```json
TBD
```

</details>
<p>

<details>

<summary>via Bicep parameters file</summary>

```bicep-params
TBD
```

</details>
<p>

### Example 2: _WAF-aligned_

Creates an AI Landing Zone with basic services in a network.


<details>

<summary>via Bicep module</summary>

```bicep
TBD
```

</details>
<p>

<details>

<summary>via JSON parameters file</summary>

```json
TBD
```

</details>
<p>

<details>

<summary>via Bicep parameters file</summary>

```bicep-params
TBD
```

</details>
<p>

## Parameters

**Required parameters**

| Parameter | Type | Description |
| :-- | :-- | :-- |
| TBD | TBD | TBD. |


**Optional parameters**

| Parameter | Type | Description |
| :-- | :-- | :-- |
| TBD | TBD | TBD. |



### Parameter: `TBD`

TBD description.

- Required: Yes
- Type: TBD


## Outputs

| Output | Type | Description |
| :-- | :-- | :-- |
| `TBD` | string | TBD. |

## Cross-referenced modules

This section gives you an overview of all local-referenced module files (i.e., other modules that are referenced in this module) and all remote-referenced files (i.e., Bicep modules that are referenced from a Bicep Registry or Template Specs).

| Reference | Type |
| :-- | :-- |
| `TBD` | Remote reference |


## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the [repository](https://aka.ms/avm/telemetry). There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
