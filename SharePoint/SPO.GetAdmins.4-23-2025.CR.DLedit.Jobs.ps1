# SPO.GetAdmins.4-23-2025.CR.DLedit.Jobs.ps1

# Variables for processing
$AdminCenterURL = "https://bartxo-admin.sharepoint.com"
$ReportOutput = "C:\Tmp\SPO\SiteCollectionAdminsResults.csv"

Try {
    # Connect to SharePoint Online
    Connect-SPOService -Url $AdminCenterURL

    # Retrieve all site collections
    $Sites = Get-SPOSite -Limit All
    $Jobs = @()

    # Start a job for each site collection
    foreach ($Site in $Sites) {
        $Jobs += Start-Job -ScriptBlock {
            param($Site)

            # Import the SharePoint Online module in the job
            Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop

            # Initialize a collection for results
            $JobResults = @()

            Try {
                # Get all Site Collection Administrators
                $SiteAdmins = Get-SPOUser -Site $Site.Url -Limit ALL |
                              Where-Object { $_.IsSiteAdmin -eq $True } |
                              Select-Object DisplayName, LoginName

                # Process Site Collection Administrators
                $SiteAdmins | ForEach-Object {
                    if ($_.LoginName -ne "mcloudgrpproprodsvc@irsgov.onmicrosoft.com") {
                        $JobResults += New-Object PSObject -Property @{
                            'TempID'                = $Site.Id
                            'URL'                   = $Site.Url
                            'Site Collection Admins' = "$($_.DisplayName) ($($_.LoginName));"
                        }
                    }
                }
            } catch {
                $JobResults += New-Object PSObject -Property @{
                    'TempID'                = $Site.Id
                    'URL'                   = $Site.Url
                    'Site Collection Admins' = "Error: $($_.Exception.Message)"
                }
            }

            # Return the results
            $JobResults
        } -ArgumentList $Site
    }

    # Wait for all jobs to complete
    Write-Host -ForegroundColor Yellow "Waiting for jobs to complete..."
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
} catch {
    Write-Host -ForegroundColor Red "Error: $($_.Exception.Message)"
}





# Key Changes:
# Added PowerShell Jobs:

# Used Start-Job to process each site collection in parallel.
# Passed the $Site object as a parameter to the job.
# Imported Module in Each Job:

# Since jobs run in isolated sessions, the Microsoft.Online.SharePoint.PowerShell module is imported within each job.
# Collected Results:

# Used Receive-Job to gather results from all completed jobs.
# Removed jobs after processing to free up resources.
# Maintained Compatibility with PowerShell 5.1:

# Used Start-Job, which is fully supported in PowerShell 5.1.
# This approach improves performance by processing site collections in parallel while remaining compatible with PowerShell 5.1.


