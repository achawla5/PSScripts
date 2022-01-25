

 [CmdletBinding()]
  Param (
        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [ValidateSet('af-za', 'am-et', 'ar-sa', 'as-in', 'az-latn-az', 'be-by', 'bg-bg', 'bn-bd', 'bn-in', 'bs-latn-ba', 'ca-es', 'ca-es-valencia', 'chr-cher-us', 'cs-cz', 'cy-gb', 'da-dk', 'de-de', 'el-gr', 'en-gb', 'en-us', 'es-es', 'es-mx', 'et-ee', 'eu-es', 'fa-ir', 'fi-fi', 'fil-ph', 'fr-ca', 'fr-fr', 'ga-ie', 'gd-gb', 'gl-es', 'gu-in', 'ha-latn-ng', 'he-il', 'hi-in', 'hr-hr', 'hu-hu', 'hy-am', 'id-id', 'ig-ng', 'is-is', 'it-it', 'ja-jp', 'ka-ge', 'kk-kz', 'km-kh', 'kn-in', 'kok-in', 'ko-kr', 'ku-arab-iq', 'ky-kg', 'lb-lu', 'lo-la', 'lt-lt', 'lv-lv', 'mi-nz', 'mk-mk', 'ml-in', 'mn-mn', 'mr-in', 'ms-my', 'mt-mt', 'nb-no', 'ne-np', 'nl-nl', 'nn-no', 'nso-za', 'or-in', 'pa-arab-pk', 'pa-in', 'pl-pl', 'prs-af', 'pt-br', 'pt-pt', 'quc-latn-gt', 'quz-pe', 'ro-ro', 'ru-ru', 'rw-rw', 'sd-arab-pk', 'si-lk', 'sk-sk', 'sl-si', 'sq-al', 'sr-cyrl-ba', 'sr-cyrl-rs', 'sr-latn-rs', 'sv-se', 'sw-ke', 'ta-in', 'te-in', 'tg-cyrl-tj', 'th-th', 'ti-et', 'tk-tm', 'tn-za', 'tr-tr', 'tt-ru', 'ug-cn', 'uk-ua', 'ur-pk', 'uz-latn-uz', 'vi-vn', 'wo-sn', 'xh-za', 'yo-ng', 'zh-cn', 'zh-tw', 'zu-za')]
        [System.String[]]$LanguageCode,

        [Parameter(Mandatory)]
        [string]$version,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$LPtoFODFile = "Windows-10-1809-FOD-to-LP-Mapping-Table.csv",

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$LogPath
    )

