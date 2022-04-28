<#Author       : Akash Chawla
# Usage        : Remove Appx Packages
#>

#######################################
#   Remove Appx Packages        #######
#######################################


[CmdletBinding()]
  Param (
        [Parameter(
            Mandatory
        )]
        [System.String[]] $AppxPackages
 )

 function Remove-AppxPackage($AppxPackages) {
   
        Foreach ($App in $AppxPackages) {
            try {                
                #Write-EventLog -EventId 20 -Message "Removing Provisioned Package $App" -LogName 'Virtual Desktop Optimization' -Source 'AppxPackages' -EntryType Information 
                Write-Host "Removing Provisioned Package $($App)"
                Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like ("*{0}*" -f $App) } | Remove-AppxProvisionedPackage -Online -ErrorAction Ignore | Out-Null
                        
                #Write-EventLog -EventId 20 -Message "Attempting to remove [All Users] $($App) - $($App.Description)" -LogName 'Virtual Desktop Optimization' -Source 'AppxPackages' -EntryType Information 
                Write-Host "Attempting to remove [All Users] $App "
                Get-AppxPackage -AllUsers -Name ("*{0}*" -f $App) | Remove-AppxPackage -AllUsers -ErrorAction Ignore
                        
                #Write-EventLog -EventId 20 -Message "Attempting to remove $App " -LogName 'Virtual Desktop Optimization' -Source 'AppxPackages' -EntryType Information 
                Write-Host "Attempting to remove $App for this user "
                Get-AppxPackage -Name ("*{0}*" -f $App) | Remove-AppxPackage -ErrorAction Ignore | Out-Null
            }
            catch {
                #Write-EventLog -EventId 120 -Message "Failed to remove Appx Package $($App) - $($_.Exception.Message)" -LogName 'Virtual Desktop Optimization' -Source 'AppxPackages' -EntryType Error 
                Write-Host "Failed to remove Appx Package $App - $($_.Exception.Message)"
            }
        }
 }

 Remove-AppxPackage -AppxPackages $AppxPackages