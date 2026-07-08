<#Author       : Akash Chawla
# Usage        : Set default Language 
#>

#######################################
#    Set default Language             #
#######################################


[CmdletBinding()]
  Param (
        # [Parameter(Mandatory)]
        [ValidateSet("Arabic (Saudi Arabia)","Bulgarian (Bulgaria)","Chinese (Simplified, China)","Chinese (Traditional, Taiwan)","Croatian (Croatia)","Czech (Czech Republic)","Danish (Denmark)","Dutch (Netherlands)", "English (United Kingdom)", "Estonian (Estonia)", "Finnish (Finland)", "French (Canada)", "French (France)", "German (Germany)", "Greek (Greece)", "Hebrew (Israel)", "Hungarian (Hungary)", "Italian (Italy)", "Japanese (Japan)", "Korean (Korea)", "Latvian (Latvia)", "Lithuanian (Lithuania)", "Norwegian, Bokmål (Norway)", "Polish (Poland)", "Portuguese (Brazil)", "Portuguese (Portugal)", "Romanian (Romania)", "Russian (Russia)", "Serbian (Latin, Serbia)", "Slovak (Slovakia)", "Slovenian (Slovenia)", "Spanish (Mexico)", "Spanish (Spain)", "Swedish (Sweden)", "Thai (Thailand)", "Turkish (Turkey)", "Ukrainian (Ukraine)", "English (Australia)", "English (United States)")]
        [string]$Language = "French (France)"
)

function Get-RegionInfo($Name='*')
{
  try {
    $cultures = [System.Globalization.CultureInfo]::GetCultures('InstalledWin32Cultures')

    foreach($culture in $cultures)
    {        
      if($culture.DisplayName -eq $Name) {
        $languageTag = $culture.Name
        break;
      }
    }

    if($null -eq $languageTag) {
        return
    } else {
        $region = [System.Globalization.RegionInfo]$culture.Name
        return @($languageTag, $region.GeoId)
    }
  }
  catch {
    Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - Exception occurred while getting region information***"
    Write-Host $PSItem.Exception
    return
  }
}

function UpdateUserLanguageList($languageTag)
{
  try {
    # Enable language Keyboard for Windows.
    $userLanguageList = New-WinUserLanguageList -Language $languageTag
    $installedUserLanguagesList = Get-WinUserLanguageList

    foreach($language in $installedUserLanguagesList)
    {
        $userLanguageList.Add($language.LanguageTag)
    }

    Set-WinUserLanguageList -LanguageList $userLanguageList -f
  }
  catch 
  {
    Write-Host "***Starting AVD AIB CUSTOMIZER PHASE: Set default Language - UpdateUserLanguageList: Error occurred: [$($_.Exception.Message)]"
  }
}

function UpdateRegionSettings($GeoID, $GeoName)
{
  try {
    try {
      # try deleting reg key for deviceRegion for DMA compliance.
      Write-Host "***Starting AVD AIB CUSTOMIZER PHASE: Set default Language - Try deleting reg key"
      Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Control Panel\DeviceRegion" -Name "DeviceRegion" -Force -ErrorAction Continue
      Write-Host "***Starting AVD AIB CUSTOMIZER PHASE: Set default Language - Remove DeviceRegion registry key succeeded."
    }
    catch 
    {
      Write-Host "***Starting AVD AIB CUSTOMIZER PHASE: Set default Language - Try deleting reg key failed with error: [$($_.Exception.Message)]"
    }

    # Ensure HKU is available as a PSDrive
    if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
        New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS | Out-Null
    }

    #Set Region in Default User Profile (applies to all new users)
    New-ItemProperty -Path "HKU:\.DEFAULT\Control Panel\International\Geo" -Name "Nation" -Value $GeoID -PropertyType String -Force
    if (-not [string]::IsNullOrEmpty($GeoName)) {
        New-ItemProperty -Path "HKU:\.DEFAULT\Control Panel\International\Geo" -Name "Name" -Value $GeoName -PropertyType String -Force
    }
    Set-WinHomeLocation -GeoId $GeoID
    Write-Host "***Starting AVD AIB CUSTOMIZER PHASE: Set default Language - Region update completed."
  }
  catch {
      Write-Host "***Starting AVD AIB CUSTOMIZER PHASE: Set default Language - UpdateRegionSettings: Error occurred: [$($_.Exception.Message)]"
      Exit 1
  }
}

