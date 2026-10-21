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
    '--profile', 'test-snort-port-scan'
)
$podmanBuildArguments = $podmanConnectionArguments + $composeProfileArguments + @(
    'build', 'snort-port-scan-test-client'
)
$podmanRunArguments = $podmanConnectionArguments + $composeProfileArguments + @(
    'run', '--rm', 'snort-port-scan-test-client'
)

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$alertLog = Join-Path $repositoryRoot 'logs\snort-alerts.log'
$alertPattern = '"rule"\s*:\s*"122:'

function Get-PortScanAlertCount {
    if (-not (Test-Path $alertLog)) {
        return 0
    }

    return (Select-String -Path $alertLog -Pattern $alertPattern |
        Measure-Object).Count
}

$alertsBefore = Get-PortScanAlertCount

& podman @podmanBuildArguments
if ($LASTEXITCODE -ne 0) {
    throw 'The Nmap test image could not be built.'
}

& podman @podmanRunArguments
if ($LASTEXITCODE -ne 0) {
    throw 'The Nmap port scan failed.'
}

$alertDeadline = (Get-Date).AddSeconds(20)
do {
    if ((Get-PortScanAlertCount) -gt $alertsBefore) {
        Write-Output 'Success: Snort logged a port-scan inspector alert.'
        return
    }
    Start-Sleep -Seconds 1
} while ((Get-Date) -lt $alertDeadline)

throw "Nmap completed, but Snort did not log a port-scan alert in '$alertLog'. Check the port_scan inspector thresholds and Snort capture."
