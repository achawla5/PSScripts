Write-Host'*** WVD AIB CUSTOMIZER PHASE *** Screen capture protection ***'

$registryPath = "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
$name = "fEnableScreenCaptureProtection"
$value = "1"

IF(!(Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}

New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
Write-Host'*** WVD AIB CUSTOMIZER PHASE *** Screen capture protection *** - Exit Code: '$LASTEXITCODE