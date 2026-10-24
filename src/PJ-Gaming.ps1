# Windows PowerShell 5.1 compatible. Embedded in dist/PJ-Gaming.cmd by tools/build.py.
param([switch]$LibraryOnly)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$script:StateFile = $null
$script:UserSid = $null
$script:OutputBox = $null
$script:EmbeddedVideoReview = '' # PJ_EMBED_VIDEO_REVIEW

function Write-Activity([string]$Message) {
    $line = ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Message)
    if ($null -ne $script:OutputBox) { $script:OutputBox.AppendText($line + "`r`n") }
    Write-Host $line
}

function Get-TweakCatalog {
    # Windows exposes these game settings in Settings > Gaming. No timer/driver hacks.
    @(
        [pscustomobject]@{ Id='game-mode'; Group='Gaming'; Label='Game Mode'; Path='Software\Microsoft\GameBar'; Name='AutoGameModeEnabled'; Kind='DWord'; Data=1 },
        [pscustomobject]@{ Id='capture'; Group='Gaming'; Label='Windows game recording'; Path='Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name='AppCaptureEnabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='game-dvr'; Group='Gaming'; Label='Game DVR recording'; Path='System\GameConfigStore'; Name='GameDVR_Enabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='transparency'; Group='Appearance'; Label='Transparency effects OFF'; Path='Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name='EnableTransparency'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='app-dark-mode'; Group='Appearance'; Label='App dark mode'; Path='Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name='AppsUseLightTheme'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='system-dark-mode'; Group='Appearance'; Label='Windows dark mode'; Path='Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name='SystemUsesLightTheme'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='dynamic-lighting'; Group='Appearance'; Label='Windows Dynamic Lighting OFF'; Path='Software\Microsoft\Lighting'; Name='AmbientLightingEnabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='foreground-lighting'; Group='Appearance'; Label='Foreground-app lighting control OFF'; Path='Software\Microsoft\Lighting'; Name='ControlledByForegroundApp'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='background-type'; Group='Appearance'; Label='Desktop background: Solid color (not Spotlight)'; Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers'; Name='BackgroundType'; Kind='DWord'; Data=1 },
        [pscustomobject]@{ Id='desktop-wallpaper'; Group='Appearance'; Label='Desktop picture disabled for solid color'; Path='Control Panel\Desktop'; Name='Wallpaper'; Kind='String'; Data='' },
        [pscustomobject]@{ Id='wallpaper-style'; Group='Appearance'; Label='Wallpaper style reset for solid background'; Path='Control Panel\Desktop'; Name='WallpaperStyle'; Kind='String'; Data='0' },
        [pscustomobject]@{ Id='wallpaper-tile'; Group='Appearance'; Label='Wallpaper tiling OFF'; Path='Control Panel\Desktop'; Name='TileWallpaper'; Kind='String'; Data='0' },
        [pscustomobject]@{ Id='background-color'; Group='Appearance'; Label='Solid background color: black'; Path='Control Panel\Colors'; Name='Background'; Kind='String'; Data='0 0 0' },
        [pscustomobject]@{ Id='lockscreen-spotlight'; Group='Appearance'; Label='Lock-screen Spotlight rotation OFF'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='RotatingLockScreenEnabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='lockscreen-overlay'; Group='Appearance'; Label='Lock-screen Spotlight tips OFF'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='RotatingLockScreenOverlayEnabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='lockscreen-tips'; Group='Appearance'; Label='Lock-screen fun facts and suggestions OFF'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-338387Enabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='advertising-id'; Group='Privacy'; Label='Advertising ID OFF'; Path='Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name='Enabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='tailored-experiences'; Group='Privacy'; Label='Tailored diagnostic recommendations OFF'; Path='Software\Microsoft\Windows\CurrentVersion\Privacy'; Name='TailoredExperiencesWithDiagnosticDataEnabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='settings-suggestions'; Group='Privacy'; Label='Windows Settings suggestions OFF'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-338393Enabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='settings-suggestions-secondary'; Group='Privacy'; Label='Additional Settings suggestions OFF'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-353694Enabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='settings-suggestions-tertiary'; Group='Privacy'; Label='Settings content suggestions OFF'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-353696Enabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='windows-welcome'; Group='Privacy'; Label='Post-update welcome suggestions OFF'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-310093Enabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='windows-tips'; Group='Privacy'; Label='Windows tips content OFF'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-338389Enabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='windows-soft-landing'; Group='Privacy'; Label='Windows tips and suggestions OFF'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SoftLandingEnabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='finish-setup'; Group='Privacy'; Label='Finish-setting-up prompts OFF'; Path='Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement'; Name='ScoobeSystemSettingEnabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='search-history'; Group='Privacy'; Label='New device search-history recording OFF'; Path='Software\Microsoft\Windows\CurrentVersion\SearchSettings'; Name='IsDeviceSearchHistoryEnabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='personal-cloud-search'; Group='Privacy'; Label='Personal Microsoft-account cloud search OFF'; Path='Software\Microsoft\Windows\CurrentVersion\SearchSettings'; Name='IsMSACloudSearchEnabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='work-cloud-search'; Group='Privacy'; Label='Work/school cloud search OFF'; Path='Software\Microsoft\Windows\CurrentVersion\SearchSettings'; Name='IsAADCloudSearchEnabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='search-highlights'; Group='Privacy'; Label='Search highlights OFF'; Path='Software\Microsoft\Windows\CurrentVersion\SearchSettings'; Name='IsDynamicSearchBoxEnabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='toast-notifications'; Group='Notifications'; Label='App toast notifications OFF (important alerts may be missed)'; Path='Software\Microsoft\Windows\CurrentVersion\PushNotifications'; Name='ToastEnabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='mouse-acceleration'; Group='Mouse'; Label='Enhanced pointer precision OFF'; Path='Control Panel\Mouse'; Name='MouseSpeed'; Kind='String'; Data='0' },
        [pscustomobject]@{ Id='mouse-threshold-one'; Group='Mouse'; Label='Pointer acceleration threshold 1 OFF'; Path='Control Panel\Mouse'; Name='MouseThreshold1'; Kind='String'; Data='0' },
        [pscustomobject]@{ Id='mouse-threshold-two'; Group='Mouse'; Label='Pointer acceleration threshold 2 OFF'; Path='Control Panel\Mouse'; Name='MouseThreshold2'; Kind='String'; Data='0' },
        [pscustomobject]@{ Id='chrome-background'; Group='Browsers'; Label='Chrome background apps'; Path='Software\Policies\Google\Chrome'; Name='BackgroundModeEnabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='edge-background'; Group='Browsers'; Label='Edge background apps'; Path='Software\Policies\Microsoft\Edge'; Name='BackgroundModeEnabled'; Kind='DWord'; Data=0 },
        [pscustomobject]@{ Id='edge-startup'; Group='Browsers'; Label='Edge Startup Boost'; Path='Software\Policies\Microsoft\Edge'; Name='StartupBoostEnabled'; Kind='DWord'; Data=0 }
    )
}

function Get-SelectedTweaks([bool]$Gaming, [bool]$Appearance, [bool]$Browsers,
    [bool]$Privacy=$false, [bool]$Notifications=$false, [bool]$Mouse=$false) {
    Get-TweakCatalog | Where-Object {
        (($_.Group -eq 'Gaming') -and $Gaming) -or
        (($_.Group -eq 'Appearance') -and $Appearance) -or
        (($_.Group -eq 'Browsers') -and $Browsers) -or
        (($_.Group -eq 'Privacy') -and $Privacy) -or
        (($_.Group -eq 'Notifications') -and $Notifications) -or
        (($_.Group -eq 'Mouse') -and $Mouse)
    }
}

function Get-VideoReviewText {
    if (-not [string]::IsNullOrEmpty($script:EmbeddedVideoReview)) {
        return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($script:EmbeddedVideoReview))
    }
    # Developer source reads the same document that the builder embeds offline.
    return [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../docs/video-review.md'))
}

function Get-RegistryState([string]$Path, [string]$Name, [switch]$Machine) {
    $base = [Microsoft.Win32.Registry]::CurrentUser
    if ($Machine) { $base = [Microsoft.Win32.Registry]::LocalMachine }
    $key = $base.OpenSubKey($Path, $false)
    try {
        if (($null -eq $key) -or ($key.GetValueNames() -notcontains $Name)) {
            return [pscustomobject]@{ Exists=$false; Kind=$null; Data=$null }
        }
        $kind = $key.GetValueKind($Name).ToString()
        $data = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        # JSON cannot exactly round-trip every 64-bit integer through every reader.
        if ($kind -eq 'QWord') { $data = $data.ToString([Globalization.CultureInfo]::InvariantCulture) }
        return [pscustomobject]@{ Exists=$true; Kind=$kind; Data=$data }
    } finally { if ($null -ne $key) { $key.Dispose() } }
}

function Set-RegistryState([string]$Path, [string]$Name, $State) {
    if (-not $State.Exists) {
        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($Path, $true)
        try { if ($null -ne $key) { $key.DeleteValue($Name, $false) } }
        finally { if ($null -ne $key) { $key.Dispose() } }
        return # Never delete a registry branch or other people's values.
    }
    $kind = [Microsoft.Win32.RegistryValueKind][Enum]::Parse([Microsoft.Win32.RegistryValueKind], [string]$State.Kind)
    $data = $State.Data
    switch ($State.Kind) {
        'DWord' { $data = [int]$data }
        'QWord' { $data = [long]::Parse([string]$data, [Globalization.CultureInfo]::InvariantCulture) }
        'Binary' { $data = [byte[]]$data }
        'None' { $data = [byte[]]$data }
        'MultiString' { $data = [string[]]$data }
        'String' { $data = [string]$data }
        'ExpandString' { $data = [string]$data }
    }
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($Path)
    try { $key.SetValue($Name, $data, $kind) }
    finally { $key.Dispose() }
}

function Test-SameState($A, $B) {
    if ([bool]$A.Exists -ne [bool]$B.Exists) { return $false }
    if (-not $A.Exists) { return $true }
    if ($A.Kind -ne $B.Kind) { return $false }
    $left = ConvertTo-Json -InputObject $A.Data -Compress -Depth 10
    $right = ConvertTo-Json -InputObject $B.Data -Compress -Depth 10
    return ($left -ceq $right)
}

function New-Journal {
    [pscustomobject]@{ Version=1; UserSid=$script:UserSid; Entries=@(); Power=$null }
}

function Read-Journal {
    if (-not [IO.File]::Exists($script:StateFile)) { return (New-Journal) }
    $journal = [IO.File]::ReadAllText($script:StateFile) | ConvertFrom-Json
    if (($journal.Version -ne 1) -or ($journal.UserSid -ne $script:UserSid)) {
        throw 'Backup belongs to a different account or version. No changes made.'
    }
    $ids = @((Get-TweakCatalog) | ForEach-Object { $_.Id })
    $seen = @{}
    foreach ($entry in @($journal.Entries)) {
        if (($ids -notcontains $entry.Id) -or $seen.ContainsKey($entry.Id)) {
            throw 'Unrecognized or duplicate backup entry. No changes made.'
        }
        $seen[$entry.Id] = $true
        if ($entry.Status -notin @('Pending', 'Applied', 'Restored')) { throw 'Invalid backup status.' }
        foreach ($state in @($entry.Original, $entry.Target)) {
            if (($state.Exists -isnot [bool]) -or ($state.Exists -and ($state.Kind -notin @('DWord','QWord','String','ExpandString','Binary','None','MultiString')))) {
                throw 'Invalid registry backup data.'
            }
        }
        $spec = (Get-TweakCatalog) | Where-Object { $_.Id -eq $entry.Id }
        $expected = [pscustomobject]@{ Exists=$true; Kind=$spec.Kind; Data=$spec.Data }
        if (-not (Test-SameState $entry.Target $expected)) { throw 'Unexpected backup target. No changes made.' }
    }
    if ($null -ne $journal.Power) {
        if (($journal.Power.Original -notmatch '^[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$') -or
            ($journal.Power.Target -ne '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c') -or
            ($journal.Power.Status -notin @('Pending', 'Applied', 'Restored'))) { throw 'Invalid power-plan backup.' }
    }
    return $journal
}

function Save-Journal($Journal) {
    # Write-ahead journal: if persisting the original fails, do not touch the setting.
    $directory = Split-Path -Parent $script:StateFile
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $temp = $script:StateFile + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        $json = ConvertTo-Json -InputObject $Journal -Depth 20
        [IO.File]::WriteAllText($temp, $json, [Text.UTF8Encoding]::new($false))
        if ([IO.File]::Exists($script:StateFile)) { [IO.File]::Replace($temp, $script:StateFile, [System.Management.Automation.Language.NullString]::Value) }
        else { [IO.File]::Move($temp, $script:StateFile) }
    } finally { if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) } }
}

