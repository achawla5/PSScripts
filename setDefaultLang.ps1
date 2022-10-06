<#Author       : Akash Chawla
# Usage        : Set default Language 
#>

#######################################
#    Set default Language             #
#######################################


[CmdletBinding()]
  Param (
        [Parameter(Mandatory)]
        [ValidateSet("Arabic (Saudi Arabia)","Bulgarian (Bulgaria)","Chinese (Simplified, China)","Chinese (Traditional, Taiwan)","Croatian (Croatia)","Czech (Czech Republic)","Danish (Denmark)","Dutch (Netherlands)", "English (United Kingdom)", "Estonian (Estonia)", "Finnish (Finland)", "French (Canada)", "French (France)", "German (Germany)", "Greek (Greece)", "Hebrew (Israel)", "Hungarian (Hungary)", "Italian (Italy)", "Japanese (Japan)", "Korean (Korea)", "Latvian (Latvia)", "Lithuanian (Lithuania)", "Norwegian, Bokmål (Norway)", "Polish (Poland)", "Portuguese (Brazil)", "Portuguese (Portugal)", "Romanian (Romania)", "Russian (Russia)", "Serbian (Latin, Serbia)", "Slovak (Slovakia)", "Slovenian (Slovenia)", "Spanish (Mexico)", "Spanish (Spain)", "Swedish (Sweden)", "Thai (Thailand)", "Turkish (Turkey)", "Ukrainian (Ukraine)")]
        [string]$Language
)

function Set-DefaultLanguage($Language) {

  BEGIN {

      $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
      Write-Host "*** Starting AVD AIB CUSTOMIZER PHASE: Set default Language ***"

      $templateFilePathFolder = "C:\AVDImage"
      # Reference: https://learn.microsoft.com/en-gb/powershell/module/languagepackmanagement/set-systempreferreduilanguage?view=windowsserver2022-ps
      # populate dictionary
      $LanguagesDictionary = @{}
      $LanguagesDictionary.Add("Arabic (Saudi Arabia)", "0x0401")
      $LanguagesDictionary.Add("Bulgarian (Bulgaria)", "0x0402")
      $LanguagesDictionary.Add("Chinese (Simplified, China)", "0x0804")
      $LanguagesDictionary.Add("Chinese (Traditional, Taiwan)", "0x0404")
      $LanguagesDictionary.Add("Croatian (Croatia)",	"0x041A")
      $LanguagesDictionary.Add("Czech (Czech Republic)",	"0x0405")
      $LanguagesDictionary.Add("Danish (Denmark)",	"0x0406")
      $LanguagesDictionary.Add("Dutch (Netherlands)",	"0x0413")
      $LanguagesDictionary.Add("English (United States)",	"0x0409")
      $LanguagesDictionary.Add("English (United Kingdom)",	"0x0809")
      $LanguagesDictionary.Add("Estonian (Estonia)",	"0x0425")
      $LanguagesDictionary.Add("Finnish (Finland)",	"0x040B")
      $LanguagesDictionary.Add("French (Canada)",	"0x0c0C")
      $LanguagesDictionary.Add("French (France)",	"0x040C")
      $LanguagesDictionary.Add("German (Germany)",	"0x0407")
      $LanguagesDictionary.Add("Greek (Greece)",	"0x0408")
      $LanguagesDictionary.Add("Hebrew (Israel)",	"0x040D")
      $LanguagesDictionary.Add("Hungarian (Hungary)",	"0x040E")
      $LanguagesDictionary.Add("Indonesian (Indonesia)",	"0x0421")
      $LanguagesDictionary.Add("Italian (Italy)",	"0x0410")
      $LanguagesDictionary.Add("Japanese (Japan)",	"0x0411")
      $LanguagesDictionary.Add("Korean (Korea)",	"0x0412")
      $LanguagesDictionary.Add("Latvian (Latvia)",	"0x0426")
      $LanguagesDictionary.Add("Lithuanian (Lithuania)",	"0x0427")
      $LanguagesDictionary.Add("Norwegian, Bokmål (Norway)",	"0x0414")
      $LanguagesDictionary.Add("Polish (Poland)",	"0x0415")
      $LanguagesDictionary.Add("Portuguese (Brazil)",	"0x0416")
      $LanguagesDictionary.Add("Portuguese (Portugal)",	"0x0816")
      $LanguagesDictionary.Add("Romanian (Romania)",	"0x0418")
      $LanguagesDictionary.Add("Russian (Russia)",	"0x0419")
      $LanguagesDictionary.Add("Serbian (Latin, Serbia)",	"0x241A")
      $LanguagesDictionary.Add("Slovak (Slovakia)",	"0x041B")
      $LanguagesDictionary.Add("Slovenian (Slovenia)",	"0x0424")
      $LanguagesDictionary.Add("Spanish (Mexico)",	"0x080A")
      $LanguagesDictionary.Add("Spanish (Spain)",	"0x0c0A")
      $LanguagesDictionary.Add("Swedish (Sweden)",	"0x041D")
      $LanguagesDictionary.Add("Thai (Thailand)",	"0x041E")
      $LanguagesDictionary.Add("Turkish (Turkey)",	"0x041F")
      $LanguagesDictionary.Add("Ukrainian (Ukraine)",	"0x0422")

      $LanguageTag = $LanguagesDictionary.$Language 
  }

  PROCESS {
      Set-SystemPreferredUILanguage -Language $LanguageTag
      Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - $Language has been set as the default System Preferred UI Language***"
  }

  END {

      if ((Test-Path -Path $templateFilePathFolder -ErrorAction SilentlyContinue)) {
          Remove-Item -Path $templateFilePathFolder -Force -Recurse -ErrorAction Continue
      }

      $stopwatch.Stop()
      $elapsedTime = $stopwatch.Elapsed
      Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - Exit Code: $LASTEXITCODE ***"
      Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - Time taken: $elapsedTime ***"
  }
}

Set-DefaultLanguage -Language $Language

#############
#    END    #
#############







