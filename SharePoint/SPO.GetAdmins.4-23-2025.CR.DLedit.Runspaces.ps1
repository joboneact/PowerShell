# SPO.GetAdmins.4-23-2025.CR.DLedit.Runspaces.ps1

# Variables for processing
$AdminCenterURL = "https://bartxo-admin.sharepoint.com"
$ReportOutput = "C:\Tmp\SPO\SiteCollectionAdminsResults.csv"

# Load the SharePoint Online module
Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop

# Connect to SharePoint Online
Connect-SPOService -Url $AdminCenterURL

# Retrieve all site collections
$Sites = Get-SPOSite -Limit All

# Initialize a collection for results
$SiteData = [System.Collections.Concurrent.ConcurrentBag[PSObject]]::new()

# Create a runspace pool
$RunspacePool = [runspacefactory]::CreateRunspacePool(1, [Environment]::ProcessorCount)
$RunspacePool.Open()

# Create a collection of runspaces
$Runspaces = @()

foreach ($Site in $Sites) {
    # Create a PowerShell instance for each site
    $PowerShell = [powershell]::Create().AddScript({
        param($Site, $AdminCenterURL)

        # Import the SharePoint Online module in the runspace
        Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop

        # Initialize a collection for results
        $JobResults = @()

        Try {
            # Get all Site Collection Administrators
            $SiteAdmins = Get-SPOUser -Site $Site.Url -Limit ALL |
                          Where-Object { $_.IsSiteAdmin -eq $True } |
                          Select-Object DisplayName, LoginName

            # Process Site Collection Administrators
            $SiteAdmins | ForEach-Object {
                if ($_.LoginName -ne "mcloudgrpproprodsvc@irsgov.onmicrosoft.com") {
                    $JobResults += [PSCustomObject]@{
                        'TempID'                = $Site.Id
                        'URL'                   = $Site.Url
                        'Site Collection Admins' = "$($_.DisplayName) ($($_.LoginName));"
                    }
                }
            }
        } catch {
            $JobResults += [PSCustomObject]@{
                'TempID'                = $Site.Id
                'URL'                   = $Site.Url
                'Site Collection Admins' = "Error: $($_.Exception.Message)"
            }
        }

        # Return the results
        return $JobResults
    }).AddArgument($Site).AddArgument($AdminCenterURL)

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
    $Results = $Runspace.Pipe.Invoke()
    $Results | ForEach-Object { $SiteData.Add($_) }
    $Runspace.Pipe.Dispose()
}

# Close the runspace pool
$RunspacePool.Close()
$RunspacePool.Dispose()

# Export the data to a CSV file
$SiteData | Export-Csv -Path $ReportOutput -NoTypeInformation
Write-Host -ForegroundColor Green "Site Collection Administrators Data Exported to CSV!"