function Test-ManagedDevice {
    # Conservative: do not add browser policies on domain/Azure AD/MDM managed PCs.
    $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    if ($computer.PartOfDomain) { return $true }
    foreach ($path in @('SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo', 'SOFTWARE\Microsoft\Provisioning\OMADM\Accounts')) {
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($path)
        try { if (($null -ne $key) -and ($key.SubKeyCount -gt 0)) { return $true } }
        finally { if ($null -ne $key) { $key.Dispose() } }
    }
    return $false
}

function Invoke-RegistryTweak($Journal, $Spec) {
    $entry = @($Journal.Entries | Where-Object { $_.Id -eq $Spec.Id })
    if ($entry.Count -gt 0) { $entry = $entry[0] } else { $entry = $null }
    $current = Get-RegistryState $Spec.Path $Spec.Name
    $target = [pscustomobject]@{ Exists=$true; Kind=$Spec.Kind; Data=$Spec.Data }
    $activeEntry = ($null -ne $entry) -and ($entry.Status -ne 'Restored')
    if ($Spec.Group -eq 'Browsers') {
        $machine = Get-RegistryState $Spec.Path $Spec.Name -Machine
        if ($machine.Exists -or ($current.Exists -and -not $activeEntry)) {
            Write-Activity ('SKIPPED: {0}; an existing browser policy takes precedence.' -f $Spec.Label)
            return
        }
    }
    if ($activeEntry -and -not (Test-SameState $current $entry.Target) -and -not (Test-SameState $current $entry.Original)) {
        Write-Activity ('SKIPPED: {0}; it was changed since this tool last ran.' -f $Spec.Label)
        return
    }
    if (Test-SameState $current $target) {
        Write-Activity ('UNCHANGED: {0}; already set.' -f $Spec.Label)
        return
    }
    if (-not $activeEntry) {
        if ($null -eq $entry) {
            $entry = [pscustomobject]@{ Id=$Spec.Id; Original=$current; Target=$target; Status='Pending' }
            $Journal.Entries = @($Journal.Entries) + @($entry)
        } else { $entry.Original = $current; $entry.Target = $target; $entry.Status = 'Pending' }
    } else { $entry.Status = 'Pending' }
    Save-Journal $Journal
    Set-RegistryState $Spec.Path $Spec.Name $target
    if (-not (Test-SameState (Get-RegistryState $Spec.Path $Spec.Name) $target)) { throw ('Read-back failed: ' + $Spec.Label) }
    $entry.Status = 'Applied'
    Save-Journal $Journal
    Write-Activity ('APPLIED: ' + $Spec.Label)
}