# =============================================================================
# Windows-team compat: Copy-UserInternationalSettingsToSystem (NewUser)
# -----------------------------------------------------------------------------
# Source: Copy-UserInternationalSettingsToSystemCompat.ps1 (shared by the
# Windows internationalization team). Preserves 1:1 behavior of the Win11
# Copy-UserInternationalSettingsToSystem -NewUser $true call on down-level
# Windows 10 SKUs by:
#   1. Preferring the native intl.cpl!IntlCopyInternationalSettings entry point
#      when available.
#   2. Falling back to copying HKCU\Control Panel\International into
#      C:\Users\Default\NTUSER.DAT, invoking input.dll ordinal 105
#      (SaveDefaultUserInputSettings) to persist keyboard/input state, and
#      copying PreferredUILanguages + LanguageConfiguration entries.
# =============================================================================

function Add-IntlNativeMethods {
    if ('CopyUserIntlSettings.NativeMethods' -as [type]) {
        return
    }

    Add-Type -Language CSharp -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace CopyUserIntlSettings
{
    public static class NativeMethods
    {
        [DllImport("intl.cpl", EntryPoint = "IntlCopyInternationalSettings", ExactSpelling = true, SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern UInt32 IntlCopyInternationalSettings(
            [MarshalAs(UnmanagedType.Bool)] bool copyToWelcomeScreenAndSystemAccounts,
            [MarshalAs(UnmanagedType.Bool)] bool copyToNewUser);
    }
}
"@
}

function Add-InputNativeMethods {
    if ('CopyUserIntlSettings.InputNativeMethods' -as [type]) {
        return
    }

    Add-Type -Language CSharp -TypeDefinition @"
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace CopyUserIntlSettings
{
    public static class InputNativeMethods
    {
        private const UInt32 LOAD_LIBRARY_SEARCH_SYSTEM32 = 0x00000800;
        private const Int32 ERROR_INVALID_PARAMETER = 87;
        private static readonly IntPtr HKEY_CURRENT_USER = new IntPtr(unchecked((int)0x80000001));

        [DllImport("kernel32.dll", EntryPoint = "LoadLibraryExW", SetLastError = true, CharSet = CharSet.Unicode)]
        private static extern IntPtr LoadLibraryEx(string fileName, IntPtr fileHandle, UInt32 flags);

        [DllImport("kernel32.dll", EntryPoint = "GetProcAddress", SetLastError = true)]
        private static extern IntPtr GetProcAddressByOrdinal(IntPtr module, IntPtr ordinal);

        [UnmanagedFunctionPointer(CallingConvention.Winapi)]
        private delegate bool SaveDefaultUserInputSettingsDelegate(IntPtr parentWindow, IntPtr sourceRegistryKey);

        public static bool IsSaveDefaultUserInputSettingsAvailable()
        {
            IntPtr inputDll = LoadInputDll();
            return GetProcAddressByOrdinal(inputDll, new IntPtr(105)) != IntPtr.Zero;
        }

        public static void SaveDefaultUserInputSettings()
        {
            IntPtr inputDll = LoadInputDll();
            IntPtr procedure = GetProcAddressByOrdinal(inputDll, new IntPtr(105));
            if (procedure == IntPtr.Zero)
            {
                throw new EntryPointNotFoundException("input.dll ordinal 105 (SaveDefaultUserInputSettings) was not found.");
            }

            SaveDefaultUserInputSettingsDelegate saveDefaultUserInputSettings =
                (SaveDefaultUserInputSettingsDelegate)Marshal.GetDelegateForFunctionPointer(
                    procedure,
                    typeof(SaveDefaultUserInputSettingsDelegate));

            if (!saveDefaultUserInputSettings(IntPtr.Zero, HKEY_CURRENT_USER))
            {
                throw new Win32Exception(ERROR_INVALID_PARAMETER);
            }
        }

        private static IntPtr LoadInputDll()
        {
            IntPtr inputDll = LoadLibraryEx("input.dll", IntPtr.Zero, LOAD_LIBRARY_SEARCH_SYSTEM32);
            if (inputDll == IntPtr.Zero)
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Unable to load input.dll from System32.");
            }

            return inputDll;
        }
    }
}
"@
}

function Test-IntlNativeEntryPoint {
    Add-IntlNativeMethods

    try {
        [void][CopyUserIntlSettings.NativeMethods]::IntlCopyInternationalSettings($false, $false)
        return $true
    }
    catch [System.EntryPointNotFoundException] {
        return $false
    }
}

function Test-InputDllSaveDefaultUserInputSettings {
    Add-InputNativeMethods
    return [CopyUserIntlSettings.InputNativeMethods]::IsSaveDefaultUserInputSettingsAvailable()
}

function Invoke-IntlCopyInternationalSettingsForNewUser {
    try {
        return [CopyUserIntlSettings.NativeMethods]::IntlCopyInternationalSettings($false, $true)
    }
    catch {
        $baseException = $_.Exception.GetBaseException()
        throw "Unable to call intl.cpl!IntlCopyInternationalSettings for NewUser. $($baseException.GetType().FullName): $($baseException.Message)"
    }
}

function Invoke-InputDllSaveDefaultUserInputSettings {
    if (-not (Test-InputDllSaveDefaultUserInputSettings)) {
        throw 'input.dll ordinal 105 (SaveDefaultUserInputSettings) is not available. The Win10 fallback cannot preserve 1:1 NewUser input-settings behavior without it.'
    }

    [CopyUserIntlSettings.InputNativeMethods]::SaveDefaultUserInputSettings()
}

function Copy-RegistryTree {
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Win32.RegistryKey]$SourceKey,

        [Parameter(Mandatory = $true)]
        [Microsoft.Win32.RegistryKey]$DestinationKey
    )

    foreach ($valueName in $SourceKey.GetValueNames()) {
        $valueKind = $SourceKey.GetValueKind($valueName)
        $value = $SourceKey.GetValue($valueName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $DestinationKey.SetValue($valueName, $value, $valueKind)
    }

    foreach ($subKeyName in $SourceKey.GetSubKeyNames()) {
        $sourceSubKey = $SourceKey.OpenSubKey($subKeyName, $false)
        $destinationSubKey = $DestinationKey.CreateSubKey($subKeyName)
        try {
            Copy-RegistryTree -SourceKey $sourceSubKey -DestinationKey $destinationSubKey
        }
        finally {
            if ($null -ne $destinationSubKey) {
                $destinationSubKey.Dispose()
            }
            if ($null -ne $sourceSubKey) {
                $sourceSubKey.Dispose()
            }
        }
    }
}

