# Lifecycle tests use fake native calls; no operating-system timer is changed.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'src/PJ-Gaming.ps1') -LibraryOnly
$script:Passed=0
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw ('ASSERTION FAILED: ' + $Message) }
}
function Assert-Throws([scriptblock]$Action, [string]$Message) {
    $threw=$false
    try { & $Action | Out-Null } catch { $threw=$true }
    Assert-True $threw $Message
}
function Get-NativeTimerInfo {
    $script:Queries++
    if ($script:QueryFails) { throw 'Simulated query failure' }
    [pscustomobject]@{ FinestTicks=$script:Finest; CoarsestTicks=156250; ReportedTicks=$script:Reported }
}
function Set-NativeTimerRequest([uint32]$DesiredTicks, [bool]$Enable) {
    $script:Calls.Add([pscustomobject]@{ DesiredTicks=$DesiredTicks; Enable=$Enable })
    if (($Enable -and $script:AcquireFails) -or (-not $Enable -and $script:ReleaseFails)) { throw 'Simulated native request failure' }
    return [uint32]$script:Reported
}
function Test-Case([string]$Name, [scriptblock]$Action) {
    $script:TimerRequestOwned=$false; $script:TimerLastReportedTicks=$null
    $script:Queries=0; $script:Finest=5000; $script:Reported=5000
    $script:QueryFails=$false; $script:AcquireFails=$false; $script:ReleaseFails=$false
    $script:Calls=New-Object 'System.Collections.Generic.List[object]'
    & $Action
    $script:Passed++
    Write-Host ('PASS: ' + $Name)
}

