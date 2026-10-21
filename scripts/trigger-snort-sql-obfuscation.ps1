[CmdletBinding()]
param(
    [string]$Connection
)

$ErrorActionPreference = 'Stop'
$podmanConnectionArguments = @()
if (-not [string]::IsNullOrWhiteSpace($Connection)) {
    $podmanConnectionArguments += @('--connection', $Connection)
}
$composeProfileArguments = @(
    'compose',
    '--profile', 'enabled',
    '--profile', 'test-snort-sql-obfuscation'
)
$podmanBuildArguments = $podmanConnectionArguments + $composeProfileArguments + @(
    'build', 'snort-sql-obfuscation-web'
)
$podmanRunArguments = $podmanConnectionArguments + $composeProfileArguments + @(
    'run', '--rm', 'snort-sql-obfuscation-test-client'
)

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$alertLog = Join-Path $repositoryRoot 'logs\snort-alerts.log'

function Get-TargetAlertCount([string]$Pattern) {
    if (-not (Test-Path $alertLog)) {
        return 0
    }

    return (Select-String -Path $alertLog -Pattern $Pattern |
        Measure-Object).Count
}

$obfuscationRule = '"rule"\s*:\s*"1:1000004:1"'
$obfuscationAlertsBefore = Get-TargetAlertCount $obfuscationRule

try {
    & podman @podmanBuildArguments
    if ($LASTEXITCODE -ne 0) {
        throw 'The SQL obfuscation test web image could not be built.'
    }

    & podman @podmanRunArguments
    if ($LASTEXITCODE -ne 0) {
        throw 'The SQL obfuscation test request failed.'
    }

    $alertDeadline = (Get-Date).AddSeconds(20)
    do {
        $obfuscationAlerted = (Get-TargetAlertCount $obfuscationRule) -gt $obfuscationAlertsBefore
        if ($obfuscationAlerted) {
            Write-Output 'Success: Snort logged local SID 1000004 for the chained CHAR SQL sent to MariaDB.'
            return
        }
        Start-Sleep -Seconds 1
    } while ((Get-Date) -lt $alertDeadline)

    throw "The request completed, but Snort did not log SID 1000004 in '$alertLog'. Check Snort capture and the local CHAR rule."
}
finally {
    $podmanStopArguments = $podmanConnectionArguments + $composeProfileArguments + @(
        'stop', 'snort-sql-obfuscation-web'
    )
    & podman @podmanStopArguments
    if ($LASTEXITCODE -ne 0) {
        throw 'The SQL obfuscation test web server failed to shut down.'
    }
}
