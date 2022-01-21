Write-Host '*** WVD AIB CUSTOMIZER PHASE *** Screen capture protection ***'

$screenCaptureRegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
$screenCaptureRegistryName = "fEnableScreenCaptureProtection"
$screenCaptureRegistryValue = "1"

IF(!(Test-Path $screenCaptureRegistryPath)) {
    New-Item -Path $screenCaptureRegistryPath -Force | Out-Null
}

New-ItemProperty -Path $screenCaptureRegistryPath -Name $screenCaptureRegistryName -Value $screenCaptureRegistryValue -PropertyType DWORD -Force | Out-Null
Write-Host '*** WVD AIB CUSTOMIZER PHASE *** Screen capture protection *** - Exit Code: '$LASTEXITCODE