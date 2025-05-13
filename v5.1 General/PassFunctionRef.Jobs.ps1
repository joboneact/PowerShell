# PassFunctionRef.Jobs.ps1
# This script demonstrates how to use PowerShell jobs to process multiple SharePoint sites in parallel and write results to separate files.
# It includes error handling and uses a shared signal file to stop processing if an error occurs in any job.
# The script also validates the function reference, site URL, and output file path before processing.

<#
.SYNOPSIS
    Processes multiple SharePoint Online sites in parallel using PowerShell jobs.

.DESCRIPTION
    This script uses PowerShell jobs to process multiple SharePoint Online site URLs concurrently.
    Each job writes its results to a separate output file. If an error occurs in any job, a shared
    error signal file is created to notify other jobs to stop processing.

.PARAMETER SiteUrl
    The URL of the SharePoint Online site to process.

.PARAMETER OutputFile
    The file where the processing results for the site will be written.

.NOTES
    - Requires the Microsoft.Online.SharePoint.PowerShell module.
    - Ensure you have sufficient permissions to access the SharePoint Online sites.
    - The script uses a shared error signal file to coordinate error handling across jobs.

.EXAMPLE
    .\PassFunctionRef.Jobs.ps1
    Processes a predefined list of SharePoint Online sites in parallel and writes results to separate files.
#>

# Define the function to be executed in parallel
# The function takes a site URL and an output file path as parameters
# It simulates some processing and writes the results to the output file
# Error handling is included to catch any exceptions that occur during processing
function Invoke-Site {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Processes a single SharePoint Online site.

    .DESCRIPTION
        This function simulates processing for a SharePoint Online site. It writes the results
        to a specified output file and handles any errors that occur during processing.

    .PARAMETER SiteUrl
        The URL of the SharePoint Online site to process.

    .PARAMETER OutputFile
        The file where the processing results for the site will be written.

    .EXAMPLE
        Invoke-Site -SiteUrl "https://site1.sharepoint.com" -OutputFile "Output_site1.txt"
        Processes the specified SharePoint Online site and writes the results to "Output_site1.txt".
    #>
    param (
        [string]$SiteUrl,
        [string]$OutputFile
    )
    
    try {
        Write-Host "Processing Site: $SiteUrl" -ForegroundColor Yellow

        # Simulate some processing (replace with actual logic)
        Start-Sleep -Seconds 2

        # Write results to the output file
        "Processed Site: $SiteUrl" | Out-File -FilePath $OutputFile -Append
        Write-Host "Completed processing for: $SiteUrl" -ForegroundColor Green
    } catch {
        Write-Host "Error processing site: $SiteUrl - $($_.Exception.Message)" -ForegroundColor Red
        "Error processing site: $SiteUrl - $($_.Exception.Message)" | Out-File -FilePath $OutputFile -Append
    }
}

# List of site URLs to process
# Replace these URLs with the actual SharePoint Online site URLs you want to process.
$SiteUrls = @(
    "https://site1.sharepoint.com",
    "https://site2.sharepoint.com",
    "https://site3.sharepoint.com"
)

# Define a shared error signal file
# This file is used to signal other jobs to stop processing if an error occurs.
$ErrorSignalFile = ".\ErrorSignal.txt"

# Ensure the error signal file does not exist at the start
if (Test-Path $ErrorSignalFile) {
    Remove-Item $ErrorSignalFile -Force
}

# Initialize an array to store jobs
$Jobs = @()

# Loop through each site URL in the list
foreach ($SiteUrl in $SiteUrls) {
    # Generate a unique output file name for each site by replacing special characters in the URL
    $OutputFile = Join-Path -Path "." -ChildPath "Output_$($SiteUrl -replace 'https://|\.|/', '_').txt"

    # Start a new background job for each site
    $Jobs += Start-Job -ScriptBlock {
        # Define parameters to be passed into the job
        param($FunctionRef, $SiteUrl, $OutputFile, $ErrorSignalFile)

        # Check if an error has already been signaled
        if (Test-Path $ErrorSignalFile) {
            Write-Host "Skipping processing for $SiteUrl as an error has already been signaled." -ForegroundColor Yellow
            return
        }

        # Validate that the function reference is not null or invalid
        if (-not $FunctionRef) {
            Write-Host "Function reference is null or invalid." -ForegroundColor Red
            Set-Content -Path $ErrorSignalFile -Value "Error in job for $SiteUrl"
            return
        }

        # Validate that the site URL is not null or invalid
        if (-not $SiteUrl) {
            Write-Host "Site URL is null or invalid." -ForegroundColor Red
            Set-Content -Path $ErrorSignalFile -Value "Error in job for $SiteUrl"
            return
        }

        # Validate that the output file path is not null or invalid
        if (-not $OutputFile) {
            Write-Host "Output file path is null or invalid." -ForegroundColor Red
            Set-Content -Path $ErrorSignalFile -Value "Error in job for $SiteUrl"
            return
        }

        try {
            # Invoke the function reference, passing the site URL and output file as arguments
            & $FunctionRef -SiteUrl $SiteUrl -OutputFile $OutputFile
        } catch {
            Write-Host "Error occurred while processing $SiteUrl: $($_.Exception.Message)" -ForegroundColor Red
            Set-Content -Path $ErrorSignalFile -Value "Error in job for $SiteUrl"
        }
    } -ArgumentList ${function:Invoke-Site}, $SiteUrl, $OutputFile, $ErrorSignalFile # Pass the function reference and arguments to the job
}

# Wait for all jobs to complete
Write-Host "Waiting for jobs to complete..."
Wait-Job -Job $Jobs

# Check if the error signal file exists
if (Test-Path $ErrorSignalFile) {
    Write-Host "An error occurred in one or more jobs. Check the error signal file for details: $ErrorSignalFile" -ForegroundColor Red
} else {
    Write-Host "All jobs completed successfully!" -ForegroundColor Green
}

# Collect results from all jobs (if applicable)
foreach ($Job in $Jobs) {
    if ($Job.State -eq "Completed") {
        Receive-Job -Job $Job
    }
    Remove-Job -Job $Job
}