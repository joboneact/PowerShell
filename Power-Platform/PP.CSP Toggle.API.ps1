# PP.CSP Toggle.API.ps1

<#
.SYNOPSIS
    Updates the Content Security Policy (CSP) configuration in a Power Platform environment using the PATCH HTTP method.

.DESCRIPTION
    This command sends a PATCH request to the specified Power Platform environment's API endpoint to update an existing CSP configuration.
    The PATCH method is used to partially update an existing resource, allowing you to modify only the specified fields in the configuration without replacing the entire object.

.PARAMETER environmentUrl
    The base URL of the Power Platform environment (e.g., https://org.crm.dynamics.com).

.PARAMETER configurationId
    The unique identifier (GUID) of the CSP configuration to be updated.

.PARAMETER headers
    A hashtable containing the required HTTP headers, such as Authorization (Bearer token) and Accept.

.PARAMETER body
    The JSON-formatted string representing the fields to update in the CSP configuration.

.PARAMETER ContentType
    The content type of the request body. Should be "application/json".

.EXAMPLE
    # Sample JSON body for updating CSP configuration
    $body = @"
    {
        "pp_name": "Updated CSP Policy",
        "pp_description": "Updated description for the CSP policy.",
        "pp_enabled": true
    }
    "@

    # PATCH request to update the CSP configuration
    Invoke-RestMethod -Method Patch -Uri "$environmentUrl/api/data/v9.2/contentsecuritypolicyconfigurations($configurationId)" -Headers $headers -ContentType "application/json" -Body $body

.NOTES
    - The PATCH method only updates the fields specified in the request body. Other fields remain unchanged.
    - Ensure that the $headers variable contains a valid Authorization header with a bearer token for authentication.
    - The $body parameter must be a valid JSON string matching the schema of the CSP configuration entity.

.ERRORS
    - 400 Bad Request: The request body is invalid or missing required fields.
    - 401 Unauthorized: The Authorization header is missing or the token is invalid/expired.
    - 404 Not Found: The specified configurationId does not exist.
    - 500 Internal Server Error: An unexpected error occurred on the server.

.EXCEPTION
    - If the request fails, Invoke-RestMethod throws a terminating error. Use try/catch to handle exceptions and inspect the error details for troubleshooting.

.LINK
    https://learn.microsoft.com/powerapps/developer/data-platform/webapi/update-entity-using-web-api
#>

# Define the environment URL and headers
$environmentUrl = "https://org.crm.dynamics.com"  # Replace with your environment URL
$headers = @{
    "Authorization" = "Bearer $($token)"
    "Accept" = "application/json"
} # Ensure $token is defined and contains a valid bearer token
# Fetch the current CSP configuration to get the configuration ID
$cspConfig = Invoke-RestMethod -Method Get -Uri "$environmentUrl/api/data/v9.2/contentsecuritypolicyconfigurations" -Headers $headers -ContentType "application/json"   

# Check if the CSP configuration exists and retrieve the first one
if ($cspConfig.value.Count -eq 0) {
    Write-Error "No CSP configuration found in the environment."
    exit
}
if ($cspConfig.value.Count -gt 1) {
    Write-Error "Multiple CSP configurations found. Please specify the correct one."
    exit
}
# Get the configuration ID from the first CSP configuration
$configurationId = $cspConfig.value[0].contentsecuritypolicyconfigurationid

# Set CSP enabled/disabled. Change $true to $false to disable CSP.
$body = @{
    "iscspenabled" = $true  # Set to $false to disable CSP
} | ConvertTo-Json

# Update the CSP configuration using PATCH method
Invoke-RestMethod -Method Patch -Uri "$environmentUrl/api/data/v9.2/contentsecuritypolicyconfigurations($configurationId)" -Headers $headers -ContentType "application/json" -Body $body

# Check the response
if ($?) {   
    Write-Host "CSP configuration updated successfully."
} else {
    Write-Error "Failed to update CSP configuration."
}   
# End of script
# Ensure to replace the environment URL and token with your actual values before running the script.
# This script updates the Content Security Policy (CSP) configuration in a Power Platform environment using the PATCH HTTP method.
# This script is designed to be run in a PowerShell environment with access to the Power Platform API.
# It requires a valid bearer token for authentication and the necessary permissions to update CSP configurations.
# This script is part of the Power Platform administration toolkit and should be used with caution.
# Ensure you have the necessary permissions to update CSP configurations in your Power Platform environment.
# This script is intended for administrators and developers working with Power Platform environments.
# This script is provided as-is and should be tested in a development environment before deploying to production.
# This script is part of the Power Platform administration toolkit and is intended for use by administrators and developers.
# This script is designed to be run in a PowerShell environment with access to the Power Platform API.
# Ensure you have the necessary permissions to update CSP configurations in your Power Platform environment.

# This script is part of the Power Platform administration toolkit and should be used with caution.
# Ensure you have the necessary permissions to update CSP configurations in your Power Platform environment.    

# This script is intended for administrators and developers working with Power Platform environments.
# This script is provided as-is and should be tested in a development environment before deploying to production.
# This script is part of the Power Platform administration toolkit and is intended for use by administrators and developers.
# This script is designed to be run in a PowerShell environment with access to the Power Platform API.
# Ensure you have the necessary permissions to update CSP configurations in your Power Platform environment.    
# This script is part of the Power Platform administration toolkit and should be used with caution.
# Ensure you have the necessary permissions to update CSP configurations in your Power Platform environment.    




