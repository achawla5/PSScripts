$uusKey = "HKLM:\SYSTEM\CurrentControlSet\Control\FeatureManagement\Overrides\4\1931709068"
if (Test-Path $uusKey) {
    if ((Get-ItemProperty -Path $uusKey -Name 'EnabledState').EnabledState -ne 1) {
        Set-ItemProperty -Path $uusKey -Name 'EnabledState' -Value 1 -Force
    }
    Write-Host "UUS Feature override (1931709068) EnabledState changed to 1"
}