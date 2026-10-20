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
    '--profile', 'test-snort-1776',
    'run', '--rm', 'snort-mysql-test-client'
)

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$alertLog = Join-Path $repositoryRoot 'logs\snort-alerts.log'

function Get-TargetAlertCount {
    if (-not (Test-Path $alertLog)) {
        return 0
    }

    return (Select-String -Path $alertLog -Pattern '"rule"\s*:\s*"1:(1776:9|1000002:1)"' |
        Measure-Object).Count
}

$alertsBefore = Get-TargetAlertCount

& podman @podmanArguments
if ($LASTEXITCODE -ne 0) {
    throw 'The MySQL test client failed to send the SHOW DATABASES query.'
}

$alertDeadline = (Get-Date).AddSeconds(20)
do {
    if ((Get-TargetAlertCount) -gt $alertsBefore) {
        Write-Output 'Success: Snort logged the MySQL SHOW DATABASES test alert.'
        return
    }
    Start-Sleep -Seconds 1
} while ((Get-Date) -lt $alertDeadline)

throw "The MySQL query succeeded, but no MySQL SHOW DATABASES alert appeared in '$alertLog'. Check 'podman compose --profile enabled logs snort' and verify Snort is capturing podman1."
