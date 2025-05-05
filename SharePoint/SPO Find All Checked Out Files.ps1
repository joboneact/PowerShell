# SPO Find All Checked Out Files.ps1
# Script to find all checked-out files in all SharePoint Online sites using PowerShell 5.1 and multi-tasking

# Import the SharePoint Online module
Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop

# Variables
$AdminCenterURL = "https://yourtenant-admin.sharepoint.com"  # Replace with your tenant admin URL
$AdminCenterURL = "https://bartco1-admin.sharepoint.com/"

$ReportOutput = "C:\Tmp\SPO\CheckedOutFilesResults.csv"
$BatchSize = 10  # Number of sites per batch

# Function to process document libraries and retrieve checked-out files
<#
.SYNOPSIS
    Retrieves all checked-out files from a specific SharePoint Online site.

.DESCRIPTION
    This function connects to a specific SharePoint Online site, retrieves all document libraries, 
    and identifies files that are currently checked out. The results include details such as the 
    file name, the user who checked it out, and the date it was checked out.

.PARAMETER SiteUrl
    The URL of the SharePoint Online site to process.
    Example: "https://yourtenant.sharepoint.com/sites/sitename"

.OUTPUTS
    An array of objects containing details about checked-out files.

.NOTES
    Requires the Microsoft.Online.SharePoint.PowerShell module.
#>
function Get-CheckedOutFiles {
    param (
        [string]$SiteUrl
    )

    $Results = @()

    try {
        # Get all document libraries in the site
        $Libraries = Get-SPODocumentLibrary -Site $SiteUrl

        foreach ($Library in $Libraries) {
            # Get all checked-out files in the library
            $CheckedOutFiles = Get-SPOFile -Site $SiteUrl -Library $Library.Title -CheckedOutOnly

            foreach ($File in $CheckedOutFiles) {
                $Results += New-Object PSObject -Property @{
                    'SiteURL'       = $SiteUrl
                    'LibraryName'   = $Library.Title
                    'FileName'      = $File.Name
                    'CheckedOutBy'  = $File.CheckedOutBy
                    'CheckedOutDate' = $File.CheckedOutDate
                }
            }
        }
    } catch {
        # Handle errors and log them in the results
        Write-Host -ForegroundColor Red "Error processing site $SiteUrl : $($_.Exception.Message)"
        $Results += New-Object PSObject -Property @{
            'SiteURL'       = $SiteUrl
            'LibraryName'   = "Error"
            'FileName'      = "Error"
            'CheckedOutBy'  = "Error"
            'CheckedOutDate' = $($_.Exception.Message)
        }
    }

    return $Results
}

# Function to process all sites and retrieve checked-out files
<#
.SYNOPSIS
    Processes all SharePoint Online sites to retrieve checked-out files.

.DESCRIPTION
    This function connects to the SharePoint Online admin center, retrieves all site collections, 
    and processes them in batches. Each batch is processed in parallel using PowerShell jobs to 
    improve performance. The results are exported to a CSV file.

.PARAMETER AdminCenterURL
    The URL of the SharePoint Online admin center.
    Example: "https://yourtenant-admin.sharepoint.com"

.PARAMETER ReportOutput
    The file path where the results will be exported as a CSV.
    Example: "C:\Tmp\SPO\CheckedOutFilesResults.csv"

.PARAMETER BatchSize
    The number of sites to process in each batch. A smaller batch size reduces memory usage but 
    may increase the total processing time.
    Example: 10

.OUTPUTS
    Exports the results to a CSV file.

.NOTES
    Requires the Microsoft.Online.SharePoint.PowerShell module.
#>
function Process-AllSites {
    param (
        [string]$AdminCenterURL,
        [string]$ReportOutput,
        [int]$BatchSize
    )

    # Connect to SharePoint Online
    Write-Host "Connecting to SharePoint Online..." -ForegroundColor Green
    Connect-SPOService -Url $AdminCenterURL -Verbose

    # Retrieve all site collections
    Write-Host "Retrieving all site collections..." -ForegroundColor Cyan
    $Sites = Get-SPOSite -Limit All -Verbose

    # Split sites into batches
    $SiteBatches = $Sites | ForEach-Object -Begin { 
        $Batch = @() 
    } -Process {
        $Batch += $_
        if ($Batch.Count -eq $BatchSize) {
            $Batch
            $Batch = @()
        }
    } -End {
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
                Write-Host -ForegroundColor Yellow "Processing Site Collection: $($Site.Url)"
                $BatchResults += Get-CheckedOutFiles -SiteUrl $Site.Url
            }

            # Return the results for this batch
            $BatchResults
        } -ArgumentList $Batch
    }

    # Wait for all jobs to complete
    Write-Host "Waiting for jobs to complete..." -ForegroundColor Cyan
    Wait-Job -Job $Jobs

    # Collect results from all jobs
    $CheckedOutFilesData = @()
    foreach ($Job in $Jobs) {
        if ($Job.State -eq "Completed") {
            $CheckedOutFilesData += Receive-Job -Job $Job
        }
        Remove-Job -Job $Job  # Clean up the job
    }

    # Export the data to a CSV file
    $CheckedOutFilesData | Export-Csv -Path $ReportOutput -NoTypeInformation
    Write-Host -ForegroundColor Green "Checked-out files data exported to CSV: $ReportOutput"
}

# Call the function to process all sites
Process-AllSites -AdminCenterURL $AdminCenterURL -ReportOutput $ReportOutput -BatchSize $BatchSize