function Get-ActivePowerPlan {
    $output = & "$env:SystemRoot\System32\powercfg.exe" /getactivescheme 2>&1
    if ($LASTEXITCODE -ne 0) { throw ('Cannot read power plan: ' + ($output -join ' ')) }
    $match = [regex]::Match(($output -join ' '), '[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}')
    if (-not $match.Success) { throw 'Could not identify current power plan.' }
    return $match.Value.ToLowerInvariant()
}

function Set-ActivePowerPlan([string]$Guid) {
    $output = & "$env:SystemRoot\System32\powercfg.exe" /setactive $Guid 2>&1
    if ($LASTEXITCODE -ne 0) { throw ('Power plan could not be selected: ' + ($output -join ' ')) }
    if ((Get-ActivePowerPlan) -ne $Guid) { throw 'Power plan did not change.' }
}

function Get-AvailablePowerPlans {
    $output = & "$env:SystemRoot\System32\powercfg.exe" /list 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Could not list available power plans.' }
    return ($output -join ' ')
}

function Invoke-PowerTweak($Journal) {
    $target = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    $current = Get-ActivePowerPlan
    if ($current -eq $target) { Write-Activity 'UNCHANGED: High performance already selected.'; return }
    # Do not create legacy plans on Modern Standby devices or override battery limits.
    $available = Get-AvailablePowerPlans
    if ($available -notmatch $target) { Write-Activity 'SKIPPED: this PC does not expose the standard High performance plan.'; return }
    if (($null -ne $Journal.Power) -and ($Journal.Power.Status -ne 'Restored')) {
        if (($current -ne $Journal.Power.Original) -and ($current -ne $Journal.Power.Target)) {
            Write-Activity 'SKIPPED: power plan was changed since this tool last ran.'; return
        }
        $Journal.Power.Status = 'Pending'
    } else { $Journal.Power = [pscustomobject]@{ Original=$current; Target=$target; Status='Pending' } }
    Save-Journal $Journal
    Set-ActivePowerPlan $target
    $Journal.Power.Status = 'Applied'
    Save-Journal $Journal
    Write-Activity 'APPLIED: High performance. Monitor heat, power use, and frame times.'
}

function Invoke-Undo($Journal) {
    foreach ($entry in @($Journal.Entries)) {
        if ($entry.Status -eq 'Restored') { continue }
        $spec = (Get-TweakCatalog) | Where-Object { $_.Id -eq $entry.Id }
        try {
            $current = Get-RegistryState $spec.Path $spec.Name
            if (Test-SameState $current $entry.Target) {
                Set-RegistryState $spec.Path $spec.Name $entry.Original
                if (-not (Test-SameState (Get-RegistryState $spec.Path $spec.Name) $entry.Original)) { throw 'Restore read-back failed.' }
            } elseif (-not (Test-SameState $current $entry.Original)) {
                Write-Activity ('SKIPPED UNDO: {0}; changed outside this tool. Backup retained.' -f $spec.Label)
                continue
            }
            $entry.Status = 'Restored'
            Save-Journal $Journal
            Write-Activity ('RESTORED: ' + $spec.Label)
        } catch { Write-Activity ('FAILED UNDO: {0}: {1}' -f $spec.Label, $_.Exception.Message) }
    }
    if (($null -ne $Journal.Power) -and ($Journal.Power.Status -ne 'Restored')) {
        try {
            $current = Get-ActivePowerPlan
            if ($current -eq $Journal.Power.Target) { Set-ActivePowerPlan $Journal.Power.Original }
            elseif ($current -ne $Journal.Power.Original) { Write-Activity 'SKIPPED UNDO: power plan changed outside this tool. Backup retained.'; return }
            $Journal.Power.Status = 'Restored'
            Save-Journal $Journal
            Write-Activity 'RESTORED: original power plan.'
        } catch { Write-Activity ('FAILED UNDO: power plan: ' + $_.Exception.Message) }
    }
}

