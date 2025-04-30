# SPO Get Site Admins DL.ps1 
# April 2025
#
# 
# Import the SharePoint Online Management Shell module
Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop

# Connect to SharePoint Online
## $tenantAdminUrl = "https://<your-tenant-name>-admin.sharepoint.com" # Replace <your-tenant-name> with your tenant name


$tenantAdminUrl = "https://bartxo-admin.sharepoint.com"; # Replace with your tenant admin URL
# Example: https://<your-tenant-name>-admin.sharepoint.com
# Example: https://bartxo-admin.sharepoint.com

# https://bartxo-admin.sharepoint.com/_layouts/15/online/AdminHome.aspx#/home

Connect-SPOService -Url $tenantAdminUrl

# Get all site collections
$sites = Get-SPOSite -Limit All

# Create an array to store job results
$jobs = @()

# Loop through each site and create a job to get administrators
foreach ($site in $sites) {
    $jobs += Start-Job -ScriptBlock {
        param($siteUrl)

        # Import the SharePoint Online module in the job
        Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop

        # Get administrators for the site
        $admins = Get-SPOUser -Site $siteUrl | Where-Object { $_.IsSiteAdmin -eq $true }

        # Initialize a collection for results
        $results = @()

        # Initialize a collection for log messages
        $logMessages = @()

        foreach ($admin in $admins) {
            # Check if the admin is a group
            if ($admin.PrincipalType -eq "SharePointGroup") {
                # Get all members of the group
                $groupMembers = Get-SPOUser -Site $siteUrl -Group $admin.LoginName
                foreach ($member in $groupMembers) {
                    $results += [PSCustomObject]@{
                        SiteUrl   = $siteUrl
                        AdminType = "Group Member"
                        AdminName = $member.LoginName
                    }
                }
            } else {
                # Add individual admin to results
                $results += [PSCustomObject]@{
                    SiteUrl   = $siteUrl
                    AdminType = "Individual"
                    AdminName = $admin.LoginName
                }

                # Log the individual admin details
                $logMessages += "Site URL: $siteUrl Admin Type: Individual Admin Name: $($admin.LoginName)"
                $logMessages += "----------------------------------"
                $logMessages += "----------------------------------"
            }
        }
        # Return the results and log messages
        [PSCustomObject]@{
            Results = $results
            Logs    = $logMessages
        }
        $results
    } -ArgumentList $site.Url
}

# Wait for all jobs to complete
Write-Host "Waiting for jobs to complete..."
Wait-Job -Job $jobs

        $jobOutput = Receive-Job -Job $job
        $results += $jobOutput.Results
        $jobOutput.Logs | ForEach-Object { Write-Host $_ }
$results = @()
foreach ($job in $jobs) {
    if ($job.State -eq "Completed") {
        $results += Receive-Job -Job $job
    }
    Remove-Job -Job $job
}

# Output the results
$results | Format-Table -AutoSize

# Optionally, export the results to a CSV file
$results | Export-Csv -Path "SharePointAdmins.csv" -NoTypeInformation

Write-Host "Completed. Results exported to SharePointAdmins.csv."