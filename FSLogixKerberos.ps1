Write-Host '*** WVD AIB CUSTOMIZER PHASE *** Access to Azure File shares for FSLogix profiles ***'

# Enable Azure AD Kerberos

Write-Host '*** WVD AIB CUSTOMIZER PHASE *** Enable Azure AD Kerberos ***'
$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters"
$name = "CloudKerberosTicketRetrievalEnabled"
$value = "1"

IF(!(Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}

New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null

# Create new reg key "LoadCredKey"
 
Write-Host '*** WVD AIB CUSTOMIZER PHASE *** Create new reg key LoadCredKey ***'

$LoadCredRegPath = "HKLM:\Software\Policies\Microsoft\AzureADAccount"
$LoadCredName = "LoadCredKeyFromProfile"
$LoadCredValue = "1"

IF(!(Test-Path $LoadCredRegPath)) {
     New-Item -Path $LoadCredRegPath -Force | Out-Null
}

New-ItemProperty -Path $LoadCredRegPath -Name $LoadCredName -Value $LoadCredValue -PropertyType DWORD -Force | Out-Null

Write-Host '*** WVD AIB CUSTOMIZER PHASE *** Access to Azure File shares for FSLogix profiles *** - Exit Code: '$LASTEXITCODE