Test-Case 'interop compiles with correct NT boolean and status signatures without calling Windows' {
    Initialize-TimerNative
    $method=[PJGaming.TimerNative].GetMethod('NtSetTimerResolution')
    Assert-True ($method.ReturnType -eq [int]) 'NTSTATUS is signed 32-bit'
    $parameters=$method.GetParameters()
    Assert-True ($parameters[0].ParameterType -eq [uint32]) 'timer units use ULONG'
    $marshal=@($parameters[1].GetCustomAttributes([Runtime.InteropServices.MarshalAsAttribute],$false))
    Assert-True (($marshal.Count -eq 1) -and ($marshal[0].Value -eq [Runtime.InteropServices.UnmanagedType]::U1)) 'BOOLEAN uses a single native byte'
    Assert-True ($parameters[2].IsOut -and ($parameters[2].ParameterType -eq [uint32].MakeByRefType())) 'current resolution is out ULONG'
    $import=@($method.GetCustomAttributes([Runtime.InteropServices.DllImportAttribute],$false))[0]
    Assert-True (($import.Value -eq 'ntdll.dll') -and $import.ExactSpelling) 'native Windows export selected'
}
Test-Case 'timer starts off and status or repeated Stop does not touch the native API' {
    Assert-True (-not (Get-TimerStatus).RequestOwned) 'default off'
    Stop-TimerRequest | Out-Null
    Stop-TimerRequest | Out-Null
    Assert-True (($script:Calls.Count -eq 0) -and ($script:Queries -eq 0)) 'no implicit timer work'
}
Test-Case 'refresh reports milliseconds without acquiring a request' {
    $script:Reported=156250
    $state=Get-TimerStatus -Refresh
    Assert-True ($state.ReportedMilliseconds -eq 15.625) '100 ns units converted to milliseconds'
    Assert-True (-not $state.RequestOwned) 'query does not acquire'
    Assert-True ($script:Calls.Count -eq 0) 'no set call'
}
Test-Case '0.5 ms requests exactly 5000 native units' {
    $state=Start-TimerRequest
    Assert-True ($state.RequestOwned -and ($state.ReportedMilliseconds -eq 0.5)) 'successful request tracked'
    Assert-True (($script:Calls.Count -eq 1) -and $script:Calls[0].Enable -and ($script:Calls[0].DesiredTicks -eq 5000)) 'correct acquisition request'
}
Test-Case 'repeated Start does not stack native acquisitions' {
    Start-TimerRequest | Out-Null
    Start-TimerRequest | Out-Null
    Assert-True (($script:Calls.Count -eq 1) -and ($script:Queries -eq 1)) 'one acquisition only'
}
Test-Case 'Stop releases the matching request once' {
    Start-TimerRequest | Out-Null
    Stop-TimerRequest | Out-Null
    Stop-TimerRequest | Out-Null
    Assert-True ($script:Calls.Count -eq 2) 'one acquire / one release'
    Assert-True ((-not $script:Calls[1].Enable) -and ($script:Calls[1].DesiredTicks -eq 5000)) 'matching release'
    Assert-True (-not (Get-TimerStatus).RequestOwned) 'ownership cleared'
}
Test-Case 'unsupported 0.5 ms is rejected without silently requesting another value' {
    $script:Finest=10000
    Assert-Throws { Start-TimerRequest } 'unsupported resolution exposed'
    Assert-True (($script:Calls.Count -eq 0) -and (-not $script:TimerRequestOwned)) 'no acquisition'
}
Test-Case 'a different returned resolution is reported honestly and still released' {
    $script:Reported=10000
    $state=Start-TimerRequest
    Assert-True ($state.RequestOwned -and ($state.ReportedMilliseconds -eq 1)) 'mismatch does not lose ownership'
    Assert-True ((Format-TimerStatus $state).Contains('1.0000 ms')) 'actual returned value displayed'
    Stop-TimerRequest | Out-Null
    Assert-True ($script:Calls.Count -eq 2) 'mismatched value still gets matching release'
}
Test-Case 'failed acquisition does not create ownership or issue a spurious release' {
    $script:AcquireFails=$true
    Assert-Throws { Start-TimerRequest } 'failure surfaced'
    Stop-TimerRequest | Out-Null
    Assert-True ((-not $script:TimerRequestOwned) -and ($script:Calls.Count -eq 1)) 'no acquired request to release'
}
Test-Case 'a failed range query does not acquire a timer' {
    $script:QueryFails=$true
    Assert-Throws { Start-TimerRequest } 'query failure surfaced'
    Assert-True (($script:Calls.Count -eq 0) -and (-not $script:TimerRequestOwned)) 'no set after failed query'
}
Test-Case 'failed release retains ownership for a later retry' {
    Start-TimerRequest | Out-Null
    $script:ReleaseFails=$true
    Assert-Throws { Stop-TimerRequest } 'release failure surfaced'
    Assert-True $script:TimerRequestOwned 'ownership retained'
    $script:ReleaseFails=$false
    Stop-TimerRequest | Out-Null
    Assert-True ((-not $script:TimerRequestOwned) -and ($script:Calls.Count -eq 3)) 'retry successfully releases'
}
Test-Case 'errors after acquisition can still release in finally' {
    try {
        Start-TimerRequest | Out-Null
        throw 'Simulated UI failure after acquisition'
    } catch { } finally { Stop-TimerRequest | Out-Null }
    Assert-True (($script:Calls.Count -eq 2) -and (-not $script:TimerRequestOwned)) 'cleanup does not leak owned request'
}
Test-Case 'a refresh failure while active does not lose request ownership' {
    Start-TimerRequest | Out-Null
    $script:QueryFails=$true
    Assert-Throws { Get-TimerStatus -Refresh } 'refresh failure surfaced'
    Assert-True $script:TimerRequestOwned 'still active'
    Stop-TimerRequest | Out-Null
    Assert-True (-not $script:TimerRequestOwned) 'Stop can release without a query'
}
Test-Case 'Stop does not promise a fixed default while another app can retain a fine resolution' {
    Start-TimerRequest | Out-Null
    $state=Stop-TimerRequest
    Assert-True ((-not $state.RequestOwned) -and ($state.ReportedMilliseconds -eq 0.5)) 'reported value is independent of our ownership'
    Assert-True ((Format-TimerStatus $state).Contains('No timer request is active in this utility.')) 'ownership is described accurately'
}
Test-Case 'missing reported timing data does not orphan a successfully acquired request' {
    $script:Reported=0
    $state=Start-TimerRequest
    Assert-True ($state.RequestOwned -and ($null -eq $state.ReportedMilliseconds)) 'request tracked without a usable reported number'
    Stop-TimerRequest | Out-Null
    Assert-True (($script:Calls.Count -eq 2) -and (-not $script:TimerRequestOwned)) 'cleanup still pairs'
}
Write-Host ("`n{0} timer tests passed. Native timer calls were mocked, not executed." -f $script:Passed)
