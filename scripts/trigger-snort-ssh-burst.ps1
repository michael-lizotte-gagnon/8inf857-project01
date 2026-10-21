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
    '--profile', 'test-snort-ssh-burst',
    'run', '--rm', 'snort-ssh-burst-test-client'
)

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$alertLog = Join-Path $repositoryRoot 'logs\snort-alerts.log'
$alertPattern = '"rule"\s*:\s*"1:1000003:1"'

function Get-TargetAlertCount {
    if (-not (Test-Path $alertLog)) {
        return 0
    }

    return (Select-String -Path $alertLog -Pattern $alertPattern |
        Measure-Object).Count
}

$alertsBefore = Get-TargetAlertCount

& podman @podmanArguments
if ($LASTEXITCODE -ne 0) {
    throw 'The SSH burst test client failed.'
}

$alertDeadline = (Get-Date).AddSeconds(20)
do {
    if ((Get-TargetAlertCount) -gt $alertsBefore) {
        Write-Output 'Success: Snort logged the SSH connection-burst alert (SID 1000003).'
        return
    }
    Start-Sleep -Seconds 1
} while ((Get-Date) -lt $alertDeadline)

throw "No SSH connection-burst alert appeared in '$alertLog'. Check Snort capture, HOME_NET, and local rules."
