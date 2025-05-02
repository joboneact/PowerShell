# Define the total number of iterations
# This determines how many calculations will be performed in total
$Iterations = 100

# Define the batch size for processing iterations in groups
# Each batch will process a subset of iterations concurrently
$BatchSize = 5

# Initialize an array to store jobs
# This array will hold references to all the jobs created for processing
$Jobs = @()

# Process iterations in batches
# The outer loop divides the total iterations into smaller batches
for ($BatchStart = 1; $BatchStart -le $Iterations; $BatchStart += $BatchSize) {

    # Calculate the end of the current batch
    # Ensure the batch does not exceed the total number of iterations
    $BatchEnd = [math]::Min($BatchStart + $BatchSize - 1, $Iterations)

    # Start a job for each iteration in the current batch
    # The inner loop creates a job for each iteration within the batch
    foreach ($i in $BatchStart..$BatchEnd) {

        # Add a new job to the jobs array
        $Jobs += Start-Job -ScriptBlock {
            param($Iteration)

            # Log the start of the job with a timestamp
            # This helps track when the job started
            $StartTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
            $Timer = [System.Diagnostics.Stopwatch]::StartNew()
            Write-Host "[$StartTime] Starting calculation for iteration $Iteration"

            # Simulate a time-consuming mathematical calculation
            # This represents the workload for each iteration
            Start-Sleep -Seconds 3
            $Result = [math]::Pow($Iteration, 2) + [math]::Sqrt($Iteration)

            # Stop the timer and calculate elapsed time
            # This measures how long the calculation took
            $Timer.Stop()
            $ElapsedMilliseconds = $Timer.ElapsedMilliseconds

            # Log the completion of the job with a timestamp and elapsed time
            # This provides detailed information about the job's execution
            $EndTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
            Write-Host "[$EndTime] Completed calculation for iteration $Iteration in $ElapsedMilliseconds ms"

            # Return the result as a custom object
            # This object contains the iteration number, result, and elapsed time
            [PSCustomObject]@{
                Iteration          = $Iteration
                Result             = $Result
                ElapsedTimeMs      = $ElapsedMilliseconds
            }
        } -ArgumentList $i
    }

    # Wait for all jobs in the current batch to complete
    # This ensures that all jobs in the batch finish before moving to the next batch
    Write-Host "Waiting for jobs in batch $BatchStart to $BatchEnd to complete..."
    Wait-Job -Job $Jobs

    # Collect results from all jobs in the current batch
    # Retrieve the output of completed jobs and clean up resources
    foreach ($Job in $Jobs) {
        if ($Job.State -eq "Completed") {
            $Results += Receive-Job -Job $Job
        }
        Remove-Job -Job $Job
    }

    # Clear the jobs array for the next batch
    # This prevents old jobs from interfering with the next batch
    $Jobs.Clear()
}

# Output the results in a formatted table
# Display the results of all iterations in a readable format
$Results | Format-Table -AutoSize

# Optionally, export the results to a CSV file
# Save the results to a file for further analysis or reporting
$Results | Export-Csv -Path "JobResults.csv" -NoTypeInformation
Write-Host "Results exported to JobResults.csv"