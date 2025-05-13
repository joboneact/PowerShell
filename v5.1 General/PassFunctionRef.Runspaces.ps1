# PassFunctionRef.Runspaces.ps1
# This script demonstrates how to pass a function reference to a runspace in PowerShell.
# It processes multiple SharePoint Online site URLs concurrently using runspaces.
# The script includes error handling and uses a shared signal file to stop processing if an error occurs.

<#
.SYNOPSIS
    Processes multiple SharePoint Online sites concurrently using PowerShell runspaces.

.DESCRIPTION
    This script uses PowerShell runspaces to process multiple SharePoint Online site URLs in parallel.
    Each runspace executes a function that processes a single site and writes the results to a unique output file.
    If an error occurs in any runspace, a shared error signal file is created to notify other runspaces to stop processing.

.PARAMETER SiteUrl
    The URL of the SharePoint Online site to process.

.PARAMETER OutputFile
    The file where the processing results for the site will be written.

.NOTES
    - This script uses PowerShell runspaces for efficient multithreading.
    - Ensure you have sufficient permissions to access the SharePoint Online sites.
    - The script uses a shared error signal file to coordinate error handling across runspaces.

.EXAMPLE
    .\PassFunctionRef.Runspaces.ps1
    Processes a predefined list of SharePoint Online sites in parallel and writes results to separate files.
#>

# Define a function to be executed in the runspace
function Invoke-Site {
    param (
        [string]$SiteUrl,    # The URL of the SharePoint Online site to process
        [string]$OutputFile  # The file where the processing results will be written
    )

    # Simulate some processing
    Start-Sleep -Seconds 2

    # Simulate an error for demonstration purposes
    if ($SiteUrl -eq "https://example.com/error") {
        throw "Simulated error for $SiteUrl"
    }

    # Write output to the specified file
    "Processed site: $SiteUrl" | Out-File -FilePath $OutputFile -Append
}

# Define a shared error signal file
# This file is used to signal other runspaces to stop processing if an error occurs.
$ErrorSignalFile = ".\ErrorSignal.txt"

# Ensure the error signal file does not exist at the start
if (Test-Path $ErrorSignalFile) {
    Remove-Item $ErrorSignalFile -Force
}

# Create a runspace pool
# The runspace pool allows multiple threads to run concurrently, up to the number of processor cores.
$RunspacePool = [runspacefactory]::CreateRunspacePool(1, [Environment]::ProcessorCount)
$RunspacePool.Open()

# Create a collection to store runspace data
# This collection will track the state of each runspace.
$Runspaces = @()

# List of site URLs to process
# Replace these URLs with the actual SharePoint Online site URLs you want to process.
$SiteUrls = @(
    "https://site1.sharepoint.com",
    "https://site2.sharepoint.com",
    "https://example.com/error" # Simulated error
)

# Loop through each site URL in the list
foreach ($SiteUrl in $SiteUrls) {
    # Generate a unique output file name for each site
    # Special characters in the URL are replaced to create a valid file name.
    $OutputFile = Join-Path -Path "." -ChildPath "Output_$($SiteUrl -replace 'https://|\.|/', '_').txt"

    # Create a PowerShell instance for the runspace
    # The script block defines the logic to execute in the runspace.
    $PowerShell = [powershell]::Create().AddScript({
        param($FunctionRef, $SiteUrl, $OutputFile, $ErrorSignalFile)

        # Check if an error has already been signaled
        # If the error signal file exists, skip processing for this site.
        if (Test-Path $ErrorSignalFile) {
            Write-Host "Skipping processing for $SiteUrl as an error has already been signaled." -ForegroundColor Yellow
            return
        }

        try {
            # Invoke the function reference, passing the site URL and output file as arguments
            & $FunctionRef -SiteUrl $SiteUrl -OutputFile $OutputFile
        } catch {
            # Handle any errors that occur during processing
            Write-Host "Error occurred while processing $SiteUrl: $($_.Exception.Message)" -ForegroundColor Red
            # Signal an error by creating the error signal file
            Set-Content -Path $ErrorSignalFile -Value "Error in runspace for $SiteUrl"
        }
    }).AddArgument(${function:Invoke-Site}).AddArgument($SiteUrl).AddArgument($OutputFile).AddArgument($ErrorSignalFile)

    # Assign the runspace pool to the PowerShell instance
    $PowerShell.RunspacePool = $RunspacePool

    # Start the runspace and store its state
    # The runspace state is tracked in the $Runspaces collection.
    $Runspaces += @{
        PowerShell = $PowerShell
        Handle = $PowerShell.BeginInvoke()
    }
}

# Wait for all runspaces to complete
Write-Host "Waiting for runspaces to complete..."
foreach ($Runspace in $Runspaces) {
    # Wait for the runspace to finish execution
    $Runspace.PowerShell.EndInvoke($Runspace.Handle)
    # Dispose of the PowerShell instance to free resources
    $Runspace.PowerShell.Dispose()
}

# Close the runspace pool
# This releases resources associated with the runspace pool.
$RunspacePool.Close()
$RunspacePool.Dispose()

# Check if the error signal file exists
# If the file exists, it indicates that an error occurred in one or more runspaces.
if (Test-Path $ErrorSignalFile) {
    Write-Host "An error occurred in one or more tasks. Check the error signal file for details: $ErrorSignalFile" -ForegroundColor Red
} else {
    Write-Host "All tasks completed successfully!" -ForegroundColor Green
}