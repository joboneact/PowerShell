# SPO.GetAdmins.4-23-2025.CR.DLedit.Runspaces.ps1

# Variables for processing
$AdminCenterURL = "https://bartxo-admin.sharepoint.com"
$ReportOutput = "C:\Tmp\SPO\SiteCollectionAdminsResults.csv"


<#
# Proxy settings
$ProxyUrl = "http://proxyserver:port" # Replace with your proxy server and port
$BypassProxyForLocal = "localhost,127.0.0.1" # Addresses to bypass the proxy

# Set proxy environment variables for the current session
[System.Environment]::SetEnvironmentVariable("HTTP_PROXY", $ProxyUrl, [System.EnvironmentVariableTarget]::Process)
[System.Environment]::SetEnvironmentVariable("HTTPS_PROXY", $ProxyUrl, [System.EnvironmentVariableTarget]::Process)
[System.Environment]::SetEnvironmentVariable("NO_PROXY", $BypassProxyForLocal, [System.EnvironmentVariableTarget]::Process)

#>



# Check if the Microsoft.Online.SharePoint.PowerShell module is loaded
if (-not (Get-Module -ListAvailable -Name Microsoft.Online.SharePoint.PowerShell)) {
    Write-Host "Microsoft.Online.SharePoint.PowerShell module is not loaded. Attempting to install..." -ForegroundColor Yellow
    try {
        Install-Module -Name Microsoft.Online.SharePoint.PowerShell -Force -ErrorAction Stop
        Write-Host "Microsoft.Online.SharePoint.PowerShell module installed successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to install Microsoft.Online.SharePoint.PowerShell module. Exiting script." -ForegroundColor Red
        exit
    }
}

# Import the SharePoint Online module
Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop

# Connect to SharePoint Online
try {
    Connect-SPOService -Url $AdminCenterURL
    Write-Host "Connected to SharePoint Online successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to connect to SharePoint Online. Check your proxy settings or credentials." -ForegroundColor Red
    exit
}

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