function Get-SystemReport {
    $lines = @('PJ Gaming - local hardware report', ('Generated: ' + (Get-Date -Format o)), '')
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $pc = Get-CimInstance Win32_ComputerSystem
        $lines += ('Windows: {0}, build {1}' -f $os.Caption, $os.BuildNumber)
        $lines += ('RAM: {0:N1} GB' -f ($pc.TotalPhysicalMemory / 1GB))
        foreach ($cpu in @(Get-CimInstance Win32_Processor)) { $lines += ('CPU: ' + $cpu.Name) }
        foreach ($gpu in @(Get-CimInstance Win32_VideoController)) { $lines += ('GPU: {0}; driver {1}; reported display {2}x{3} @ {4} Hz' -f $gpu.Name, $gpu.DriverVersion, $gpu.CurrentHorizontalResolution, $gpu.CurrentVerticalResolution, $gpu.CurrentRefreshRate) }
    } catch { $lines += ('Hardware query unavailable: ' + $_.Exception.Message) }
    try {
        foreach ($board in @(Get-CimInstance Win32_BaseBoard)) {
            $lines += ('Motherboard: {0} {1}; revision {2}' -f $board.Manufacturer, $board.Product, $board.Version)
        }
        foreach ($bios in @(Get-CimInstance Win32_BIOS)) {
            $lines += ('BIOS: {0}; released {1}' -f $bios.SMBIOSBIOSVersion, $bios.ReleaseDate)
        }
        foreach ($memory in @(Get-CimInstance Win32_PhysicalMemory)) {
            $lines += ('RAM module: {0:N1} GB; configured speed reported {1}; rated speed reported {2}' -f ($memory.Capacity / 1GB), $memory.ConfiguredClockSpeed, $memory.Speed)
        }
    } catch { $lines += ('Motherboard/BIOS/RAM detail unavailable: ' + $_.Exception.Message) }
    try { $lines += ('Power plan: ' + (Get-ActivePowerPlan)) } catch { $lines += $_.Exception.Message }
    $lines += @('', 'Physical network adapters (read-only; no addresses collected):')
    try {
        foreach ($adapter in @(Get-NetAdapter -Physical -ErrorAction Stop)) {
            $lines += ('Adapter: {0}; state: {1}; link speed: {2}' -f $adapter.InterfaceDescription, $adapter.Status, $adapter.LinkSpeed)
        }
    } catch { $lines += ('Adapter report unavailable: ' + $_.Exception.Message) }
    try {
        foreach ($driver in @(Get-CimInstance Win32_PnPSignedDriver -Filter "DeviceClass='NET'")) {
            $lines += ('Network driver: {0}; provider {1}; version {2}; date {3}' -f $driver.DeviceName, $driver.DriverProviderName, $driver.DriverVersion, $driver.DriverDate)
        }
    } catch { $lines += ('Network driver report unavailable: ' + $_.Exception.Message) }
    $lines += @('', 'No IP/MAC addresses, Wi-Fi names, identifying serial numbers, or credentials collected.', 'Network configuration is not changed. Link speed is not a latency or Internet-speed test.', 'Display rates are driver-reported; verify each monitor in Windows Display settings.', 'No benchmark has been run. This report does not measure input latency or FPS.')
    return ($lines -join "`r`n")
}

