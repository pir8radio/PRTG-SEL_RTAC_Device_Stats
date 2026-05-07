
param (
    [string]$DeviceIP,
    [string]$Username,
    [string]$Password
)

# Encode credentials for Basic Auth
$pair = "$Username:$Password"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$encodedCreds = [Convert]::ToBase64String($bytes)
$headers = @{
    Authorization = "Basic $encodedCreds"
}

# Define the API endpoint
$uri = "https://$DeviceIP/api/v1/projects/active/connections"

# Ignore SSL errors (self-signed certs)
Add-Type @" 
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

# Make the API request
try {
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET
} catch {
    Write-Host "Error accessing RTAC API: $_"
    exit 1
}

# Prepare PRTG output
$channels = @()
foreach ($conn in $response) {
    $name = $conn.Name
    $status = switch ($conn.Status) {
        "Online"  { 1 }
        "Offline" { 0 }
        "Disabled" { -1 }
        default   { -2 }
    }

    $failures = $conn.MessageCount.Status.Failures
    $successes = $conn.MessageCount.Status.Successes
    $sent = $conn.MessageCount.Total.Sent
    $received = $conn.MessageCount.Total.Received

    $channels += @{
        channel = "$name Status"
        value = $status
        unit = "Custom"
    }
    $channels += @{
        channel = "$name Failures"
        value = $failures
        unit = "Count"
    }
    $channels += @{
        channel = "$name Successes"
        value = $successes
        unit = "Count"
    }
    $channels += @{
        channel = "$name Sent"
        value = $sent
        unit = "Count"
    }
    $channels += @{
        channel = "$name Received"
        value = $received
        unit = "Count"
    }
}

# Output JSON for PRTG
$result = @{
    prtg = @{
        result = $channels
    }
}
$result | ConvertTo-Json -Depth 5
