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

# Function to export results to file (optional)
function Export-SystemInfo {
    param(
        [string]$OutputPath = "SystemInfo_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    )
    
    Write-Host "=== Exporting System Information ===" -ForegroundColor Green
    Write-Host ""
    
    try {
        # Capture all output to file
        Start-Transcript -Path $OutputPath -Force
        
        # Re-run all functions to capture output
        Get-PowerShellVersionInfo
        Get-WindowsVersionInfo
        Get-AllModulesInfo
        
        Stop-Transcript
        
        Write-Host "System information exported to: $OutputPath" -ForegroundColor Green
    } # End try block for Export-SystemInfo
    catch {
        Write-Host "Error exporting system information: $($_.Exception.Message)" -ForegroundColor Red
    } # End catch block for Export-SystemInfo
} # End function Export-SystemInfo

# Main execution
Write-Host "PowerShell System Information Checker" -ForegroundColor White -BackgroundColor Blue
Write-Host "=====================================" -ForegroundColor White -BackgroundColor Blue
Write-Host ""

# Run all information gathering functions
Get-PowerShellVersionInfo
Get-WindowsVersionInfo
Get-AllModulesInfo

# Ask user if they want to export to file
Write-Host "Would you like to export this information to a text file? (Y/N): " -ForegroundColor Yellow -NoNewline
$exportChoice = Read-Host

if ($exportChoice -match '^[Yy]') {
    Export-SystemInfo
} # End if export choice

Write-Host ""
Write-Host "System information check completed." -ForegroundColor Green
Write-Host ""