function Copy-CurrentUserSubKeyToUsersHive {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceSubKeyPath,

        [Parameter(Mandatory = $true)]
        [string]$TargetUsersSubKeyPath
    )

    $sourceKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($SourceSubKeyPath, $false)
    if ($null -eq $sourceKey) {
        Write-Verbose "Source key HKCU\$SourceSubKeyPath does not exist."
        return
    }

    try {
        $usersHive = [Microsoft.Win32.Registry]::Users
        $usersHive.DeleteSubKeyTree($TargetUsersSubKeyPath, $false)

        $destinationKey = $usersHive.CreateSubKey($TargetUsersSubKeyPath)
        try {
            Copy-RegistryTree -SourceKey $sourceKey -DestinationKey $destinationKey
        }
        finally {
            if ($null -ne $destinationKey) {
                $destinationKey.Dispose()
            }
        }
    }
    finally {
        $sourceKey.Dispose()
    }
}

function Get-CurrentUserRegistryValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceSubKeyPath,

        [Parameter(Mandatory = $true)]
        [string[]]$SourceValueNames
    )

    $sourceKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($SourceSubKeyPath, $false)
    if ($null -eq $sourceKey) {
        return $null
    }

    try {
        foreach ($sourceValueName in $SourceValueNames) {
            $value = $sourceKey.GetValue($sourceValueName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            if ($null -ne $value) {
                return [pscustomobject]@{
                    Name = $sourceValueName
                    Value = $value
                    Kind = $sourceKey.GetValueKind($sourceValueName)
                }
            }
        }

        return $null
    }
    finally {
        $sourceKey.Dispose()
    }
}

