param(
    [string]$containerName = "${container_name}",
    [string]$resourceGroup = "${resource_group}"
)

az login --identity
#https://learn.microsoft.com/en-us/cli/azure/containerapp/revision?view=azure-cli-latest#az-containerapp-revision-restart
$revisions = az containerapp revision list --name $containerName --resource-group $resourceGroup | ConvertFrom-Json 
az containerapp revision restart --revision $revisions[0].name --name $containerName --resource-group $resourceGroup