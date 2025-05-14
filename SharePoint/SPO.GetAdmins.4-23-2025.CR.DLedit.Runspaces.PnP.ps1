# SPO.GetAdmins.4-23-2025.CR.DLedit.Runspaces.PnP.ps1
# Needs PowerShell 7.4.6
# PnP version

# Variables for processing
$AdminCenterURL = "https://bartxo-admin.sharepoint.com"
$ReportOutput = "C:\Tmp\SPO\SiteCollectionAdminsResults.csv"

# Load the PnP PowerShell module
if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
    Write-Host "Installing PnP.PowerShell module..." -ForegroundColor Yellow
    Install-Module -Name PnP.PowerShell -Force
}
Import-Module PnP.PowerShell -ErrorAction Stop

# Connect to SharePoint Online using PnP PowerShell
# This supports modern authentication, including MFA
Connect-PnPOnline -Url $AdminCenterURL -UseWebLogin

# Retrieve all site collections
$Sites = Get-PnPTenantSite -IncludeOneDriveSites:$false -Detailed

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

        # Import the PnP PowerShell module in the runspace
        Import-Module PnP.PowerShell -ErrorAction Stop

        # Initialize a collection for results
        $JobResults = @()

        Try {
            # Connect to the site collection
            Connect-PnPOnline -Url $Site.Url -UseWebLogin

            # Get all Site Collection Administrators
            $SiteAdmins = Get-PnPUser -Web $Site.Url |
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