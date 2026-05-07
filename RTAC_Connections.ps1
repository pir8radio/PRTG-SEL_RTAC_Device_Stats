param (
    [string]$DeviceIP,
    [string]$Username,
    [string]$Password
)

$DeviceIP = $DeviceIP -replace '%', ''
$pair = "${Username}:${Password}"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$encodedCreds = [Convert]::ToBase64String($bytes)
$headers = @{ Authorization = "Basic $encodedCreds" }

Add-Type -TypeDefinition @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

# Create history directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$historyDir = Join-Path $scriptDir "FDC_HISTORY"
if (-not (Test-Path $historyDir)) {
    New-Item -Path $historyDir -ItemType Directory | Out-Null
}

# API endpoint
$uri = "https://$DeviceIP/api/v1/projects/active/connections"

try {
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET
} catch {
    $errorOutput = @{
        prtg = @{
            error = 1
            text = "API request failed: $_"
        }
    }
    $errorOutput | ConvertTo-Json -Depth 5
    exit 1
}

$channels = @()
$statusMap = @{ "Online" = 2; "Offline" = 1; "Disabled" = 0 }

# Determine if response contains any connections and create a primary prtg channel
$hasConnections = if ($response.Count -gt 0) { 1 } else { 0 }

# Add API Status channel once
$channels += @{
    channel = "API Status"
    value = $hasConnections
    unit = "Count"
    LimitMode = 1
    LimitMinError = 0
    isPrimaryChannel = 1
}

foreach ($conn in $response) {
    $name = $conn.Name
    $status = $statusMap[$conn.Status]
    if ($null -eq $status) { $status = -1 }

    $failures  = $conn.MessageCount.Status.Failures
    $successes = $conn.MessageCount.Status.Successes
    $sent      = $conn.MessageCount.Total.Sent
    $received  = $conn.MessageCount.Total.Received

    if ($null -eq $failures)  { $failures = -1 }
    if ($null -eq $successes) { $successes = -1 }
    if ($null -eq $sent)      { $sent = -1 }
    if ($null -eq $received)  { $received = -1 }

# Log status to history file
$logFile = Join-Path $historyDir "$name.txt"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"$timestamp,$status" | Out-File -FilePath $logFile -Append -Encoding UTF8
# Read entries from the last 30 and 7 days and calculate uptime %
$uptimePercent30 = -1
$uptimePercent7 = -1

if (Test-Path $logFile) {
    $lines = Get-Content $logFile

    # 30-day calculation
    $cutoffDate30 = (Get-Date).AddDays(-30)
    $recentLines30 = $lines | Where-Object {
        $lineDate = Get-Date ($_ -split ",")[0]
        $lineDate -ge $cutoffDate30
    }
    $total30 = $recentLines30.Count
    $online30 = ($recentLines30 | Where-Object { ($_ -split ",")[1] -ne "1" }).Count
    if ($total30 -gt 0) {
        $uptimePercent30 = [int][math]::Round(($online30 / $total30) * 100, 2)
    }

    # 7-day calculation
    $cutoffDate7 = (Get-Date).AddDays(-7)
    $recentLines7 = $lines | Where-Object {
        $lineDate = Get-Date ($_ -split ",")[0]
        $lineDate -ge $cutoffDate7
    }
    $total7 = $recentLines7.Count
    $online7 = ($recentLines7 | Where-Object { ($_ -split ",")[1] -ne "1" }).Count
    if ($total7 -gt 0) {
        $uptimePercent7 = [int][math]::Round(($online7 / $total7) * 100, 2)
    }

    # Clean-up log file
    # Remove lines older than 30 days
    $cutoffDate = (Get-Date).AddDays(-30)
    $filteredLines = $lines | Where-Object {
        $lineDate = Get-Date ($_ -split ",")[0]
        $lineDate -ge $cutoffDate
    }

    # Overwrite the log file with filtered lines
    $filteredLines | Out-File -FilePath $logFile -Encoding UTF8
}

    $channels += @(
        @{ channel = "$name Status"; value = $status; unit = "Custom"; mode = "lookup"; ValueLookup = "rtac.connection.status" },
        @{ channel = "$name Failures"; value = $failures; unit = "Count" },
        @{ channel = "$name Successes"; value = $successes; unit = "Count" },
        @{ channel = "$name Sent"; value = $sent; unit = "Count" },
        @{ channel = "$name Received"; value = $received; unit = "Count" },
        @{ channel = "$name 7-Day Uptime"; value = $uptimePercent7; unit = "Percent"; float = 1; DecimalMode = "All"; LimitMode = 1; LimitMinWarning = 98; LimitMinError = 95 },
        @{ channel = "$name 30-Day Uptime"; value = $uptimePercent30; unit = "Percent"; float = 1; DecimalMode = "All"; LimitMode = 1; LimitMinWarning = 98; LimitMinError = 95 }
    )
}

# Output JSON for PRTG
$prtgOutput = @{ prtg = @{ result = $channels } }
$prtgOutput | ConvertTo-Json -Depth 5
