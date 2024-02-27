 <#Author       : Akash Chawla
# Usage        : Teams Optimization
#>

#######################################
#    Teams Optimization               #
#######################################

# Reference: https://learn.microsoft.com/en-us/azure/virtual-desktop/teams-on-avd

[CmdletBinding()]
  Param (
        [Parameter()]
        [string]$TeamsBootStrapperUrl = "https://go.microsoft.com/fwlink/?linkid=2243204&clcid=0x409",

        [Parameter()]
        [string]$VCRedistributableLink = "https://aka.ms/vs/17/release/vc_redist.x64.exe",

        [Parameter()]
        [string]$WebRTCInstaller = "https://aka.ms/msrdcwebrtcsvc/msi",

        [Parameter()]
        [string]$TeamMsixPackageUrl = "https://go.microsoft.com/fwlink/?linkid=2196106"
)
 
 function InstallTeamsOptimizationforAVD($TeamsBootStrapperUrl, $VCRedistributableLink, $WebRTCInstaller, $TeamsMsixPackageUrl) {
   
        Begin {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $templateFilePathFolder = "C:\AVDImage"
            Write-host "Starting AVD AIB Customization: Teams Optimization : $((Get-Date).ToUniversalTime()) "

            $guid = [guid]::NewGuid().Guid
            $tempFolder = (Join-Path -Path "C:\temp\" -ChildPath $guid)

            if (!(Test-Path -Path $tempFolder)) {
                New-Item -Path $tempFolder -ItemType Directory
            }
    
            Write-Host "AVD AIB Customization: Teams Optimization: Created temp folder $tempFolder"
        }

        Process {
            
            try {     
                # Set reg key
                New-Item -Path HKLM:\SOFTWARE\Microsoft -Name "Teams" 
                $registryPath = "HKLM:\SOFTWARE\Microsoft\Teams"
                $registryKey = "IsWVDEnvironment"
                $registryValue = "1"
                Set-RegKey -registryPath $registryPath -registryKey $registryKey -registryValue $registryValue 
                
                # Install the latest version of the Microsoft Visual C++ Redistributable
                Write-host "AVD AIB Customization: Teams Optimization - Starting the installation of latest Microsoft Visual C++ Redistributable"
                $appName = 'teams'
                New-Item -Path $tempFolder -Name $appName  -ItemType Directory -ErrorAction SilentlyContinue

                $LocalPath = $tempFolder + '\' + $appName 
                Set-Location $LocalPath
                $VCRedistExe = 'vc_redist.x64.exe'
                $outputPath = $LocalPath + '\' + $VCRedistExe
                Invoke-WebRequest -Uri $VCRedistributableLink -OutFile $outputPath
                Start-Process -FilePath $outputPath -Args "/install /quiet /norestart /log vcdist.log" -Wait
                Write-host "AVD AIB Customization: Teams Optimization - Finished the installation of latest Microsoft Visual C++ Redistributable"

                # Install the Remote Desktop WebRTC Redirector Service
                $webRTCMSI = 'webSocketSvc.msi'
                $outputPath = $LocalPath + '\' + $webRTCMSI
                Invoke-WebRequest -Uri $WebRTCInstaller -OutFile $outputPath
                Start-Process -FilePath msiexec.exe -Args "/I $outputPath /quiet /norestart /log webSocket.log" -Wait
                Write-host "AVD AIB Customization: Teams Optimization - Finished the installation of the Teams WebSocket Service"

                #Install Teams
                $teamsBootStrapperPath = Join-Path -Path $LocalPath -ChildPath 'teamsbootstrapper.exe'
                Invoke-WebRequest -Uri $TeamsBootStrapperUrl -OutFile $teamsBootStrapperPath

                $msixPackagePath = Join-Path -Path $LocalPath -ChildPath 'teams.msix'
                Invoke-WebRequest -Uri $TeamMsixPackageUrl -OutFile $msixPackagePath

                $process = Start-Process -FilePath $teamsBootStrapperPath -ArgumentList "-p", "-o", $msixPackagePath -Wait -NoNewWindow
                $exitCode = $process.ExitCode

                Write-Host "Exit Code: $exitCode"
                Write-host "AVD AIB Customization: Teams Optimization - Finished installation of Teams"
            }
            catch {
                Write-Host "*** AVD AIB CUSTOMIZER PHASE ***  Teams Optimization  - Exception occured  *** : [$($_.Exception.Message)]"
            }    
        }
        
        End {

            #Cleanup
            if ((Test-Path -Path $templateFilePathFolder -ErrorAction SilentlyContinue)) {
                Remove-Item -Path $templateFilePathFolder -Force -Recurse -ErrorAction Continue
            }
    
            $stopwatch.Stop()
            $elapsedTime = $stopwatch.Elapsed
            Write-Host "*** AVD AIB CUSTOMIZER PHASE : Teams Optimization -  Exit Code: $LASTEXITCODE ***"    
            Write-Host "Ending AVD AIB Customization : Teams Optimization - Time taken: $elapsedTime"
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

InstallTeamsOptimizationforAVD -TeamsBootStrapperUrl $TeamsBootStrapperUrl -VCRedistributableLink $VCRedistributableLink -WebRTCInstaller $WebRTCInstaller -TeamsMsixPackageUrl $TeamMsixPackageUrl

 