function Get-FirstMultiStringEntry {
    param(
        [Parameter(Mandatory = $true)]
        $Value
    )

    if ($Value -is [string[]]) {
        if ($Value.Count -eq 0) {
            return $null
        }

        return [string]$Value[0]
    }

    return [string]$Value
}

function Invoke-WithDefaultUserHive {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    $tempHiveName = 'CopyUserIntlSettingsDefaultUser'
    $ntUserPath = Join-Path $env:SystemDrive 'Users\Default\NTUSER.DAT'

    if (-not (Test-Path $ntUserPath)) {
        throw "Default User hive was not found at $ntUserPath."
    }

    if (Test-Path "Registry::HKEY_USERS\$tempHiveName") {
        $preUnloadOutput = & reg.exe unload "HKU\$tempHiveName" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to unload stale Default User hive mount HKU\$tempHiveName. reg.exe exit code $LASTEXITCODE. $preUnloadOutput"
        }
    }

    $loadOutput = & reg.exe load "HKU\$tempHiveName" $ntUserPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to load Default User hive '$ntUserPath'. reg.exe exit code $LASTEXITCODE. $loadOutput"
    }

    $actionFailed = $false
    try {
        try {
            & $Action $tempHiveName
        }
        catch {
            $actionFailed = $true
            throw
        }
    }
    finally {
        [gc]::Collect()
        [gc]::WaitForPendingFinalizers()
        $unloadOutput = & reg.exe unload "HKU\$tempHiveName" 2>&1
        if ($LASTEXITCODE -ne 0) {
            $unloadError = "Failed to unload Default User hive. reg.exe exit code $LASTEXITCODE. $unloadOutput"
            if ($actionFailed) {
                Write-Warning $unloadError
            }
            else {
                throw $unloadError
            }
        }
    }
}

function Copy-CurrentUserSubKeyToDefaultUserHive {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceSubKeyPath
    )

    Invoke-WithDefaultUserHive {
        param([Parameter(Mandatory = $true)][string]$TempHiveName)

        Copy-CurrentUserSubKeyToUsersHive `
            -SourceSubKeyPath $SourceSubKeyPath `
            -TargetUsersSubKeyPath "$TempHiveName\$SourceSubKeyPath"
    }
}

function Copy-UserInterfaceSettingsToDefaultUserHive {
    $uiLanguageValue = Get-CurrentUserRegistryValue `
        -SourceSubKeyPath 'Control Panel\Desktop' `
        -SourceValueNames @('PreferredUILanguagesPending', 'PreferredUILanguages')

    if ($null -eq $uiLanguageValue) {
        Write-Verbose 'No current-user PreferredUILanguagesPending or PreferredUILanguages value was found.'
        return
    }

    if ($uiLanguageValue.Kind -ne [Microsoft.Win32.RegistryValueKind]::MultiString) {
        Write-Verbose "Skipping UI language value '$($uiLanguageValue.Name)' because it is $($uiLanguageValue.Kind), not REG_MULTI_SZ."
        return
    }

    $uiLanguage = Get-FirstMultiStringEntry -Value $uiLanguageValue.Value
    if ([string]::IsNullOrEmpty($uiLanguage)) {
        Write-Verbose 'The current-user UI language value is empty.'
        return
    }

    $uiFallbackValue = Get-CurrentUserRegistryValue `
        -SourceSubKeyPath 'Control Panel\Desktop\LanguageConfigurationPending' `
        -SourceValueNames @($uiLanguage)

    if ($null -eq $uiFallbackValue) {
        $uiFallbackValue = Get-CurrentUserRegistryValue `
            -SourceSubKeyPath 'Control Panel\Desktop\LanguageConfiguration' `
            -SourceValueNames @($uiLanguage)
    }

    Invoke-WithDefaultUserHive {
        param([Parameter(Mandatory = $true)][string]$TempHiveName)

        $desktopKey = [Microsoft.Win32.Registry]::Users.CreateSubKey("$TempHiveName\Control Panel\Desktop")
        try {
            $desktopKey.SetValue('PreferredUILanguages', [string[]]@($uiLanguage), [Microsoft.Win32.RegistryValueKind]::MultiString)
        }
        finally {
            if ($null -ne $desktopKey) {
                $desktopKey.Dispose()
            }
        }

        if ($null -ne $uiFallbackValue) {
            if ($uiFallbackValue.Kind -ne [Microsoft.Win32.RegistryValueKind]::MultiString) {
                Write-Verbose "Skipping UI fallback value '$($uiFallbackValue.Name)' because it is $($uiFallbackValue.Kind), not REG_MULTI_SZ."
                return
            }

            $languageConfigurationKey = [Microsoft.Win32.Registry]::Users.CreateSubKey("$TempHiveName\Control Panel\Desktop\LanguageConfiguration")
            try {
                $languageConfigurationKey.SetValue($uiLanguage, $uiFallbackValue.Value, [Microsoft.Win32.RegistryValueKind]::MultiString)
            }
            finally {
                if ($null -ne $languageConfigurationKey) {
                    $languageConfigurationKey.Dispose()
                }
            }
        }
    }
}

