# Dependency-free tests. No real Windows settings are changed by these tests.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'src/PJ-Gaming.ps1'
$tokens = $null; $parseErrors = $null
$null = [Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }
. $source -LibraryOnly
$script:SaveFunction = ${function:Save-Journal}
$script:Scratch = Join-Path ([IO.Path]::GetTempPath()) ('pj-tests-' + [guid]::NewGuid().ToString('N'))
$script:Passed = 0

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw ('ASSERTION FAILED: ' + $Message) }
}
function Assert-Throws([scriptblock]$Action, [string]$Message) {
    $threw = $false
    try { & $Action } catch { $threw = $true }
    Assert-True $threw $Message
}
function Write-Activity([string]$Message) { $script:Messages.Add($Message) }
function New-State($Data, [string]$Kind='DWord') {
    return [pscustomobject]@{ Exists=$true; Kind=$Kind; Data=$Data }
}
function Get-RegistryState([string]$Path, [string]$Name, [switch]$Machine) {
    $id = ('{0}|{1}|{2}' -f [bool]$Machine, $Path, $Name)
    if ($script:Registry.ContainsKey($id)) { return $script:Registry[$id] }
    return [pscustomobject]@{ Exists=$false; Kind=$null; Data=$null }
}
function Set-RegistryState([string]$Path, [string]$Name, $State) {
    # Assert the ORIGINAL is already safely persisted, not just held in memory.
    $journal = Read-Journal
    $spec = (Get-TweakCatalog) | Where-Object { ($_.Path -eq $Path) -and ($_.Name -eq $Name) }
    $entry = @($journal.Entries | Where-Object { $_.Id -eq $spec.Id })
    Assert-True ($entry.Count -eq 1) 'a backup must exist before every write'
    $script:Writes++
    $id = ('False|{0}|{1}' -f $Path, $Name)
    if ($State.Exists) { $script:Registry[$id]=$State } else { $script:Registry.Remove($id) }
}
function Set-Fixture($Spec, $State, [switch]$Machine) {
    $script:Registry[('{0}|{1}|{2}' -f [bool]$Machine, $Spec.Path, $Spec.Name)] = $State
}
function Get-ActivePowerPlan { return $script:PowerPlan }
function Get-AvailablePowerPlans { return $script:AvailablePower }
function Set-ActivePowerPlan([string]$Guid) {
    $journal = Read-Journal
    Assert-True ($null -ne $journal.Power) 'power baseline must already exist on disk'
    $script:PowerPlan = $Guid
    $script:PowerWrites++
}
function Reset-Fixture {
    $script:Registry = @{}
    $script:Messages = New-Object 'System.Collections.Generic.List[string]'
    $script:Writes=0; $script:PowerWrites=0
    $script:UserSid='test-user'
    $script:StateFile = Join-Path $script:Scratch ([guid]::NewGuid().ToString('N') + '/backup.json')
    $script:PowerPlan = '381b4222-f694-41f0-9685-ff5bb260df2e'
    $script:AvailablePower = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 381b4222-f694-41f0-9685-ff5bb260df2e'
}
function Test-Case([string]$Name, [scriptblock]$Action) {
    Reset-Fixture
    & $Action
    $script:Passed++
    Write-Host ('PASS: ' + $Name)
}

