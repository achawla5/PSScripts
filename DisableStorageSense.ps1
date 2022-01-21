Write-Host'*** WVD AIB CUSTOMIZER PHASE *** Disable Storage Sense ***'

$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense"
$name = "AllowStorageSenseGlobal"
$value = "0"

IF(!(Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}

New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
Write-Host'*** WVD AIB CUSTOMIZER PHASE *** Disable Storage Sense *** - Exit Code: '$LASTEXITCODE