function Get-PersonalGuide {
    return @'
PJ'S PERSONAL GAMING + NETWORK REVIEW
Profile supplied by you: Ryzen 7 9800X3D, RTX 5070, 32 GB RAM, Windows 11 desktop.
Display: 2560 x 1440 at 360 Hz (advertised 0.03 ms pixel response). Ethernet.
Main game: Fortnite. Also: Dead by Daylight, Call of Duty, Uncharted.
These are manual review options, not hidden changes made by this tool.

START HERE
- Use the hardware report to confirm the detected hardware and Windows build.
- Keep Balanced as the initial power plan on this Ryzen X3D desktop. High
  performance is only an optional comparison, not a universal Ryzen upgrade.
- Install current AMD chipset and NVIDIA drivers from AMD/NVIDIA official
  sources. Do not stack driver updaters, timer tools, or registry tweak packs.
- Windows Settings > System > Display > Advanced display: select your 2560 x 1440
  monitor and verify 360 Hz is actually selected. Use a cable/port combination
  supported by your monitor and GPU for this mode. The tool does not change modes.
- A 360 Hz refresh interval is about 2.78 ms. Your advertised 0.03 ms pixel response
  is not total system input latency. A registry profile cannot guarantee that rating.
- Settings > Apps > Startup: review unused chat, launchers and sync apps. Disable
  only apps you recognize and do not need. Keep security, peripheral software you
  rely on, game launchers needed by your game, audio and anti-cheat components.
- Keep the Windows pagefile system-managed and keep free space on your SSD.
- If your Windows release no longer receives security updates, update to a
  supported release. This optimizer does not disable or change Windows Update.

YOUR APPEARANCE PRESET (SELECTED BY DEFAULT)
- Transparency effects OFF; Windows and supported apps use dark mode.
- Windows Dynamic Lighting and foreground-app lighting control OFF. RGB controlled
  by device firmware or third-party
  peripheral software may need switching off in that software separately.
- Desktop background is Solid color, BLACK, rather than Picture or Spotlight.
  Lock-screen Spotlight rotation/tips are off; no new lock-screen image is chosen.
  Use Settings > Personalization > Lock screen to choose a particular Picture.
- Restart Windows after Apply or Undo. These registry preferences are not forced
  into running apps; no Explorer kill, theme file, or wallpaper API adds hidden
  changes outside the backup. Settings can vary with Windows releases and policy.
- Verify Settings > Personalization > Colors, Background, Dynamic Lighting and
  Lock screen after restarting. Apps with their own themes may need manual changes.
- These are your appearance preferences, not a guaranteed gaming FPS improvement.

VIDEO-BASED OPTIONAL PRESETS
- Privacy/search: advertising ID, tailored recommendations, Windows welcome/tips,
  setup prompts, new device search history, account cloud search and search
  highlights OFF. Existing search history is not deleted. Account-backed Windows
  Search results can disappear; game/browser networking is not changed.
- Quiet notifications: app toast notifications OFF. You can miss important alerts;
  security services and the Windows Security tray are not disabled.
- Mouse: Enhanced pointer precision and its acceleration thresholds OFF. Pointer
  speed, DPI, polling rate and game sensitivity stay unchanged. Desktop movement
  can feel different; raw-input games typically ignore Windows pointer acceleration.
- All three are opt-in and use the same saved-originals/Undo mechanism. Restart
  after applying or undoing. Privacy preferences are not an FPS benchmark result.
- The Video review tab accounts for every transcript section, including manual
  permissions/diagnostics, Discord overlays, audio, drivers, firmware and BIOS.
- Game Mode stays ON in the default profile. The video's OFF recommendation is
  a manual A/B test, not a universal setting for this Ryzen/Windows configuration.
- Hidden PTU Apply-all, services, game, NVIDIA and paid presets cannot be copied
  exactly from a transcript that does not disclose their settings.

FORTNITE / RTX 5070
- Start with NVIDIA Reflex ON in Fortnite. In supported games Reflex manages the
  queue; do not assume forcing NVIDIA Control Panel Low Latency Mode Ultra on top
  adds a benefit. ON + BOOST increases power use; only keep it if measurements help.
- Compare Performance and DirectX 12 rendering at the same resolution. Mode names
  and availability can change by game version. Allow shaders to compile after a
  renderer or driver change before judging stutter. Do not erase shader caches as
  a routine optimization.
- Start comparison at native 2560 x 1440. If GPU-limited, reduce expensive effects
  and then compare a lower render resolution or game-supported upscaling. Keep the
  display output at its native mode; assess the image clarity tradeoff yourself.
- For competitive visibility/FPS, lower shadows and expensive lighting features
  first. Start with ray tracing off if maximum competitive FPS is the priority.
  Choose textures based on VRAM use rather than blindly selecting everything Low.
- For competitive input response, start with Frame Generation OFF. It increases
  displayed frames but does not increase the input-sampling rate at the same pace.
- Competitive starting point: Reflex ON, Frame Generation OFF, and in-game VSync
  OFF if tearing is acceptable. At 360 Hz compare uncapped FPS with a 360 FPS cap
  in the same scene. If heavy gameplay cannot hold that rate, compare a lower stable
  cap, for example 300. A 360 Hz display does not require forcing 360 FPS everywhere.
- Optional tear-free alternative, only if your monitor supports G-SYNC/compatible
  VRR: enable the supported VRR setup, use NVIDIA Control Panel VSync ON for the
  game with in-game VSync OFF, and stay below the 360 Hz ceiling. A 357 FPS cap is
  a starting test, not a guarantee against hitting the ceiling. Reflex can already
  limit FPS in this configuration; if it does, avoid stacking another limiter
  unnecessarily. Verify the actual frame rate, smoothness and latency. Keep a lower
  sustainable cap if needed. Do not combine this with the VSync-OFF competitive
  path and assume both are the same setup. The tool changes neither configuration.
- Use the in-game latency/Reflex statistics if available. OS registry writes
  cannot establish or guarantee click-to-photon latency.

OTHER GAMES
- Call of Duty: use its native Reflex option if present; avoid third-party hooks.
- Dead by Daylight: respect game-supported FPS/display options and anti-cheat.
  Do not edit protected files or use injection tools to force hidden settings.
- Uncharted: compare native resolution and DLSS Quality/Balanced if available.
  DLSS can reduce GPU load at an image-quality cost. Adjust per game, not globally.
- Leave HAGS, fullscreen optimizations, MPO, core parking and GPU driver profiles
  at current defaults unless a repeatable problem calls for an individual test.

CHROME + EDGE
- The optional tool setting stops background apps after the browser closes, and
  disables Edge Startup Boost. It does not close tabs or uninstall extensions.
- Browser launch can take longer. Background extensions/notifications may stop
  while the browser is closed. Policies may show 'Managed by your organization'.
- Keep browser hardware acceleration enabled unless you are diagnosing a driver
  problem. Disabling it can move video/compositing work onto the CPU.
- Review unused extensions and active tabs. Close video streams while gaming.
  Memory Saver / sleeping tabs are optional browser settings with per-site tradeoffs;
  the tool does not overwrite your browser profile, passwords, cookies or preferences.

NETWORKING OPTIONS FOR REVIEW -- NO AUTOMATIC NETWORK CHANGES
- You already use Ethernet. Check the adapter report for the expected link speed
  and investigate disconnects or packet loss before changing adapter properties.
  Link speed does not measure Internet speed or ping to a game server. Leave
  working speed/duplex autonegotiation and vendor adapter defaults in place.
- Pause your own large downloads, game updates, streaming and cloud uploads while
  playing. Do not disable Windows Update services; schedule updates in Settings.
- Pick the game's appropriate nearby server region when that option is available.
- Compare game ping, jitter and packet loss both while idle and during an upload.
  If delay spikes only under load, review supported router SQM/QoS options. SQM can
  reduce throughput and use router CPU; configure it from measured connection speeds.
- Changing DNS can affect hostname lookup; it is not a reliable fix for an
  established game's server ping. Keep your current DNS unless diagnosing a DNS issue.
- Keep TCP autotuning, RSS, adapter offloads, MTU, IPv6 and adapter interrupt settings
  at working defaults. Many games use UDP. No universal TCP registry tweak improves
  all games; interrupt-moderation/offload changes need adapter-specific measurements.
- Do not use port-forward/DMZ/UPnP changes as a generic FPS or input-delay tweak.
  This tool never changes ports, firewall, DNS, TCP, Wi-Fi, adapter settings or routing.

HOW TO CHECK WHETHER A CHANGE HELPS
1. Before changing anything, record the same game's benchmark/replay or a repeatable
   gameplay route, same resolution/settings, and similar background apps/temperatures.
2. Record average FPS, 1% lows/frame-time spikes and in-game latency/ping statistics
   where available. Repeat several runs to understand normal variation.
3. Apply only the options you want, restart Windows, let shaders finish compiling,
   and repeat. Keep a change only when the measurements or required behavior improve.
4. Reopen PJ-Gaming.cmd > Undo my changes to restore the tool's saved settings.
   Manual game/router/driver changes are NOT covered by the tool's Undo.

SECURITY AND RECOVERY
No service disabling, debloating, security/Defender changes, update changes,
overclocking, BIOS changes, network writes, timers/HPET/BCDEdit changes, downloads,
account changes, data cleanup, automatic restart or forced application closing.
The saved backup is per Windows account: %LOCALAPPDATA%\PJ-Tweaks\backup-v1.json.
Keep it for Undo. Undo skips settings changed later by another app or by you.
Browser/game settings can require restarting their apps or Windows to take effect.
'@
}

