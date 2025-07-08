# PowerShell System Information and Module Checker
#
# This script provides comprehensive information about:
# - PowerShell version and edition
# - Windows operating system version
# - All installed PowerShell modules
#
# Compatible with PowerShell 5.1 and later versions

<#
.SYNOPSIS
    Displays PowerShell version, Windows version, and all installed modules

.DESCRIPTION
    This script checks and displays:
    - PowerShell version information (version, edition, host)
    - Windows operating system details (version, build, edition)
    - Complete list of installed PowerShell modules with versions
    - Module installation locations and availability

.NOTES
    Requirements:
    - PowerShell 5.1 or higher
    - Windows operating system
    - Administrative privileges recommended for complete module enumeration
#>

# Function to get detailed PowerShell version information
function Get-PowerShellVersionInfo {
    Write-Host "=== PowerShell Version Information ===" -ForegroundColor Green
    Write-Host ""
    
    # PowerShell version details
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
    Write-Host "PowerShell Edition: $($PSVersionTable.PSEdition)" -ForegroundColor Cyan
    Write-Host "PowerShell Host: $($Host.Name)" -ForegroundColor Cyan
    Write-Host "Host Version: $($Host.Version)" -ForegroundColor Cyan
    
    # .NET Framework/Core version
    if ($PSVersionTable.PSEdition -eq "Desktop") {
        Write-Host ".NET Framework Version: $($PSVersionTable.CLRVersion)" -ForegroundColor Cyan
    } else {
        Write-Host ".NET Core Version: $($PSVersionTable.CLRVersion)" -ForegroundColor Cyan
    } # End if-else .NET version check
    
    # Platform and OS information from PowerShell perspective
    if ($PSVersionTable.Platform) {
        Write-Host "Platform: $($PSVersionTable.Platform)" -ForegroundColor Cyan
    } # End if platform check
    
    # PowerShell execution policy
    Write-Host "Execution Policy: $(Get-ExecutionPolicy)" -ForegroundColor Cyan
    
    # PowerShell installation path
    if ($PSHome) {
        Write-Host "PowerShell Home: $PSHome" -ForegroundColor Cyan
    } # End if PSHome check
    
    Write-Host ""
} # End function Get-PowerShellVersionInfo

# Function to get detailed Windows version information
function Get-WindowsVersionInfo {
    Write-Host "=== Windows Version Information ===" -ForegroundColor Green
    Write-Host ""
    
    try {
        # Get Windows version using WMI
        $osInfo = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
        
        Write-Host "Operating System: $($osInfo.Caption)" -ForegroundColor Yellow
        Write-Host "Version: $($osInfo.Version)" -ForegroundColor Yellow
        Write-Host "Build Number: $($osInfo.BuildNumber)" -ForegroundColor Yellow
        Write-Host "Service Pack: $($osInfo.ServicePackMajorVersion).$($osInfo.ServicePackMinorVersion)" -ForegroundColor Yellow
        Write-Host "Architecture: $($osInfo.OSArchitecture)" -ForegroundColor Yellow
        Write-Host "Install Date: $($osInfo.InstallDate)" -ForegroundColor Yellow
        Write-Host "Last Boot Time: $($osInfo.LastBootUpTime)" -ForegroundColor Yellow
        
        # Additional system information
        $computerInfo = Get-ComputerInfo -ErrorAction SilentlyContinue
        if ($computerInfo) {
            Write-Host "Windows Edition: $($computerInfo.WindowsEditionId)" -ForegroundColor Yellow
            Write-Host "Windows Product Name: $($computerInfo.WindowsProductName)" -ForegroundColor Yellow
            Write-Host "Windows Version (Release ID): $($computerInfo.WindowsVersion)" -ForegroundColor Yellow
        } # End if computerInfo check
        
        # Registry-based version info (more detailed for Windows 10/11)
        try {
            $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            $regInfo = Get-ItemProperty -Path $registryPath -ErrorAction Stop
            
            if ($regInfo.DisplayVersion) {
                Write-Host "Windows Display Version: $($regInfo.DisplayVersion)" -ForegroundColor Yellow
            } # End if DisplayVersion check
            if ($regInfo.ReleaseId) {
                Write-Host "Windows Release ID: $($regInfo.ReleaseId)" -ForegroundColor Yellow
            } # End if ReleaseId check
            if ($regInfo.UBR) {
                Write-Host "Update Build Revision (UBR): $($regInfo.UBR)" -ForegroundColor Yellow
            } # End if UBR check
        } # End inner try block for registry
        catch {
            Write-Host "Could not retrieve additional registry version information" -ForegroundColor Red
        } # End inner catch block for registry
        
    } # End outer try block
    catch {
        Write-Host "Error retrieving Windows version information: $($_.Exception.Message)" -ForegroundColor Red
    } # End outer catch block
    
    Write-Host ""
} # End function Get-WindowsVersionInfo

