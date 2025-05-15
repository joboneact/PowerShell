# BatchProcessing.SharedFile.MultiComputer.ps1
# This script demonstrates how to batch process a large collection of items using multiple PowerShell instances across multiple computers with a shared network location.

# Define the shared network location for the input file, lock file, and output file
$SharedFolder = "\\NetworkShare\BatchProcessing" # Replace with your shared network folder
$InputFile = Join-Path -Path $SharedFolder -ChildPath "BatchInput.txt"
$OutputFile = Join-Path -Path $SharedFolder -ChildPath "BatchProcessingResults.csv"
$LockFile = Join-Path -Path $SharedFolder -ChildPath "BatchInput.lock"

# Define the batch size
$BatchSize = 100

# Ensure the shared folder exists
if (-not (Test-Path $SharedFolder)) {
    Write-Host "Shared folder not found. Please ensure the shared folder exists: $SharedFolder" -ForegroundColor Red
    exit
}

# Ensure the input file exists
if (-not (Test-Path $InputFile)) {
    Write-Host "Input file not found. Generating a new input file..." -ForegroundColor Yellow
    1..1000 | Set-Content -Path $InputFile # Example: A collection of 1000 items
}

# Function to get the next batch of items
function Get-NextBatch {
    while (Test-Path $LockFile) {
        Start-Sleep -Milliseconds 100 # Wait for the lock to be released
    }

    # Create a lock file
    New-Item -Path $LockFile -ItemType File -Force | Out-Null

    # Read the input file
    $Items = Get-Content -Path $InputFile

    # Get the next batch
    $Batch = $Items[0..[math]::Min($BatchSize - 1, $Items.Count - 1)]

    # Remove the processed items from the input file
    if ($Batch.Count -gt 0) {
        $RemainingItems = $Items[$Batch.Count..($Items.Count - 1)]
        Set-Content -Path $InputFile -Value $RemainingItems
    }

    # Remove the lock file
    Remove-Item -Path $LockFile -Force

    return $Batch
}

# Function to process a batch
function Process-Batch {
    param (
        [array]$Batch
    )

    # Initialize a collection for results
    $BatchResults = @()

    foreach ($Item in $Batch) {
        try {
            # Simulate processing (replace with actual logic)
            Start-Sleep -Milliseconds 100 # Simulate work
            $BatchResults += [PSCustomObject]@{
                Item = $Item
                Status = "Processed"
            }
        } catch {
            # Handle errors
            $BatchResults += [PSCustomObject]@{
                Item = $Item
                Status = "Error: $($_.Exception.Message)"
            }
        }
    }

    # Append the results to the output file
    $BatchResults | Export-Csv -Path $OutputFile -NoTypeInformation -Append
}

# Main processing loop
while ((Get-Content -Path $InputFile -ErrorAction SilentlyContinue).Count -gt 0) {
    # Get the next batch
    $Batch = Get-NextBatch

    if ($Batch.Count -gt 0) {
        Write-Host "Processing batch: $($Batch -join ', ')" -ForegroundColor Cyan
        Process-Batch -Batch $Batch
    } else {
        Write-Host "No more items to process." -ForegroundColor Green
        break
    }
}

Write-Host -ForegroundColor Green "Batch processing completed. Results exported to $OutputFile."