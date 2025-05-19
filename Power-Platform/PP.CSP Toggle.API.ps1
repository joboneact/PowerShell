# PP.CSP Toggle.API.ps1

# Replace these values
$environmentUrl = "https://<your-environment>.crm.dynamics.com"
$clientId = "<your-client-id>"
$clientSecret = "<your-client-secret>"
$tenantId = "<your-tenant-id>"

# Get access token
$body = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    scope         = "$environmentUrl/.default"
}
$tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -ContentType "application/x-www-form-urlencoded" -Body $body
$token = $tokenResponse.access_token

# Get current CSP config (optional)
$headers = @{ Authorization = "Bearer $token" }
$cspConfig = Invoke-RestMethod -Method Get -Uri "$environmentUrl/api/data/v9.2/contentsecuritypolicyconfigurations" -Headers $headers

# Toggle CSP (example: enable CSP)
$configurationId = $cspConfig.value[0].contentsecuritypolicyconfigurationid
$body = @{
    "iscspenabled" = $true  # Set to $false to disable
} | ConvertTo-Json

Invoke-RestMethod -Method Patch -Uri "$environmentUrl/api/data/v9.2/contentsecuritypolicyconfigurations($configurationId)" -Headers $headers -ContentType "application/json" -Body $body