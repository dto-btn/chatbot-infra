$sp = Get-AzureADServicePrincipal -Filter "displayName eq 'Robot conversationnel - Azure OpenAI - Chatbot'"

# this would show role assignments
Get-AzureADServiceAppRoleAssignment -ObjectId $sp.ObjectId

# remove CIO-ALL
$cio_grp        = Get-AzureADGroup -SearchString "CIO-ALL"
$cio_grp_role_id = Get-AzureADGroupAppRoleAssignment -ObjectId $cio_grp.ObjectId
Remove-AzureADServiceAppRoleAssignment -AppRoleAssignmentId $cio_grp_role_id.ObjectId -ObjectId $sp.ObjectId

# add SSC Early Adopters ..
$early_adp_grp  = Get-AzureADGroup -SearchString "SSC Early Adopters"
New-AzureADGroupAppRoleAssignment -Id ([Guid]::Empty) -ObjectId $early_adp_grp.ObjectId -PrincipalId $early_adp_grp.ObjectId -ResourceId $sp.ObjectId