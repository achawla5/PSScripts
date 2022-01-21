# Reference: https://docs.microsoft.com/en-us/azure/virtual-desktop/shortpath
write-host 'AIB Customization: Configure RDP shortpath and Windows Defender Firewall'

# rdp shortpath reg key
$WinstationsKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations'

IF(!(Test-Path $WinstationsKey)) {
    New-Item -Path $WinstationsKey -Force | Out-Null
}

New-ItemProperty -Path $WinstationsKey -Name 'fUseUdpPortRedirector' -ErrorAction:SilentlyContinue -PropertyType:dword -Value 1 -Force | Out-Null
New-ItemProperty -Path $WinstationsKey -Name 'UdpPortNumber' -ErrorAction:SilentlyContinue -PropertyType:dword -Value 3390 -Force | Out-Null

# set up windows defender firewall

try {
    New-NetFirewallRule -DisplayName 'Remote Desktop - Shortpath (UDP-In)'  -Action Allow -Description 'Inbound rule for the Remote Desktop service to allow RDP traffic. [UDP 3390]' -Group '@FirewallAPI.dll,-28752' -Name 'RemoteDesktop-UserMode-In-Shortpath-UDP'  -PolicyStore PersistentStore -Profile Domain, Private -Service TermService -Protocol udp -LocalPort 3390 -Program '%SystemRoot%\system32\svchost.exe' -Enabled:True
}
catch {
    Write-Host '*** WVD AIB CUSTOMIZER PHASE *** Cannot create firewall rule ***'
    Write-Host "Message: [$($_.Exception.Message)"]
}
 
Write-Host '*** WVD AIB CUSTOMIZER PHASE *** Configure RDP shortpath and Windows Defender Firewall *** - Exit Code: '$LASTEXITCODE
