# BatchProcessing.Runspaces.ps1
# Windows PowerShell 5.1
# 
# This script demonstrates how to batch process a large collection of items using PowerShell runspaces.

# Define a large collection of items to process
$Items = 1..1000 # Example: A collection of 1000 items

# Define the batch size
$BatchSize = 100

# Create a runspace pool
$RunspacePool = [runspacefactory]::CreateRunspacePool(1, [Environment]::ProcessorCount)
$RunspacePool.Open()

# Create a collection to store runspace data
$Runspaces = @()

# Split the collection into batches
$Batches = @()
for ($i = 0; $i -lt $Items.Count; $i += $BatchSize) {
    $Batches += ,($Items[$i..[math]::Min($i + $BatchSize - 1, $Items.Count - 1)])
}

# Process each batch
foreach ($Batch in $Batches) {
    # Create a PowerShell instance for each batch
    $PowerShell = [powershell]::Create().AddScript({
        param($Batch)

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

        # Return the results
        return $BatchResults
    }).AddArgument($Batch)

    # Assign the runspace pool to the PowerShell instance
    $PowerShell.RunspacePool = $RunspacePool

    # Start the runspace and store its state
    $Runspaces += [PSCustomObject]@{
        Pipe = $PowerShell
        Handle = $PowerShell.BeginInvoke()
    }
}

# Wait for all runspaces to complete
$Results = @()
foreach ($Runspace in $Runspaces) {
    $Runspace.Pipe.EndInvoke($Runspace.Handle)
    $Results += $Runspace.Pipe.Invoke()
    $Runspace.Pipe.Dispose()
}

# Close the runspace pool
$RunspacePool.Close()
$RunspacePool.Dispose()

# Output the results
$Results | ForEach-Object { Write-Host "Item: $($_.Item), Status: $($_.Status)" }

# Optionally, export the results to a CSV file
$Results | Export-Csv -Path "BatchProcessingResults.csv" -NoTypeInformation
Write-Host -ForegroundColor Green "Batch processing completed. Results exported to BatchProcessingResults.csv."