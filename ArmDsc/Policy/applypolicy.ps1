Param(
  [string]$rgName,
  [string]$policyUrl
)

$policyName = "securityCenterPolicy"

$definition = New-AzureRmPolicyDefinition `
    -Name $policyName `
    -DisplayName "Enable security center" `
    -Policy $policyUrl
	
$rg = Get-AzureRmResourceGroup -Name $rgName

New-AzureRMPolicyAssignment -Name $policyName -Scope $rg.ResourceId -PolicyDefinition $definition