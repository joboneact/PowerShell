# Define the total number of iterations to process
$Iterations = 100

# Define the batch size for processing iterations in groups
$BatchSize = 5

# Initialize a thread-safe collection to store results
$Results = [System.Collections.Concurrent.ConcurrentBag[PSObject]]::new()

# Create a runspace pool to manage parallel threads efficiently
# Minimum threads: 1, Maximum threads: Number of processor cores
$RunspacePool = [runspacefactory]::CreateRunspacePool(1, [Environment]::ProcessorCount)
$RunspacePool.Open()

# Initialize a collection to store runspace objects
$Runspaces = @()

# Process iterations in batches
for ($BatchStart = 1; $BatchStart -le $Iterations; $BatchStart += $BatchSize) {
    # Calculate the end of the current batch
    $BatchEnd = [math]::Min($BatchStart + $BatchSize - 1, $Iterations)

    # Loop through each iteration in the current batch
    foreach ($i in $BatchStart..$BatchEnd) {
        # Create a PowerShell instance for the current iteration
        $PowerShell = [powershell]::Create().AddScript({
            param($Iteration, $RunspaceId)

            # Log the start of the calculation with a timestamp
            $StartTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
            $Timer = [System.Diagnostics.Stopwatch]::StartNew()
            Write-Host "[$StartTime] [Runspace ID: $RunspaceId] Starting calculation for iteration $Iteration"

            # Simulate a time-consuming mathematical calculation
            Start-Sleep -Seconds 3
            $Result = [math]::Pow($Iteration, 2) + [math]::Sqrt($Iteration)

            # Stop the timer and calculate elapsed time
            $Timer.Stop()
            $ElapsedMilliseconds = $Timer.ElapsedMilliseconds

            # Log the completion of the calculation with a timestamp and elapsed time
            $EndTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
            Write-Host "[$EndTime] [Runspace ID: $RunspaceId] Completed calculation for iteration $Iteration in $ElapsedMilliseconds ms"

            # Return the result as a custom object
            [PSCustomObject]@{
                RunspaceId        = $RunspaceId
                Iteration         = $Iteration
                Result            = $Result
                ElapsedTimeMs     = $ElapsedMilliseconds
            }
        }).AddArgument($i).AddArgument([System.Guid]::NewGuid().ToString())

        # Assign the runspace pool to the PowerShell instance
        $PowerShell.RunspacePool = $RunspacePool

        # Add the PowerShell instance to the runspaces collection
        $Runspaces += [PSCustomObject]@{
            Pipe = $PowerShell
            Handle = $PowerShell.BeginInvoke()
        }
    }

    # Wait for all runspaces in the current batch to complete
    foreach ($Runspace in $Runspaces) {
        # End the asynchronous invocation and retrieve the result
        $Runspace.Pipe.EndInvoke($Runspace.Handle)
        $Result = $Runspace.Pipe.Invoke()

        # Add the result to the thread-safe collection
        $Result | ForEach-Object { $Results.Add($_) }

        # Dispose of the PowerShell instance to free resources
        $Runspace.Pipe.Dispose()
    }

    # Clear the runspaces collection for the next batch
    $Runspaces.Clear()
}

# Close and dispose of the runspace pool
$RunspacePool.Close()
$RunspacePool.Dispose()

# Output the results in a formatted table
$Results | Format-Table -AutoSize

# Optionally, export the results to a CSV file
$Results | Export-Csv -Path "RunspaceResults.csv" -NoTypeInformation
Write-Host "Results exported to RunspaceResults.csv"