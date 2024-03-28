write-host 'Customization:  Setting registry key'
New-Item -Path HKLM:\SOFTWARE\Microsoft -Name "Teams"
New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Teams -Name "IsWVDEnvironment" -Type "Dword" -Value "1" -Force
write-host 'Customization: Finished Set required regKey'


if (!(Test-Path "C:\Windows\CloudPC\")) 
{
    write-host 'Create CloudPC Folder'
    New-Item -path C:\Windows\CloudPC\ -ItemType directory
}

# Install Teams
write-host 'Customization: Install Teams Client'
set-Location $env:SystemRoot\CloudPC
write-host 'Downloading teamsbootstrapper.exe file'
Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?linkid=2243204&clcid=0x409' -Outfile $env:SystemRoot\CloudPC\teamsbootstrapper.exe -TimeoutSec 1000
write-host 'Downloading teams.msix file'
Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?linkid=2196106' -Outfile $env:SystemRoot\CloudPC\teams.msix -TimeoutSec 1000

# Install WebView2
try 
{
    $version = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}' -ErrorAction Stop).pv 
    if (-not $version)
    {
        write-host 'Downloading MicrosoftEdgeWebView2Setup.exe file'
        Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' -OutFile $env:SystemRoot\CloudPC\MicrosoftEdgeWebView2Setup.exe -TimeoutSec 1000
    }
    else 
    {
        write-host "EdgeWebView2 installed with $version"
    }
}
catch 
{
    write-host 'Downloading MicrosoftEdgeWebView2Setup.exe file'
    Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' -OutFile $env:SystemRoot\CloudPC\MicrosoftEdgeWebView2Setup.exe -TimeoutSec 1000
}

if ((Test-Path "C:\Windows\CloudPC\teamsbootstrapper.exe") -and (Test-Path "C:\Windows\CloudPC\teams.msix"))
{
    write-host 'Finished Downloading teamsbootstrapper.exe file '
    write-host 'Starting teamsbootstrapper.exe file'
    Start-Process -FilePath $env:SystemRoot\CloudPC\teamsbootstrapper.exe -ArgumentList "-p", "-o", $env:SystemRoot\CloudPC\teams.msix -Wait -NoNewWindow
}
else 
{
    write-host 'Failed Downloading teamsbootstrapper.exe file or teams.msix file'
}


if ((-not $version) -and (Test-Path "C:\Windows\CloudPC\MicrosoftEdgeWebView2Setup.exe"))
{
    write-host 'Finished Downloading MicrosoftEdgeWebView2Setup.exe file '
    write-host 'Starting MicrosoftEdgeWebView2Setup.exe file'
    Start-Process -FilePath $env:SystemRoot\CloudPC\MicrosoftEdgeWebView2Setup.exe -Wait -NoNewWindow
}
else 
{
    write-host 'Failed Downloading MicrosoftEdgeWebView2Setup.exe file '
}

write-host 'Customization: Finished Install Teams Client'