if ($LibraryOnly) { return }
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'This tool requires Windows 10 or Windows 11.' }
if ([Environment]::OSVersion.Version.Build -lt 10240) { throw 'This tool requires Windows 10 or Windows 11.' }
$script:UserSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { throw 'LOCALAPPDATA is not available.' }
$script:StateFile = Join-Path $env:LOCALAPPDATA 'PJ-Tweaks\backup-v1.json'

# Serialize instances so two windows cannot race and replace the original baseline.
$mutex = [Threading.Mutex]::new($false, ('Local\PJ-Gaming-' + $script:UserSid))
$locked = $false
try {
    try { $locked = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $locked = $true }
    if (-not $locked) { throw 'PJ Gaming is already open for this account. Use that window.' }
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [Windows.Forms.Application]::EnableVisualStyles()
    $form = New-Object Windows.Forms.Form
    $form.Text = 'PJ Gaming | 9800X3D + RTX 5070 | Video review'
    $form.ClientSize = New-Object Drawing.Size(980, ([Math]::Min(900, [Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Height - 80)))
    $form.MinimumSize = New-Object Drawing.Size(890, 650)
    $form.StartPosition = 'CenterScreen'
    $form.Font = New-Object Drawing.Font('Segoe UI', 10)

    $layout = New-Object Windows.Forms.TableLayoutPanel
    $layout.Dock = 'Fill'; $layout.Padding = New-Object Windows.Forms.Padding(12)
    $layout.ColumnCount = 1; $layout.RowCount = 7
    $layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    foreach ($height in @(78, -1, 48, 44, 44, 150, 44)) {
        if ($height -eq -1) { $style = New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100) }
        else { $style = New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $height) }
        $layout.RowStyles.Add($style) | Out-Null
    }
    $form.Controls.Add($layout)
    $header = New-Object Windows.Forms.Label
    $header.Dock = 'Fill'
    $header.Text = "Your desktop: 9800X3D | RTX 5070 | 32 GB | 1440p 360 Hz | Ethernet | Windows 11`r`nApply needs no downloads or admin; some manual tools need admin. No guaranteed FPS/latency gain.`r`nVideo review explains manual steps, unknown PTU presets and hardware-specific differences."
    $layout.Controls.Add($header, 0, 0)

    $tabs = New-Object Windows.Forms.TabControl
    $tabs.Dock = 'Fill'
    $tweaksTab = New-Object Windows.Forms.TabPage
    $tweaksTab.Text = 'Tweaks'
    $reviewTab = New-Object Windows.Forms.TabPage
    $reviewTab.Text = 'Video review / manual steps'
    $tabs.TabPages.Add($tweaksTab); $tabs.TabPages.Add($reviewTab)
    $layout.Controls.Add($tabs, 0, 1)
    $optionsPanel = New-Object Windows.Forms.Panel
    $optionsPanel.Dock = 'Fill'; $optionsPanel.AutoScroll = $true
    $optionsPanel.AutoScrollMinSize = New-Object Drawing.Size(820, 650)
    $tweaksTab.Controls.Add($optionsPanel)

    function Add-Option([string]$Text, [string]$Description, [bool]$Checked, [int]$Y) {
        $check = New-Object Windows.Forms.CheckBox
        $check.Text = $Text; $check.Checked = $Checked
        $check.Location = New-Object Drawing.Point(10, $Y)
        $check.Size = New-Object Drawing.Size(810, 28)
        $optionsPanel.Controls.Add($check)
        $descriptionLabel = New-Object Windows.Forms.Label
        $descriptionLabel.Text = $Description
        $descriptionLabel.Location = New-Object Drawing.Point(30, ($Y + 30))
        $descriptionLabel.Size = New-Object Drawing.Size(790, 52)
        $optionsPanel.Controls.Add($descriptionLabel)
        return $check
    }
    $gaming = Add-Option 'Gaming: Game Mode ON; Windows game recording OFF' 'Keeps the existing recommended baseline. The video says Game Mode OFF; its manual comparison and HAGS test are explained in Video review. No GPU driver settings are changed.' $true 8
    $appearance = Add-Option 'Appearance: dark mode; transparency / Dynamic Lighting OFF; solid BLACK desktop' 'Also stops Windows foreground-app lighting control and lock-screen Spotlight rotation/tips. Restart Windows after Apply or Undo. Vendor-controlled RGB and apps with their own themes have separate controls.' $true 100
    $browsers = Add-Option 'Chrome / Edge: background apps OFF; Edge Startup Boost OFF' 'Optional policies may show "Managed by your organization", slow browser startup or stop closed-browser notifications. Existing target policies and detected managed PCs are skipped. Hardware acceleration stays unchanged.' $false 192
    $privacy = Add-Option 'Privacy: advertising, recommendations, search history / cloud results / highlights OFF' 'Optional privacy choices can remove account-backed Windows Search results. Existing history is not deleted. Speech, inking dictionaries, diagnostics levels, app permissions and microphone/camera access stay unchanged.' $false 284
    $notifications = Add-Option 'Quiet desktop: Windows app toast notifications OFF' 'Optional: app notifications and reminders may be missed. This changes your notification preference, not security services or firewall settings. Check Notifications settings after restarting.' $false 376
    $mouse = Add-Option 'Mouse: Enhance pointer precision OFF (preserve pointer speed)' 'Optional: disables Windows pointer acceleration and its thresholds. Desktop aiming can feel different; modern raw-input games usually ignore this Windows setting. Restart or sign out to apply.' $false 468
    $power = Add-Option 'Power: use existing High performance plan (AC-powered desktop only)' 'Keep Balanced as your Ryzen X3D starting point. This optional comparison can increase heat and power use. Laptops and PCs without the standard High performance plan are skipped.' $false 560

    $reviewText = New-Object Windows.Forms.TextBox
    $reviewText.Dock = 'Fill'; $reviewText.Multiline = $true; $reviewText.ReadOnly = $true
    $reviewText.ScrollBars = 'Vertical'; $reviewText.WordWrap = $true
    $reviewText.Font = New-Object Drawing.Font('Consolas', 10)
    try { $reviewText.Text = ((Get-VideoReviewText) -replace '\r?\n', "`r`n") }
    catch { $reviewText.Text = 'Video review is unavailable: ' + $_.Exception.Message }
    $reviewTab.Controls.Add($reviewText)

    function New-Button([string]$Text, [int]$Width) {
        $button = New-Object Windows.Forms.Button
        $button.Text = $Text; $button.Size = New-Object Drawing.Size($Width, 34)
        return $button
    }
    function New-ButtonRow([int]$Row) {
        $panel = New-Object Windows.Forms.FlowLayoutPanel
        $panel.Dock = 'Fill'; $panel.WrapContents = $false
        $layout.Controls.Add($panel, 0, $Row)
        return $panel
    }
    $actions = New-ButtonRow 2
    $apply = New-Button 'Apply selected settings' 215; $actions.Controls.Add($apply)
    $undo = New-Button 'Undo my changes' 175; $actions.Controls.Add($undo)
    $report = New-Button 'Save hardware report' 195; $actions.Controls.Add($report)
    $helpers = New-ButtonRow 3
    $guide = New-Button 'Gaming + network guide' 210; $helpers.Controls.Add($guide)
    $saveReview = New-Button 'Save video review' 170; $helpers.Controls.Add($saveReview)
    $startup = New-Button 'Review startup apps' 185; $helpers.Controls.Add($startup)
    $personalize = New-Button 'Appearance settings' 185; $helpers.Controls.Add($personalize)

    $settingsRow = New-ButtonRow 4
    $settings = New-Object Windows.Forms.ComboBox
    $settings.DropDownStyle = 'DropDownList'
    $settings.Size = New-Object Drawing.Size(570, 32)
    $settings.DisplayMember = 'Label'
    $settings.Items.AddRange([object[]]@(
        [pscustomobject]@{ Label='Notifications'; Kind='Settings'; Value='ms-settings:notifications' },
        [pscustomobject]@{ Label='Privacy: general / recommendations'; Kind='Settings'; Value='ms-settings:privacy-general' },
        [pscustomobject]@{ Label='Privacy: online speech (manual)'; Kind='Settings'; Value='ms-settings:privacy-speech' },
        [pscustomobject]@{ Label='Privacy: inking / typing (dictionary may be cleared)'; Kind='Settings'; Value='ms-settings:privacy-speechtyping' },
        [pscustomobject]@{ Label='Privacy: diagnostics / feedback (manual)'; Kind='Settings'; Value='ms-settings:privacy-feedback' },
        [pscustomobject]@{ Label='Windows Search permissions / history'; Kind='Settings'; Value='ms-settings:search-permissions' },
        [pscustomobject]@{ Label='Windows Search / indexing (Classic review)'; Kind='Settings'; Value='ms-settings:search' },
        [pscustomobject]@{ Label='Privacy: location (manual)'; Kind='Settings'; Value='ms-settings:privacy-location' },
        [pscustomobject]@{ Label='Privacy: app diagnostics (manual)'; Kind='Settings'; Value='ms-settings:privacy-appdiagnostics' },
        [pscustomobject]@{ Label='Privacy: microphone (preserve required voice access)'; Kind='Settings'; Value='ms-settings:privacy-microphone' },
        [pscustomobject]@{ Label='Privacy: camera (preserve required access)'; Kind='Settings'; Value='ms-settings:privacy-webcam' },
        [pscustomobject]@{ Label='Graphics / HAGS (manual comparison)'; Kind='Settings'; Value='ms-settings:display-advancedgraphics' },
        [pscustomobject]@{ Label='Game Mode (manual comparison with video OFF choice)'; Kind='Settings'; Value='ms-settings:gaming-gamemode' },
        [pscustomobject]@{ Label='Mouse settings'; Kind='Settings'; Value='ms-settings:mousetouchpad' },
        [pscustomobject]@{ Label='Sound / audio enhancements (manual, device-specific)'; Kind='Settings'; Value='ms-settings:sound' },
        [pscustomobject]@{ Label='Installed apps (review only; no auto uninstall)'; Kind='Settings'; Value='ms-settings:appsfeatures' },
        [pscustomobject]@{ Label='Windows Update'; Kind='Settings'; Value='ms-settings:windowsupdate' },
        [pscustomobject]@{ Label='Your account (no automatic password / sign-in changes)'; Kind='Settings'; Value='ms-settings:yourinfo' },
        [pscustomobject]@{ Label='Device Manager (driver / adapter review only)'; Kind='DeviceManager'; Value='devmgmt.msc' },
        [pscustomobject]@{ Label='System Information (motherboard / firmware)'; Kind='Tool'; Value='msinfo32.exe' },
        [pscustomobject]@{ Label='System Protection (manual restore-point creation)'; Kind='Tool'; Value='SystemPropertiesProtection.exe' }
    ))
    $settings.SelectedIndex = 0
    $settingsRow.Controls.Add($settings)
    $openSettings = New-Button 'Open selected page' 200; $settingsRow.Controls.Add($openSettings)

    $script:OutputBox = New-Object Windows.Forms.TextBox
    $script:OutputBox.Dock = 'Fill'; $script:OutputBox.Multiline = $true
    $script:OutputBox.ReadOnly = $true; $script:OutputBox.ScrollBars = 'Vertical'
    $layout.Controls.Add($script:OutputBox, 0, 5)
    $footer = New-Object Windows.Forms.Label
    $footer.Dock = 'Fill'
    $footer.Text = 'Restart after Apply / Undo. Backup: %LOCALAPPDATA%\PJ-Tweaks. Manual game, driver, BIOS and Settings changes are not covered by Undo.'
    $layout.Controls.Add($footer, 0, 6)

    function Set-ButtonsEnabled([bool]$Enabled) {
        foreach ($button in @($apply, $undo, $report, $guide, $saveReview, $startup, $personalize, $openSettings)) { $button.Enabled=$Enabled }
    }
    $apply.Add_Click({
        Set-ButtonsEnabled $false
        try {
            $journal = Read-Journal
            if (-not ($gaming.Checked -or $appearance.Checked -or $browsers.Checked -or $privacy.Checked -or $notifications.Checked -or $mouse.Checked -or $power.Checked)) { Write-Activity 'Select at least one option.'; return }
            $allowBrowsers = $browsers.Checked
            if ($allowBrowsers) {
                try { if (Test-ManagedDevice) { $allowBrowsers=$false; Write-Activity 'SKIPPED: browser policies on a managed device.' } }
                catch { $allowBrowsers=$false; Write-Activity ('SKIPPED: could not rule out device management: ' + $_.Exception.Message) }
            }
            foreach ($spec in (Get-SelectedTweaks -Gaming $gaming.Checked -Appearance $appearance.Checked -Browsers $allowBrowsers -Privacy $privacy.Checked -Notifications $notifications.Checked -Mouse $mouse.Checked)) {
                try { Invoke-RegistryTweak $journal $spec }
                catch { Write-Activity ('FAILED: {0}: {1}. Backup retained; use Undo if needed.' -f $spec.Label, $_.Exception.Message) }
            }
            if ($power.Checked) {
                $battery = [Windows.Forms.SystemInformation]::PowerStatus
                if (($battery.PowerLineStatus.ToString() -ne 'Online') -or
                    ($battery.BatteryChargeStatus.ToString() -notmatch 'NoSystemBattery')) {
                    Write-Activity 'SKIPPED: High performance is restricted to AC-powered desktops without a system battery.'
                } else {
                    try { Invoke-PowerTweak $journal } catch { Write-Activity ('FAILED: power plan: ' + $_.Exception.Message) }
                }
            }
            Write-Activity 'Finished checking selections. Review APPLIED / SKIPPED / FAILED above. Restart Windows before verifying settings and comparing the same game benchmark.'
        } catch { Write-Activity ('STOPPED: ' + $_.Exception.Message) }
        finally { Set-ButtonsEnabled $true }
    })
    $undo.Add_Click({
        Set-ButtonsEnabled $false
        try {
            if (-not [IO.File]::Exists($script:StateFile)) { Write-Activity 'No saved changes found for this Windows account.'; return }
            Invoke-Undo (Read-Journal)
            Write-Activity 'Undo pass finished. Review RESTORED / SKIPPED UNDO / FAILED UNDO above. Restart Windows.'
        } catch { Write-Activity ('STOPPED: ' + $_.Exception.Message) }
        finally { Set-ButtonsEnabled $true }
    })
    $report.Add_Click({
        Set-ButtonsEnabled $false
        try {
            $text = Get-SystemReport
            $folder = Split-Path -Parent $script:StateFile
            [IO.Directory]::CreateDirectory($folder) | Out-Null
            $path = Join-Path $folder 'hardware-report.txt'
            [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
            Write-Activity ('Report saved locally: ' + $path)
            $script:OutputBox.AppendText($text + "`r`n")
        } catch { Write-Activity ('FAILED: hardware report: ' + $_.Exception.Message) }
        finally { Set-ButtonsEnabled $true }
    })
    $guide.Add_Click({
        try {
            $folder = Split-Path -Parent $script:StateFile
            [IO.Directory]::CreateDirectory($folder) | Out-Null
            $path = Join-Path $folder 'personal-guide.txt'
            [IO.File]::WriteAllText($path, (Get-PersonalGuide), [Text.UTF8Encoding]::new($false))
            Write-Activity ('Guide saved locally: ' + $path)
            Start-Process -FilePath "$env:SystemRoot\System32\notepad.exe" -ArgumentList ('"' + $path + '"')
        } catch { Write-Activity ('FAILED: guide: ' + $_.Exception.Message) }
    })
    $saveReview.Add_Click({
        try {
            $folder = Split-Path -Parent $script:StateFile
            [IO.Directory]::CreateDirectory($folder) | Out-Null
            $path = Join-Path $folder 'video-review.txt'
            [IO.File]::WriteAllText($path, (Get-VideoReviewText), [Text.UTF8Encoding]::new($false))
            Write-Activity ('Video review saved locally: ' + $path)
            Start-Process -FilePath "$env:SystemRoot\System32\notepad.exe" -ArgumentList ('"' + $path + '"')
        } catch { Write-Activity ('FAILED: video review: ' + $_.Exception.Message) }
    })
    $startup.Add_Click({
        try { Start-Process 'ms-settings:startupapps'; Write-Activity 'Opened Windows Startup settings for your review. No startup entries changed.' }
        catch { Write-Activity ('Could not open Startup settings: ' + $_.Exception.Message) }
    })
    $personalize.Add_Click({
        try { Start-Process 'ms-settings:personalization'; Write-Activity 'Opened Windows Personalization settings for verification. Restart first if changes have not appeared yet.' }
        catch { Write-Activity ('Could not open Personalization settings: ' + $_.Exception.Message) }
    })
    $openSettings.Add_Click({
        try {
            $selected = $settings.SelectedItem
            if ($null -eq $selected) { return }
            if ($selected.Kind -eq 'Settings') { Start-Process -FilePath $selected.Value }
            elseif ($selected.Kind -eq 'DeviceManager') {
                $msc = Join-Path $env:SystemRoot 'System32\devmgmt.msc'
                Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\mmc.exe') -ArgumentList ('"' + $msc + '"')
            } else { Start-Process -FilePath (Join-Path $env:SystemRoot ('System32\' + $selected.Value)) }
            Write-Activity ('Opened for manual review: ' + $selected.Label + '. Changes made there are outside this tool''s Undo.')
        } catch { Write-Activity ('Could not open the selected page: ' + $_.Exception.Message) }
    })
    function Set-DarkControls($Parent) {
        foreach ($control in $Parent.Controls) {
            $control.BackColor = [Drawing.Color]::FromArgb(24, 24, 24)
            $control.ForeColor = [Drawing.Color]::Gainsboro
            if ($control -is [Windows.Forms.Button]) {
                $control.FlatStyle = 'Flat'; $control.BackColor = [Drawing.Color]::FromArgb(45, 45, 45)
            } elseif ($control -is [Windows.Forms.CheckBox]) { $control.UseVisualStyleBackColor = $false }
            Set-DarkControls $control
        }
    }
    $form.BackColor = [Drawing.Color]::FromArgb(24, 24, 24)
    $form.ForeColor = [Drawing.Color]::Gainsboro
    Set-DarkControls $form
    Write-Activity 'Ready. Gaming and your dark / solid-black appearance preset are selected; other tweaks are optional. The Video review tab accounts for the supplied transcript.'
    [void]$form.ShowDialog()
    $form.Dispose()
} finally {
    if ($locked) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
