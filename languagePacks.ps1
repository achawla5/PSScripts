[CmdletBinding()]
  Param (
        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [System.String[]]$LanguageCode,

        [Parameter(Mandatory)]
        [string]$version
    )

function Set-Assets($version, [ref] $langDrive, [ref] $fodPath, [ref] $inboxAppDrive, [ref] $langPackPath) {

    Begin {
        Write-Verbose "In Begin block: Get-Assets"
        
        $appName = 'languagePacks'
        $drive = 'C:\'
        New-Item -Path $drive -Name $appName  -ItemType Directory -ErrorAction SilentlyContinue
        $LocalPath = $drive + $appName
        Set-Location $LocalPath

        $langIsoUrlIso = 'ClientLangPack.iso'
        $fodIsoUrlIso = 'FOD.iso'
        $inboxAppsIsoUrlIso = 'InboxApps.iso'

       
        $langOutputPath = $LocalPath + '\' + $langIsoUrlIso
        $fodOutputPath = $LocalPath + '\' + $fodIsoUrlIso
        $inboxAppsOutputPath = $LocalPath + '\' + $inboxAppsIsoUrlIso
    }

    Process {

        # Windows 11
        if($version -like "11") {
        
            $langIsoUrl = 'https://software-download.microsoft.com/download/sg/22000.1.210604-1628.co_release_amd64fre_CLIENT_LOF_PACKAGES_OEM.iso'
            $inboxAppsIsoUrl = 'https://software-download.microsoft.com/download/pr/22000.194.210911-1543.co_release_svc_prod1_amd64fre_InboxApps.iso'

            # Starting ISO downloads
            Invoke-WebRequest -Uri $langIsoUrl -OutFile $langOutputPath
            # Write-host 'AIB Customization: Finished Download for Language ISO for ' + $version

            # Mount ISOs
            $langMount = Mount-DiskImage -ImagePath $langOutputPath
            
            $langDrive.Value = ($langMount | Get-Volume).DriveLetter+":"
            $langPackPath.Value = $langDrive.Value+"\LanguagesAndOptionalFeatures"

            $fodPath.Value = $langDrive.Value+"\LanguagesAndOptionalFeatures"

        }  
        # Windows 10 - supported versions: 1903, 1909, 2004, 20H2, 21H1, 21H2
        else {
        
            if($version -like "1903" -or $version -like "1909") {
 
                $langIsoUrl = 'https://software-download.microsoft.com/download/pr/18362.1.190318-1202.19h1_release_CLIENTLANGPACKDVD_OEM_MULTI.iso'
                $fodIsoUrl = 'https://software-download.microsoft.com/download/pr/18362.1.190318-1202.19h1_release_amd64fre_FOD-PACKAGES_OEM_PT1_amd64fre_MULTI.iso'
                $inboxAppsIsoUrl = 'https://software-download.microsoft.com/download/pr/18362.1.190318-1202.19h1_release_amd64fre_InboxApps.iso'
            } 

            else {

                 $langIsoUrl = 'https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_CLIENTLANGPACKDVD_OEM_MULTI.iso'
                 $fodIsoUrl = 'https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_amd64fre_FOD-PACKAGES_OEM_PT1_amd64fre_MULTI.iso'

                  if($version -eq "2004") {

                        $inboxAppsIsoUrl = 'https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_amd64fre_InboxApps.iso'

                   } elseif ($version -eq "20H2") {

                        $inboxAppsIsoUrl = 'https://software-download.microsoft.com/download/pr/19041.508.200905-1327.vb_release_svc_prod1_amd64fre_InboxApps.iso'
        
                   } elseif ($version -eq "21H1" -or $version -eq "21H2") {
        
                        $inboxAppsIsoUrl = 'https://software-download.microsoft.com/download/sg/19041.928.210407-2138.vb_release_svc_prod1_amd64fre_InboxApps.iso'
                   } 
            } 

            # Starting ISO downloads
            Invoke-WebRequest -Uri $langIsoUrl -OutFile $langOutputPath
            Write-host 'AIB Customization: Finished Download for Language ISO for ' + $version

            Invoke-WebRequest -Uri $fodIsoUrl -OutFile $fodOutputPath
            Write-host 'AIB Customization: Finished Download for Feature on Demand (FOD) Disk 1 for ' $version

            $langMount = Mount-DiskImage -ImagePath $langOutputPath
            $fodMount = Mount-DiskImage -ImagePath $fodOutputPath

            $langDrive.Value = ($langMount | Get-Volume).DriveLetter+":"
            $fodPath.Value = ($fodMount | Get-Volume).DriveLetter+":"
            $langPackPath.Value = $langDrive.Value+"\x64\langpacks"

        }

        Invoke-WebRequest -Uri $inboxAppsIsoUrl -OutFile $inboxAppsOutputPath
        $inboxAppsMount = Mount-DiskImage -ImagePath $inboxAppsOutputPath
        Write-host 'AIB Customization: Finished Download for Inbox App ISO ' $version

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
        
        Set-StrictMode -Version Latest

        #Requires -RunAsAdministrator

        ##Disable Language Pack Cleanup## (do not re-enable)
        Disable-ScheduledTask -TaskPath "\Microsoft\Windows\AppxDeploymentClient\" -TaskName "Pre-staged app cleanup" | Out-Null

        #Code mapping from https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/features-on-demand-language-fod

        write-host 'AIB Customization: Download Language ISO, Feature on Demand (FOD) Disk 1, and Inbox Apps ISO'

        $appName = 'languagePacks'
        $drive = 'C:\'
        New-Item -Path $drive -Name $appName  -ItemType Directory -ErrorAction SilentlyContinue
        $LocalPath = $drive + $appName
        Set-Location $LocalPath

        # populate dictionary
        $languagesDict = @{}
        $languagesDict.Add("Arabic (Saudi Arabia)", "ar-SA")
        $languagesDict.Add("Basque (Basque)", "eu-ES")
        $languagesDict.Add("Bulgarian (Bulgaria)", "bg-BG")
        $languagesDict.Add("Catalan", "ca-ES")
        $languagesDict.Add("Chinese (Traditional, Hong Kong SAR)", "zh-HK")
        $languagesDict.Add("Chinese (Simplified, China)", "zh-CN")
        $languagesDict.Add("Chinese (Traditional, Taiwan)", "zh-TW")
        $languagesDict.Add("Croatian (Croatia)",	"hr-HR")
        $languagesDict.Add("Czech (Czech Republic)",	"cs-CZ")
        $languagesDict.Add("Danish (Denmark)",	"da-DK")
        $languagesDict.Add("Dutch (Netherlands)",	"nl-NL")
        $languagesDict.Add("English (United States)",	"en-US")
        $languagesDict.Add("English (United Kingdom)",	"en-GB")
        $languagesDict.Add("Estonian (Estonia)",	"et-EE")
        $languagesDict.Add("Finnish (Finland)",	"fi-FI")
        $languagesDict.Add("French (Canada)",	"fr-CA")
        $languagesDict.Add("French (France)",	"fr-FR")
        $languagesDict.Add("Galician",	"gl-ES")
        $languagesDict.Add("German (Germany)",	"de-DE")
        $languagesDict.Add("Greek (Greece)",	"el-GR")
        $languagesDict.Add("Hebrew (Israel)",	"he-IL")
        $languagesDict.Add("Hungarian (Hungary)",	"hu-HU")
        $languagesDict.Add("Indonesian (Indonesia)",	"id-ID")
        $languagesDict.Add("Italian (Italy)",	"it-IT")
        $languagesDict.Add("Japanese (Japan)",	"ja-JP")
        $languagesDict.Add("Korean (Korea)",	"ko-KR")
        $languagesDict.Add("Latvian (Latvia)",	"lv-LV")
        $languagesDict.Add("Lithuanian (Lithuania)",	"lt-LT")
        $languagesDict.Add("Norwegian, Bokmål (Norway)",	"nb-NO")
        $languagesDict.Add("Polish (Poland)",	"pl-PL")
        $languagesDict.Add("Portuguese (Brazil)",	"pt-BR")
        $languagesDict.Add("Portuguese (Portugal)",	"pt-PT")
        $languagesDict.Add("Romanian (Romania)",	"ro-RO")
        $languagesDict.Add("Russian (Russia)",	"ru-RU")
        $languagesDict.Add("Serbian (Latin, Serbia)",	"sr-Latn-RS")
        $languagesDict.Add("Slovak (Slovakia)",	"sk-SK")
        $languagesDict.Add("Slovenian (Slovenia)",	"sl-SI")
        $languagesDict.Add("Spanish (Mexico)",	"es-MX")
        $languagesDict.Add("Spanish (Spain)",	"es-ES")
        $languagesDict.Add("Swedish (Sweden)",	"sv-SE")
        $languagesDict.Add("Thai (Thailand)",	"th-TH")
        $languagesDict.Add("Turkish (Turkey)",	"tr-TR")
        $languagesDict.Add("Ukrainian (Ukraine)",	"uk-UA")
        $languagesDict.Add("Vietnamese",	"vi-VN")


        # download lang ISOs and FOD ISOs based on windows version
        $fodPath = "undefined"
        $langDrive = "undefined"
        $langPackPath = "undefined"
        $inboxAppDrive = "undefined"

        Set-Assets -version ($version) -langDrive ([ref] $langDrive) -fodPath ([ref] $fodPath) -langPackPath ([ref] $langPackPath) -inboxAppDrive ([ref] $inboxAppDrive)

        Invoke-WebRequest https://raw.githubusercontent.com/achawla5/PSScripts/main/Windows-10-1809-FOD-to-LP-Mapping-Table.csv  -OutFile .\LPtoFODFile.csv

        $LPtoFODFile = ".\LPtoFODFile.csv"

        #Check for code mapping file
        if (-not (Test-Path $LPtoFODFile )) {
            Write-Error "Could not validate that $LPtoFODFile file exists in this location"
            exit
        }

        $codeMapping = Import-Csv $LPtoFODFile

        <#
        if($version -eq "1903" -or $version -eq "1909") {
 
            $langIsoUrl = 'https://software-download.microsoft.com/download/pr/18362.1.190318-1202.19h1_release_CLIENTLANGPACKDVD_OEM_MULTI.iso'
            $fodIsoUrl = 'https://software-download.microsoft.com/download/pr/18362.1.190318-1202.19h1_release_amd64fre_FOD-PACKAGES_OEM_PT1_amd64fre_MULTI.iso'
            $inboxAppsIsoUrl = 'https://software-download.microsoft.com/download/pr/18362.1.190318-1202.19h1_release_amd64fre_InboxApps.iso'

        } else {

            $langIsoUrl = 'https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_CLIENTLANGPACKDVD_OEM_MULTI.iso'
            $fodIsoUrl = 'https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_amd64fre_FOD-PACKAGES_OEM_PT1_amd64fre_MULTI.iso'

            if($version -eq "2004") {

                $inboxAppsIsoUrl = 'https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_amd64fre_InboxApps.iso'

            } elseif($version -eq "20H2") {

                $inboxAppsIsoUrl = 'https://software-download.microsoft.com/download/pr/19041.508.200905-1327.vb_release_svc_prod1_amd64fre_InboxApps.iso'
        
            } elseif($version -eq "21H1" -or $version -eq "21H2") {
        
                $inboxAppsIsoUrl = 'https://software-download.microsoft.com/download/sg/19041.928.210407-2138.vb_release_svc_prod1_amd64fre_InboxApps.iso'
            } else {

                # Windows 11

                $inboxAppsIsoUrl = 'https://software-download.microsoft.com/download/pr/22000.194.210911-1543.co_release_svc_prod1_amd64fre_InboxApps.iso'
            }
        }


        $langOutputPath = $LocalPath + '\' + $langIsoUrlIso
        $fodOutputPath = $LocalPath + '\' + $fodIsoUrlIso
        #$inboxAppsOutputPath = $LocalPath + '\' + $inboxAppsIsoUrlIso
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $langIsoUrl -OutFile $langOutputPath
        write-host 'AIB Customization: Finished Download for Language ISO for ' + $version
        Invoke-WebRequest -Uri $fodIsoUrl -OutFile $fodOutputPath
        write-host 'AIB Customization: Finished Download for Feature on Demand (FOD) Disk 1 for Windows version ' $version

        write-host 'AIB Customization: Mount ISOs'
        $langMount = Mount-DiskImage -ImagePath $langOutputPath
        $fodMount = Mount-DiskImage -ImagePath $fodOutputPath
        #$inboxAppsMount = Mount-DiskImage -ImagePath $inboxAppsOutputPath

        $langDrive = ($langMount | Get-Volume).DriveLetter+":"
        $fodDrive = ($fodMount | Get-Volume).DriveLetter+":"
        #$inboxAppsDrive = ($inboxAppsMount | Get-Volume).DriveLetter

        $langPackPath = $langDrive+"\x64\langpacks"
        write-host 'AIB Customization: Finished Mounting ISOs'
        #>

         # Disable Language Pack Cleanup
        write-host 'AIB Customization: Disabling language pack cleanup task'
        Disable-ScheduledTask -TaskPath "\Microsoft\Windows\AppxDeploymentClient\" -TaskName "Pre-staged app cleanup"


    } # Begin
    PROCESS {

        foreach ($code in $LanguageCode) {
            $contentPath = Join-Path $langDrive (Join-Path 'LocalExperiencePack' $code)
            #From the local experience iso
            $appxPath = "$contentPath\LanguageExperiencePack.$code.Neutral.appx"
            if (-not (Test-Path $appxPath)) {
                Write-Verbose "Could not validate that $appxPath file exists in this location"
            }
            if (-not (Test-Path "$contentPath\License.xml")) {
                Write-Verbose "Could not validate that $contentPath\License.xml file exists in this location"
            }

            <#
            try {
                Add-AppProvisionedPackage -Online -PackagePath $appxPath -LicensePath "$contentPath\License.xml" -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null #ToDo enable logging  -LogPath 
            }
            catch {
                $error[0]
                break
            }
            #>

            $langPackPath = "$langPackPath\Microsoft-Windows-Client-Language-Pack_x64_$code.cab"

            try {
                Add-WindowsPackage -Online -PackagePath $langPackPath -NoRestart -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
            }
            catch {
                $error[0]
                continue
            }
            
            $fileList = $codeMapping | Where-Object { $_.'Target Lang' -eq $code }

            #From the Features On Demand iso

            if (($fileList | Measure-Object).Count -eq 0){
                Write-Verbose "Installed $code"
                break
            }

            foreach ($file in $fileList.'Cab Name') {
                $filePath = Get-ChildItem (Join-Path $fodPath $file.replace('.cab', '*.cab'))

                if ($null -eq $filePath) {
                    Write-Error "Could not find $filePath"
                    break
                }

                try {
                    Add-WindowsPackage -Online -PackagePath $filePath.FullName -NoRestart -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
                }
                catch {
                    $error[0]
                    continue
                }
            }
        
            # try setting default language
            try {
                $LanguageList = Get-WinUserLanguageList -ErrorAction Stop
                $LanguageList.Add("$code") 
                Set-WinUserLanguageList $LanguageList -force -ErrorAction Stop
                Set-WinUILanguageOverride -Language $code
                Set-WinSystemLocale $code
                Set-Culture -CultureInfo $code
            }
            catch {
                $error[0]
                continue
            }


            # Update Inbox Apps
            # reference https://docs.microsoft.com/en-us/azure/virtual-desktop/language-packs

            foreach ($App in (Get-AppxProvisionedPackage -Online)) {
                $AppPath = $inboxAppDrive + $App.DisplayName + '_' + $App.PublisherId
                Write-Host "Handling $AppPath"
                $licFile = Get-Item $AppPath*.xml
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
                        Add-AppxProvisionedPackage -Online -PackagePath $appxFilePath -LicensePath $licFilePath 
                    } else {
                        Add-AppxProvisionedPackage -Online -PackagePath $appxFilePath -skiplicense
                    }
                }
            }

            Write-Verbose "Installed $code"
            shutdown /r
        }
    } #Process
    END {
        
    } #End
}  #function Install-LanguagePack


 Install-LanguagePack -LanguageCode $LanguageCode -Version $version 