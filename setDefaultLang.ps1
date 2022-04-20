<#Author       : Akash Chawla
# Usage        : Set default language 
#>

#######################################
#    Set default Language             #
#######################################


[CmdletBinding()]
  Param (
        [Parameter(Mandatory)]
        [string]$language
)

function Set-DefaultLanguage($language) {

  BEGIN {

      $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
      Write-Host "*** Starting AVD AIB CUSTOMIZER PHASE: Set default Language ***"

      # Reference: https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-lcid/a9eac961-e77d-41a6-90a5-ce1a8b0cdb9c?redirectedfrom=MSDN
      # populate dictionary
      $languagesDict = @{}
      $languagesDict.Add("Arabic (Saudi Arabia)", "0x0401")
      $languagesDict.Add("Basque (Basque)", "0x042D")
      $languagesDict.Add("Bulgarian (Bulgaria)", "0x0402")
      $languagesDict.Add("Catalan", "0x0403")
      $languagesDict.Add("Chinese (Traditional, Hong Kong SAR)", "0x0C04")
      $languagesDict.Add("Chinese (Simplified, China)", "0x0804")
      $languagesDict.Add("Chinese (Traditional, Taiwan)", "0x0404")
      $languagesDict.Add("Croatian (Croatia)",	"0x041A")
      $languagesDict.Add("Czech (Czech Republic)",	"0x0405")
      $languagesDict.Add("Danish (Denmark)",	"0x0406")
      $languagesDict.Add("Dutch (Netherlands)",	"0x0413")
      $languagesDict.Add("English (United States)",	"0x0409")
      $languagesDict.Add("English (United Kingdom)",	"0x0809")
      $languagesDict.Add("Estonian (Estonia)",	"0x0425")
      $languagesDict.Add("Finnish (Finland)",	"0x040B")
      $languagesDict.Add("French (Canada)",	"0x0c0C")
      $languagesDict.Add("French (France)",	"0x040C")
      $languagesDict.Add("Galician",	"0x0056")
      $languagesDict.Add("German (Germany)",	"0x0407")
      $languagesDict.Add("Greek (Greece)",	"0x0408")
      $languagesDict.Add("Hebrew (Israel)",	"0x040D")
      $languagesDict.Add("Hungarian (Hungary)",	"0x040E")
      $languagesDict.Add("Indonesian (Indonesia)",	"0x0421")
      $languagesDict.Add("Italian (Italy)",	"0x0410")
      $languagesDict.Add("Japanese (Japan)",	"0x0411")
      $languagesDict.Add("Korean (Korea)",	"0x0412")
      $languagesDict.Add("Latvian (Latvia)",	"0x0426")
      $languagesDict.Add("Lithuanian (Lithuania)",	"0x0427")
      $languagesDict.Add("Norwegian, Bokmål (Norway)",	"0x0414")
      $languagesDict.Add("Polish (Poland)",	"0x0415")
      $languagesDict.Add("Portuguese (Brazil)",	"0x0416")
      $languagesDict.Add("Portuguese (Portugal)",	"0x0816")
      $languagesDict.Add("Romanian (Romania)",	"0x0418")
      $languagesDict.Add("Russian (Russia)",	"0x0419")
      $languagesDict.Add("Serbian (Latin, Serbia)",	"0x241A")
      $languagesDict.Add("Slovak (Slovakia)",	"0x041B")
      $languagesDict.Add("Slovenian (Slovenia)",	"0x0424")
      $languagesDict.Add("Spanish (Mexico)",	"0x080A")
      $languagesDict.Add("Spanish (Spain)",	"0x0c0A")
      $languagesDict.Add("Swedish (Sweden)",	"0x041D")
      $languagesDict.Add("Thai (Thailand)",	"0x041E")
      $languagesDict.Add("Turkish (Turkey)",	"0x041F")
      $languagesDict.Add("Ukrainian (Ukraine)",	"0x0422")
      $languagesDict.Add("Vietnamese",	"0x042A")

      $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\Language"
      $registryKey = "InstallLanguage"
      $registryValue = $languagesDict.$language 

      IF(!(Test-Path $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
      }
  }

  PROCESS {

      try {
        New-ItemProperty -Path $registryPath -Name $registryKey -Value $registryValue -PropertyType DWORD -Force | Out-Null
      }
      catch {
        Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Set default language - Cannot add the registry key *** : [$($_.Exception.Message)]"
        Write-Host "Message: [$($_.Exception.Message)"]
      }
  }

  END {
      $stopwatch.Stop()
      $elapsedTime = $stopwatch.Elapsed
      Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default language - Exit Code: $LASTEXITCODE ***"
      Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default language - Time taken: $elapsedTime ***"
  }
}

Set-DefaultLanguage -Language $language

#############
#    END    #
#############







