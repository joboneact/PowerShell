# Split sites into batches
# Each $Batch is a group of $BatchSize sites.
# This is done to manage resource utilization and improve performance.
$SiteBatches = $Sites | ForEach-Object -Begin { 
    $Batch = @()  # Initialize an empty batch
} -Process {
    $Batch += $_  # Add the current site to the batch

    # If the batch reaches the specified size, output it and reset the batch
    if ($Batch.Count -eq $BatchSize) {
        $Batch  # Output the completed batch
        $Batch = @()  # Reset the batch
    }
} -End {
    # Output any remaining sites in the last batch
    if ($Batch.Count -gt 0) { 
        $Batch 
    }
}

# Initialize an array to store jobs
$Jobs = @()

# Start a job for each batch
foreach ($Batch in $SiteBatches) {
    $Jobs += Start-Job -ScriptBlock {
        param($Batch)

        # Import the SharePoint Online module in the job
        Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop

        # Initialize an array to store results for the current batch
        $BatchResults = @()

        # Process each site in the batch
        foreach ($Site in $Batch) {
            try {
                Write-Host -ForegroundColor Yellow "Processing Site Collection: $($Site.Url)"

                # Get all Site Collection Administrators
                $SiteAdmins = Get-SPOUser -Site $Site.Url -Limit ALL |
                              Where-Object { $_.IsSiteAdmin -eq $True } |
                              Select-Object DisplayName, LoginName

                # Process each Site Collection Administrator
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
                # Handle errors and log them in the results
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
    Remove-Job -Job $Job  # Clean up the job
}

# Export the data to a CSV file
$SiteData | Export-Csv -Path $ReportOutput -NoTypeInformation
Write-Host -ForegroundColor Green "Site Collection Administrators Data Exported to CSV!"