function Invoke-NewUserRegistryFallbackCopy {
    Copy-CurrentUserSubKeyToDefaultUserHive -SourceSubKeyPath 'Control Panel\International'
    Invoke-InputDllSaveDefaultUserInputSettings
    Copy-UserInterfaceSettingsToDefaultUserHive
}

function Invoke-CopyUserIntlSettingsCompatForNewUser {
    # Entry point invoked by the main script. Uses Set-StrictMode/ErrorAction
    # locally to match the Windows-team script's assumptions without leaking
    # them into the outer AIB customizer scope.
    Set-StrictMode -Version 2.0
    $ErrorActionPreference = 'Stop'

    if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
        throw 'Copy-UserInternationalSettingsToSystemCompat requires 64-bit Windows PowerShell on 64-bit Windows.'
    }

    try {
        if (Test-IntlNativeEntryPoint) {
            $result = Invoke-IntlCopyInternationalSettingsForNewUser
            if ($result -ne 0) {
                $message = (New-Object ComponentModel.Win32Exception([int]$result)).Message
                throw "IntlCopyInternationalSettings failed with Win32 error $result ($message)."
            }
            Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - Copied current-user international settings to the default new-user profile via intl.cpl!IntlCopyInternationalSettings ***"
        }
        else {
            Invoke-NewUserRegistryFallbackCopy
            Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - Copied current-user international settings to the default new-user profile via NewUser registry/input.dll fallback ***"
        }
    }
    catch {
        Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - Invoke-CopyUserIntlSettingsCompatForNewUser failed: [$($_.Exception.Message)] ***"
        throw
    }
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host "*** Starting AVD AIB CUSTOMIZER PHASE: Set default Language ***"

$templateFilePathFolder = "C:\AVDImage"
# Reference: https://learn.microsoft.com/en-gb/powershell/module/languagepackmanagement/set-systempreferreduilanguage?view=windowsserver2022-ps
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
$LanguagesDictionary.Add("English (Australia)",	"en-AU")

