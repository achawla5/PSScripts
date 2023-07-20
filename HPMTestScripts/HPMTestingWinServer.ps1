[CmdletBinding()] Param (
    [Parameter(
        Mandatory
    )]
    [System.String]$HostPoolName,

    [Parameter(
        Mandatory
    )]
    [string]$SubID,

    [Parameter(
        Mandatory
    )]
    [string]$ResourceGroupName,

    [Parameter(
        Mandatory
    )]
    [string]$NetworkInfoSubnetId,

    [Parameter(
        Mandatory
    )]
    [string]$VMPasswordSecretUri,

    [Parameter(
        Mandatory
    )]
    [string]$VMUsernameSecretUri,

    [Parameter(
        Mandatory
    )]
    [string]$VMNamePrefix,

    [Parameter(
        Mandatory
    )]
    [string]$VMLocation,

    [Parameter(
        Mandatory
    )]
    [string]$VMCount,

    
    [Parameter(
        Mandatory
    )]
    [string]$DomainJoinSecretUri,

    
    [Parameter(
        Mandatory
    )]
    [string]$DomainJoinUsernameUri
)

Connect-AzAccount
Set-AzContext -Subscription $subID
$hostpool = Get-AzWvdHostPool -Name $HostPoolName -ResourceGroupName $ResourceGroupName -SubscriptionId $SubID

if(-not $hostpool) {
    Write-Host "Hostpool with provided hostpool name does not exist. Please create one"
    #New-AzWvdHostPool -HostPoolType Pooled -Name $HostPoolName -ResourceGroupName $ResourceGroupName -LoadBalancerType 'DepthFirst' -Location $VMLocation -PreferredAppGroupType 'Desktop' -SubscriptionId $SubID -ManagementType 'Automated'
} 

Write-Host "Updating session host config"
Update-AzWvdSessionHostConfiguration -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -friendlyName Initial -DiskInfoType Standard_LRS -DomainInfoJoinType AzureActiveDirectory -ImageInfoType MarketPlace -MarketPlaceInfoOffer "office-365" -MarketPlaceInfoPublisher MicrosoftWindowsDesktop -MarketPlaceInfoSku "win10-22h2-avd-m365" -MarketPlaceInfoExactVersion "19045.3086.230621" -NetworkInfoSubnetId $NetworkInfoSubnetId -VMAdminCredentialsPasswordKeyVaultSecretUri $VMPasswordSecretUri -VMAdminCredentialsUsernameKeyVaultSecretUri $VMUsernameSecretUri -VMNamePrefix $VMNamePrefix -VMSizeId Standard_D2s_v3 -VMLocation $VMLocation -DomainCredentialsPasswordKeyVaultSecretUri $DomainJoinSecretUri -DomainCredentialsUsernameKeyVaultSecretUri $DomainJoinUsernameUri 
Write-Host "Session host config updated"

$VMSizes = @("Standard_D4s_v5", "Standard_B4ms", "Standard_A8_v2", "Standard_E16-4s_v5");
$disks = @("StandardSSD_LRS", "Premium_LRS", "Standard_LRS");

class Image {
    [string]$Publisher
    [string]$Offer
    [string]$Version;
    [string]$sku;
}

$images = @([Image]@{Publisher='MicrosoftWindowsServer';Offer='WindowsServer';Sku="2022-Datacenter";Version="20348.1850.230707"}
[Image]@{Publisher='MicrosoftWindowsServer';Offer='WindowsServer';Sku="2019-Datacenter";Version="17763.3132.220610"})

