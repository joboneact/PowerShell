# GetRanges-SPO-Sites.ps1
# This script retrieves SharePoint Online (SPO) sites in ranges using PowerShell.
# It uses the Microsoft.Online.SharePoint.PowerShell module to connect to SharePoint Online and fetch site collections.
# Ensure the Microsoft.Online.SharePoint.PowerShell module is installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Online.SharePoint.PowerShell)) {
    Write-Host "Installing Microsoft.Online.SharePoint.PowerShell module..." -ForegroundColor Yellow
    Install-Module -Name Microsoft.Online.SharePoint.PowerShell -Force
}

# Import the module
Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop

# Connect to SharePoint Online
# Replace <AdminSiteUrl> with your SharePoint Online admin center URL (e.g., https://contoso-admin.sharepoint.com)
Connect-SPOService -Url "<AdminSiteUrl>"

# Define the range size for pagination
$PageSize = 50

# Initialize variables
$Sites = @()
$StartIndex = 0

# Retrieve SPO sites in ranges
do {
    # Get a range of sites
    $CurrentBatch = Get-SPOSite -StartIndex $StartIndex -Limit $PageSize

    # Add the current batch to the list of sites
    $Sites += $CurrentBatch

    # Increment the start index for the next batch
    $StartIndex += $PageSize
} while ($CurrentBatch.Count -eq $PageSize) # Continue until the last batch is smaller than the page size

# Output the retrieved sites
Write-Host "Retrieved $($Sites.Count) SharePoint Online sites:" -ForegroundColor Green
$Sites | ForEach-Object {
    Write-Host $_.Url
}

# Disconnect from SharePoint Online
Disconnect-SPOService