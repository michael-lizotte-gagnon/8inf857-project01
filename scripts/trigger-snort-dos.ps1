#Gen AI

[CmdletBinding()]
param(
    [string]$Connection
)

$ErrorActionPreference = 'Stop'
$podmanArguments = @()
if (-not [string]::IsNullOrWhiteSpace($Connection)) {
    $podmanArguments += @('--connection', $Connection)
}
$podmanArguments += @(
    'compose',
    '--profile', 'enabled',
    '--profile', 'test-snort-dos',
    'run', '--rm', 'snort-icmp-test-client'
)

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$alertLog = Join-Path $repositoryRoot 'logs\snort-alerts.log'
$targetSids = '1:(221|222):'

function Get-TargetAlertCount {
    if (-not (Test-Path $alertLog)) {
        return 0
    }

    return (Select-String -Path $alertLog -Pattern ('"rule"\s*:\s*"' + $targetSids) |
        Measure-Object).Count
}

$alertsBefore = Get-TargetAlertCount

& podman @podmanArguments
if ($LASTEXITCODE -ne 0) {
    throw 'The ICMP test client failed to send the test packets.'
}

$alertDeadline = (Get-Date).AddSeconds(20)
do {
    if ((Get-TargetAlertCount) -ge ($alertsBefore + 2)) {
        Write-Output 'Success: Snort logged both ICMP DoS test alerts (SIDs 221 and 222).'
        return
    }
    Start-Sleep -Seconds 1
} while ((Get-Date) -lt $alertDeadline)

throw "Expected ICMP test alerts for SIDs 221 and 222 in '$alertLog'. Check Snort capture and community rule configuration."
