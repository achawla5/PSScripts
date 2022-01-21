Write-Host '*** WVD AIB CUSTOMIZER PHASE *** Timezone redirection ***'

$TimeZoneRegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
$TimeZoneRegName = "fEnableTimeZoneRedirection"
$TimeZoneRegValue = "1"

IF(!(Test-Path $registryPath)) {
    New-Item -Path $TimeZoneRegistryPath -Force | Out-Null
}

New-ItemProperty -Path $TimeZoneRegistryPath -Name $TimeZoneRegName -Value $value -PropertyType DWORD -Force | Out-Null
Write-Host '*** WVD AIB CUSTOMIZER PHASE *** Timezone redirection *** - Exit Code: '$LASTEXITCODE