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

# Create a list to store tasks
$tasks = @()

# Process each site in parallel using .NET Tasks
foreach ($site in $sites) {
    $tasks += [System.Threading.Tasks.Task]::Run({
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
    }, $site.Url, $logFile)
}

# Wait for all tasks to complete
[System.Threading.Tasks.Task]::WaitAll($tasks)

Write-Host "Site admin retrieval completed. Check the log file at $logFile"