# Function to get all PowerShell modules with detailed information
function Get-AllModulesInfo {
    Write-Host "=== PowerShell Modules Information ===" -ForegroundColor Green
    Write-Host ""
    
    try {
        # Get installed modules
        $installedModules = Get-Module -ListAvailable | Sort-Object Name, Version -Descending
        
        if ($installedModules) {
            Write-Host "=== Installed Modules (Total: $($installedModules.Count)) ===" -ForegroundColor Magenta
            Write-Host ""
            
            foreach ($module in $installedModules) {
                Write-Host "Module: $($module.Name)" -ForegroundColor White
                Write-Host "  Version: $($module.Version)" -ForegroundColor Gray
                Write-Host "  Path: $($module.ModuleBase)" -ForegroundColor Gray
                Write-Host ""
            } # End foreach module
        } else {
            Write-Host "No modules found." -ForegroundColor Red
        } # End if-else installedModules
        
    } # End try block for Get-AllModulesInfo
    catch {
        Write-Host "Error retrieving module information: $($_.Exception.Message)" -ForegroundColor Red
    } # End catch block for Get-AllModulesInfo
    
    Write-Host ""
} # End function Get-AllModulesInfo

# Function to get detailed machine information
function Get-MachineInfo {
    Write-Host "=== Machine Information ===" -ForegroundColor Green
    Write-Host ""
    
    try {
        $computerInfo = Get-ComputerInfo -ErrorAction SilentlyContinue
        Write-Host "Machine Name: $($computerInfo.CsName)" -ForegroundColor Yellow
        Write-Host "Manufacturer: $($computerInfo.Manufacturer)" -ForegroundColor Yellow
        Write-Host "Model: $($computerInfo.Model)" -ForegroundColor Yellow
        Write-Host "System Type: $($computerInfo.SystemType)" -ForegroundColor Yellow
        Write-Host "Total Physical Memory: $($computerInfo.TotalPhysicalMemory)" -ForegroundColor Yellow
        Write-Host ""
    }
    catch {
        Write-Host "Error retrieving machine information: $($_.Exception.Message)" -ForegroundColor Red
    }
} # End function Get-MachineInfo

# Function to get detailed network information
function Get-NetworkInfo {
    Write-Host "=== Network Information ===" -ForegroundColor Green
    Write-Host ""
    
    try {
        $networkAdapters = Get-NetAdapter -ErrorAction SilentlyContinue
        foreach ($adapter in $networkAdapters) {
            Write-Host "Adapter Name: $($adapter.Name)" -ForegroundColor Yellow
            Write-Host "Status: $($adapter.Status)" -ForegroundColor Yellow
            Write-Host "MAC Address: $($adapter.MacAddress)" -ForegroundColor Yellow
            Write-Host "Link Speed: $($adapter.LinkSpeed)" -ForegroundColor Yellow
            Write-Host ""
        }
    }
    catch {
        Write-Host "Error retrieving network information: $($_.Exception.Message)" -ForegroundColor Red
    }
} # End function Get-NetworkInfo

