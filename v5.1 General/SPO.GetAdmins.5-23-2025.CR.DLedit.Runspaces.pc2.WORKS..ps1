# SPO.GetAdmins.5-23-2025.CR.DLedit.Runspaces.pc2.ps1
# SPO.GetAdmins.4-23-2025.CR.DLedit.Runspaces.pc2.ps1

# This script retrieves all site collection administrators from SharePoint Online and exports the results to a CSV file.
# It uses runspaces for parallel processing to improve performance.
# The script also includes error handling and proxy settings for environments that require them.

<#
cd C:\Tmp\SPO
#>

# change log
# Fri 5-23-2025 12:07p
# MUST USE PowerShell ISE (tested under Windows 11)
# C:\Tmp\SPO should exist
# 1. Added detailed comments to the script for clarity.
# 2. Added error handling for cmdlet not found and no parameters found.
# 3. Improved UI layout and added comments for clarity.
# 4. Added cmdlet name box to allow user to select cmdlet from a list.
# 5. Added cmdlet search box to filter cmdlets as user types.
# 6. Added button to show parameters for the selected cmdlet.
# 7. Added ListBox to display cmdlet parameters.
# 8. Added TextBox to display parameter help.


# Variables for processing
# xx $AdminCenterURL = "https://bartxo-admin.sharepoint.com"
$AdminCenterURL = "https://bartco1-admin.sharepoint.com"
$ReportOutput = "C:\Tmp\SPO\SiteCollectionAdminsResults.csv"


<# run selected
Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell -ErrorAction Stop
Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell 
# original below
# Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
$AdminCenterURL = "https://bartco1-admin.sharepoint.com"
Connect-SPOService -Url $AdminCenterURL -Verbose
#>


# interactive login
function Ensure-SPOManagementShellModule {
    <#
    .SYNOPSIS
        Ensures the Microsoft.Online.SharePoint.PowerShell module is installed and up to date.

    .DESCRIPTION
        Checks if the SharePoint Online Management Shell module is installed. If not, attempts to install it.
        Updates the module to the latest version if already installed.

    .PARAMETER ModuleName
        The name of the module to check and install. Default is 'Microsoft.Online.SharePoint.PowerShell'.

    .EXAMPLE
        Ensure-SPOManagementShellModule
    #>
    param (
        [string]$ModuleName = "Microsoft.Online.SharePoint.PowerShell"
    )

    # Check if the SharePoint Online Management Shell module is installed
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "$ModuleName module is not installed. Attempting to install..." -ForegroundColor Yellow
        try {
            Install-Module -Name $ModuleName -Force -ErrorAction Stop
            Write-Host "$ModuleName module installed successfully." -ForegroundColor Green
        } catch {
            Write-Host "Failed to install $ModuleName module. Exiting script." -ForegroundColor Red
            Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
            Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Stack Trace: $($_.Exception.StackTrace)" -ForegroundColor DarkGray
            exit
        }
    }
    # Update the module to the latest version
    Update-Module $ModuleName
    Connect-SPOService -Url $AdminCenterURL
    Write-Host "Connected to SharePoint Online successfully." -ForegroundColor Green
}

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
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.Exception.StackTrace)" -ForegroundColor DarkGray
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

# Added below - results  - cleanup 5-23-2025 MDW


# Display the results
$SiteData | ForEach-Object {
    Write-Host -ForegroundColor Green "Site URL: $($_.URL)"
    Write-Host -ForegroundColor Green "Site Collection Admins: $($_.'Site Collection Admins')"
}
# Display the total number of site collections processed
Write-Host -ForegroundColor Green "Total Site Collections Processed: $($SiteData.Count)"
# Display the total number of site collections with errors
$ErrorCount = $SiteData | Where-Object { $_.'Site Collection Admins' -like "Error:*" }
Write-Host -ForegroundColor Red "Total Site Collections with Errors: $($ErrorCount.Count)"
# Display the total number of site collections with no admins
$NoAdminCount = $SiteData | Where-Object { $_.'Site Collection Admins' -eq "" }
Write-Host -ForegroundColor Yellow "Total Site Collections with No Admins: $($NoAdminCount.Count)"
# Display the total number of site collections with admins
$WithAdminCount = $SiteData | Where-Object { $_.'Site Collection Admins' -ne "" -and $_.'Site Collection Admins' -notlike "Error:*" }
Write-Host -ForegroundColor Cyan "Total Site Collections with Admins: $($WithAdminCount.Count)"
# Display the total number of site collections with multiple admins
$MultiAdminCount = $SiteData | Where-Object { $_.'Site Collection Admins' -like "*;*" }
Write-Host -ForegroundColor Magenta "Total Site Collections with Multiple Admins: $($MultiAdminCount.Count)"
# Display the total number of site collections with a specific admin
$SpecificAdminCount = $SiteData | Where-Object { $_.'Site Collection Admins' -like "*@irsgov.onmicrosoft.com" }
Write-Host -ForegroundColor Blue "Total Site Collections with Specific Admin: $($SpecificAdminCount.Count)"
# Display the total number of site collections with a specific admin
$SpecificAdminCount = $SiteData | Where-Object { $_.'Site Collection Admins' -like "*@irsgov.onmicrosoft.com" }
Write-Host -ForegroundColor Blue "Total Site Collections with Specific Admin: $($SpecificAdminCount.Count)"

# Added below - cleanup 5-23-2025 MDW

# Disconnect from SharePoint Online
Disconnect-SPOService
Write-Host -ForegroundColor Green "Disconnected from SharePoint Online."
# End of script
# Cleanup
# $SiteData.Clear() # error [System.Management.Automation.PSCustomObject] does not contain a method named 'Clear'.
$SiteData = $null
$Runspaces.Clear()
$Runspaces = $null
$PowerShell = $null
$RunspacePool = $null
$Sites = $null
$AdminCenterURL = $null
$ReportOutput = $null
$ProxyUrl = $null
$BypassProxyForLocal = $null
[System.Environment]::SetEnvironmentVariable("HTTP_PROXY", $null, [System.EnvironmentVariableTarget]::Process)
[System.Environment]::SetEnvironmentVariable("HTTPS_PROXY", $null, [System.EnvironmentVariableTarget]::Process)
[System.Environment]::SetEnvironmentVariable("NO_PROXY", $null, [System.EnvironmentVariableTarget]::Process)
# End of script
# End of script
# End of script
# End of script
# End of script




