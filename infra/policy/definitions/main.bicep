// ---------------------------------------------------------------------------
// Custom policy definitions + one initiative (policy set), deployed at
// MANAGEMENT GROUP scope - specifically at the intermediate root, so that
// everything below inherits them.
//
// Policy definitions and initiatives are free. Only the resources a
// deployIfNotExists policy creates cost money - and there are none here.
// Every effect below is Deny or Audit, so no managed identity is required.
//
// Deploy with:  az deployment mg create --management-group-id <intermediate root>
// ---------------------------------------------------------------------------

targetScope = 'managementGroup'

@description('Regions permitted for resource deployment.')
param allowedLocations array

// ---------------------------------------------------------------------------
// Custom definition 1 - block anonymous blob access.
// Good first test case: a default-configuration storage account trips this,
// so you can watch a deny fire within a minute of assigning it.
// ---------------------------------------------------------------------------
resource denyPublicBlob 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: 'Deny-Storage-PublicBlobAccess'
  properties: {
    displayName: 'Storage accounts must disable anonymous blob access'
    policyType: 'Custom'
    mode: 'Indexed'
    description: 'Blocks creation or update of storage accounts where allowBlobPublicAccess is not explicitly false.'
    metadata: {
      category: 'Storage'
      version: '1.0.0'
    }
    parameters: {
      effect: {
        type: 'String'
        defaultValue: 'Deny'
        allowedValues: [
          'Audit'
          'Deny'
          'Disabled'
        ]
        metadata: {
          displayName: 'Effect'
          description: 'Start with Audit, move to Deny once you understand the blast radius.'
        }
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Storage/storageAccounts'
          }
          {
            field: 'Microsoft.Storage/storageAccounts/allowBlobPublicAccess'
            notEquals: 'false'
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Custom definition 2 - block public IP addresses.
// In a real Corp landing zone this enforces "no direct internet ingress".
// In a lab it also stops you accidentally standing up billable resources.
// ---------------------------------------------------------------------------
resource denyPublicIp 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: 'Deny-PublicIP'
  properties: {
    displayName: 'Public IP addresses are not permitted'
    policyType: 'Custom'
    mode: 'Indexed'
    description: 'Blocks creation of public IP addresses. Intended for Corp landing zones with no direct internet ingress.'
    metadata: {
      category: 'Network'
      version: '1.0.0'
    }
    parameters: {
      effect: {
        type: 'String'
        defaultValue: 'Deny'
        allowedValues: [
          'Audit'
          'Deny'
          'Disabled'
        ]
        metadata: {
          displayName: 'Effect'
        }
      }
    }
    policyRule: {
      if: {
        field: 'type'
        equals: 'Microsoft.Network/publicIPAddresses'
      }
      then: {
        effect: '[parameters(\'effect\')]'
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Initiative - bundles the two custom definitions with one built-in.
// ALZ assigns initiatives, not individual definitions. Getting used to that
// shape now saves rework later.
// ---------------------------------------------------------------------------
var allowedLocationsBuiltIn = tenantResourceId(
  'Microsoft.Authorization/policyDefinitions',
  'e56962a6-4747-49cd-b67b-bf8b01975c4c'
)

resource baselineInitiative 'Microsoft.Authorization/policySetDefinitions@2023-04-01' = {
  name: 'ALZLab-Baseline'
  properties: {
    displayName: 'ALZ Lab baseline guardrails'
    policyType: 'Custom'
    description: 'Minimal governance baseline for the lab: region restriction, no anonymous blob access, no public IPs.'
    metadata: {
      category: 'Lab'
      version: '1.0.0'
    }
    parameters: {
      effect: {
        type: 'String'
        defaultValue: 'Deny'
        allowedValues: [
          'Audit'
          'Deny'
          'Disabled'
        ]
        metadata: {
          displayName: 'Effect for the custom controls'
        }
      }
      allowedLocations: {
        type: 'Array'
        defaultValue: allowedLocations
        metadata: {
          displayName: 'Allowed regions'
          strongType: 'location'
        }
      }
    }
    policyDefinitions: [
      {
        policyDefinitionReferenceId: 'AllowedLocations'
        policyDefinitionId: allowedLocationsBuiltIn
        parameters: {
          listOfAllowedLocations: {
            value: '[parameters(\'allowedLocations\')]'
          }
        }
      }
      {
        policyDefinitionReferenceId: 'DenyStoragePublicBlobAccess'
        policyDefinitionId: denyPublicBlob.id
        parameters: {
          effect: {
            value: '[parameters(\'effect\')]'
          }
        }
      }
      {
        policyDefinitionReferenceId: 'DenyPublicIP'
        policyDefinitionId: denyPublicIp.id
        parameters: {
          effect: {
            value: '[parameters(\'effect\')]'
          }
        }
      }
    ]
  }
}

output baselineInitiativeId string = baselineInitiative.id
output denyPublicIpDefinitionId string = denyPublicIp.id
