[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $Prefix = "Valheim01",
    # Azure Region
    [Parameter()]
    [string]
    $Location = "northcentralus"
)

$resourceGroupName = "$Prefix-RG"

$rg = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue

if (!$rg) {
    $rg = New-AzResourceGroup -Name $resourceGroupName -Location $Location
}

$timestamp = (Get-Date).ToString("yyyy-MM-dd-hh-mm-ss")

New-AzResourceGroupDeployment `
    -Name "$resourceGroupName-$timestamp" `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile ".\main.bicep" `
    -Verbose `
    -namePrefix $Prefix