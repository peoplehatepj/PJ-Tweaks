# Native registry smoke tests. Run with Windows PowerShell 5.1 on Windows.
# Uses ONLY a new randomly named HKCU test key; does not apply the gaming profile.
param([switch]$ExerciseTimer)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'Native integration checks require Windows; no tests executed.'
}
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'src/PJ-Gaming.ps1') -LibraryOnly
$testPath = 'Software\PJ-Tweaks\Tests\' + [guid]::NewGuid().ToString('N')
$absent = [pscustomobject]@{ Exists=$false; Kind=$null; Data=$null }
$states = @(
    [pscustomobject]@{ Exists=$true; Kind='DWord'; Data=1 },
    [pscustomobject]@{ Exists=$true; Kind='DWord'; Data=-1 },
    [pscustomobject]@{ Exists=$true; Kind='QWord'; Data='9223372036854775807' },
    [pscustomobject]@{ Exists=$true; Kind='String'; Data='test' },
    [pscustomobject]@{ Exists=$true; Kind='ExpandString'; Data='%USERPROFILE%\literal' },
    [pscustomobject]@{ Exists=$true; Kind='MultiString'; Data=@('one','two') },
    [pscustomobject]@{ Exists=$true; Kind='MultiString'; Data=@() },
    [pscustomobject]@{ Exists=$true; Kind='Binary'; Data=[byte[]]@(0,1,255) },
    [pscustomobject]@{ Exists=$true; Kind='Binary'; Data=[byte[]]@() }
)
try {
    foreach ($state in $states) {
        Set-RegistryState $testPath 'Roundtrip' $state
        $readback = Get-RegistryState $testPath 'Roundtrip'
        if (-not (Test-SameState $readback $state)) { throw ('Native registry roundtrip failed: ' + $state.Kind) }
        # A sibling value must survive deleting only the targeted value.
        Set-RegistryState $testPath 'Untouched' ([pscustomobject]@{ Exists=$true; Kind='String'; Data='keep' })
        Set-RegistryState $testPath 'Roundtrip' $absent
        if ((Get-RegistryState $testPath 'Roundtrip').Exists) { throw 'Value removal failed.' }
        if ((Get-RegistryState $testPath 'Untouched').Data -ne 'keep') { throw 'An unrelated value was changed.' }
        Write-Host ('PASS: native ' + $state.Kind + ' write/read/remove and sibling preservation')
    }
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $form = New-Object Windows.Forms.Form
    try {
        $form.Font = New-Object Drawing.Font('Segoe UI', 10)
        $form.ClientSize = New-Object Drawing.Size(790, 730)
        if ($form.ClientSize.Width -ne 790) { throw 'WinForms construction failed.' }
        Write-Host 'PASS: Windows Forms/Drawing assembly load and native form construction (not full UI automation)'
    } finally { $form.Dispose() }
    $plan = Get-ActivePowerPlan
    if ($plan -notmatch '^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$') { throw 'Native power plan query failed.' }
    Write-Host 'PASS: native read-only power plan query (no plan changed)'
    $timer=Get-NativeTimerInfo
    if (($timer.FinestTicks -le 0) -or ($timer.CoarsestTicks -lt $timer.FinestTicks)) { throw 'Native timer bounds invalid.' }
    Write-Host ('PASS: native read-only timer query; supported range {0:F4}-{1:F4} ms' -f ($timer.FinestTicks / 10000.0), ($timer.CoarsestTicks / 10000.0))
    if ($ExerciseTimer) {
        if ((5000 -ge $timer.FinestTicks) -and (5000 -le $timer.CoarsestTicks)) {
            try {
                $state=Start-TimerRequest
                if (-not $state.RequestOwned) { throw 'Native timer ownership not recorded.' }
                Write-Host ('PASS: native 0.5 ms request accepted; reported {0} ms (not game latency)' -f $state.ReportedMilliseconds)
            } finally { Stop-TimerRequest | Out-Null }
            if ($script:TimerRequestOwned) { throw 'Native timer request not released.' }
            Write-Host 'PASS: native timer request released'
        } else { Write-Host 'SKIPPED: 0.5 ms outside the native reported range; no request made.' }
    }
    Write-Host 'Native integration checks passed. Full GUI workflow and game benchmarks still need manual checks.'
} finally {
    # This exact GUID key was made by the tests and contains no user data.
    [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($testPath, $false)
}