try {
    $game = (Get-TweakCatalog | Where-Object { $_.Id -eq 'game-mode' })
    $chrome = (Get-TweakCatalog | Where-Object { $_.Id -eq 'chrome-background' })
    Test-Case 'new registry values are journaled before mutation and removed by undo' {
        $journal = Read-Journal
        Invoke-RegistryTweak $journal $game
        Assert-True ((Read-Journal).Entries[0].Status -eq 'Applied') 'applied status persisted'
        Invoke-Undo (Read-Journal)
        Assert-True (-not (Get-RegistryState $game.Path $game.Name).Exists) 'absent original restored'
        Assert-True ($script:Writes -eq 2) 'one apply and one restore'
    }
    Test-Case 'rerunning Apply preserves the FIRST original and does not rewrite settings' {
        Set-Fixture $game (New-State 0)
        Invoke-RegistryTweak (Read-Journal) $game
        Invoke-RegistryTweak (Read-Journal) $game
        Assert-True ($script:Writes -eq 1) 'idempotent apply'
        Assert-True ((Read-Journal).Entries[0].Original.Data -eq 0) 'original baseline retained'
        Assert-True (@((Read-Journal).Entries).Count -eq 1) 'no duplicate baseline'
        Invoke-Undo (Read-Journal)
        Assert-True ((Get-RegistryState $game.Path $game.Name).Data -eq 0) 'original DWORD restored'
    }
    Test-Case 'undo and reapply preserve newly selected user baseline' {
        Invoke-RegistryTweak (Read-Journal) $game
        Invoke-Undo (Read-Journal)
        Set-Fixture $game (New-State 'user-preference' 'String')
        Invoke-RegistryTweak (Read-Journal) $game
        Invoke-Undo (Read-Journal)
        Assert-True ((Get-RegistryState $game.Path $game.Name).Data -ceq 'user-preference') 'fresh baseline after completed undo'
    }
    Test-Case 'original registry types and data survive JSON persistence and undo' {
        $states = @(
            (New-State 'text' 'String'),
            (New-State '%USERPROFILE%\test' 'ExpandString'),
            (New-State @('one','two') 'MultiString'),
            (New-State @() 'MultiString'),
            (New-State ([byte[]]@(0,255,8)) 'Binary'),
            (New-State ([byte[]]@()) 'Binary'),
            (New-State '9223372036854775807' 'QWord'),
            (New-State -1)
        )
        foreach ($state in $states) {
            Reset-Fixture
            Set-Fixture $game $state
            Invoke-RegistryTweak (Read-Journal) $game
            Invoke-Undo (Read-Journal)
            Assert-True (Test-SameState (Get-RegistryState $game.Path $game.Name) $state) ('exact original restored: ' + $state.Kind)
        }
    }
    Test-Case 'external changes are not overwritten by Apply or Undo' {
        Invoke-RegistryTweak (Read-Journal) $game
        Set-Fixture $game (New-State 2)
        Invoke-RegistryTweak (Read-Journal) $game
        Invoke-Undo (Read-Journal)
        Assert-True ($script:Writes -eq 1) 'no overwrite of intervening change'
        Assert-True ((Get-RegistryState $game.Path $game.Name).Data -eq 2) 'external value preserved'
        Assert-True ((Read-Journal).Entries[0].Status -eq 'Applied') 'baseline retained for future recovery'
    }
    Test-Case 'settings already at target need no backup or write' {
        Set-Fixture $game (New-State 1)
        Invoke-RegistryTweak (Read-Journal) $game
        Assert-True ($script:Writes -eq 0) 'no unnecessary writes'
        Assert-True (-not [IO.File]::Exists($script:StateFile)) 'no invented baseline'
    }
    Test-Case 'existing user browser policies are preserved' {
        Set-Fixture $chrome (New-State 1)
        Invoke-RegistryTweak (Read-Journal) $chrome
        Assert-True ($script:Writes -eq 0) 'existing user policy skipped'
    }
    Test-Case 'machine browser policies are preserved and not shadowed' {
        Set-Fixture $chrome (New-State 1) -Machine
        Invoke-RegistryTweak (Read-Journal) $chrome
        Assert-True ($script:Writes -eq 0) 'machine policy skipped'
        Assert-True (-not (Get-RegistryState $chrome.Path $chrome.Name).Exists) 'no user policy created'
    }
    Test-Case 'optional browser settings are removed completely by Undo' {
        foreach ($spec in (Get-TweakCatalog | Where-Object { $_.Group -eq 'Browsers' })) {
            Invoke-RegistryTweak (Read-Journal) $spec
        }
        Invoke-Undo (Read-Journal)
        Assert-True ($script:Registry.Count -eq 0) 'all added policy values removed'
        Assert-True ($script:Writes -eq 6) 'three writes and three restores'
    }
    Test-Case 'appearance selection is separate from gaming and browser tweaks' {
        $selected = @(Get-SelectedTweaks $false $true $false)
        Assert-True ($selected.Count -gt 0) 'appearance options selected'
        Assert-True (@($selected | Where-Object { $_.Group -ne 'Appearance' }).Count -eq 0) 'no unselected group applied'
        Assert-True (@(Get-SelectedTweaks $true $false $false).Count -eq 3) 'existing gaming preset unchanged'
        Assert-True (@(Get-SelectedTweaks $false $false $false).Count -eq 0) 'no selection yields no tweaks'
    }
    Test-Case 'appearance preset disables effects and Spotlight and chooses dark solid-black desktop' {
        $specs = @(Get-SelectedTweaks $false $true $false)
        foreach ($spec in $specs) { Invoke-RegistryTweak (Read-Journal) $spec }
        foreach ($id in @('transparency','app-dark-mode','system-dark-mode','dynamic-lighting','foreground-lighting','lockscreen-spotlight','lockscreen-overlay','lockscreen-tips')) {
            $spec = $specs | Where-Object { $_.Id -eq $id }
            $state = Get-RegistryState $spec.Path $spec.Name
            Assert-True ($state.Exists -and ($state.Kind -eq 'DWord') -and ($state.Data -eq 0)) ($id + ' disabled')
        }
        $mode = $specs | Where-Object { $_.Id -eq 'background-type' }
        Assert-True ((Get-RegistryState $mode.Path $mode.Name).Data -eq 1) 'solid color selected, not picture/Spotlight'
        $wallpaper = $specs | Where-Object { $_.Id -eq 'desktop-wallpaper' }
        Assert-True ((Get-RegistryState $wallpaper.Path $wallpaper.Name).Data -ceq '') 'wallpaper cleared'
        $color = $specs | Where-Object { $_.Id -eq 'background-color' }
        Assert-True ((Get-RegistryState $color.Path $color.Name).Data -ceq '0 0 0') 'black background selected'
        Invoke-Undo (Read-Journal)
        Assert-True ($script:Registry.Count -eq 0) 'all added appearance values removed by Undo'
    }
    Test-Case 'appearance reruns preserve original wallpaper, color, theme and lighting state' {
        $specs = @(Get-SelectedTweaks $false $true $false)
        $before = @{}
        foreach ($spec in $specs) {
            $data = 1
            if ($spec.Kind -eq 'String') { $data = 'old-value' }
            if ($spec.Id -eq 'background-type') { $data = 3 }
            if ($spec.Id -eq 'desktop-wallpaper') { $data = 'C:\Users\Player\Pictures\My Wallpaper.jpg' }
            if ($spec.Id -eq 'background-color') { $data = '24 60 120' }
            $state = New-State $data $spec.Kind
            $before[$spec.Id] = $state
            Set-Fixture $spec $state
        }
        foreach ($spec in $specs) { Invoke-RegistryTweak (Read-Journal) $spec }
        $firstWrites = $script:Writes
        foreach ($spec in $specs) { Invoke-RegistryTweak (Read-Journal) $spec }
        Assert-True ($script:Writes -eq $firstWrites) 'appearance repeat Apply performs no extra writes'
        Invoke-Undo (Read-Journal)
        foreach ($spec in $specs) {
            Assert-True (Test-SameState (Get-RegistryState $spec.Path $spec.Name) $before[$spec.Id]) ('original restored: ' + $spec.Id)
        }
    }
    Test-Case 'old gaming-only backup is compatible when adding appearance preferences' {
        Invoke-RegistryTweak (Read-Journal) $game
        $baseline = (Read-Journal).Entries[0].Original
        foreach ($spec in (Get-SelectedTweaks $false $true $false)) { Invoke-RegistryTweak (Read-Journal) $spec }
        $journal = Read-Journal
        $oldEntry = $journal.Entries | Where-Object { $_.Id -eq $game.Id }
        Assert-True (Test-SameState $oldEntry.Original $baseline) 'old original not replaced during upgrade'
        Invoke-Undo $journal
        Assert-True ($script:Registry.Count -eq 0) 'old and new preset changes undone together'
    }
    Test-Case 'Undo preserves a wallpaper selected later outside the optimizer' {
        $wallpaper = Get-TweakCatalog | Where-Object { $_.Id -eq 'desktop-wallpaper' }
        Invoke-RegistryTweak (Read-Journal) $wallpaper
        Set-Fixture $wallpaper (New-State 'C:\Pictures\New choice.jpg' 'String')
        Invoke-Undo (Read-Journal)
        Assert-True ((Get-RegistryState $wallpaper.Path $wallpaper.Name).Data -ceq 'C:\Pictures\New choice.jpg') 'later wallpaper choice not overwritten'
        Assert-True ((Read-Journal).Entries[0].Status -eq 'Applied') 'original wallpaper backup retained'
    }
    Test-Case 'video presets are opt-in and each group can be selected independently' {
        $default = @(Get-SelectedTweaks $true $true $false)
        Assert-True (@($default | Where-Object { $_.Group -in @('Privacy','Notifications','Mouse') }).Count -eq 0) 'older/default selectors do not apply new options'
        $privacy = @(Get-SelectedTweaks -Privacy $true)
        $quiet = @(Get-SelectedTweaks -Notifications $true)
        $mouse = @(Get-SelectedTweaks -Mouse $true)
        Assert-True (($privacy.Count -eq 13) -and (@($privacy | Where-Object { $_.Group -ne 'Privacy' }).Count -eq 0)) 'privacy is selected independently'
        Assert-True (($quiet.Count -eq 1) -and ($quiet[0].Group -eq 'Notifications')) 'notifications are separate'
        Assert-True (($mouse.Count -eq 3) -and (@($mouse | Where-Object { $_.Group -ne 'Mouse' }).Count -eq 0)) 'mouse is selected independently'
    }
    Test-Case 'privacy recommendations and search preferences restore their original values' {
        $specs = @(Get-SelectedTweaks -Privacy $true)
        foreach ($spec in $specs) { Set-Fixture $spec (New-State 1) }
        foreach ($spec in $specs) { Invoke-RegistryTweak (Read-Journal) $spec }
        foreach ($spec in $specs) { Assert-True ((Get-RegistryState $spec.Path $spec.Name).Data -eq 0) ($spec.Id + ' switched off') }
        $writes = $script:Writes
        foreach ($spec in $specs) { Invoke-RegistryTweak (Read-Journal) $spec }
        Assert-True ($script:Writes -eq $writes) 'privacy repeat application keeps baseline'
        Invoke-Undo (Read-Journal)
        foreach ($spec in $specs) { Assert-True ((Get-RegistryState $spec.Path $spec.Name).Data -eq 1) ($spec.Id + ' restored') }
    }
    Test-Case 'notification preference is backed up and restores without affecting other preferences' {
        $spec = @(Get-SelectedTweaks -Notifications $true)[0]
        Set-Fixture $spec (New-State 1)
        Invoke-RegistryTweak (Read-Journal) $spec
        Assert-True ((Get-RegistryState $spec.Path $spec.Name).Data -eq 0) 'toast switch off'
        Assert-True ($script:Registry.Count -eq 1) 'no other preferences changed'
        Invoke-Undo (Read-Journal)
        Assert-True ((Get-RegistryState $spec.Path $spec.Name).Data -eq 1) 'toast switch restored'
    }
    Test-Case 'mouse preset preserves sensitivity and restores prior acceleration thresholds' {
        $specs = @(Get-SelectedTweaks -Mouse $true)
        $sensitivity = [pscustomobject]@{ Path='Control Panel\Mouse'; Name='MouseSensitivity' }
        Set-Fixture $sensitivity (New-State '13' 'String')
        $baseline = @('1','6','10')
        for ($i=0; $i -lt $specs.Count; $i++) { Set-Fixture $specs[$i] (New-State $baseline[$i] 'String') }
        foreach ($spec in $specs) { Invoke-RegistryTweak (Read-Journal) $spec }
        foreach ($spec in $specs) { Assert-True ((Get-RegistryState $spec.Path $spec.Name).Data -ceq '0') ($spec.Id + ' off') }
        Assert-True ((Get-RegistryState $sensitivity.Path $sensitivity.Name).Data -ceq '13') 'pointer speed untouched'
        Invoke-Undo (Read-Journal)
        for ($i=0; $i -lt $specs.Count; $i++) { Assert-True ((Get-RegistryState $specs[$i].Path $specs[$i].Name).Data -ceq $baseline[$i]) 'original mouse value restored' }
        Assert-True ((Get-RegistryState $sensitivity.Path $sensitivity.Name).Data -ceq '13') 'pointer speed still untouched'
    }
    Test-Case 'video options can be added to a previous-version backup without losing originals' {
        Invoke-RegistryTweak (Read-Journal) $game
        $old = (Read-Journal).Entries[0].Original
        foreach ($spec in (Get-SelectedTweaks -Privacy $true -Notifications $true -Mouse $true)) { Invoke-RegistryTweak (Read-Journal) $spec }
        $entry = (Read-Journal).Entries | Where-Object { $_.Id -eq $game.Id }
        Assert-True (Test-SameState $entry.Original $old) 'old baseline still accessible'
        Invoke-Undo (Read-Journal)
        Assert-True ($script:Registry.Count -eq 0) 'old and new values restored together'
    }
    Test-Case 'no two catalog entries write the same registry setting or reuse an ID' {
        $ids=@{}; $locations=@{}
        foreach ($spec in (Get-TweakCatalog)) {
            $location=($spec.Path + '|' + $spec.Name).ToLowerInvariant()
            Assert-True (-not $ids.ContainsKey($spec.Id)) ('unique ID: ' + $spec.Id)
            Assert-True (-not $locations.ContainsKey($location)) ('unique registry target: ' + $spec.Id)
            $ids[$spec.Id]=$true; $locations[$location]=$true
        }
        Assert-True ($game.Data -eq 1) 'original Game Mode target preserved for backup compatibility'
    }
    Test-Case 'a backup write failure blocks the corresponding registry change' {
        function Save-Journal($Journal) { throw 'Simulated disk failure' }
        Assert-Throws { Invoke-RegistryTweak (New-Journal) $game } 'apply must fail before mutation'
        Assert-True ($script:Writes -eq 0) 'no write without backup'
    }
    Test-Case 'failed registry write leaves a recoverable pending backup' {
        function Set-RegistryState([string]$Path, [string]$Name, $State) { throw 'Simulated access denied' }
        Assert-Throws { Invoke-RegistryTweak (Read-Journal) $game } 'write failure exposed'
        Assert-True ((Read-Journal).Entries[0].Status -eq 'Pending') 'pending backup retained'
        Invoke-Undo (Read-Journal)
        Assert-True ((Read-Journal).Entries[0].Status -eq 'Restored') 'no-op restore clears pending entry'
    }
    Test-Case 'a crash after mutation but before final save is recoverable' {
        $script:SaveCalls=0
        function Save-Journal($Journal) {
            $script:SaveCalls++
            if ($script:SaveCalls -eq 2) { throw 'Simulated interruption after registry mutation' }
            & $script:SaveFunction $Journal
        }
        Assert-Throws { Invoke-RegistryTweak (Read-Journal) $game } 'post-write failure surfaced'
        Assert-True ((Read-Journal).Entries[0].Status -eq 'Pending') 'write-ahead record survived'
        Assert-True ((Get-RegistryState $game.Path $game.Name).Data -eq 1) 'setting was changed'
        Invoke-Undo (Read-Journal)
        Assert-True (-not (Get-RegistryState $game.Path $game.Name).Exists) 'undo of interrupted operation succeeds'
    }
    Test-Case 'wrong account, unknown entries, duplicate entries and changed targets are rejected' {
        Invoke-RegistryTweak (Read-Journal) $game
        $baseline = [IO.File]::ReadAllText($script:StateFile)
        foreach ($mutation in @('account','id','duplicate','target','status')) {
            $journal = $baseline | ConvertFrom-Json
            switch ($mutation) {
                'account' { $journal.UserSid='another-account' }
                'id' { $journal.Entries[0].Id='untrusted-key' }
                'duplicate' { $journal.Entries=@($journal.Entries) + @($journal.Entries[0]) }
                'target' { $journal.Entries[0].Target.Data=99 }
                'status' { $journal.Entries[0].Status='unknown' }
            }
            Save-Journal $journal
            Assert-Throws { Read-Journal } ('invalid journal rejected: ' + $mutation)
        }
        Assert-True ($script:Writes -eq 1) 'no mutation during journal validation'
    }
    Test-Case 'malformed backup JSON is not overwritten or ignored' {
        [IO.Directory]::CreateDirectory((Split-Path -Parent $script:StateFile)) | Out-Null
        [IO.File]::WriteAllText($script:StateFile, '{bad-json')
        Assert-Throws { Read-Journal } 'malformed backup must stop processing'
        Assert-True ([IO.File]::ReadAllText($script:StateFile) -eq '{bad-json') 'corrupt backup preserved for diagnosis'
    }
    Test-Case 'power plan is backed up, idempotent and restored' {
        Invoke-PowerTweak (Read-Journal)
        Invoke-PowerTweak (Read-Journal)
        Assert-True ($script:PowerWrites -eq 1) 'power apply idempotent'
        Invoke-Undo (Read-Journal)
        Assert-True ($script:PowerPlan -eq '381b4222-f694-41f0-9685-ff5bb260df2e') 'original power plan restored'
    }
    Test-Case 'power plans changed outside the optimizer are preserved' {
        Invoke-PowerTweak (Read-Journal)
        $script:PowerPlan='a1841308-3541-4fab-bc81-f71556f20b4a'
        Invoke-PowerTweak (Read-Journal)
        Invoke-Undo (Read-Journal)
        Assert-True ($script:PowerWrites -eq 1) 'external plan not overwritten'
    }
    Test-Case 'unsupported High performance plan is skipped without creating a plan' {
        $script:AvailablePower='381b4222-f694-41f0-9685-ff5bb260df2e'
        Invoke-PowerTweak (Read-Journal)
        Assert-True ($script:PowerWrites -eq 0) 'no forced power plan'
        Assert-True (-not [IO.File]::Exists($script:StateFile)) 'no power backup needed'
    }
    Test-Case 'corrupted power backup is rejected' {
        Invoke-PowerTweak (Read-Journal)
        $journal=Read-Journal
        $journal.Power.Original='invalid-power-guid'
        Save-Journal $journal
        Assert-Throws { Read-Journal } 'invalid power identifier rejected'
    }
    Test-Case 'standalone CMD contains the exact source and a parseable PowerShell launcher' {
        $artifact=Join-Path $root 'dist/PJ-Gaming.cmd'
        $content=[IO.File]::ReadAllText($artifact)
        $parts=$content -split '(?m)^::PJ_PAYLOAD_BASE64\r?$'
        Assert-True ($parts.Count -eq 2) 'exactly one payload delimiter'
        $decoded=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($parts[1].Trim()))
        $reviewBytes=[IO.File]::ReadAllBytes((Join-Path $root 'docs/video-review.md'))
        $marker = '$script:EmbeddedVideoReview = ' + "'' # PJ_EMBED_VIDEO_REVIEW"
        $replacement = '$script:EmbeddedVideoReview = ' + "'" + [Convert]::ToBase64String($reviewBytes) + "' # PJ_EMBED_VIDEO_REVIEW"
        $expected=[IO.File]::ReadAllText($source).Replace($marker,$replacement)
        Assert-True ($decoded -ceq $expected) 'packaged payload matches reviewed source plus embedded video review'
        $command=[regex]::Match($parts[0], '(?m)^"%SystemRoot%.*? -Command "(.*)"\r?$').Groups[1].Value
        Assert-True (-not [string]::IsNullOrWhiteSpace($command)) 'launcher found'
        $launcherErrors=$null; $launcherTokens=$null
        $null=[Management.Automation.Language.Parser]::ParseInput($command,[ref]$launcherTokens,[ref]$launcherErrors)
        Assert-True ($launcherErrors.Count -eq 0) 'launcher PowerShell parses'
        $hash=[Security.Cryptography.SHA256]::Create()
        try { $actual=([BitConverter]::ToString($hash.ComputeHash([IO.File]::ReadAllBytes($artifact)))).Replace('-','').ToLowerInvariant() }
        finally { $hash.Dispose() }
        $hashFile=[IO.File]::ReadAllText((Join-Path $root 'dist/SHA256SUMS.txt'))
        Assert-True ($hashFile.StartsWith($actual + '  PJ-Gaming.cmd')) 'distributed checksum correct'
    }
    Test-Case 'video review is available offline from both source and standalone payload' {
        $review=[IO.File]::ReadAllText((Join-Path $root 'docs/video-review.md'))
        Assert-True ((Get-VideoReviewText) -ceq $review) 'source loads the actual review document'
        Assert-True ($review.Contains('ulRe_t8ACw0')) 'video source identified'
        $artifact=[IO.File]::ReadAllText((Join-Path $root 'dist/PJ-Gaming.cmd'))
        $payload=($artifact -split '(?m)^::PJ_PAYLOAD_BASE64\r?$')[1].Trim()
        $decoded=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload))
        & {
            . ([scriptblock]::Create($decoded)) -LibraryOnly
            Assert-True ((Get-VideoReviewText) -ceq $review) 'standalone provides exact review without a checkout or Internet'
        }
    }
    Write-Host ("`n{0} tests passed. Windows registry/power APIs and GUI were mocked or not executed." -f $script:Passed)
} finally {
    if ([IO.Directory]::Exists($script:Scratch)) { [IO.Directory]::Delete($script:Scratch, $true) }
}
