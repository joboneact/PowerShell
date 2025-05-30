# Define the number of iterations
$Iterations = 10

# Initialize a collection for results
$Results = [System.Collections.Concurrent.ConcurrentBag[PSObject]]::new()

# Create a runspace pool
$RunspacePool = [runspacefactory]::CreateRunspacePool(1, [Environment]::ProcessorCount)
$RunspacePool.Open()

# Create a collection of runspaces
$Runspaces = @()

foreach ($i in 1..$Iterations) {
    # Create a PowerShell instance for each iteration
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

        # Return the result
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

# Wait for all runspaces to complete
foreach ($Runspace in $Runspaces) {
    $Runspace.Pipe.EndInvoke($Runspace.Handle)
    $Result = $Runspace.Pipe.Invoke()
    $Result | ForEach-Object { $Results.Add($_) }
    $Runspace.Pipe.Dispose()
}

# Close the runspace pool
$RunspacePool.Close()
$RunspacePool.Dispose()

# Output the results
$Results | Format-Table -AutoSize

# Optionally, export the results to a CSV file
$Results | Export-Csv -Path "RunspaceResults.csv" -NoTypeInformation
Write-Host "Results exported to RunspaceResults.csv"


<#

Key Changes:
Runspace Pool:

Created a runspace pool using [runspacefactory]::CreateRunspacePool() to manage parallel threads efficiently.
Limited the number of concurrent threads to the number of processor cores ([Environment]::ProcessorCount).
ConcurrentBag for Thread-Safe Results:

Used [System.Collections.Concurrent.ConcurrentBag] to store results in a thread-safe manner.
PowerShell Instances:

Created a PowerShell instance for each iteration and assigned the runspace pool to it.
Efficient Resource Management:

Disposed of each PowerShell instance after processing to free up resources.
Logging:

Added timestamps and elapsed time for each iteration, similar to the original script.
Example Log Output:
This script now uses runspaces for parallel processing, which is more efficient than PowerShell jobs, especially for scenarios requiring high performance.

#>