function Install-LanguagePack {
  
    <#
    .SYNOPSIS
    Function to install language packs along with features on demand,

    .DESCRIPTION
    This PowerShell function is designed to automate the installation of language packs with their respective features on demand.  Not all languages have all features available to them, but this function will install all available. 
    This supports Windows 10 single and multisession, along with Windows 11.

    You will need 3 external resources for this script to run:

    The excel file from 'Language and region Features on Demand' documentation **saved as a csv file**.  This is needed as it shows what features are available for each language.  I'd prefer an API or the ability to daownload a CSV, but I guess we work with what we've got so you've got to download the xlsx file and save it as a csv.
    https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/features-on-demand-language-fod

    As long as the structure of the iso files and format of the excel file stay the same, this function will work for future language updates.

    *currently supported languages: 'af-za', 'am-et', 'ar-sa', 'as-in', 'az-latn-az', 'be-by', 'bg-bg', 'bn-bd', 'bn-in', 'bs-latn-ba', 'ca-es', 'ca-es-valencia', 'chr-cher-us', 'cs-cz', 'cy-gb', 'da-dk', 'de-de', 'el-gr', 'en-gb', 'en-us', 'es-es', 'es-mx', 'et-ee', 'eu-es', 'fa-ir', 'fi-fi', 'fil-ph', 'fr-ca', 'fr-fr', 'ga-ie', 'gd-gb', 'gl-es', 'gu-in', 'ha-latn-ng', 'he-il', 'hi-in', 'hr-hr', 'hu-hu', 'hy-am', 'id-id', 'ig-ng', 'is-is', 'it-it', 'ja-jp', 'ka-ge', 'kk-kz', 'km-kh', 'kn-in', 'kok-in', 'ko-kr', 'ku-arab-iq', 'ky-kg', 'lb-lu', 'lo-la', 'lt-lt', 'lv-lv', 'mi-nz', 'mk-mk', 'ml-in', 'mn-mn', 'mr-in', 'ms-my', 'mt-mt', 'nb-no', 'ne-np', 'nl-nl', 'nn-no', 'nso-za', 'or-in', 'pa-arab-pk', 'pa-in', 'pl-pl', 'prs-af', 'pt-br', 'pt-pt', 'quc-latn-gt', 'quz-pe', 'ro-ro', 'ru-ru', 'rw-rw', 'sd-arab-pk', 'si-lk', 'sk-sk', 'sl-si', 'sq-al', 'sr-cyrl-ba', 'sr-cyrl-rs', 'sr-latn-rs', 'sv-se', 'sw-ke', 'ta-in', 'te-in', 'tg-cyrl-tj', 'th-th', 'ti-et', 'tk-tm', 'tn-za', 'tr-tr', 'tt-ru', 'ug-cn', 'uk-ua', 'ur-pk', 'uz-latn-uz', 'vi-vn', 'wo-sn', 'xh-za', 'yo-ng', 'zh-cn', 'zh-tw', 'zu-za'

    .PARAMETER LanguageCode
    This is the language code for your language the full list of available codes is in the description.  The parameter will only allow valid codes

    .PARAMETER LPtoFODFile
    This is the path to the csv version of the excel file from 'Language and region Features on Demand' documentation.  You can find it here: https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/features-on-demand-language-fod.
    The default value for this parameter is Windows-10-1809-FOD-to-LP-Mapping-Table.csv

    .EXAMPLE
    

    .EXAMPLE 
    

    .EXAMPLE
    

    .EXAMPLE
   

    #>

    [CmdletBinding()]

    Param (
        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [ValidateSet('af-za', 'am-et', 'ar-sa', 'as-in', 'az-latn-az', 'be-by', 'bg-bg', 'bn-bd', 'bn-in', 'bs-latn-ba', 'ca-es', 'ca-es-valencia', 'chr-cher-us', 'cs-cz', 'cy-gb', 'da-dk', 'de-de', 'el-gr', 'en-gb', 'en-us', 'es-es', 'es-mx', 'et-ee', 'eu-es', 'fa-ir', 'fi-fi', 'fil-ph', 'fr-ca', 'fr-fr', 'ga-ie', 'gd-gb', 'gl-es', 'gu-in', 'ha-latn-ng', 'he-il', 'hi-in', 'hr-hr', 'hu-hu', 'hy-am', 'id-id', 'ig-ng', 'is-is', 'it-it', 'ja-jp', 'ka-ge', 'kk-kz', 'km-kh', 'kn-in', 'kok-in', 'ko-kr', 'ku-arab-iq', 'ky-kg', 'lb-lu', 'lo-la', 'lt-lt', 'lv-lv', 'mi-nz', 'mk-mk', 'ml-in', 'mn-mn', 'mr-in', 'ms-my', 'mt-mt', 'nb-no', 'ne-np', 'nl-nl', 'nn-no', 'nso-za', 'or-in', 'pa-arab-pk', 'pa-in', 'pl-pl', 'prs-af', 'pt-br', 'pt-pt', 'quc-latn-gt', 'quz-pe', 'ro-ro', 'ru-ru', 'rw-rw', 'sd-arab-pk', 'si-lk', 'sk-sk', 'sl-si', 'sq-al', 'sr-cyrl-ba', 'sr-cyrl-rs', 'sr-latn-rs', 'sv-se', 'sw-ke', 'ta-in', 'te-in', 'tg-cyrl-tj', 'th-th', 'ti-et', 'tk-tm', 'tn-za', 'tr-tr', 'tt-ru', 'ug-cn', 'uk-ua', 'ur-pk', 'uz-latn-uz', 'vi-vn', 'wo-sn', 'xh-za', 'yo-ng', 'zh-cn', 'zh-tw', 'zu-za')]
        [System.String[]]$LanguageCode,

        [Parameter(Mandatory)]
        [string]$version,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$LPtoFODFile = "C:\Users\akashchawla\Downloads\Windows-10-1809-FOD-to-LP-Mapping-Table.csv",

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$LogPath
    )

    BEGIN {
        
        Set-StrictMode -Version Latest

        #Requires -RunAsAdministrator

        ##Disable Language Pack Cleanup## (do not re-enable)
        Disable-ScheduledTask -TaskPath "\Microsoft\Windows\AppxDeploymentClient\" -TaskName "Pre-staged app cleanup" | Out-Null

        #Code mapping from https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/features-on-demand-language-fod

        Invoke-WebRequest https://raw.githubusercontent.com/achawla5/PSScripts/main/Windows-10-1809-FOD-to-LP-Mapping-Table.csv  -OutFile .\LPtoFODFile.csv

        $LPtoFODFile = ".\LPtoFODFile.csv"
        #Check for code mapping file
        if (-not (Test-Path $LPtoFODFile )) {

            #Check for Excel file
            $excelName = $LPtoFODFile.Replace('.csv', '*.xlsx')
            if (Test-Path $excelName) {
                Write-Error "Please open $excelName and save as a csv"
                exit
            }

            Write-Error "Could not validate that $LPtoFODFile file exists in this location"
            exit
        }
        $codeMapping = Import-Csv $LPtoFODFile

        write-host 'AIB Customization: Download Language ISO, Feature on Demand (FOD) Disk 1, and Inbox Apps ISO'
        $appName = 'languagePacks'
        $drive = 'C:\'
        New-Item -Path $drive -Name $appName  -ItemType Directory -ErrorAction SilentlyContinue
        $LocalPath = $drive + $appName
        Set-Location $LocalPath

        $langIsoUrlIso = 'ClientLangPack.iso'
        $fodIsoUrlIso = 'FOD.iso'
        $inboxAppsIsoUrlIso = 'InboxApps.iso'

        $languagesDict = @{}
        $languagesDict.Add("Arabic (Saudi Arabia)", "ar-SA")
        $languagesDict.Add("Basque (Basque)", "eu-ES")
        $languagesDict.Add("Bulgarian (Bulgaria)", "bg-BG")
        $languagesDict.Add("Catalan", "ca-ES")
        $languagesDict.Add("Chinese (Traditional, Hong Kong SAR)", "zh-HK")
        $languagesDict.Add("Chinese (Simplified, China)", "zh-CN")
        $languagesDict.Add("Chinese (Traditional, Taiwan)", "zh-TW")
        $languagesDict.Add("Croatian (Croatia)",	"hr-HR")
        $languagesDict.Add("Spanish (Spain)",	"es-ES")



        # download lang ISOs and FOD ISOs based on windows version

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
                Write-Error "Could not validate that $appxPath file exists in this location"
                break
            }
            if (-not (Test-Path "$contentPath\License.xml")) {
                Write-Error "Could not validate that $contentPath\License.xml file exists in this location"
                break
            }
            try {
                Add-AppProvisionedPackage -Online -PackagePath $appxPath -LicensePath "$contentPath\License.xml" -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null #ToDo enable logging  -LogPath 
            }
            catch {
                $error[0]
                break
            }
            
            $fileList = $codeMapping | Where-Object { $_.'Target Lang' -eq $code }

            #From the Features On Demand iso

            if (($fileList | Measure-Object).Count -eq 0){
                Write-Verbose "Installed $code"
                break
            }

            foreach ($file in $fileList.'Cab Name') {
                $filePath = Get-ChildItem (Join-Path $fodDrive $file.replace('.cab', '*.cab'))

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
        
            try {
                $LanguageList = Get-WinUserLanguageList -ErrorAction Stop
                $LanguageList.Add("$code") 
                Set-WinUserLanguageList $LanguageList -force -ErrorAction Stop
            }
            catch {
                $error[0]
                continue
            }
            Write-Verbose "Installed $code"
        }
    } #Process
    END {
        
    } #End
}  #function Install-LanguagePack


 Install-LanguagePack -LanguageCode $LanguageCode -Version $version 

