# PassFunctionRef.Batch.Runspaces.ps1
# This script demonstrates how to batch process many input lines using PowerShell runspaces.
# It includes error handling and uses a shared signal to manage concurrent processing.

# Define a function to process each input line
function Convert-Line {
    param (
        [string]$InputLine,
        [string]$OutputFile
    )

    # Simulate some processing
    Start-Sleep -Seconds 1

    # Simulate an error for demonstration purposes
    if ($InputLine -eq "ErrorLine") {
        throw "Simulated error for $InputLine"
    }

    # Write output to the specified file
    "Processed line: $InputLine" | Out-File -FilePath $OutputFile -Append
}

# Define a shared error signal file
$ErrorSignalFile = ".\ErrorSignal.txt"

# Ensure the error signal file does not exist at the start
if (Test-Path $ErrorSignalFile) {
    Remove-Item $ErrorSignalFile -Force
}

# Create a runspace pool
$RunspacePool = [runspacefactory]::CreateRunspacePool(1, [Environment]::ProcessorCount)
$RunspacePool.Open()

# Create a collection to store runspace data
$Runspaces = @()

# Input lines to process
$InputLines = @(
    "Line1",
    "Line2",
    "ErrorLine", # Simulated error
    "Line3",
    "Line4"
)

# Batch size for processing
$BatchSize = 2

# Split input lines into batches
$Batches = @()
for ($i = 0; $i -lt $InputLines.Count; $i += $BatchSize) {
    $Batches += ,($InputLines[$i..[math]::Min($i + $BatchSize - 1, $InputLines.Count - 1)])
}

# Process each batch
foreach ($Batch in $Batches) {
    foreach ($InputLine in $Batch) {
        # Generate a unique output file name for each line
        $OutputFile = Join-Path -Path "." -ChildPath "Output_$($InputLine -replace ' ', '_').txt"

        # Create a PowerShell instance for the runspace
        $PowerShell = [powershell]::Create().AddScript({
            param($FunctionRef, $InputLine, $OutputFile, $ErrorSignalFile)

            # Check if an error has already been signaled
            if (Test-Path $ErrorSignalFile) {
                Write-Host "Skipping processing for $InputLine as an error has already been signaled." -ForegroundColor Yellow
                return
            }

            try {
                # Invoke the function reference, passing the input line and output file as arguments
                & $FunctionRef -InputLine $InputLine -OutputFile $OutputFile
            } catch {
                Write-Host "Error occurred while processing $InputLine : $($_.Exception.Message)" -ForegroundColor Red
                Set-Content -Path $ErrorSignalFile -Value "Error in runspace for $InputLine"
            }
        }).AddArgument(${function:Convert-Line}).AddArgument($InputLine).AddArgument($OutputFile).AddArgument($ErrorSignalFile)

        # Assign the runspace pool to the PowerShell instance
        $PowerShell.RunspacePool = $RunspacePool

        # Start the runspace and store its state
        $Runspaces += @{
            PowerShell = $PowerShell
            Handle = $PowerShell.BeginInvoke()
        }
    }

    # Wait for all runspaces in the current batch to complete
    Write-Host "Waiting for runspaces in the current batch to complete..."
    foreach ($Runspace in $Runspaces) {
        $Runspace.PowerShell.EndInvoke($Runspace.Handle)
        $Runspace.PowerShell.Dispose()
    }

    # Clear the runspaces collection for the next batch
    $Runspaces.Clear()
}

# Close the runspace pool
$RunspacePool.Close()
$RunspacePool.Dispose()

# Check if the error signal file exists
if (Test-Path $ErrorSignalFile) {
    Write-Host "An error occurred in one or more tasks. Check the error signal file for details: $ErrorSignalFile" -ForegroundColor Red
} else {
    Write-Host "All tasks completed successfully!" -ForegroundColor Green
}