# Define the number of iterations
$Iterations = 10

# Initialize an array to store jobs
$Jobs = @()

# Start a job for each iteration
foreach ($i in 1..$Iterations) {
    $Jobs += Start-Job -ScriptBlock {
        param($Iteration)

        # Log the start of the job with a timestamp
        $StartTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $Timer = [System.Diagnostics.Stopwatch]::StartNew()
        Write-Host "[$StartTime] Starting calculation for iteration $Iteration"

        # Simulate a time-consuming mathematical calculation
        Start-Sleep -Seconds 3
        $Result = [math]::Pow($Iteration, 2) + [math]::Sqrt($Iteration)

        # Stop the timer and calculate elapsed time
        $Timer.Stop()
        $ElapsedMilliseconds = $Timer.ElapsedMilliseconds

        # Log the completion of the job with a timestamp and elapsed time
        $EndTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        Write-Host "[$EndTime] Completed calculation for iteration $Iteration in $ElapsedMilliseconds ms"

        # Return the result
        [PSCustomObject]@{
            Iteration          = $Iteration
            Result             = $Result
            ElapsedTimeMs      = $ElapsedMilliseconds
        }
    } -ArgumentList $i
}

# Wait for all jobs to complete
Write-Host "Waiting for jobs to complete..."
Wait-Job -Job $Jobs

# Collect results from all jobs
$Results = @()
foreach ($Job in $Jobs) {
    if ($Job.State -eq "Completed") {
        $Results += Receive-Job -Job $Job
    }
    Remove-Job -Job $Job
}

# Output the results
$Results | Format-Table -AutoSize

# Optionally, export the results to a CSV file
$Results | Export-Csv -Path "JobResults.csv" -NoTypeInformation
Write-Host "Results exported to JobResults.csv"