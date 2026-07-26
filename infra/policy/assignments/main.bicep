// ---------------------------------------------------------------------------
// Assigns the baseline initiative at different scopes with DIFFERENT postures.
// This is the whole point of the exercise: the same initiative behaves
// differently depending on where in the hierarchy it lands.
//
//   <prefix>-corp     strict   - Deny, no public IPs
//   <prefix>-sandbox  relaxed  - Audit only, nothing is blocked
//
// Once deployed, move your subscription between corp and sandbox and try the
// same deployment in each. That single loop teaches inheritance better than
// any amount of reading.
//
// Deployed at the intermediate root; the modules re-scope to the children.
// ---------------------------------------------------------------------------

targetScope = 'managementGroup'

@description('Same prefix used by the management group deployment.')
param prefix string

@description('Resource ID of the baseline initiative, output by the definitions deployment.')
param initiativeId string

@description('Set to Default only once you have watched compliance results and understand what will break.')
@allowed([
  'Default'
  'DoNotEnforce'
])
param enforcementMode string

@description('Regions permitted for resource deployment.')
param allowedLocations array

// ---------------------------------------------------------------------------
// Corp - the strict landing zone.
// ---------------------------------------------------------------------------
module corpAssignment './assignment.bicep' = {
  name: 'assign-baseline-corp'
  scope: managementGroup('${prefix}-corp')
  params: {
    assignmentName: 'baseline-corp'
    displayName: 'Baseline guardrails (Corp)'
    initiativeId: initiativeId
    enforcementMode: enforcementMode
    effect: 'Deny'
    allowedLocations: allowedLocations
    nonComplianceMessage: 'Corp landing zones do not permit anonymous blob access or public IP addresses. Use a private endpoint, or deploy to the Online landing zone.'
  }
}

// ---------------------------------------------------------------------------
// Sandbox - deliberately permissive. Audit records the violation without
// blocking it, which is exactly what a sandbox should do.
// ---------------------------------------------------------------------------
module sandboxAssignment './assignment.bicep' = {
  name: 'assign-baseline-sandbox'
  scope: managementGroup('${prefix}-sandbox')
  params: {
    assignmentName: 'baseline-sandbox'
    displayName: 'Baseline guardrails (Sandbox - audit only)'
    initiativeId: initiativeId
    enforcementMode: enforcementMode
    effect: 'Audit'
    allowedLocations: allowedLocations
    nonComplianceMessage: 'Sandbox records policy violations but does not block them. Anything built here must be rebuilt compliantly before promotion.'
  }
}

output corpAssignmentId string = corpAssignment.outputs.assignmentId
output sandboxAssignmentId string = sandboxAssignment.outputs.assignmentId
