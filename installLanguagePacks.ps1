<#Author       : Akash Chawla
# Usage        : Install Language packs
#>

#######################################
#    Install language packs           #
#######################################


[CmdletBinding()]
  Param (
        [Parameter(
            Mandatory
        )]
        [System.String[]]$LanguageList,

        [Parameter(
            Mandatory
        )]
        [string]$WindowsVersion
    )

function Set-Assets($WindowsVersion, [ref] $langDrive, [ref] $fodPath, [ref] $inboxAppDrive, [ref] $LangPackPath) {

    Begin {
     
        # Set paths 

        $appName = 'languagePacks'
        $drive = 'C:\'
        New-Item -Path $drive -Name $appName -ItemType Directory -ErrorAction SilentlyContinue
        $LocalPath = $drive + $appName
        Set-Location $LocalPath

        $langIsoUrlIso = 'LanguagePack.iso'
        $fodIsoUrlIso = 'FOD.iso'
        $inboxAppsIsoUrlIso = 'InboxApps.iso'

       
        $langOutputPath = $LocalPath + '\' + $langIsoUrlIso
        $fodOutputPath = $LocalPath + '\' + $fodIsoUrlIso
        $inboxAppsOutputPath = $LocalPath + '\' + $inboxAppsIsoUrlIso
    }

    Process {

        # Windows 11
        if($WindowsVersion -eq "Windows 11") {
        
            $langIsoUrl = 'https://software-download.microsoft.com/download/sg/22000.1.210604-1628.co_release_amd64fre_CLIENT_LOF_PACKAGES_OEM.iso'
            $inboxAppsIsoUrl = 'https://software-download.microsoft.com/download/pr/22000.194.210911-1543.co_release_svc_prod1_amd64fre_InboxApps.iso'

            # Starting ISO downloads
            Invoke-WebRequest -Uri $langIsoUrl -OutFile $langOutputPath
            Write-host "AVD AIB Customization: Finished Download for Language ISO for $WindowsVersion : $((Get-Date).ToUniversalTime()) "

            # Mount ISOs
            $langMount = Mount-DiskImage -ImagePath $langOutputPath
            
            $langDrive.Value = ($langMount | Get-Volume).DriveLetter+":"
            $LangPackPath.Value = $langDrive.Value+"\LanguagesAndOptionalFeatures"
            $fodPath.Value = $langDrive.Value+"\LanguagesAndOptionalFeatures"
        }  
        # Windows 10 - supported versions: 1903, 1909, 2004 (20H1), 20H2, 21H1, 21H2
        else {
        
            if($WindowsVersion -eq "Windows 10 - 1903" -or $WindowsVersion -eq "Windows 10 - 1909") {
 
                $langIsoUrl = 'https://software-download.microsoft.com/download/pr/18362.1.190318-1202.19h1_release_CLIENTLANGPACKDVD_OEM_MULTI.iso'
                $fodIsoUrl = 'https://software-download.microsoft.com/download/pr/18362.1.190318-1202.19h1_release_amd64fre_FOD-PACKAGES_OEM_PT1_amd64fre_MULTI.iso'
                $inboxAppsIsoUrl = 'https://software-download.microsoft.com/download/pr/18362.1.190318-1202.19h1_release_amd64fre_InboxApps.iso'
            } 

            else {

                 $langIsoUrl = 'https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_CLIENTLANGPACKDVD_OEM_MULTI.iso'
                 $fodIsoUrl = 'https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_amd64fre_FOD-PACKAGES_OEM_PT1_amd64fre_MULTI.iso'

                  if($WindowsVersion -eq "Windows 10 - 20H1") {

                        $inboxAppsIsoUrl = 'https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_amd64fre_InboxApps.iso'

                   } elseif ($WindowsVersion -eq "Windows 10 - 20H2") {

                        $inboxAppsIsoUrl = 'https://software-download.microsoft.com/download/pr/19041.508.200905-1327.vb_release_svc_prod1_amd64fre_InboxApps.iso'
        
                   } elseif ($WindowsVersion -eq "Windows 10 - 21H1" -or $WindowsVersion -eq "Windows 10 - 21H2") {
        
                        $inboxAppsIsoUrl = 'https://software-download.microsoft.com/download/sg/19041.928.210407-2138.vb_release_svc_prod1_amd64fre_InboxApps.iso'
                   } 
            } 

            # Starting ISO downloads
            Invoke-WebRequest -Uri $langIsoUrl -OutFile $langOutputPath
            Write-host "AVD AIB Customization: Finished Download for Language ISO for $WindowsVersion : $((Get-Date).ToUniversalTime()) "

            Invoke-WebRequest -Uri $fodIsoUrl -OutFile $fodOutputPath
            Write-host "AIB Customization: Finished Download for Feature on Demand (FOD) Disk 1 for $WindowsVersion : $((Get-Date).ToUniversalTime()) " 

            $langMount = Mount-DiskImage -ImagePath $langOutputPath
            $fodMount = Mount-DiskImage -ImagePath $fodOutputPath

            $langDrive.Value = ($langMount | Get-Volume).DriveLetter+":"
            $fodPath.Value = ($fodMount | Get-Volume).DriveLetter+":"
            $LangPackPath.Value = $langDrive.Value+"\x64\langpacks"

        }

        Invoke-WebRequest -Uri $inboxAppsIsoUrl -OutFile $inboxAppsOutputPath
        Write-host "AIB Customization: Finished Download for Inbox Apps for $WindowsVersion : $((Get-Date).ToUniversalTime()) " 

        $inboxAppsMount = Mount-DiskImage -ImagePath $inboxAppsOutputPath
        $inboxAppDrive.Value = ($inboxAppsMount | Get-Volume).DriveLetter+":"
    }

    End {

    }
    

}

