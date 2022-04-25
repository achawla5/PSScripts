<#Author       : Akash Chawla
# Usage        : Configure session timeouts
#>

#######################################
#   Configure session timeouts        #
#######################################


[CmdletBinding()]
  Param (
        [Parameter(
            Mandatory
        )]
        [string] $SessionTimeoutTypes
 )

 function ConvertToMilliSecond($timeInMinutes) {
    return (60 * 1000 * $timeInMinutes)
 }

 function Set-RegKey($registryPath, $registryKey, $registryValue) {
    try {
         New-ItemProperty -Path $registryPath -Name $registryKey -Value $registryValue -PropertyType DWORD -Force -ErrorAction Stop
    }
    catch {
         Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Configure session timeouts - Cannot add the registry key  $registryKey *** : [$($_.Exception.Message)]"
    }
 }

 function Set-SessionTimeout {

    BEGIN {
          
          $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
          $registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
          Write-host "Starting AVD AIB Customization: Configure session timeouts"

          IF(!(Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
          }

    }
    PROCESS {

        $SessionTimeoutsDictionary = ConvertFrom-StringData -StringData $SessionTimeoutTypes

        try {
            foreach($sessionTypes in $SessionTimeoutsDictionary.GetEnumerator()) {

                $sessionTypeName = $($sessionTypes.Name);
                $sessionTypeValue = $($sessionTypes.Value);

                if($sessionTypeName -eq "EndSessionAtTimeLimit") {

                    $registryKey = "fResetBroken"
                    $registryValue = "1"
                    Set-RegKey -registryPath $registryPath -registryKey $registryKey -registryValue $registryValue
                } else {

                    $registryValue = ConvertToMilliSecond -time $sessionTypeValue

                    switch($sessionTypeName) {
    
                        "DisconnectedSessions" {
                            $registryKey = "MaxDisconnectionTime"
                        }
    
                        "ActiveButIdleSessions" {
                            $registryKey = "MaxIdleTime"
                        }
    
                        "ActiveSessions" {
                            $registryKey = "MaxConnectionTime"
                        }
    
                        "LogOffSessions" {
                            $registryKey = "RemoteAppLogoffTimeLimit"

                        }
                    }

                    Set-RegKey -registryPath $registryPath -registryKey $registryKey -registryValue $registryValue
                }
            }
        }
        catch {
             Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Configure session timeouts - Error occured : [$($_.Exception.Message)]"
        } 
    }

    END {

        $stopwatch.Stop()
        $elapsedTime = $stopwatch.Elapsed
        Write-Host "*** AVD AIB CUSTOMIZER PHASE: Configure session timeouts - Exit Code: $LASTEXITCODE ***"
        Write-host "Ending AVD AIB Customization: Configure session timeouts - Time taken: $elapsedTime "
    }
 }

 Set-SessionTimeout -SessionTimeoutTypes $SessionTimeoutTypes

