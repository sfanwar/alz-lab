// ---------------------------------------------------------------------------
// Reusable module: assigns an initiative to whichever management group the
// caller targets via the module's scope property.
//
// All effects here are Deny/Audit, so no managed identity and no role
// assignment are needed. A deployIfNotExists or modify policy WOULD need
// identity: { type: 'SystemAssigned' } plus a role assignment for the
// remediation identity - that is the next exercise, not this one.
// ---------------------------------------------------------------------------

targetScope = 'managementGroup'

@description('Assignment name. Management group scoped assignments are capped at 24 characters.')
@maxLength(24)
param assignmentName string

@description('Friendly name shown in the portal.')
param displayName string

@description('Resource ID of the initiative (policy set definition) being assigned.')
param initiativeId string

@description('Default actually enforces. DoNotEnforce evaluates compliance but never blocks - always start here.')
@allowed([
  'Default'
  'DoNotEnforce'
])
param enforcementMode string

@description('Effect passed through to the custom controls in the initiative.')
@allowed([
  'Audit'
  'Deny'
  'Disabled'
])
param effect string

@description('Regions permitted at this scope.')
param allowedLocations array

@description('Shown to a user whose deployment gets blocked. Worth writing properly - this is the only feedback they get.')
param nonComplianceMessage string

resource assignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: assignmentName
  properties: {
    displayName: displayName
    policyDefinitionId: initiativeId
    enforcementMode: enforcementMode
    parameters: {
      effect: {
        value: effect
      }
      allowedLocations: {
        value: allowedLocations
      }
    }
    nonComplianceMessages: [
      {
        message: nonComplianceMessage
      }
    ]
  }
}

output assignmentId string = assignment.id