function Install-LanguagePack {
  
   
    <#
    .SYNOPSIS
    Function to install language packs along with features on demand and inbox apps

    .DESCRIPTION
    Based on the language parameter, this function installs language packs along with the necessary features on demand (FOD) and inbox apps. Not all FODs are available for each language - this function
    will install the FODs based on the mapping here: https://raw.githubusercontent.com/achawla5/PSScripts/main/Windows-10-1809-FOD-to-LP-Mapping-Table.csv

    // add supported languages

    // add examples
    .EXAMPLE
    

    #>

    BEGIN {
        
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        Write-host "Starting AVD AIB Customization: Install Language packs: $((Get-Date).ToUniversalTime()) "
        
        # Disable Language Pack Cleanup
        Disable-ScheduledTask -TaskPath "\Microsoft\Windows\AppxDeploymentClient\" -TaskName "Pre-staged app cleanup" | Out-Null

        $fodPath = ""
        $langDrive = ""
        $LangPackPath = ""
        $inboxAppDrive = ""

        Set-Assets -WindowsVersion ($WindowsVersion) -langDrive ([ref] $langDrive) -fodPath ([ref] $fodPath) -langPackPath ([ref] $LangPackPath) -inboxAppDrive ([ref] $inboxAppDrive)

        #$langPackPath = "H:\x64\langpacks"
        #$fodPath = "F:"
        #$inboxAppDrive = "G:"
        
        Invoke-WebRequest https://raw.githubusercontent.com/achawla5/PSScripts/main/Windows-10-1809-FOD-to-LP-Mapping-Table.csv  -OutFile .\LPtoFODFile.csv

        $LPtoFODFile = ".\LPtoFODFile.csv"

        #Check for Language mapping file
        if (-not (Test-Path $LPtoFODFile )) {
            Write-Error "Could not validate that $LPtoFODFile file exists in this location"
            exit
        }

        $LPtoFODMapping = Import-Csv $LPtoFODFile

         # populate dictionary
         $LanguagesDictionary = @{}
         $LanguagesDictionary.Add("Arabic (Saudi Arabia)", "ar-SA")
         $LanguagesDictionary.Add("Bulgarian (Bulgaria)", "bg-BG")
         $LanguagesDictionary.Add("Chinese (Simplified, China)", "zh-CN")
         $LanguagesDictionary.Add("Chinese (Traditional, Taiwan)", "zh-TW")
         $LanguagesDictionary.Add("Croatian (Croatia)",	"hr-HR")
         $LanguagesDictionary.Add("Czech (Czech Republic)",	"cs-CZ")
         $LanguagesDictionary.Add("Danish (Denmark)",	"da-DK")
         $LanguagesDictionary.Add("Dutch (Netherlands)",	"nl-NL")
         $LanguagesDictionary.Add("English (United States)",	"en-US")
         $LanguagesDictionary.Add("English (United Kingdom)",	"en-GB")
         $LanguagesDictionary.Add("Estonian (Estonia)",	"et-EE")
         $LanguagesDictionary.Add("Finnish (Finland)",	"fi-FI")
         $LanguagesDictionary.Add("French (Canada)",	"fr-CA")
         $LanguagesDictionary.Add("French (France)",	"fr-FR")
         $LanguagesDictionary.Add("German (Germany)",	"de-DE")
         $LanguagesDictionary.Add("Greek (Greece)",	"el-GR")
         $LanguagesDictionary.Add("Hebrew (Israel)",	"he-IL")
         $LanguagesDictionary.Add("Hungarian (Hungary)",	"hu-HU")
         $LanguagesDictionary.Add("Indonesian (Indonesia)",	"id-ID")
         $LanguagesDictionary.Add("Italian (Italy)",	"it-IT")
         $LanguagesDictionary.Add("Japanese (Japan)",	"ja-JP")
         $LanguagesDictionary.Add("Korean (Korea)",	"ko-KR")
         $LanguagesDictionary.Add("Latvian (Latvia)",	"lv-LV")
         $LanguagesDictionary.Add("Lithuanian (Lithuania)",	"lt-LT")
         $LanguagesDictionary.Add("Norwegian, Bokmål (Norway)",	"nb-NO")
         $LanguagesDictionary.Add("Polish (Poland)",	"pl-PL")
         $LanguagesDictionary.Add("Portuguese (Brazil)",	"pt-BR")
         $LanguagesDictionary.Add("Portuguese (Portugal)",	"pt-PT")
         $LanguagesDictionary.Add("Romanian (Romania)",	"ro-RO")
         $LanguagesDictionary.Add("Russian (Russia)",	"ru-RU")
         $LanguagesDictionary.Add("Serbian (Latin, Serbia)",	"sr-Latn-RS")
         $LanguagesDictionary.Add("Slovak (Slovakia)",	"sk-SK")
         $LanguagesDictionary.Add("Slovenian (Slovenia)",	"sl-SI")
         $LanguagesDictionary.Add("Spanish (Mexico)",	"es-MX")
         $LanguagesDictionary.Add("Spanish (Spain)",	"es-ES")
         $LanguagesDictionary.Add("Swedish (Sweden)",	"sv-SE")
         $LanguagesDictionary.Add("Thai (Thailand)",	"th-TH")
         $LanguagesDictionary.Add("Turkish (Turkey)",	"tr-TR")
         $LanguagesDictionary.Add("Ukrainian (Ukraine)",	"uk-UA")

    } # Begin
    PROCESS {

        foreach ($Language in $LanguageList) {

            $LanguageCode =  $LanguagesDictionary.$Language
            
            $LanguagePackPath = "$LangPackPath\Microsoft-Windows-Client-Language-Pack_x64_$LanguageCode.cab"

            try {
                Add-WindowsPackage -Online -PackagePath $LanguagePackPath -NoRestart -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
            }
            catch {
                Write-Host "AVD AIB Customization : Exception occured with language pack: $LanguagePackPath - [$($_.Exception.Message)]"
                continue
            }
            
            $FeaturesList = $LPtoFODMapping | Where-Object { $_.'Target Lang' -eq $LanguageCode }

            #From the Features On Demand iso

            if (($FeaturesList | Measure-Object).Count -ne 0){
                foreach ($file in $FeaturesList.'Cab Name') {
                    $filePath = Get-ChildItem (Join-Path $fodPath $file.replace('.cab', '*.cab'))
    
                    if ($null -eq $filePath) {
                        Write-Host "AVD AIB Customization : Could not find $filePath"
                        break
                    }
    
                    try {
                        $PackageName = $filePath.FullName
                        Add-WindowsPackage -Online -PackagePath $PackageName -NoRestart -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
                    }
                    catch {
                        Write-Host "AVD AIB Customization : Exception occured while adding package $PackageName : [$($_.Exception.Message)]"
                        continue
                    }
                }
            }

            # Update Inbox Apps
            # reference https://docs.microsoft.com/en-us/azure/virtual-desktop/language-packs
            $inboxAppPath = $inboxAppDrive + "\amd64fre\"
            foreach ($App in (Get-AppxProvisionedPackage -Online)) {
                $AppPath = $inboxAppPath + $App.DisplayName + '_' + $App.PublisherId
                $licFile = Get-Item $AppPath*.xml

                try {
                    if ($licFile.Count) {
                        $lic = $true
                        $licFilePath = $licFile.FullName
                    } else {
                        $lic = $false
                    }
                    $appxFile = Get-Item $AppPath*.appx*
                    if ($appxFile.Count) {
                        $appxFilePath = $appxFile.FullName
                        if ($lic) {
                            Add-AppxProvisionedPackage -Online -PackagePath $appxFilePath -LicensePath $licFilePath -ErrorAction Stop
                        } else {
                            Add-AppxProvisionedPackage -Online -PackagePath $appxFilePath -skiplicense -ErrorAction Stop
                        }
                    }        
                }
                catch {
                    Write-Host "AVD AIB Customization : Exception occured with inbox app package: $AppPath - [$($_.Exception.Message)]"
                    continue;
                }
            }
        }
    } #Process
    END {

        $stopwatch.Stop()
        $elapsedTime = $stopwatch.Elapsed
        Write-Host "*** AVD AIB CUSTOMIZER PHASE : Install language packs -  Exit Code: $LASTEXITCODE ***"    
        Write-Host "Ending AVD AIB Customization : Install language packs - Time taken: $elapsedTime"
    } 
}

 Install-LanguagePack -LanguageList $LanguageList -WindowsVersion $WindowsVersion 