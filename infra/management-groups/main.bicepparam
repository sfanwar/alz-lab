using './main.bicep'

// Keep this short and lowercase. It becomes part of every management group ID,
// and management group IDs cannot be renamed after creation - only deleted and
// recreated. Pick something you will not want to change.
param prefix = 'alzlab'

param intermediateRootDisplayName = 'ALZ Lab v1'
