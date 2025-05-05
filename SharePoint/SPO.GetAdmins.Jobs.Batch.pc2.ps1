# SPO.GetAdmins.Jobs.Batch.ps1
# May 1, 2025
# This script retrieves Site Collection Administrators from SharePoint Online using PowerShell jobs and batching.
# It processes site collections in batches to improve performance and manage resource utilization.


# Install-Module -Name Microsoft.Online.SharePoint.PowerShell -Force
## Install-Module -Name Microsoft.Online.SharePoint.PowerShell -Force
Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop

<#
WARNING: The names of some imported commands from the module 'Microsoft.Online.SharePoint.PowerShell' include unapproved verbs that might make them less discoverable. To find the commands with unapproved verbs, run the Import-Module command again with the Verbose parameter. For a list of approved verbs, type Get-Verb.
#>


# Variables for processing
# $AdminCenterURL = "https://bartxo-admin.sharepoint.com"
# bartco1.sharepoint.com
# bartco1-admin.sharepoint.com

$AdminCenterURL = "https://bartco1-admin.sharepoint.com"

$ReportOutput = "C:\Tmp\SPO\SiteCollectionAdminsResults.csv"
$BatchSize = 10  # Number of sites per batch

<#

Error  not digitally signed.

powershell.exe -ExecutionPolicy Bypass -File "PowerShell\SharePoint\SPO.GetAdmins.Jobs.Batch.pc2.ps1" 

Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned


Install-Module -Name Microsoft.Online.SharePoint.PowerShell -Force -Scope CurrentUser
Install-Module -Name Microsoft.Online.SharePoint.PowerShell -Force -Scope AllUsers


#>

# Werk
<#

command shell
CHeck .NET version
 (Get-ItemPropertyValue -LiteralPath 'HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release) -ge 394802
Get-ItemPropertyValue -LiteralPath 'HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release
.NET Framework 4.8.1 	533320 	Windows 10, version 1809 and later
.NET Framework 4.8 	528040 	Windows 10, version 1809 and later
.NET Framework 4.7.2 	461808 	Windows 10, version 1803 and later  


Update-Module -Name Microsoft.Online.SharePoint.PowerShell


Could not load type 'Microsoft.SharePoint.Client.Publishing.PortalLaunch.PortalLaunchRedirectionType'
Microsoft.Online.SharePoint.PowerShell

Get-Module -ListAvailable | Where-Object { $_.Name -like "*SharePoint*" } | ForEach-Object { Remove-Module $_.Name -Force }


If your tenant uses MFA, the Connect-SPOService cmdlet may not work as expected.
Solution: Use the PnP PowerShell module, which supports modern authentication:

##
Install-Module -Name PnP.PowerShell -Force
about 10 mB

Reinstall

Uninstall-Module -Name Microsoft.Online.SharePoint.PowerShell -AllVersions -Force
Install-Module -Name Microsoft.Online.SharePoint.PowerShell -Force


#>


Write-Host "Starting SharePoint Online Site Collection Administrators Retrieval Script..." -ForegroundColor Green



# Connect to SharePoint Online
Connect-SPOService -Url $AdminCenterURL -Verbose


# 400
# Connect-SPOService -Url "https://bartco1-admin.sharepoint.com/" -Verbose
# 401
# Connect-SPOService -Url "https://bartxo-admin.sharepoint.com" -Verbose


# Retrieve all site collections

$Sites = Get-SPOSite -Limit All -Verbose
<#
$Sites = Get-SPOSite -Limit All -Verbose |
         Where-Object { $_.Template -ne "SPSPERS" -and $_.Url -notlike "*-my.sharepoint.com*" } |
         Select-Object Url, Id
#>

Write-Host "Total Site Collections Found: $($Sites.Count)" -ForegroundColor Cyan


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