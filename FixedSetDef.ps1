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

function UpdateCurrentUserDisplayLanguage($languageTag)
{
  # Set the Windows DISPLAY language for the current user (the account running this script),
  # alongside the input language (UpdateUserLanguageList) and system preferred UI language
  # (Set-systempreferreduilanguage). Set-WinUILanguageOverride writes the current user's
  # PreferredUILanguages and works on both Windows 10 and Windows 11. Takes effect at next
  # sign-in and renders only if the language's display pack is installed (Install-Language above).
  try {
    Set-WinUILanguageOverride -Language $languageTag
    Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - Set CURRENT user display language override to $languageTag (applies at next sign-in) ***"
  }
  catch
  {
    Write-Host "***Starting AVD AIB CUSTOMIZER PHASE: Set default Language - UpdateCurrentUserDisplayLanguage: Error occurred: [$($_.Exception.Message)]"
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
#      C:\Users\Default\NTUSER.DAT, invoking the named export
#      input.dll!SaveDefaultUserInputSettings (ordinal 105) to persist
#      keyboard/input state, and
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

        // input.dll!SaveDefaultUserInputSettings is a named -- but UNDOCUMENTED / unsupported --
        // export. We resolve it by name first (stable, self-documenting, how Windows' own components
        // resolve it) and fall back to ordinal 105 for any build that exports it by ordinal only.
        // It remains an internal API with no support contract.
        private const UInt16 SaveDefaultUserInputSettingsOrdinal = 105;

        [DllImport("kernel32.dll", EntryPoint = "GetProcAddress", SetLastError = true, CharSet = CharSet.Ansi)]
        private static extern IntPtr GetProcAddressByName(IntPtr module, string procName);

        [DllImport("kernel32.dll", EntryPoint = "GetProcAddress", SetLastError = true)]
        private static extern IntPtr GetProcAddressByOrdinal(IntPtr module, IntPtr ordinal);

        private static IntPtr ResolveSaveDefaultUserInputSettings(IntPtr module)
        {
            IntPtr procedure = GetProcAddressByName(module, "SaveDefaultUserInputSettings");
            if (procedure == IntPtr.Zero)
            {
                procedure = GetProcAddressByOrdinal(module, new IntPtr(SaveDefaultUserInputSettingsOrdinal));
            }

            return procedure;
        }

        [UnmanagedFunctionPointer(CallingConvention.Winapi)]
        private delegate bool SaveDefaultUserInputSettingsDelegate(IntPtr parentWindow, IntPtr sourceRegistryKey);

        public static bool IsSaveDefaultUserInputSettingsAvailable()
        {
            IntPtr inputDll = LoadInputDll();
            return ResolveSaveDefaultUserInputSettings(inputDll) != IntPtr.Zero;
        }

        public static void SaveDefaultUserInputSettings()
        {
            IntPtr inputDll = LoadInputDll();
            IntPtr procedure = ResolveSaveDefaultUserInputSettings(inputDll);
            if (procedure == IntPtr.Zero)
            {
                throw new EntryPointNotFoundException("input.dll!SaveDefaultUserInputSettings (undocumented export, name and ordinal 105) was not found.");
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
        throw 'input.dll!SaveDefaultUserInputSettings (undocumented export) is not available. The Win10 fallback cannot preserve 1:1 NewUser input-settings behavior without it.'
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

# =============================================================================
# DIAGNOSTICS - TestLangSetup.ps1
# Console-only diagnostics, in parity with Akash's FixedSetDef.ps1 (plain
# Write-Host, no file logging). We keep the extra diagnostic / version / summary
# output, but it is written to the console just like every other AVD banner --
# nothing is teed to C:\TestLangSetup.log or any other file.
# =============================================================================
$script:DefaultSnap = @{}
$script:CopyMethod = '(not reached)'
$script:InstallOutcome = '(not evaluated)'
$script:InstallVerified = $null

function Write-TestLog {
    param([string]$Message, [string]$Level = 'INFO')
    Write-Host "[TestLangSetup] [$Level] $Message"
}

Write-Host "*** Starting AVD AIB CUSTOMIZER PHASE: Set default Language ***"

# Windows / environment version info.
function Write-WindowsVersionInfo {
    Write-TestLog "===== WINDOWS VERSION INFO =====" 'DIAG'
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        Write-TestLog "Caption: $($os.Caption)" 'DIAG'
        Write-TestLog "Version: $($os.Version)  Build: $($os.BuildNumber)  Arch: $($os.OSArchitecture)" 'DIAG'
        Write-TestLog "InstallDate: $($os.InstallDate)  LastBoot: $($os.LastBootUpTime)" 'DIAG'
    } catch { Write-TestLog "Win32_OperatingSystem query failed: $($_.Exception.Message)" 'WARN' }
    try {
        $p = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        Write-TestLog "ProductName: $($p.ProductName)  DisplayVersion: $($p.DisplayVersion)  ReleaseId: $($p.ReleaseId)" 'DIAG'
        Write-TestLog "CurrentBuild: $($p.CurrentBuild).$($p.UBR)  EditionID: $($p.EditionID)  InstallationType: $($p.InstallationType)" 'DIAG'
    } catch { }
    Write-TestLog ("OSVersion(.NET): {0}  x64OS={1}  x64Proc={2}  PS={3}" -f `
        [Environment]::OSVersion.Version, [Environment]::Is64BitOperatingSystem, `
        [Environment]::Is64BitProcess, $PSVersionTable.PSVersion) 'DIAG'
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $pr = New-Object Security.Principal.WindowsPrincipal($id)
        $elev = $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        Write-TestLog "User: $($id.Name)  SID: $($id.User.Value)  Elevated: $elev" 'DIAG'
    } catch { }
}

# End-of-run summary comparing new-user display language before/after the copy.
function Write-RunSummary {
    Write-TestLog "===== RUN SUMMARY =====" 'SUMMARY'
    Write-TestLog "Requested: '$Language'  Resolved tag: '$LanguageTag'  GeoID: '$GeoID'" 'SUMMARY'
    Write-TestLog "Language pack install: $script:InstallOutcome" 'SUMMARY'
    $verifyText = if ($null -eq $script:InstallVerified) { '(not checked)' }
                  elseif ($script:InstallVerified) { "YES - '$LanguageTag' is present" }
                  else { "NO - '$LanguageTag' is NOT present on this machine" }
    Write-TestLog "Display language actually installed: $verifyText" 'SUMMARY'
    Write-TestLog "Copy performed via: $script:CopyMethod" 'SUMMARY'
    if ($script:DefaultSnap.ContainsKey('BEFORE-COMPAT-COPY') -and $script:DefaultSnap.ContainsKey('AFTER-COMPAT-COPY')) {
        $b = $script:DefaultSnap['BEFORE-COMPAT-COPY']; $a = $script:DefaultSnap['AFTER-COMPAT-COPY']
        Write-TestLog "Default profile BEFORE copy: Locale=[$($b.Locale)] Geo=[$($b.Nation)] PreferredUILanguages=[$($b.Pref)]" 'SUMMARY'
        Write-TestLog "Default profile AFTER  copy: Locale=[$($a.Locale)] Geo=[$($a.Nation)] PreferredUILanguages=[$($a.Pref)]" 'SUMMARY'
        if ("$($a.Pref)" -eq "$LanguageTag") {
            Write-TestLog "RESULT: new-user display language = [$($a.Pref)] MATCHES expected [$LanguageTag] (OK)" 'SUMMARY'
        } else {
            Write-TestLog "RESULT: new-user display language = [$($a.Pref)] != expected [$LanguageTag] (MISMATCH / regression)" 'SUMMARY'
            if ($false -eq $script:InstallVerified) {
                Write-TestLog "LIKELY CAUSE: '$LanguageTag' was never installed (install outcome: $script:InstallOutcome). The copy propagated whatever the build user actually had - it did not lose the setting." 'SUMMARY'
            }
        }
    } else {
        Write-TestLog "Compat copy did not run (no before/after snapshot) - see earlier log for why." 'SUMMARY'
    }
}

Write-WindowsVersionInfo

# Is the target language actually installed as a display (MUI) language?
# Get-InstalledLanguage only exists on Win11/Server2022+, so fall back to the MUI registry
# key, which is present on every SKU and is what the display-language stack actually reads.
function Test-LanguageInstalled {
    param([string]$Tag)
    try {
        $inst = @(Get-InstalledLanguage -ErrorAction Stop | ForEach-Object { $_.LanguageId })
        if ($inst -contains $Tag) { return $true }
    } catch { }
    $mui = @(Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\MUI\UILanguages' -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty PSChildName)
    return ($mui -contains $Tag)
}

# Snapshot of the CURRENT user + machine language state.
function Write-LanguageState {
    param([string]$Phase)
    Write-TestLog "===== LANGUAGE STATE ($Phase) =====" 'DIAG'
    Write-TestLog ("OS build={0} x64OS={1} x64Proc={2} PS={3} User={4}" -f `
        [Environment]::OSVersion.Version.Build, [Environment]::Is64BitOperatingSystem, `
        [Environment]::Is64BitProcess, $PSVersionTable.PSVersion, $env:USERNAME) 'DIAG'
    try {
        $inst = (Get-InstalledLanguage -ErrorAction Stop | ForEach-Object { $_.LanguageId }) -join ', '
        Write-TestLog "Installed languages (Get-InstalledLanguage): $inst" 'DIAG'
    } catch { Write-TestLog "Get-InstalledLanguage unavailable: $($_.Exception.Message)" 'DIAG' }
    $mui = (Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\MUI\UILanguages' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty PSChildName) -join ', '
    Write-TestLog "Installed display (MUI) packs: $mui" 'DIAG'
    try { $list = (Get-WinUserLanguageList | ForEach-Object { $_.LanguageTag }) -join ', '; Write-TestLog "Current-user language list: $list" 'DIAG' } catch { }
    $pend = (Get-ItemProperty 'HKCU:\Control Panel\Desktop' -Name PreferredUILanguagesPending -ErrorAction SilentlyContinue).PreferredUILanguagesPending -join ','
    $pref = (Get-ItemProperty 'HKCU:\Control Panel\Desktop' -Name PreferredUILanguages -ErrorAction SilentlyContinue).PreferredUILanguages -join ','
    Write-TestLog "Current-user HKCU PreferredUILanguagesPending=[$pend] PreferredUILanguages=[$pref]" 'DIAG'
    try { Write-TestLog "Current-user WinUILanguageOverride: $((Get-WinUILanguageOverride).Name)" 'DIAG' } catch { }
    try { Write-TestLog "Current-user HomeLocation GeoId: $((Get-WinHomeLocation).GeoId)" 'DIAG' } catch { }
}

# Snapshot of what NEW users will inherit (offline C:\Users\Default\NTUSER.DAT).
function Write-DefaultProfileState {
    param([string]$Phase)
    Write-TestLog "===== DEFAULT PROFILE (new-user) STATE ($Phase) =====" 'DIAG'
    $mount = 'TestLangSetup_Diag'
    if (Test-Path "Registry::HKEY_USERS\$mount") {
        & reg.exe unload "HKU\$mount" 2>&1 | Out-Null
    }
    & reg.exe load "HKU\$mount" 'C:\Users\Default\NTUSER.DAT' 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-TestLog "Could not load Default hive for diagnostics (exit $LASTEXITCODE)" 'WARN'; return }
    $locale = (Get-ItemProperty "Registry::HKEY_USERS\$mount\Control Panel\International" -Name LocaleName -ErrorAction SilentlyContinue).LocaleName
    $nation = (Get-ItemProperty "Registry::HKEY_USERS\$mount\Control Panel\International\Geo" -Name Nation -ErrorAction SilentlyContinue).Nation
    $dpref = (Get-ItemProperty "Registry::HKEY_USERS\$mount\Control Panel\Desktop" -Name PreferredUILanguages -ErrorAction SilentlyContinue).PreferredUILanguages -join ','
    $dpend = (Get-ItemProperty "Registry::HKEY_USERS\$mount\Control Panel\Desktop" -Name PreferredUILanguagesPending -ErrorAction SilentlyContinue).PreferredUILanguagesPending -join ','
    Write-TestLog "Default profile: LocaleName=[$locale] Geo.Nation=[$nation] PreferredUILanguages=[$dpref] Pending=[$dpend]" 'DIAG'
    $script:DefaultSnap[$Phase] = [pscustomobject]@{ Locale = $locale; Nation = $nation; Pref = $dpref; Pend = $dpend }
    [gc]::Collect(); [gc]::WaitForPendingFinalizers()
    $unloadOutput = & reg.exe unload "HKU\$mount" 2>&1
    if ($LASTEXITCODE -ne 0) {
        # The diagnostic must not leave the Default hive mounted: a lingering mount on the
        # same NTUSER.DAT causes ERROR_SHARING_VIOLATION when the compat copy re-loads it.
        Write-TestLog "Could not unload diagnostic Default hive HKU\$mount (exit $LASTEXITCODE): $unloadOutput" 'WARN'
    }
}

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

  Write-TestLog "Requested language: '$Language'  ->  resolved tag: '$LanguageTag'  GeoID: '$GeoID'" 'INFO'
  Write-LanguageState 'BEFORE-INSTALL'

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
    # Install-Language comes from LanguagePackManagement (Win11/Server2022+ only). Distinguish
    # "cmdlet absent on this OS" from "install genuinely failed" so the summary can say which.
    if (-not (Get-Command -Name Install-Language -ErrorAction SilentlyContinue)) {
        $script:InstallOutcome = 'CmdletNotAvailable (LanguagePackManagement is Win11/Server2022+ only)'
        Write-Host "*** AVD AIB CUSTOMIZER PHASE : Set default language - Install-Language NOT available on this OS; skipping language-pack install ***"
    }
    else {
        $installSucceeded = $false
        # retry in case we hit transient errors
        for($i=1; $i -le 5; $i++) {
            try {
                Write-Host "*** AVD AIB CUSTOMIZER PHASE : Set default language - Install language packs -  Attempt: $i ***"   
                Install-Language -Language $LanguageTag -ErrorAction Stop
                Write-Host "*** AVD AIB CUSTOMIZER PHASE : Set default language - Install language packs -  Installed language $LanguageTag ***"   
                $installSucceeded = $true
                break
            }
            catch {
                Write-Host "*** AVD AIB CUSTOMIZER PHASE : Set default language - Install language packs - Exception occurred***"
                Write-Host $PSItem.Exception
                continue
            }
        }
        if ($installSucceeded) {
            $script:InstallOutcome = 'Installed'
        }
        else {
            $script:InstallOutcome = 'FAILED after 5 attempts'
            Write-Host "*** AVD AIB CUSTOMIZER PHASE : Set default language - Install language packs - ALL 5 ATTEMPTS FAILED for $LanguageTag ***"
        }
    }
  }
  else {
     $script:InstallOutcome = 'AlreadyPresent'
     Write-Host "*** AVD AIB CUSTOMIZER PHASE : Set default language - Language pack for $LanguageTag is installed already***"
  }

  # Re-verify independently of the install cmdlet's own reporting. This is the check that
  # matters: if the display language is not actually present, the current user's pending UI
  # language never becomes $LanguageTag, and the NewUser copy below will faithfully propagate
  # en-US into the default profile - the exact shape of the reported new-user regression.
  $script:InstallVerified = Test-LanguageInstalled -Tag $LanguageTag
  if ($script:InstallVerified) {
      Write-TestLog "Post-install verification: display language '$LanguageTag' IS present on this machine" 'INFO'
  } else {
      Write-TestLog "Post-install verification: display language '$LanguageTag' is NOT present - new users will NOT get it (install outcome: $script:InstallOutcome)" 'WARN'
  }
  
  # Set-SystemPreferredUILanguage / Install-Language / Get-InstalledLanguage come from the
  # LanguagePackManagement module, which exists ONLY on Windows 11 / Server 2022+. On Windows 10
  # they are "not recognized" and throw CommandNotFoundException, which (unguarded) aborts the whole
  # script before our NewUser compat copy runs. Guard the Win11-only cmdlet so execution continues
  # on Win10 and reaches Invoke-CopyUserIntlSettingsCompatForNewUser (the whole point of this harness).
  if (Get-Command -Name Set-SystemPreferredUILanguage -ErrorAction SilentlyContinue) {
    Set-systempreferreduilanguage -Language $LanguageTag
    Write-TestLog "Set-SystemPreferredUILanguage -Language $LanguageTag succeeded" 'INFO'
  } else {
    Write-TestLog "Set-SystemPreferredUILanguage NOT available (LanguagePackManagement is Win11/Server2022+ only) - skipping on this OS; continuing to reach compat copy" 'WARN'
  }
  Set-WinSystemLocale -SystemLocale $LanguageTag
  Set-Culture -CultureInfo $LanguageTag

  Write-LanguageState 'AFTER-INSTALL-AND-SYSTEM-SET'
  
  # Enable language Keyboard for Windows.
  UpdateUserLanguageList -languageTag $LanguageTag

  # NOTE: Do NOT set Set-WinUILanguageOverride on the current (build/Packer) user. On Win10
  # (build 19045) that queues a pending full display-language switch that finalizes during the
  # post-customization reboot's first logon, blocking the WinRM session Packer needs and causing
  # "Timeout waiting for machine to restart". New users still receive the display language via the
  # NewUser compat copy of PreferredUILanguages into C:\Users\Default\NTUSER.DAT below, so DMA
  # parity for new users/region is preserved without stalling the build account's reboot logon.

  Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - $Language with $LanguageTag has been set as the default System Preferred UI Language***"

  $GeoID = (new-object System.Globalization.RegionInfo($languageTag.Split("-")[1])).GeoId
  $GeoName = (new-object System.Globalization.RegionInfo($languageTag.Split("-")[1])).Name
  UpdateRegionSettings -GeoID $GeoID -GeoName $GeoName

  # Copy user international settings to system for welcome screen and new users.
  # Prefer the in-box Copy-UserInternationalSettingsToSystem cmdlet on Windows 11 / Server 2022+
  # (build >= 22000) when it is present 
  #   1) Prefers the native intl.cpl!IntlCopyInternationalSettings entry point when available.
  #   2) Otherwise copies HKCU\Control Panel\International into Default\NTUSER.DAT, invokes
  #      input.dll!SaveDefaultUserInputSettings, and copies PreferredUILanguages/LanguageConfiguration.
  # UpdateRegionSettings above already handles the Welcome Screen (HKU\.DEFAULT\Geo) piece.
  $osBuild = [System.Environment]::OSVersion.Version.Build
  $cmdletAvailable = [bool](Get-Command -Name Copy-UserInternationalSettingsToSystem -ErrorAction SilentlyContinue)
  Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - OS build $osBuild; in-box Copy-UserInternationalSettingsToSystem available: $cmdletAvailable ***"

  Write-LanguageState 'BEFORE-COMPAT-COPY'
  Write-DefaultProfileState 'BEFORE-COMPAT-COPY'

  if ($osBuild -ge 22000 -and (Get-Command -Name Copy-UserInternationalSettingsToSystem -ErrorAction SilentlyContinue)) {
    $script:CopyMethod = 'in-box cmdlet Copy-UserInternationalSettingsToSystem'
    Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - In-box cmdlet present (build $osBuild). Copying user international settings to system via the cmdlet ***"
    Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
    Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - Successfully copied settings to welcome screen and new user defaults via the in-box cmdlet ***"
  }
  else {
    $script:CopyMethod = 'Windows-team NewUser compat helper'
    Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - In-box cmdlet gate not satisfied (build $osBuild, available: $cmdletAvailable). Invoking Windows-team NewUser compat helper ***"
    Invoke-CopyUserIntlSettingsCompatForNewUser
    Write-Host "*** AVD AIB CUSTOMIZER PHASE: Set default Language - Compat helper completed (NewUser copy to default profile) ***"
  }

  Write-DefaultProfileState 'AFTER-COMPAT-COPY'
  Write-LanguageState 'AFTER-COMPAT-COPY'
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

Write-RunSummary
Write-Host "*** TestLangSetup: run complete ***"


#############
#    END    #
#############