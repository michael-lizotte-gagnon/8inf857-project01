$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repositoryRoot

function Get-TestAlertCount {
    $body = @{
        query = @{
            match_phrase = @{
                rule = "1:1000001:2"
            }
        }
        size = 0
    } | ConvertTo-Json -Depth 5

    try {
        $result = Invoke-RestMethod -Method Post `
            -Uri "http://localhost:9200/snort-alerts-*/_search" `
            -ContentType "application/json" `
            -Body $body `
            -TimeoutSec 5
        return [int]$result.hits.total.value
    }
    catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 404) {
            return 0
        }
        throw
    }
}

function Wait-ForElasticsearch {
    $readyBy = (Get-Date).AddSeconds(120)
    do {
        try {
            $null = Invoke-RestMethod -Uri "http://localhost:9200/" -TimeoutSec 5
            return Get-TestAlertCount
        }
        catch {
            if ((Get-Date) -ge $readyBy) {
                throw "Elasticsearch did not become available: $($_.Exception.Message)"
            }
            Start-Sleep -Seconds 2
        }
    } while ((Get-Date) -lt $readyBy)
}

try {
    & podman compose --profile enabled --profile test-alerts up -d --force-recreate snort-test-capture
    if ($LASTEXITCODE -ne 0) {
        throw "Could not start the Snort test web service."
    }

    $before = Wait-ForElasticsearch
    & podman compose --profile enabled --profile test-alerts run --rm snort-test-client
    if ($LASTEXITCODE -ne 0) {
        throw "The test client could not complete its requests to the Nginx endpoint."
    }
    Write-Output "Sent two HTTP requests to the Nginx test endpoint."

    $expected = $before + 2
    $indexedBy = (Get-Date).AddSeconds(90)
    do {
        $count = Get-TestAlertCount
        if ($count -ge $expected) {
            Write-Output "Success: Elasticsearch now has $count matching Snort alert(s)."
            return
        }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $indexedBy)

    throw "Timed out waiting for two new alerts in Elasticsearch. Check 'podman compose --profile enabled --profile test-alerts logs snort-test-capture logstash' and inspect the shared alert file with 'podman compose --profile enabled --profile test-alerts exec snort-test-capture tail -n 20 /var/log/snort/alert_json.txt'."
}
finally {
    Pop-Location
}
