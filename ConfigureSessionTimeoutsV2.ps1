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
        [string[]] $SessionTimeoutTypes,

        [Parameter(
            Mandatory
        )]
        [string[]] $SessionTimeoutValues
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

        $SessionTimeoutsDictionary = @{}

        for($i = 0; $i -lt $SessionTimeoutTypes.Count; $i++) {

                $SessionTimeoutKey = $SessionTimeoutTypes[$i]
                $SessionTimeoutValue = $SessionTimeoutValues[$i]

                if(!($SessionTimeoutsDictionary.ContainsKey($SessionTimeoutKey))) {
                    $SessionTimeoutsDictionary.Add( $SessionTimeoutKey,  $SessionTimeoutValue)
                } 
        }

        try {
            foreach($sessionTypes in $SessionTimeoutsDictionary.GetEnumerator()) {

                $sessionTypeName = $($sessionTypes.Name);
                $sessionTypeValue = $($sessionTypes.Value);

                Write-Host "AVD AIB CUSTOMIZER PHASE - Configure session timeouts: Request to configure session type $sessionTypeName with value $sessionTypeValue"

                if($sessionTypeName -eq "End session when time limits are reached") {
                    $registryKey = "fResetBroken"
                    $registryValue = "1"
                    Set-RegKey -registryPath $registryPath -registryKey $registryKey -registryValue $registryValue
                } else {

                    $registryValue = ConvertToMilliSecond -time $sessionTypeValue

                    switch($sessionTypeName) {
    
                        "Set time limit for disconnected sessions" {
                            $registryKey = "MaxDisconnectionTime"
                        }
    
                        "Set time limit for active but idle Remote Desktop Services sessions" {
                            $registryKey = "MaxIdleTime"
                        }
    
                        "Set time limit for active Remote Desktop Services sessions" {
                            $registryKey = "MaxConnectionTime"
                        }
    
                        "Set time limit for logoff of RemoteApp sessions" {
                            $registryKey = "RemoteAppLogoffTimeLimit"

                        }
                        default {
                            Write-Host "AVD AIB CUSTOMIZER PHASE - Configure session timeouts: Invalid parameter for session type"
                        }
                    }

                    if($null -ne $registryKey) {
                        Set-RegKey -registryPath $registryPath -registryKey $registryKey -registryValue $registryValue
                    }

                    # resetting the registry key and value for the next iteration
                    $registryKey = $null
                    $registryValue = $null
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