# Function to check if a URL is valid
function Is-ValidUrl {
    param(
        [string]$Url
    )
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Function to export results to text file
function Export-SystemInfo {
    param(
        [string]$OutputPath = ".\SystemInfo_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    )
    
    Write-Host "=== Exporting System Information to Text File ===" -ForegroundColor Green
    Write-Host ""
    
    try {
        # Start capturing output to file
        Start-Transcript -Path $OutputPath -Force
        
        try {
            # Script Header
            Write-Host "=================================================" -ForegroundColor Cyan
            Write-Host "  POWERSHELL SYSTEM INFORMATION REPORT" -ForegroundColor Cyan
            Write-Host "  Generated: $(Get-Date)" -ForegroundColor Cyan
            Write-Host "=================================================" -ForegroundColor Cyan
            Write-Host ""

            # PowerShell version information
            Write-Host "=== PowerShell Version Information ===" -ForegroundColor Green
            Write-Host ""
            Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)"
            Write-Host "PowerShell Edition: $($PSVersionTable.PSEdition)"
            Write-Host "PowerShell Host: $($Host.Name)"
            Write-Host "Host Version: $($Host.Version)"
            Write-Host "CLR Version: $($PSVersionTable.CLRVersion)"
            Write-Host "PowerShell Script Path: $($MyInvocation.ScriptName)"
            Write-Host "Current Directory: $(Get-Location)"
            Write-Host "Execution Policy: $(Get-ExecutionPolicy)"
            if ($PSHome) {
                Write-Host "PowerShell Home: $PSHome"
            }
            Write-Host ""
            
            # Windows version information
            Write-Host "=== Windows Version Information ===" -ForegroundColor Green
            Write-Host ""
            try {
                $osInfo = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
                Write-Host "Operating System: $($osInfo.Caption)"
                Write-Host "Version: $($osInfo.Version)"
                Write-Host "Build Number: $($osInfo.BuildNumber)"
                Write-Host "Architecture: $($osInfo.OSArchitecture)"
                Write-Host "Service Pack: $($osInfo.ServicePackMajorVersion).$($osInfo.ServicePackMinorVersion)"
                Write-Host "Install Date: $($osInfo.InstallDate)"
                Write-Host "Last Boot Time: $($osInfo.LastBootUpTime)"
                
                # Registry-based version info
                $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
                $regInfo = Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue
                if ($regInfo) {
                    if ($regInfo.DisplayVersion) {
                        Write-Host "Windows Display Version: $($regInfo.DisplayVersion)"
                    }
                    if ($regInfo.ReleaseId) {
                        Write-Host "Windows Release ID: $($regInfo.ReleaseId)"
                    }
                    if ($regInfo.UBR) {
                        Write-Host "Update Build Revision (UBR): $($regInfo.UBR)"
                    }
                }
            } catch {
                Write-Host "Error: Unable to retrieve Windows version information"
                Write-Host "Exception: $($_.Exception.Message)" -ForegroundColor Red
            }
            Write-Host ""
            
            # Machine information
            Write-Host "=== Detailed Machine Information ===" -ForegroundColor Green
            Write-Host ""
            try {
                $computerInfo = Get-ComputerInfo -ErrorAction SilentlyContinue
                Write-Host "Machine Name: $($computerInfo.CsName)"
                Write-Host "Manufacturer: $($computerInfo.Manufacturer)"
                Write-Host "Model: $($computerInfo.Model)"
                Write-Host "System Type: $($computerInfo.SystemType)"
                Write-Host "Total Physical Memory: $([math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)) GB"
                Write-Host "BIOS Version: $($computerInfo.BiosVersion)"
                Write-Host "Processor: $($computerInfo.CsProcessors.Name)"
                Write-Host "Cores: $($computerInfo.CsProcessors.NumberOfCores)"
                Write-Host "Logical Processors: $($computerInfo.CsProcessors.NumberOfLogicalProcessors)"
                Write-Host "Windows Edition: $($computerInfo.WindowsEditionId)"
                Write-Host "Windows Product Name: $($computerInfo.WindowsProductName)"
            } catch {
                Write-Host "Error: Unable to retrieve machine information"
                Write-Host "Exception: $($_.Exception.Message)" -ForegroundColor Red
            }
            Write-Host ""
            
            # Network information
            Write-Host "=== Detailed Network Information ===" -ForegroundColor Green
            Write-Host ""
            try {
                $networkAdapters = Get-NetAdapter -ErrorAction SilentlyContinue
                foreach ($adapter in $networkAdapters) {
                    Write-Host "Adapter Name: $($adapter.Name)" -ForegroundColor Yellow
                    Write-Host "Status: $($adapter.Status)" -ForegroundColor Yellow
                    Write-Host "MAC Address: $($adapter.MacAddress)" -ForegroundColor Yellow
                    Write-Host "Link Speed: $($adapter.LinkSpeed)" -ForegroundColor Yellow
                    
                    # Get IP configuration for this adapter
                    $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue
                    foreach ($ip in $ipConfig) {
                        Write-Host "  IP Address: $($ip.IPAddress)" -ForegroundColor Yellow
                        Write-Host "  Prefix Length: $($ip.PrefixLength)" -ForegroundColor Yellow
                        Write-Host "  Address Family: $($ip.AddressFamily)" -ForegroundColor Yellow
                    }
                    Write-Host ""
                }
                
                # DNS information
                $dnsServers = Get-DnsClientServerAddress -ErrorAction SilentlyContinue
                Write-Host "DNS Servers:"
                foreach ($dns in $dnsServers | Where-Object {$_.ServerAddresses}) {
                    Write-Host "  Interface: $($dns.InterfaceAlias)" -ForegroundColor Yellow
                    Write-Host "  Address Family: $($dns.AddressFamily)" -ForegroundColor Yellow
                    Write-Host "  DNS Servers: $($dns.ServerAddresses -join ', ')" -ForegroundColor Yellow
                    Write-Host ""
                }
            } catch {
                Write-Host "Error: Unable to retrieve network information"
                Write-Host "Exception: $($_.Exception.Message)" -ForegroundColor Red
            }
            Write-Host ""
            
            # Installed modules information
            Write-Host "=== PowerShell Modules Information ===" -ForegroundColor Green
            Write-Host ""
            try {
                $installedModules = Get-Module -ListAvailable | Sort-Object Name, Version -Descending
                
                if ($installedModules) {
                    Write-Host "=== Installed Modules (Total: $($installedModules.Count)) ===" -ForegroundColor Magenta
                    Write-Host ""
                    
                    foreach ($module in $installedModules) {
                        Write-Host "Module: $($module.Name)" -ForegroundColor White
                        Write-Host "Version: $($module.Version)" -ForegroundColor Gray
                        Write-Host "Path: $($module.ModuleBase)" -ForegroundColor Gray
                        Write-Host ""
                    } # End foreach module
                } else {
                    Write-Host "No modules found." -ForegroundColor Red
                } # End if-else installedModules
                
            } # End try block for module information
            catch {
                Write-Host "Error retrieving module information: $($_.Exception.Message)" -ForegroundColor Red
            } # End catch block for module information
            
        } # End try block for exporting information
        finally {
            # Stop capturing output
            Stop-Transcript
        } # End finally block
        
        Write-Host "System information exported to: $OutputPath" -ForegroundColor Green
        
    } # End try block for Export-SystemInfo
    catch {
        Write-Host "Error exporting system information: $($_.Exception.Message)" -ForegroundColor Red
        # Log the error to the console and continue
        Write-Host "Continuing to HTML output generation..." -ForegroundColor Yellow
    } # End catch block for Export-SystemInfo
} # End function Export-SystemInfo

# Function to export results to HTML file
function Export-AllSystemInfoToHTML {
    param(
        [string]$OutputPath = ".\SystemInfo_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    )
    
    Write-Host "=== Exporting All System Information to HTML ===" -ForegroundColor Green
    Write-Host ""
    
    try {
        # Initialize HTML content
        $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>System Information</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #4CAF50; }
        h2 { color: #2196F3; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; }
        th { background-color: #f2f2f2; text-align: left; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        tr:hover { background-color: #ddd; }
        a { color: #2196F3; text-decoration: none; }
        a:hover { text-decoration: underline; }
        .header { background-color: #4CAF50; color: white; padding: 10px; text-align: center; margin-bottom: 20px; }
        .timestamp { font-size: 0.8em; margin-top: 5px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>System Information Report</h1>
        <div class="timestamp">Generated: $(Get-Date)</div>
    </div>
"@

        # Add PowerShell version information
        $htmlContent += "<h2>PowerShell Version Information</h2>"
        $htmlContent += "<table><tr><th>Property</th><th>Value</th></tr>"
        $htmlContent += "<tr><td>PowerShell Version</td><td>$($PSVersionTable.PSVersion)</td></tr>"
        $htmlContent += "<tr><td>PowerShell Edition</td><td>$($PSVersionTable.PSEdition)</td></tr>"
        $htmlContent += "<tr><td>PowerShell Host</td><td>$($Host.Name)</td></tr>"
        $htmlContent += "<tr><td>Host Version</td><td>$($Host.Version)</td></tr>"
        $htmlContent += "<tr><td>CLR Version</td><td>$($PSVersionTable.CLRVersion)</td></tr>"
        $htmlContent += "<tr><td>PowerShell Script Path</td><td>$($MyInvocation.ScriptName)</td></tr>"
        $htmlContent += "<tr><td>Current Directory</td><td>$(Get-Location)</td></tr>"
        $htmlContent += "<tr><td>Execution Policy</td><td>$(Get-ExecutionPolicy)</td></tr>"
        if ($PSHome) {
            $htmlContent += "<tr><td>PowerShell Home</td><td>$PSHome</td></tr>"
        }
        $htmlContent += "</table>"

        # Add Windows version information
        $htmlContent += "<h2>Windows Version Information</h2>"
        $htmlContent += "<table><tr><th>Property</th><th>Value</th></tr>"
        try {
            $osInfo = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
            $htmlContent += "<tr><td>Operating System</td><td>$($osInfo.Caption)</td></tr>"
            $htmlContent += "<tr><td>Version</td><td>$($osInfo.Version)</td></tr>"
            $htmlContent += "<tr><td>Build Number</td><td>$($osInfo.BuildNumber)</td></tr>"
            $htmlContent += "<tr><td>Architecture</td><td>$($osInfo.OSArchitecture)</td></tr>"
            $htmlContent += "<tr><td>Service Pack</td><td>$($osInfo.ServicePackMajorVersion).$($osInfo.ServicePackMinorVersion)</td></tr>"
            $htmlContent += "<tr><td>Install Date</td><td>$($osInfo.InstallDate)</td></tr>"
            $htmlContent += "<tr><td>Last Boot Time</td><td>$($osInfo.LastBootUpTime)</td></tr>"
            
            # Registry-based version info
            $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            $regInfo = Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue
            if ($regInfo) {
                if ($regInfo.DisplayVersion) {
                    $htmlContent += "<tr><td>Windows Display Version</td><td>$($regInfo.DisplayVersion)</td></tr>"
                }
                if ($regInfo.ReleaseId) {
                    $htmlContent += "<tr><td>Windows Release ID</td><td>$($regInfo.ReleaseId)</td></tr>"
                }
                if ($regInfo.UBR) {
                    $htmlContent += "<tr><td>Update Build Revision (UBR)</td><td>$($regInfo.UBR)</td></tr>"
                }
            }
        } catch {
            $htmlContent += "<tr><td>Error</td><td>Unable to retrieve Windows version information: $($_.Exception.Message)</td></tr>"
        }
        $htmlContent += "</table>"

        # Add detailed machine information
        $htmlContent += "<h2>Detailed Machine Information</h2>"
        $htmlContent += "<table><tr><th>Property</th><th>Value</th></tr>"
        try {
            $computerInfo = Get-ComputerInfo -ErrorAction SilentlyContinue
            $htmlContent += "<tr><td>Machine Name</td><td>$($computerInfo.CsName)</td></tr>"
            $htmlContent += "<tr><td>Manufacturer</td><td>$($computerInfo.Manufacturer)</td></tr>"
            $htmlContent += "<tr><td>Model</td><td>$($computerInfo.Model)</td></tr>"
            $htmlContent += "<tr><td>System Type</td><td>$($computerInfo.SystemType)</td></tr>"
            $htmlContent += "<tr><td>Total Physical Memory</td><td>$([math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)) GB</td></tr>"
            $htmlContent += "<tr><td>BIOS Version</td><td>$($computerInfo.BiosVersion)</td></tr>"
            $htmlContent += "<tr><td>Processor</td><td>$($computerInfo.CsProcessors.Name)</td></tr>"
            $htmlContent += "<tr><td>Cores</td><td>$($computerInfo.CsProcessors.NumberOfCores)</td></tr>"
            $htmlContent += "<tr><td>Logical Processors</td><td>$($computerInfo.CsProcessors.NumberOfLogicalProcessors)</td></tr>"
            $htmlContent += "<tr><td>Windows Edition</td><td>$($computerInfo.WindowsEditionId)</td></tr>"
            $htmlContent += "<tr><td>Windows Product Name</td><td>$($computerInfo.WindowsProductName)</td></tr>"
        } catch {
            $htmlContent += "<tr><td>Error</td><td>Unable to retrieve machine information: $($_.Exception.Message)</td></tr>"
        }
        $htmlContent += "</table>"

        # Add detailed network information
        $htmlContent += "<h2>Detailed Network Information</h2>"
        $htmlContent += "<table><tr><th>Adapter</th><th>Status</th><th>MAC Address</th><th>Link Speed</th><th>IP Configuration</th></tr>"
        try {
            $networkAdapters = Get-NetAdapter -ErrorAction SilentlyContinue
            foreach ($adapter in $networkAdapters) {
                $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue
                $ipInfo = ""
                foreach ($ip in $ipConfig) {
                    $ipInfo += "$($ip.IPAddress) ($($ip.AddressFamily))<br>"
                }
                
                $htmlContent += "<tr>"
                $htmlContent += "<td>$($adapter.Name)</td>"
                $htmlContent += "<td>$($adapter.Status)</td>"
                $htmlContent += "<td>$($adapter.MacAddress)</td>"
                $htmlContent += "<td>$($adapter.LinkSpeed)</td>"
                $htmlContent += "<td>$ipInfo</td>"
                $htmlContent += "</tr>"
            }
        } catch {
            $htmlContent += "<tr><td colspan='5'>Error retrieving network information: $($_.Exception.Message)</td></tr>"
        }
        $htmlContent += "</table>"

        # Add DNS information
        $htmlContent += "<h2>DNS Configuration</h2>"
        $htmlContent += "<table><tr><th>Interface</th><th>Address Family</th><th>DNS Servers</th></tr>"
        try {
            $dnsServers = Get-DnsClientServerAddress -ErrorAction SilentlyContinue
            foreach ($dns in $dnsServers | Where-Object {$_.ServerAddresses}) {
                $htmlContent += "<tr>"
                $htmlContent += "<td>$($dns.InterfaceAlias)</td>"
                $htmlContent += "<td>$($dns.AddressFamily)</td>"
                $htmlContent += "<td>$($dns.ServerAddresses -join ', ')</td>"
                $htmlContent += "</tr>"
            }
        } catch {
            $htmlContent += "<tr><td colspan='3'>Error retrieving DNS information: $($_.Exception.Message)</td></tr>"
        }
        $htmlContent += "</table>"

        # Add Installed Modules information
        $htmlContent += "<h2>PowerShell Modules Information</h2>"
        $htmlContent += "<table><tr><th>Module Name</th><th>Version</th><th>Count</th><th>DLL Info</th></tr>"
        try {
            $installedModules = Get-Module -ListAvailable | Sort-Object Name, Version -Descending
            $groupedModules = $installedModules | Group-Object Name
            
            foreach ($group in $groupedModules) {
                $moduleName = $group.Name
                $moduleCount = $group.Group.Count
                $moduleVersion = $group.Group[0].Version
                $modulePath = $group.Group[0].ModuleBase
                $dllFiles = Get-ChildItem -Path "$modulePath\*.dll" -ErrorAction SilentlyContinue
                $dllCount = $dllFiles.Count

                # Use if-else to determine DLL information
                if ($dllCount -gt 0) {
                    $dllInfo = "DLL(s) needed ($dllCount)"
                } else {
                    $dllInfo = "No DLL(s)"
                }

                # Generate links for module name and version
                $moduleInfoLink = "https://www.powershellgallery.com/packages/$moduleName/$moduleVersion"
                $moduleNameLink = if (Is-ValidUrl $moduleInfoLink) { "<a href='$moduleInfoLink' target='_blank'>$moduleName</a>" } else { $moduleName }
                $moduleVersionLink = if (Is-ValidUrl $moduleInfoLink) { "<a href='$moduleInfoLink' target='_blank'>$moduleVersion</a>" } else { $moduleVersion }
                
                $htmlContent += "<tr>"
                $htmlContent += "<td>$moduleNameLink</td>"
                $htmlContent += "<td>$moduleVersionLink</td>"
                $htmlContent += "<td>$moduleCount</td>"
                $htmlContent += "<td>$dllInfo</td>"
                $htmlContent += "</tr>"
            }
        } catch {
            $htmlContent += "<tr><td colspan='4'>Error retrieving module information: $($_.Exception.Message)</td></tr>"
        }
        $htmlContent += "</table>"

        # Close HTML content
        $htmlContent += "</body></html>"

        # Write HTML content to file
        $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Host "All system information exported to HTML: $OutputPath" -ForegroundColor Green
    }
    catch {
        Write-Host "Error exporting all system information to HTML: $($_.Exception.Message)" -ForegroundColor Red
    }
} # End function Export-AllSystemInfoToHTML

# Main script execution

# Clear the host screen
Clear-Host

# Generate a timestamp to use in both file names for consistency
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

# Export all gathered information to a text file
Export-SystemInfo -OutputPath ".\SystemInfo_$timestamp.txt"

# Export all gathered information to an HTML file
Export-AllSystemInfoToHTML -OutputPath ".\SystemInfo_$timestamp.html"

# End of script
