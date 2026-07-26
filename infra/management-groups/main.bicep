// ---------------------------------------------------------------------------
// Management group hierarchy (ALZ-style), deployed at TENANT scope.
//
//   Tenant Root Group
//   └── <prefix>                    intermediate root  <- policy anchor
//       ├── <prefix>-platform
//       │   ├── <prefix>-identity
//       │   ├── <prefix>-management
//       │   └── <prefix>-connectivity
//       ├── <prefix>-landingzones
//       │   ├── <prefix>-corp
//       │   └── <prefix>-online
//       ├── <prefix>-sandbox
//       └── <prefix>-decommissioned
//
// Management groups are free. This whole file costs nothing to deploy.
// Deploy with:  az deployment tenant create --location <region> ...
// ---------------------------------------------------------------------------

targetScope = 'tenant'

@description('Short prefix used to build every management group ID. Must be unique in the tenant.')
@minLength(2)
@maxLength(10)
param prefix string

@description('Display name shown in the portal for the intermediate root management group.')
param intermediateRootDisplayName string

// ---------------------------------------------------------------------------
// Level 1 - intermediate root.
// Omitting details.parent parents this to the Tenant Root Group.
// Never assign policy at the Tenant Root Group itself; that is why this exists.
// ---------------------------------------------------------------------------
resource intermediateRoot 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: prefix
  properties: {
    displayName: intermediateRootDisplayName
  }
}

// ---------------------------------------------------------------------------
// Level 2
// ---------------------------------------------------------------------------
var level2 = [
  { id: 'platform', displayName: 'Platform' }
  { id: 'landingzones', displayName: 'Landing zones' }
  { id: 'sandbox', displayName: 'Sandbox' }
  { id: 'decommissioned', displayName: 'Decommissioned' }
]

resource level2Groups 'Microsoft.Management/managementGroups@2023-04-01' = [
  for mg in level2: {
    name: '${prefix}-${mg.id}'
    properties: {
      displayName: mg.displayName
      details: {
        parent: {
          id: intermediateRoot.id
        }
      }
    }
  }
]

// ---------------------------------------------------------------------------
// Level 3 - platform children.
// The parent ID is built with tenantResourceId() rather than indexing into the
// loop above, because indexing a loop makes the graph fragile. dependsOn on the
// whole loop is enough to get the ordering right.
// ---------------------------------------------------------------------------
var platformChildren = [
  { id: 'identity', displayName: 'Identity' }
  { id: 'management', displayName: 'Management' }
  { id: 'connectivity', displayName: 'Connectivity' }
]

resource platformGroups 'Microsoft.Management/managementGroups@2023-04-01' = [
  for mg in platformChildren: {
    name: '${prefix}-${mg.id}'
    properties: {
      displayName: mg.displayName
      details: {
        parent: {
          id: tenantResourceId('Microsoft.Management/managementGroups', '${prefix}-platform')
        }
      }
    }
    dependsOn: [
      level2Groups
    ]
  }
]

// ---------------------------------------------------------------------------
// Level 3 - landing zone children.
// Corp  = no direct internet ingress, expects hybrid connectivity.
// Online = internet-facing workloads, no corporate network dependency.
// ---------------------------------------------------------------------------
var landingZoneChildren = [
  { id: 'corp', displayName: 'Corp' }
  { id: 'online', displayName: 'Online' }
]

resource landingZoneGroups 'Microsoft.Management/managementGroups@2023-04-01' = [
  for mg in landingZoneChildren: {
    name: '${prefix}-${mg.id}'
    properties: {
      displayName: mg.displayName
      details: {
        parent: {
          id: tenantResourceId('Microsoft.Management/managementGroups', '${prefix}-landingzones')
        }
      }
    }
    dependsOn: [
      level2Groups
    ]
  }
]

// ---------------------------------------------------------------------------
// Outputs - handy for the next deployment stage and for teardown scripts.
// ---------------------------------------------------------------------------
output intermediateRootId string = intermediateRoot.id
output intermediateRootName string = intermediateRoot.name
output allManagementGroupNames array = concat(
  [prefix],
  map(level2, mg => '${prefix}-${mg.id}'),
  map(platformChildren, mg => '${prefix}-${mg.id}'),
  map(landingZoneChildren, mg => '${prefix}-${mg.id}')
)
