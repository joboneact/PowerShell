# Import the SharePoint Online Management Shell module
Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop

# Define the SharePoint Online admin URL
$adminUrl = "https://yourtenant-admin.sharepoint.com"

# Authenticate to SharePoint Online
Connect-SPOService -Url $adminUrl

# Log file to store results
$logFile = "C:\SiteAdminsLog.txt"
if (Test-Path $logFile) {
    Remove-Item $logFile -Force
}

# Get all SharePoint Online site collections
$sites = Get-SPOSite -Limit All

# Create an array to store jobs
$jobs = @()

# Process each site in parallel using jobs
foreach ($site in $sites) {
    $jobs += Start-Job -ScriptBlock {
        param ($siteUrl, $logFilePath)

        # Get all site administrators
        try {
            $admins = Get-SPOUser -Site $siteUrl -Filter "IsSiteAdmin -eq $true"
            foreach ($admin in $admins) {
                $logMessage = "Site: $siteUrl, Admin: $($admin.LoginName)"
                $logMessage | Add-Content -Path $logFilePath
            }
        } catch {
            $errorMessage = "Error retrieving admins for site $siteUrl: $_"
            $errorMessage | Add-Content -Path $logFilePath
        }
    } -ArgumentList $site.Url, $logFile
}

# Wait for all jobs to complete
$jobs | ForEach-Object {
    $_ | Wait-Job | Receive-Job
    Remove-Job -Job $_
}

Write-Host "Site admin retrieval completed. Check the log file at $logFile"