try {
  # Disable LanguageComponentsInstaller while installing language packs
  # See Bug 45044965: Installing language pack fails with error: ERROR_SHARING_VIOLATION for more details
  Disable-ScheduledTask -TaskName "\Microsoft\Windows\LanguageComponentsInstaller\Installation"
  Disable-ScheduledTask -TaskName "\Microsoft\Windows\LanguageComponentsInstaller\ReconcileLanguageResources"

  $languageDetails = Get-RegionInfo -Name $Language

  if($null -eq $languageDetails) {
    $LanguageTag = $LanguagesDictionary.$Language 
  } else {
    $languageTag = $languageDetails[0]
    $GeoID = $languageDetails[1]
  }

  $foundLanguage = $false;

  try {
    #install language pack in case the provided language is not installed
    $installedLanguages = Get-InstalledLanguage
    foreach($languagePack in $installedLanguages) {
      $languageID = $languagePack.LanguageId
      if($languageID -eq $LanguageTag) {
        $foundLanguage = $true
        break
      }
    } 
  }
  catch {
    Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - Exception occurred while installing language packs***"
    Write-Host $PSItem.Exception
  }

  if(-Not $foundLanguage) {
    # retry in case we hit transient errors
    for($i=1; $i -le 5; $i++) {
        try {
            Write-Host "*** AVD AIB CUSTOMIZER PHASE : Set default language - Install language packs -  Attempt: $i ***"   
            Install-Language -Language $LanguageTag -ErrorAction Stop
            Write-Host "*** AVD AIB CUSTOMIZER PHASE : Set default language - Install language packs -  Installed language $LanguageCode ***"   
            break
        }
        catch {
            Write-Host "*** AVD AIB CUSTOMIZER PHASE : Set default language - Install language packs - Exception occurred***"
            Write-Host $PSItem.Exception
            continue
        }
    }
  }
  else {
     Write-Host "*** AVD AIB CUSTOMIZER PHASE : Set default language - Language pack for $LanguageTag is installed already***"
  }
  
  Set-systempreferreduilanguage -Language $LanguageTag
  Set-WinSystemLocale -SystemLocale $LanguageTag
  Set-Culture -CultureInfo $LanguageTag
  
  # Enable language Keyboard for Windows.
  UpdateUserLanguageList -languageTag $LanguageTag

  Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - $Language with $LanguageTag has been set as the default System Preferred UI Language***"

  $GeoID = (new-object System.Globalization.RegionInfo($languageTag.Split("-")[1])).GeoId
  $GeoName = (new-object System.Globalization.RegionInfo($languageTag.Split("-")[1])).Name
  UpdateRegionSettings -GeoID $GeoID -GeoName $GeoName

  # Copy user international settings to system for welcome screen and new users.
  # On Windows 11 / Server 2022+ the built-in cmdlet handles both WelcomeScreen and NewUser.
  # On Windows 10 the cmdlet is missing, so we call the Windows-team compat helper which:
  #   1) Prefers the native intl.cpl!IntlCopyInternationalSettings when present, else
  #   2) Copies HKCU\Control Panel\International into Default\NTUSER.DAT, invokes
  #      input.dll ordinal 105, and copies PreferredUILanguages/LanguageConfiguration.
  # UpdateRegionSettings above already handles the Welcome Screen (HKU\.DEFAULT\Geo) piece.
  $osBuild = [System.Environment]::OSVersion.Version.Build
  if ($osBuild -ge 22000 -and (Get-Command -Name Copy-UserInternationalSettingsToSystem -ErrorAction SilentlyContinue)) {
    Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - Windows 11 / Server 2022+ detected (build $osBuild). Copying user international settings to system ***"
    Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
    Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - Successfully copied settings to welcome screen and new user defaults ***"
  }
  else {
    Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - Pre-Windows 11 detected (build $osBuild). Invoking Windows-team NewUser compat helper ***"
    Invoke-CopyUserIntlSettingsCompatForNewUser
  }
} 
catch {
    Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - Exception occurred***"
    Write-Host $PSItem.Exception
}

if ((Test-Path -Path $templateFilePathFolder -ErrorAction SilentlyContinue)) {
    Remove-Item -Path $templateFilePathFolder -Force -Recurse -ErrorAction Continue
}

# Enable LanguageComponentsInstaller after language packs are installed
Enable-ScheduledTask -TaskName "\Microsoft\Windows\LanguageComponentsInstaller\Installation"
Enable-ScheduledTask -TaskName "\Microsoft\Windows\LanguageComponentsInstaller\ReconcileLanguageResources"

$stopwatch.Stop()
$elapsedTime = $stopwatch.Elapsed
Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - Exit Code: $LASTEXITCODE ***"
Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - Time taken: $elapsedTime ***"


#############
#    END    #
#############