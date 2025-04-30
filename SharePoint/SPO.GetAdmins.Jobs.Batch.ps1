# SPO.GetAdmins.Jobs.Batch.ps1
# This script retrieves Site Collection Administrators from SharePoint Online using PowerShell jobs and batching.
# It processes site collections in batches to improve performance and manage resource utilization.

# Variables for processing
$AdminCenterURL = "https://bartxo-admin.sharepoint.com"
$ReportOutput = "C:\Tmp\SPO\SiteCollectionAdminsResults.csv"
$BatchSize = 10  # Number of sites per batch

# Connect to SharePoint Online
Connect-SPOService -Url $AdminCenterURL

# Retrieve all site collections
$Sites = Get-SPOSite -Limit All

# Split sites into batches
# each $Batch is a group of $BatchSize sites
# This is done to manage resource utilization and improve performance
$SiteBatches = $Sites | ForEach-Object -Begin { $Batch = @() } -Process {
    $Batch += $_
    if ($Batch.Count -eq $BatchSize) {
        # show batch
        $Batch
        # Reset the batch
        $Batch = @()
    }
} -End {
    if ($Batch.Count -gt 0) { $Batch }
}

# Initialize an array to store jobs
$Jobs = @()

# Start a job for each batch
foreach ($Batch in $SiteBatches) {
    $Jobs += Start-Job -ScriptBlock {
        param($Batch)

        # Import the SharePoint Online module in the job
        Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop

        $BatchResults = @()

        foreach ($Site in $Batch) {
            try {
                Write-Host -ForegroundColor Yellow "Processing Site Collection: $($Site.Url)"

                # Get all Site Collection Administrators
                $SiteAdmins = Get-SPOUser -Site $Site.Url -Limit ALL |
                              Where-Object { $_.IsSiteAdmin -eq $True } |
                              Select-Object DisplayName, LoginName

                # Process Site Collection Administrators
                $SiteAdmins | ForEach-Object {
                    if ($_.LoginName -ne "mcloudgrpproprodsvc@irsgov.onmicrosoft.com") {
                        $BatchResults += New-Object PSObject -Property @{
                            'TempID'                = $Site.Id
                            'URL'                   = $Site.Url
                            'Site Collection Admins' = "$($_.DisplayName) ($($_.LoginName));"
                        }
                    }
                }
            } catch {
                Write-Host -ForegroundColor Red "Error: $($_.Exception.Message)"
                $BatchResults += New-Object PSObject -Property @{
                    'TempID'                = $Site.Id
                    'URL'                   = $Site.Url
                    'Site Collection Admins' = "Error: $($_.Exception.Message)"
                }
            }
        }

        # Return the results for this batch
        $BatchResults
    } -ArgumentList $Batch
}

# Wait for all jobs to complete
Write-Host "Waiting for jobs to complete..."
Wait-Job -Job $Jobs

# Collect results from all jobs
$SiteData = @()
foreach ($Job in $Jobs) {
    if ($Job.State -eq "Completed") {
        $SiteData += Receive-Job -Job $Job
    }
    Remove-Job -Job $Job
}

# Export the data to a CSV file
$SiteData | Export-Csv -Path $ReportOutput -NoTypeInformation
Write-Host -ForegroundColor Green "Site Collection Administrators Data Exported to CSV!"


<#

Key Points in the Script:
Batching:

The $BatchSize variable determines how many sites are processed in each batch.
The ForEach-Object block splits the sites into smaller groups.
Parallel Processing:

Each batch is processed in a separate job using Start-Job.
Job Management:

Wait-Job ensures all jobs complete before collecting results.
Receive-Job retrieves the results from each job.
Thread-Safe Results:

Results from all jobs are combined into $SiteData for final processing.
Why Use Batching?
Improved Resource Utilization: Processing smaller groups of sites in parallel reduces the risk of overloading system resources.
Scalability: You can adjust the batch size ($BatchSize) based on the available system resources (e.g., CPU cores, memory).
This approach ensures efficient multitasking while maintaining control over resource usage.

#>