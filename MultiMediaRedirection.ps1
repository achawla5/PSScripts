<#Author       : Akash Chawla
# Usage        : Install and enable multimedia redirection
#>

###########################################################
#      Install and enable multimedia redirection         #
###########################################################

# Install Edge
# Install Chrome
# Install Visual C++ Redistributable
# Install host component
# Install browser extension

[CmdletBinding()] Param (
    [Parameter(
        Mandatory
    )]
    [string]$VCRedistributableLink,

    [Parameter(
        Mandatory
    )]
    [bool]$EnableEdge,

    [Parameter(
        Mandatory
    )]
    [bool]$EnableChrome
)

function InstallAndEnableMMR($VCRedistributableLink, $EnableChrome, $EnableEdge) {
   
        Begin {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $templateFilePathFolder = "C:\AVDImage"
            Write-host "Starting AVD AIB Customization: MultiMedia Redirection: $((Get-Date).ToUniversalTime()) "

            $guid = [guid]::NewGuid().Guid
            $tempFolder = (Join-Path -Path "C:\temp\" -ChildPath $guid)

            if (!(Test-Path -Path $tempFolder)) {
                New-Item -Path $tempFolder -ItemType Directory
            }

            $mmrHostUrl = "https://aka.ms/avdmmr/msi"
            $mmrExePath = Join-Path -Path $tempFolder -ChildPath "mmrtool.msi"
        }

        Process {
            
            try {     
                # Set reg key while the feature is in preview

                New-Item -Path "HKLM:\SOFTWARE\Microsoft\MSRDC\Policies" -Force
                New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\MSRDC\Policies" -Name ReleaseRing -PropertyType String -Value insider -Force
                
                # Install the latest version of the Microsoft Visual C++ Redistributable
                Write-host "AVD AIB Customization:  MultiMedia Redirection - Starting the installation of provided Microsoft Visual C++ Redistributable"
                $appName = 'mmr'
                $drive = 'C:\'
                New-Item -Path $drive -Name $appName  -ItemType Directory -ErrorAction SilentlyContinue
                $LocalPath = $drive + '\' + $appName 
                Set-Location $LocalPath
                $VCRedistExe = 'vc_redist.x64.exe'
                $outputPath = $LocalPath + '\' + $VCRedistExe
                Invoke-WebRequest -Uri $VCRedistributableLink -OutFile $outputPath
                Start-Process -FilePath $outputPath -Args "/install /quiet /norestart /log vcdist.log" -Wait
                Write-host "AVD AIB Customization: MultiMedia Redirection - Finished the installation of provided Microsoft Visual C++ Redistributable"

                #Install the host component
                Write-host "AVD AIB Customization:  MultiMedia Redirection - Starting the installation of host component"
                Write-Host "AVD AIB Customization:  MultiMedia Redirection - Downloading MMR host into folder $mmrExePath"
                $mmrHostResponse = Invoke-WebRequest -Uri "$mmrHostUrl" -UseBasicParsing -UseDefaultCredentials -OutFile $mmrExePath -PassThru

                if ($mmrHostResponse.StatusCode -ne 200) { 
                    throw "MMR host failed to download -- Response $($mmrHostResponse.StatusCode) ($($mmrHostResponse.StatusDescription))"
                }

                msiexec.exe /i $mmrExePath /q
                Write-Host "AVD AIB Customization:  MultiMedia Redirection - Finished installing the mmr host agent"

                #Install Edge and enable extension

                Write-host "AVD AIB Customization:  MultiMedia Redirection - Checking if Microsoft Edge is installed"
                # $edgePackage = Get-AppxPackage -Name "*Edge*"

                # if([string]::IsNullOrEmpty($edgePackage)) {
                #      Write-host "AVD AIB Customization:  MultiMedia Redirection - Microsoft Edge is not installed - Installing latest version of Microsoft Edge"

                # }
                if($EnableEdge) {
                    $registryValue = '{ "joeclbldhdmoijbaagobkhlpfjglcihd": { "installation_mode": "force_installed", "update_url": "https://edge.microsoft.com/extensionwebstorebase/v1/crx" } }';
                    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Force
                    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name ExtensionSettings -PropertyType String -Value $registryValue -Force  
                    Write-host "AVD AIB Customization:  MultiMedia Redirection - Finished enabling extension for Microsoft Edge" 
                }

                if($EnableChrome) {
                     #Install Chrome and enable extension
                    Write-host "AVD AIB Customization:  MultiMedia Redirection - Checking if Google Chrome is installed"

                    try {
                        $chrome = $(Get-Package -Name "Google Chrome")
                    }
                    catch {
                        Write-host "AVD AIB Customization:  MultiMedia Redirection - Google Chrome is not installed"
                    }

                    if([string]::IsNullOrEmpty($chrome)) {
                        Write-host "AVD AIB Customization:  MultiMedia Redirection - Installing latest version of chrome"
                        $chromeInstallerPath = Join-Path -Path $tempFolder -ChildPath "chromeInstaller.exe"
                        $chromeResponse = Invoke-WebRequest "https://dl.google.com/chrome/install/latest/chrome_installer.exe" -UseBasicParsing -UseDefaultCredentials -OutFile $chromeInstallerPath -PassThru

                        if ($chromeResponse.StatusCode -ne 200) { 
                            throw "Google chrome failed to download -- Response $($chromeResponse.StatusCode) ($($chromeResponse.StatusDescription))"
                        }

                        Start-Process -FilePath $chromeInstallerPath -Args "/silent /install" -Verb RunAs -Wait
                        Write-host "AVD AIB Customization:  MultiMedia Redirection - Finished installing Google Chrome"
                    }

                    $registryValue = '{ "lfmemoeeciijgkjkgbgikoonlkabmlno": { "installation_mode": "force_installed", "update_url": "https://clients2.google.com/service/update2/crx" } }';
                    New-Item -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Force
                    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name ExtensionSettings -PropertyType String -Value $registryValue -Force

                    Write-host "AVD AIB Customization:  MultiMedia Redirection - Finished enabling extension for Google Chrome"
                }
            }
            catch {
                Write-Host "*** AVD AIB CUSTOMIZER PHASE ***   MultiMedia Redirection  - Exception occured  *** : [$($_.Exception.Message)]"
            }    
        }
        
        End {

            #Cleanup
            if ((Test-Path -Path $templateFilePathFolder -ErrorAction SilentlyContinue)) {
                Remove-Item -Path $templateFilePathFolder -Force -Recurse -ErrorAction Continue
            }

            if ((Test-Path -Path $tempFolder -ErrorAction SilentlyContinue)) {
                Remove-Item -Path $tempFolder -Force -Recurse -ErrorAction Continue
            }
    
            $stopwatch.Stop()
            $elapsedTime = $stopwatch.Elapsed
            Write-Host "*** AVD AIB CUSTOMIZER PHASE :  MultiMedia Redirection -  Exit Code: $LASTEXITCODE ***"    
            Write-Host "Ending AVD AIB Customization :  MultiMedia Redirection - Time taken: $elapsedTime"
        }
 }

function Set-RegKey($registryPath, $registryKey, $registryValue) {
    try {
         Write-Host "*** AVD AIB CUSTOMIZER PHASE ***  Teams Optimization  - Setting  $registryKey with value $registryValue ***"
         New-ItemProperty -Path $registryPath -Name $registryKey -Value $registryValue -PropertyType DWORD -Force -ErrorAction Stop
    }
    catch {
         Write-Host "*** AVD AIB CUSTOMIZER PHASE ***  Teams Optimization  - Cannot add the registry key  $registryKey *** : [$($_.Exception.Message)]"
    }
 }

InstallAndEnableMMR -VCRedistributableLink $VCRedistributableLink -EnableChrome $EnableChrome -EnableEdge $EnableEdge