for($i = 0; $i -le $images.Count; $i++) {

    for($j = 0; $j -le $VMSizes.Count; $j++) {
        
        for($k = 0; $k -le $disks.Count; $k++) {
             $publisher = $images[$i].Publisher
             $sku = $images[$i].Sku
             $offer = $images[$i].Offer
             $version = $images[$i].Version

             #Update-AzWvdSessionHostConfiguration -SubscriptionId $subID -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -DiskInfoType $disks[$k] -VMSizeId $VMSizes[$j] -DomainInfoJoinType 'AzureActiveDirectory' -ImageInfoType 'Marketplace' -MarketplaceInfoExactVersion $version -MarketplaceInfoOffer $offer -MarketplaceInfoPublisher $publisher -MarketplaceInfoSku $sku 
             #Update-AzWvdSessionHostManagement -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -SubscriptionId $SubID -UpdateLogOffDelayMinute "1" -UpdateLogOffMessage "logoff"  
             #$MaxVMRemoved = $VMCount - 1
             $vmRemove = 2
             Write-Information "VMs to be removed during update: $vmRemove"
             #Invoke-AzWvdInitiateSessionHostUpdate -HostPoolName $hpname -ResourceGroupName $ResourceGroupName -SubscriptionId $subID -UpdateMaxVmsRemoved $vmRemove -UpdateDeleteOriginalVM

             if($k -eq 0 -or ($k % 2 -eq 0)) {
                # Do AAD
                #Schedule update now
                Write-Host "Updating session host configuration for domainJointype: AAD, diskInfoType: $($disks[$k]), VM sizeID: $($VMSizes[$j])."
                Write-Host "Publisher: $publisher"
                Write-Host "SKU: $sku"
                Write-Host "Offer: $offer"
                Write-Host "Version: $version"

                Update-AzWvdSessionHostConfiguration -SubscriptionId $subID -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -DiskInfoType $disks[$k] -VMSizeId $VMSizes[$j] -DomainInfoJoinType 'AzureActiveDirectory' -ImageInfoType 'Marketplace' -MarketplaceInfoExactVersion $version -MarketplaceInfoOffer $offer -MarketplaceInfoPublisher $publisher -MarketplaceInfoSku $sku
                Update-AzWvdSessionHostManagement -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -SubscriptionId $SubID -UpdateLogOffDelayMinute "1" -UpdateLogOffMessage "logoff" -UpdateMaxVmsRemoved $vmRemove

                Write-Host "Initiating update now"
                Invoke-AzWvdInitiateSessionHostUpdate -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -SubscriptionId $subID -UpdateMaxVmsRemoved $vmRemove -UpdateDeleteOriginalVM
             }
             else {
                # Do AD
                #Schedule update in the future (+ 5 mins of current time)
                $currentTime = Get-Date
                $updatedTime = $currentTime.AddMinutes(5)
                $updatedTimeFormatted = $updatedTime.ToString("MM/dd/yyyy HH:mm tt")
                
                Write-Host "Updating session host configuration for domainJointype: AD, diskInfoType: $($disks[$k]), VM sizeID: $($VMSizes[$j])."
                Write-Host "Publisher: $publisher"
                Write-Host "SKU: $sku"
                Write-Host "Offer: $offer"
                Write-Host "Version: $version"
                Update-AzWvdSessionHostConfiguration -SubscriptionId $subID -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -DiskInfoType $disks[$k] -VMSizeId $VMSizes[$j] -DomainInfoJoinType 'ActiveDirectory' -ImageInfoType 'Marketplace' -MarketplaceInfoExactVersion $version -MarketplaceInfoOffer $offer -MarketplaceInfoPublisher $publisher -MarketplaceInfoSku $sku 
                Update-AzWvdSessionHostManagement -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -SubscriptionId $SubID -UpdateLogOffDelayMinute "1" -UpdateLogOffMessage "logoff" -UpdateMaxVmsRemoved $vmRemove
                
                Write-Host "Initiating update to be scheduled at $updatedTimeFormatted"

                Invoke-AzWvdInitiateSessionHostUpdate -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -SubscriptionId $subID -UpdateDeleteOriginalVM -ScheduledDateTime $updatedTimeFormatted
             }

             $UpdateStatus = Get-AzWvdSessionHostManagementsOperationStatus -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -SubscriptionId $subID -IsInitiatingOperation -IsLatest | fl Status | Out-String

             if($UpdateStatus.Contains("Succeeded")) {
                Write-Host "Update completed successfully" -ForegroundColor "Green"
             } 
             else {
                Write-Host "Update failed - please check and raise a bug if necessary" -ForegroundColor "Red"
             }
        }
    }
}

#Example
# $hostpoolName = "achre3"
# $ResourceGroupName = "akas1-rg"
# $subID = "a8a70c23-aed1-4555-885a-55e5bccf9d34"
# $NetworkInfoSubnetId = "/subscriptions/a8a70c23-aed1-4555-885a-55e5bccf9d34/resourceGroups/akas1-rg/providers/Microsoft.Network/virtualNetworks/akas1-rg-vnet/subnets/default"
# $VMPasswordSecretUri = " https://achpukv.vault.azure.net/secrets/vmpassword"
# $VMUsernameSecretUri = "https://achpukv.vault.azure.net/secrets/vmuser"
# $VMNamePrefix = "acvre3"
# $VMCount = 10;
# $VMLocation = "eastus"

# $hostpoolName = "acdjhte1"
# $ResourceGroupName = "akas1-rg"
# $subID = "0325dd32-ebf8-403e-86b0-365c7d3306d9"
# $NetworkInfoSubnetId = "/subscriptions/0325dd32-ebf8-403e-86b0-365c7d3306d9/resourceGroups/rdpgwcon/providers/Microsoft.Network/virtualNetworks/rdpgwcon-vnet-eus2/subnets/default"
# $VMPasswordSecretUri = " https://validkv.vault.azure.net/secrets/LocalVMPW"
# $VMUsernameSecretUri = "https://validkv.vault.azure.net/secrets/vmusername"
# $VMNamePrefix = "testvac1"
# $VMCount = 10;
# $VMLocation = "eastus2"
# $DomainJoinSecretUri = "https://validkv.vault.azure.net/secrets/DJPW"
# $DomainJoinUsernameUri = "https://validkv.vault.azure.net/secrets/DJUsername"

# .\HPMTestingWinServer.ps1 -HostPoolName $hostpoolName -SubID $subID -ResourceGroupName $ResourceGroupName -NetworkInfoSubnetId $NetworkInfoSubnetId -VMPasswordSecretUri $VMPasswordSecretUri -VMUsernameSecretUri $VMUsernameSecretUri -VMNamePrefix $VMNamePrefix -VMLocation $VMLocation -VMCount $VMCount -DomainJoinSecretUri $DomainJoinSecretUri -DomainJoinUsernameUri $DomainJoinUsernameUri 






