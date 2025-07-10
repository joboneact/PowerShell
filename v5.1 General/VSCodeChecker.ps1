# Visual Studio Code Configuration and Extensions Checker
#
# DESCRIPTION:
# This script provides comprehensive information about:
# - Visual Studio Code installation details
# - User and workspace settings
# - Profiles and profile configurations
# - All installed extensions with detailed information
# - Extension marketplace links and metadata
#
# Compatible with PowerShell 5.1 and later versions

<#
.SYNOPSIS
    Displays Visual Studio Code configuration, profiles, and extensions information

.DESCRIPTION
    This script checks and displays:
    - VS Code installation information (version, edition, installation path)
    - User settings and workspace configurations
    - All VS Code profiles and their settings
    - Complete list of installed extensions with versions, authors, and links
    - Extension marketplace information and ratings

.NOTES
    Requirements:
    - PowerShell 5.1 or higher
    - Visual Studio Code installed
    - Access to VS Code configuration directories
    
    ACRONYMS USED:
    - VS Code: Visual Studio Code (Microsoft's code editor)
    - JSON: JavaScript Object Notation (data format for configuration files)
    - URL: Uniform Resource Locator (web address)
    - HTML: HyperText Markup Language (web page format)
    - UTF8: Unicode Transformation Format 8-bit (character encoding)
    - CSS: Cascading Style Sheets (web styling language)
    - MB: Megabyte (unit of data measurement)
    - KB: Kilobyte (unit of data measurement)
    - API: Application Programming Interface
    - GUID: Globally Unique Identifier
#>

# Function to get VS Code installation information
# ADVANCED CONCEPTS:
# - Try-catch error handling for robust execution
# - Environment variable expansion using ${env:VARIABLE} syntax
# - Array iteration with foreach loops
# - Conditional execution with if-else statements
# - External process execution using call operator (&)
function Get-VSCodeInstallationInfo {
    # ANSI color codes: Green = success/headers, Cyan = information, Red = errors, Yellow = warnings
    Write-Host "=== Visual Studio Code Installation Information ===" -ForegroundColor Green
    Write-Host ""
    
    try {
        # ARRAY CONCEPT: Define multiple possible installation locations
        # ${env:VARIABLE} syntax: PowerShell's preferred method for environment variable expansion
        # This is more reliable than $env:VARIABLE in string contexts
        $vscodeLocations = @(
            "${env:LOCALAPPDATA}\Programs\Microsoft VS Code\Code.exe",    # User-specific installation (Windows Store or user install)
            "${env:ProgramFiles}\Microsoft VS Code\Code.exe",             # System-wide installation (64-bit)
            "${env:ProgramFiles(x86)}\Microsoft VS Code\Code.exe"         # System-wide installation (32-bit legacy)
        )
        
        # VARIABLE INITIALIZATION: Start with null to detect if VS Code is found
        $vscodePath = $null
        
        # FOREACH LOOP: Iterate through each potential installation location
        foreach ($location in $vscodeLocations) {
            # TEST-PATH CMDLET: PowerShell built-in to check file/folder existence
            # Returns $true if path exists, $false otherwise
            if (Test-Path $location) {
                $vscodePath = $location
                break    # Exit loop early when first valid path is found (performance optimization)
            }
        } # End foreach loop through VS Code installation locations
        
        # CONDITIONAL EXECUTION: Process VS Code if found
        if ($vscodePath) {
            Write-Host "VS Code Executable: $vscodePath" -ForegroundColor Cyan
            
            # NESTED TRY-CATCH: Handle version retrieval separately from main error handling
            # This allows the script to continue even if version detection fails
            try {
                # CALL OPERATOR (&): Execute external programs from PowerShell
                # 2>$null: Redirect stderr (error stream) to null to suppress error messages
                # --version: Command-line argument to get VS Code version information
                $versionOutput = & $vscodePath --version 2>$null
                
                # ARRAY INDEXING: VS Code --version returns 3 lines: [0]=version, [1]=commit, [2]=architecture
                if ($versionOutput) {
                    Write-Host "VS Code Version: $($versionOutput[0])" -ForegroundColor Cyan
                    Write-Host "Commit: $($versionOutput[1])" -ForegroundColor Cyan
                    Write-Host "Architecture: $($versionOutput[2])" -ForegroundColor Cyan
                }
            }
            catch {
                # GRACEFUL DEGRADATION: Continue script execution even if version check fails
                Write-Host "Could not retrieve version information" -ForegroundColor Yellow
            } # End inner try-catch for version retrieval
            
            # GET-ITEMPROPERTY CMDLET: Retrieve file metadata and properties
            # This provides detailed file system information including version details
            $fileInfo = Get-ItemProperty -Path $vscodePath
            
            # PROPERTY ACCESS: Use dot notation to access nested properties
            # VersionInfo is a FileVersionInfo object with detailed version data
            Write-Host "File Version: $($fileInfo.VersionInfo.FileVersion)" -ForegroundColor Cyan
            Write-Host "Product Version: $($fileInfo.VersionInfo.ProductVersion)" -ForegroundColor Cyan
            Write-Host "Install Date: $($fileInfo.CreationTime)" -ForegroundColor Cyan
            Write-Host "Last Modified: $($fileInfo.LastWriteTime)" -ForegroundColor Cyan
        }
        else {
            # ERROR REPORTING: Inform user when VS Code is not found
            Write-Host "Visual Studio Code not found in standard locations" -ForegroundColor Red
            return $false    # Return boolean to indicate failure
        } # End if-else VS Code path validation
        
        # CHECK FOR VS CODE INSIDERS: Development/preview version of VS Code
        # VS Code Insiders is a separate installation with different features and update cadence
        $vscodeInsidersLocations = @(
            "${env:LOCALAPPDATA}\Programs\Microsoft VS Code Insiders\Code - Insiders.exe",
            "${env:ProgramFiles}\Microsoft VS Code Insiders\Code - Insiders.exe"
        )
        
        # SEPARATE LOOP: Check for Insiders edition without affecting main VS Code detection
        foreach ($location in $vscodeInsidersLocations) {
            if (Test-Path $location) {
                Write-Host "VS Code Insiders found: $location" -ForegroundColor Cyan
                break    # Only report first found instance
            }
        } # End foreach loop for VS Code Insiders detection
        
    }
    catch {
        # EXCEPTION HANDLING: Catch any unexpected errors in the function
        # $_.Exception.Message: PowerShell's automatic variable for error details
        Write-Host "Error retrieving VS Code installation information: $($_.Exception.Message)" -ForegroundColor Red
        return $false    # Indicate function failure
    } # End main try-catch block
    
    Write-Host ""
    return $true    # Indicate successful execution
} # End function Get-VSCodeInstallationInfo

# Function to get VS Code configuration directories
# ADVANCED CONCEPTS:
# - Hashtable data structure for key-value pairs
# - Foreach loop with hashtable key iteration
# - File system size calculation using Measure-Object
# - Error handling for file system operations
function Get-VSCodeConfigDirectories {
    Write-Host "=== VS Code Configuration Directories ===" -ForegroundColor Green
    Write-Host ""
    
    # HASHTABLE CONCEPT: Key-value pairs for organizing related data
    # @{} syntax creates a hashtable in PowerShell
    # This structure allows descriptive names paired with actual paths
    $configDirs = @{
        "User Data Directory" = "${env:APPDATA}\Code"                           # Main VS Code data folder
        "User Settings" = "${env:APPDATA}\Code\User"                           # User-specific settings and preferences
        "Extensions Directory" = "${env:USERPROFILE}\.vscode\extensions"        # Installed extensions storage
        "Workspace Storage" = "${env:APPDATA}\Code\User\workspaceStorage"       # Per-workspace state and data
        "Logs Directory" = "${env:APPDATA}\Code\logs"                          # Application logs and diagnostics
    }
    
    # HASHTABLE ITERATION: Use .Keys property to iterate through hashtable keys
    foreach ($dirType in $configDirs.Keys) {
        # HASHTABLE ACCESS: Use square brackets to access values by key
        $dirPath = $configDirs[$dirType]
        
        # PATH VALIDATION: Check if directory exists before processing
        if (Test-Path $dirPath) {
            # STRING INTERPOLATION: Embed variables in strings using $() syntax
            Write-Host "$dirType`: $dirPath" -ForegroundColor Cyan
            
            try {
                # FILE ENUMERATION: Get all files recursively for size calculation
                # -Recurse: Include subdirectories
                # -File: Only return files, not directories
                # -ErrorAction SilentlyContinue: Suppress access denied errors
                $files = Get-ChildItem -Path $dirPath -Recurse -File -ErrorAction SilentlyContinue
                
                if ($files) {
                    # MEASURE-OBJECT CMDLET: Calculate aggregate statistics
                    # -Property Length: Sum the Length property (file size in bytes)
                    # -Sum: Calculate total sum of all file sizes
                    $dirSize = ($files | Measure-Object -Property Length -Sum).Sum
                } else {
                    $dirSize = 0    # No files found
                }
                
                # MATHEMATICAL OPERATIONS: Convert bytes to megabytes
                # [math]::Round(): .NET static method for rounding numbers
                # Division by 1MB: PowerShell constant for 1,048,576 bytes
                Write-Host "  Size: $([math]::Round($dirSize / 1MB, 2)) MB" -ForegroundColor Gray
            } catch {
                # ERROR HANDLING: Gracefully handle file system access errors
                Write-Host "  Size: Unable to calculate" -ForegroundColor Gray
            } # End try-catch for size calculation
        }
        else {
            # MISSING DIRECTORY REPORTING: Inform user about non-existent directories
            Write-Host "$dirType`: Not found at $dirPath" -ForegroundColor Yellow
        } # End if-else directory existence check
    } # End foreach loop through configuration directories
    
    Write-Host ""
} # End function Get-VSCodeConfigDirectories

# Function to get VS Code user settings
# ADVANCED CONCEPTS:
# - JSON parsing and object manipulation
# - Dynamic property access on JSON objects
# - String splitting and array operations
# - Conditional property checking
function Get-VSCodeUserSettings {
    Write-Host "=== VS Code User Settings ===" -ForegroundColor Green
    Write-Host ""
    
    # SETTINGS PATH: VS Code stores user settings in JSON format
    $settingsPath = "${env:APPDATA}\Code\User\settings.json"
    
    if (Test-Path $settingsPath) {
        Write-Host "Settings file: $settingsPath" -ForegroundColor Cyan
        
        # FILE METADATA: Get file system properties
        $settingsInfo = Get-ItemProperty -Path $settingsPath
        Write-Host "Last Modified: $($settingsInfo.LastWriteTime)" -ForegroundColor Gray
        Write-Host "Size: $([math]::Round($settingsInfo.Length / 1KB, 2)) KB" -ForegroundColor Gray
        
        try {
            # JSON PARSING: Convert JSON file content to PowerShell object
            # Get-Content -Raw: Read entire file as single string (not array of lines)
            # ConvertFrom-Json: Parse JSON string into PowerShell object
            $settingsContent = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
            
            # OBJECT INTROSPECTION: Count properties in the settings object
            # Get-Member: Retrieve object metadata and properties
            # -MemberType NoteProperty: Only count actual data properties
            $settingsCount = ($settingsContent | Get-Member -MemberType NoteProperty).Count
            Write-Host "Number of Settings: $settingsCount" -ForegroundColor Gray
            
            # COMMON SETTINGS ANALYSIS: Check for frequently used VS Code settings
            $keySettings = @("editor.fontSize", "editor.fontFamily", "workbench.colorTheme", "extensions.autoUpdate")
            
            foreach ($setting in $keySettings) {
                # STRING SPLITTING: Parse nested property paths (e.g., "editor.fontSize")
                $settingPath = $setting.Split('.')
                $value = $settingsContent
                
                # DYNAMIC PROPERTY ACCESS: Navigate nested object properties
                foreach ($part in $settingPath) {
                    # PROPERTY EXISTENCE CHECK: Verify property exists before accessing
                    if ($value.$part) {
                        $value = $value.$part    # Drill down to next level
                    }
                    else {
                        $value = $null    # Property doesn't exist
                        break             # Exit inner loop
                    }
                } # End foreach loop for property path navigation
                
                # CONDITIONAL OUTPUT: Only display settings that have values
                if ($value) {
                    Write-Host "  $setting`: $value" -ForegroundColor Gray
                }
            } # End foreach loop for key settings
        }
        catch {
            # JSON PARSING ERROR HANDLING: Handle malformed JSON gracefully
            Write-Host "Could not parse settings.json: $($_.Exception.Message)" -ForegroundColor Yellow
        } # End try-catch for JSON parsing
    }
    else {
        # MISSING FILE HANDLING: Report when settings file doesn't exist
        Write-Host "User settings file not found" -ForegroundColor Yellow
    } # End if-else settings file existence check
    
    Write-Host ""
} # End function Get-VSCodeUserSettings

# Function to get VS Code profiles
# ADVANCED CONCEPTS:
# - Directory enumeration and filtering
# - Object property access and date formatting
# - File path construction using Join-Path
# - Conditional file existence checking
function Get-VSCodeProfiles {
    Write-Host "=== VS Code Profiles ===" -ForegroundColor Green
    Write-Host ""
    
    # PROFILES DIRECTORY: VS Code stores custom profiles here
    # Profiles allow different VS Code configurations for different use cases
    $profilesPath = "${env:APPDATA}\Code\User\profiles"
    
    if (Test-Path $profilesPath) {
        Write-Host "Profiles directory: $profilesPath" -ForegroundColor Cyan
        
        # DIRECTORY ENUMERATION: Get subdirectories (each represents a profile)
        # -Directory: Only return directories, not files
        # -ErrorAction SilentlyContinue: Suppress access errors
        $profiles = Get-ChildItem -Path $profilesPath -Directory -ErrorAction SilentlyContinue
        
        if ($profiles) {
            # ARRAY COUNT: Use .Count property to get number of elements
            Write-Host "Found $($profiles.Count) profile(s):" -ForegroundColor Cyan
            
            # PROFILE ITERATION: Process each discovered profile
            foreach ($profile in $profiles) {
                Write-Host ""
                Write-Host "Profile: $($profile.Name)" -ForegroundColor White
                Write-Host "  Path: $($profile.FullName)" -ForegroundColor Gray
                Write-Host "  Created: $($profile.CreationTime)" -ForegroundColor Gray
                Write-Host "  Last Modified: $($profile.LastWriteTime)" -ForegroundColor Gray
                
                # PROFILE-SPECIFIC SETTINGS: Check for profile's settings.json
                # JOIN-PATH CMDLET: Safely combine path components (handles path separators)
                $profileSettingsPath = Join-Path $profile.FullName "settings.json"
                if (Test-Path $profileSettingsPath) {
                    $profileSettingsInfo = Get-ItemProperty -Path $profileSettingsPath
                    Write-Host "  Settings Size: $([math]::Round($profileSettingsInfo.Length / 1KB, 2)) KB" -ForegroundColor Gray
                }
                
                # PROFILE-SPECIFIC EXTENSIONS: Check for profile's extensions configuration
                $profileExtensionsPath = Join-Path $profile.FullName "extensions.json"
                if (Test-Path $profileExtensionsPath) {
                    Write-Host "  Has profile-specific extensions" -ForegroundColor Gray
                }
            } # End foreach loop through profiles
        }
        else {
            # NO PROFILES FOUND: Most users use only the default profile
            Write-Host "No custom profiles found" -ForegroundColor Yellow
        } # End if-else profiles existence check
    }
    else {
        # PROFILES DIRECTORY MISSING: Normal for default VS Code installations
        Write-Host "Profiles directory not found (using default profile only)" -ForegroundColor Yellow
    } # End if-else profiles directory existence check
    
    Write-Host ""
} # End function Get-VSCodeProfiles

# Function to check if a URL is valid
# ADVANCED CONCEPTS:
# - Parameter validation and type specification
# - Web request handling with timeout
# - HTTP HEAD method for efficient URL validation
# - Exception handling for network operations
function Test-WebUrl {
    param(
        [string]$Url    # PARAMETER TYPE: Explicitly specify string type for type safety
    )
    try {
        # WEB REQUEST: Use Invoke-WebRequest for URL validation
        # -Method Head: HTTP HEAD request (faster than GET, only returns headers)
        # -ErrorAction Stop: Convert warnings to terminating errors
        # -TimeoutSec 5: 5-second timeout to prevent hanging
        # $null assignment: Suppress output (we only care about success/failure)
        $null = Invoke-WebRequest -Uri $Url -Method Head -ErrorAction Stop -TimeoutSec 5
        return $true    # URL is accessible
    } catch {
        # NETWORK ERROR HANDLING: URL is not accessible or network error occurred
        return $false   # URL validation failed
    } # End try-catch for URL validation
} # End function Test-WebUrl

# Function to get VS Code extensions information
# ADVANCED CONCEPTS:
# - Regular expression pattern matching for folder validation
# - String manipulation methods (LastIndexOf, Substring, IndexOf)
# - JSON object parsing and conditional property access
# - Custom PowerShell object creation with calculated properties
# - Array building and object property assignment
function Get-VSCodeExtensions {
    Write-Host "=== VS Code Extensions ===" -ForegroundColor Green
    Write-Host ""
    
    # EXTENSIONS DIRECTORY: VS Code stores extensions in user profile
    $extensionsPath = "${env:USERPROFILE}\.vscode\extensions"
    
    # EARLY RETURN PATTERN: Exit function early if prerequisites not met
    if (-not (Test-Path $extensionsPath)) {
        Write-Host "Extensions directory not found: $extensionsPath" -ForegroundColor Red
        return @()    # Return empty array
    }
    
    Write-Host "Extensions directory: $extensionsPath" -ForegroundColor Cyan
    
    # DIRECTORY FILTERING: Get extension directories using regex pattern
    # REGEX PATTERN: ^[^.]+\.[^.]+-.+$ matches "publisher.name-version" format
    # ^ = start of string, [^.]+ = one or more non-dot characters, \. = literal dot
    # - = literal dash, .+ = one or more any characters, $ = end of string
    $extensions = Get-ChildItem -Path $extensionsPath -Directory | Where-Object { $_.Name -match "^[^.]+\.[^.]+-.+$" }
    
    if (-not $extensions) {
        Write-Host "No extensions found" -ForegroundColor Yellow
        return @()    # Return empty array
    }
    
    Write-Host "Found $($extensions.Count) extension(s)" -ForegroundColor Cyan
    Write-Host ""
    
    # ARRAY INITIALIZATION: Create empty array to store extension objects
    $extensionResults = @()
    
    # EXTENSION PROCESSING: Parse each extension directory
    foreach ($extension in $extensions) {
        try {
            # STRING PARSING: Extract publisher, name, and version from folder name
            # EXTENSION NAMING CONVENTION: "publisher.name-version"
            $folderName = $extension.Name
            
            # LASTINDEXOF METHOD: Find last occurrence of dash (separates version)
            $lastDash = $folderName.LastIndexOf('-')
            
            if ($lastDash -gt 0) {
                # SUBSTRING METHOD: Extract parts of the folder name
                $publisherAndName = $folderName.Substring(0, $lastDash)      # Everything before last dash
                $version = $folderName.Substring($lastDash + 1)              # Everything after last dash
                
                # INDEXOF METHOD: Find first dot (separates publisher from name)
                $dotIndex = $publisherAndName.IndexOf('.')
                if ($dotIndex -gt 0) {
                    $publisher = $publisherAndName.Substring(0, $dotIndex)           # Before first dot
                    $name = $publisherAndName.Substring($dotIndex + 1)               # After first dot
                }
                else {
                    # FALLBACK VALUES: Handle malformed folder names gracefully
                    $publisher = "Unknown"
                    $name = $publisherAndName
                }
            }
            else {
                # PARSING FAILURE HANDLING: Use defaults when parsing fails
                $publisher = "Unknown"
                $name = $folderName
                $version = "Unknown"
            } # End if-else version parsing
            
            # PACKAGE.JSON PARSING: Read extension metadata from package.json
            # This file contains official extension information
            $packageJsonPath = Join-Path $extension.FullName "package.json"
            
            # DEFAULT VALUES: Initialize with parsed values, override with package.json if available
            $displayName = $name
            $description = ""
            $author = $publisher
            $homepage = ""
            $repository = ""
            
            if (Test-Path $packageJsonPath) {
                try {
                    # JSON DESERIALIZATION: Parse package.json into PowerShell object
                    $packageJson = Get-Content -Path $packageJsonPath -Raw | ConvertFrom-Json
                    
                    # CONDITIONAL PROPERTY ACCESS: Update values only if they exist in JSON
                    if ($packageJson.displayName) { $displayName = $packageJson.displayName }
                    if ($packageJson.description) { $description = $packageJson.description }
                    
                    # POLYMORPHIC PROPERTY HANDLING: Author can be string or object
                    if ($packageJson.author) { 
                        if ($packageJson.author -is [string]) {
                            $author = $packageJson.author
                        }
                        elseif ($packageJson.author.name) {
                            $author = $packageJson.author.name
                        }
                    }
                    
                    if ($packageJson.publisher) { $publisher = $packageJson.publisher }
                    if ($packageJson.homepage) { $homepage = $packageJson.homepage }
                    
                    # REPOSITORY URL HANDLING: Repository can be string or object
                    if ($packageJson.repository) {
                        if ($packageJson.repository -is [string]) {
                            $repository = $packageJson.repository
                        }
                        elseif ($packageJson.repository.url) {
                            $repository = $packageJson.repository.url
                        }
                    }
                    
                    if ($packageJson.version) { $version = $packageJson.version }
                }
                catch {
                    # JSON PARSING ERROR: Continue with parsed values if package.json is corrupt
                    Write-Host "Could not parse package.json for $($extension.Name)" -ForegroundColor Yellow
                } # End try-catch for package.json parsing
            } # End if package.json exists
            
            # MARKETPLACE URL GENERATION: Standard VS Code marketplace URL pattern
            $marketplaceUrl = "https://marketplace.visualstudio.com/items?itemName=$publisher.$name"
            
            # CUSTOM OBJECT CREATION: Create structured object with all extension data
            # [PSCustomObject] type accelerator creates custom objects with named properties
            $extensionInfo = [PSCustomObject]@{
                DisplayName = $displayName
                Name = $name
                Publisher = $publisher
                Author = $author
                Version = $version
                Description = $description
                FolderName = $folderName
                InstallPath = $extension.FullName
                InstallDate = $extension.CreationTime
                LastModified = $extension.LastWriteTime
                MarketplaceUrl = $marketplaceUrl
                Homepage = $homepage
                Repository = $repository
                # CALCULATED PROPERTY: Compute extension size using try-catch for error handling
                Size = try {
                    $files = Get-ChildItem -Path $extension.FullName -Recurse -File -ErrorAction SilentlyContinue
                    if ($files) {
                        ($files | Measure-Object -Property Length -Sum).Sum
                    } else {
                        0
                    }
                } catch {
                    0    # Default to 0 if size calculation fails
                }
            }
            
            # ARRAY ADDITION: Add extension object to results array
            # += operator appends to array (creates new array each time)
            $extensionResults += $extensionInfo
            
            # CONSOLE OUTPUT: Display extension information as it's processed
            Write-Host "Extension: $displayName" -ForegroundColor White
            Write-Host "  Publisher: $publisher" -ForegroundColor Gray
            Write-Host "  Version: $version" -ForegroundColor Gray
            Write-Host "  Author: $author" -ForegroundColor Gray
            if ($description) {
                Write-Host "  Description: $description" -ForegroundColor Gray
            }
            Write-Host "  Size: $([math]::Round($extensionInfo.Size / 1MB, 2)) MB" -ForegroundColor Gray
            Write-Host "  Install Date: $($extension.CreationTime)" -ForegroundColor Gray
            Write-Host "  Marketplace: $marketplaceUrl" -ForegroundColor Gray
            Write-Host ""
        }
        catch {
            # EXTENSION PROCESSING ERROR: Handle individual extension errors gracefully
            Write-Host "Error processing extension $($extension.Name): $($_.Exception.Message)" -ForegroundColor Red
        } # End try-catch for individual extension processing
    } # End foreach loop through extensions
    
    # FUNCTION RETURN: Return array of extension objects for further processing
    return $extensionResults
} # End function Get-VSCodeExtensions

# Function to export VS Code information to text file
# ADVANCED CONCEPTS:
# - Parameter specification with default values
# - Transcript logging for capturing all output
# - String formatting and date manipulation
# - Array processing with sorting and grouping
# - Finally block for cleanup operations
function Export-VSCodeInfoToText {
    param(
        [array]$ExtensionResults,    # Input array of extension objects
        # DEFAULT PARAMETER VALUE: Generate timestamped filename if not provided
        [string]$OutputPath = ".\VSCodeInfo_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    )
    
    Write-Host "=== Exporting VS Code Information to Text File ===" -ForegroundColor Green
    Write-Host ""
    
    try {
        # TRANSCRIPT LOGGING: Capture all Write-Host output to file
        # Start-Transcript redirects console output to file
        # -Force: Overwrite existing file if it exists
        Start-Transcript -Path $OutputPath -Force
        
        try {
            # SCRIPT HEADER: Formatted report header with timestamp
            Write-Host "=================================================" -ForegroundColor Cyan
            Write-Host "  VISUAL STUDIO CODE CONFIGURATION REPORT" -ForegroundColor Cyan
            Write-Host "  Generated: $(Get-Date)" -ForegroundColor Cyan
            Write-Host "=================================================" -ForegroundColor Cyan
            Write-Host ""

            # FUNCTION CALLS: Reuse existing functions for consistent output
            # VS Code Installation Information
            $null = Get-VSCodeInstallationInfo    # $null assignment suppresses return value
            
            # Configuration Directories
            Get-VSCodeConfigDirectories
            
            # User Settings
            Get-VSCodeUserSettings
            
            # Profiles
            Get-VSCodeProfiles
            
            # EXTENSIONS SUMMARY PROCESSING
            Write-Host "=== Extensions Summary ===" -ForegroundColor Green
            Write-Host ""
            Write-Host "Total Extensions: $($ExtensionResults.Count)" -ForegroundColor Cyan
            
            if ($ExtensionResults.Count -gt 0) {
                try {
                    # AGGREGATE CALCULATIONS: Sum total size of all extensions
                    $totalSize = ($ExtensionResults | Measure-Object -Property Size -Sum).Sum
                    Write-Host "Total Extensions Size: $([math]::Round($totalSize / 1MB, 2)) MB" -ForegroundColor Cyan
                    
                    # GROUP-OBJECT CMDLET: Group extensions by publisher and count them
                    # Sort-Object: Order groups by count (descending = most extensions first)
                    $publishers = $ExtensionResults | Group-Object Publisher | Sort-Object Count -Descending
                    Write-Host "Top Publishers:" -ForegroundColor Cyan
                    
                    # PIPELINE PROCESSING: Select top 5 publishers and display them
                    foreach ($pub in $publishers | Select-Object -First 5) {
                        Write-Host "  $($pub.Name): $($pub.Count) extension(s)" -ForegroundColor Gray
                    }
                    Write-Host ""
                    
                    # DETAILED EXTENSIONS LIST
                    Write-Host "=== Detailed Extensions List ===" -ForegroundColor Green
                    Write-Host ""
                    
                    # SORTING: Alphabetical order by display name for readability
                    foreach ($ext in $ExtensionResults | Sort-Object DisplayName) {
                        Write-Host "Extension: $($ext.DisplayName)" -ForegroundColor White
                        Write-Host "  Name: $($ext.Name)" -ForegroundColor Gray
                        Write-Host "  Publisher: $($ext.Publisher)" -ForegroundColor Gray
                        Write-Host "  Author: $($ext.Author)" -ForegroundColor Gray
                        Write-Host "  Version: $($ext.Version)" -ForegroundColor Gray
                        Write-Host "  Description: $($ext.Description)" -ForegroundColor Gray
                        Write-Host "  Size: $([math]::Round($ext.Size / 1MB, 2)) MB" -ForegroundColor Gray
                        Write-Host "  Install Date: $($ext.InstallDate)" -ForegroundColor Gray
                        Write-Host "  Marketplace URL: $($ext.MarketplaceUrl)" -ForegroundColor Gray
                        
                        # CONDITIONAL OUTPUT: Only show optional fields if they have values
                        if ($ext.Homepage) {
                            Write-Host "  Homepage: $($ext.Homepage)" -ForegroundColor Gray
                        }
                        if ($ext.Repository) {
                            Write-Host "  Repository: $($ext.Repository)" -ForegroundColor Gray
                        }
                        Write-Host ""
                    } # End foreach extension details
                }
                catch {
                    # EXTENSIONS PROCESSING ERROR: Handle errors in summary calculations
                    Write-Host "Error processing extensions summary: $($_.Exception.Message)" -ForegroundColor Red
                } # End try-catch for extensions summary
            } # End if extensions exist
            
        }
        finally {
            # FINALLY BLOCK: Always executes, even if errors occur
            # Ensures transcript logging is properly stopped
            Stop-Transcript
        } # End finally block for transcript cleanup
        
        Write-Host "VS Code information exported to: $OutputPath" -ForegroundColor Green
        
    }
    catch {
        # FILE EXPORT ERROR: Handle file system or permission errors
        Write-Host "Error exporting VS Code information: $($_.Exception.Message)" -ForegroundColor Red
    } # End main try-catch for text export
} # End function Export-VSCodeInfoToText

# Function to export VS Code information to HTML file
# ADVANCED CONCEPTS:
# - Here-string (@"..."@) for multi-line string literals
# - HTML generation with embedded CSS styling
# - String concatenation and interpolation in HTML context
# - Responsive web design principles
# - URL encoding and validation
function Export-VSCodeInfoToHTML {
    param(
        [array]$ExtensionResults,    # Input array of extension objects
        # DEFAULT PARAMETER VALUE: Generate timestamped HTML filename
        [string]$OutputPath = ".\VSCodeInfo_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    )
    
    Write-Host "=== Exporting VS Code Information to HTML ===" -ForegroundColor Green
    Write-Host ""
    
    try {
        # HERE-STRING: Multi-line string literal for HTML template
        # @"..."@ syntax preserves formatting and allows embedded quotes
        # STRING INTERPOLATION: $(expression) syntax embeds PowerShell expressions
        $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Visual Studio Code Configuration Report</title>
    <style>
        /* CSS STYLING: Modern responsive design with VS Code color scheme */
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #007ACC; border-bottom: 3px solid #007ACC; padding-bottom: 10px; }
        h2 { color: #005a9e; border-bottom: 1px solid #ddd; padding-bottom: 5px; }
        h3 { color: #333; }
        /* TABLE STYLING: Professional appearance with hover effects */
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #007ACC; color: white; font-weight: bold; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        tr:hover { background-color: #e6f3ff; }
        /* LINK STYLING: VS Code blue theme */
        a { color: #007ACC; text-decoration: none; }
        a:hover { text-decoration: underline; color: #005a9e; }
        /* HEADER STYLING: Gradient background matching VS Code branding */
        .header { background: linear-gradient(135deg, #007ACC, #005a9e); color: white; padding: 20px; text-align: center; margin: -20px -20px 20px -20px; border-radius: 8px 8px 0 0; }
        .timestamp { font-size: 0.9em; margin-top: 5px; opacity: 0.9; }
        /* CARD COMPONENTS: Information display containers */
        .summary-card { background-color: #e6f3ff; padding: 15px; border-radius: 5px; margin-bottom: 20px; border-left: 4px solid #007ACC; }
        .extension-card { background-color: #f8f9fa; padding: 10px; margin-bottom: 10px; border-radius: 5px; border-left: 3px solid #007ACC; }
        .extension-title { font-weight: bold; color: #007ACC; margin-bottom: 5px; }
        .extension-details { font-size: 0.9em; color: #666; }
        /* STATUS INDICATORS: Color-coded status messages */
        .status-installed { color: #28a745; font-weight: bold; }
        .status-error { color: #dc3545; font-weight: bold; }
        /* METRICS DISPLAY: Dashboard-style statistics */
        .metric { display: inline-block; margin-right: 20px; padding: 10px; background-color: #007ACC; color: white; border-radius: 5px; text-align: center; min-width: 100px; }
        .metric-label { display: block; font-size: 0.8em; }
        .metric-value { display: block; font-size: 1.2em; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Visual Studio Code Configuration Report</h1>
            <div class="timestamp">Generated: $(Get-Date -Format "dddd, MMMM dd, yyyy 'at' HH:mm:ss")</div>
        </div>
"@        # Add installation information
        $htmlContent += "<h2>Installation Information</h2>"
        $htmlContent += "<div class='summary-card'>"
        
        try {
            # VS CODE DETECTION: Same logic as console version but formatted for HTML
            $vscodeLocations = @(
                "${env:LOCALAPPDATA}\Programs\Microsoft VS Code\Code.exe",
                "${env:ProgramFiles}\Microsoft VS Code\Code.exe",
                "${env:ProgramFiles(x86)}\Microsoft VS Code\Code.exe"
            )
            
            $vscodePath = $null
            foreach ($location in $vscodeLocations) {
                if (Test-Path $location) {
                    $vscodePath = $location
                    break
                }
            } # End foreach VS Code location check
            
            if ($vscodePath) {
                $fileInfo = Get-ItemProperty -Path $vscodePath
                # HTML TABLE GENERATION: Structured data presentation
                $htmlContent += "<table><tr><th>Property</th><th>Value</th></tr>"
                $htmlContent += "<tr><td>Executable Path</td><td>" + $vscodePath + "</td></tr>"
                $htmlContent += "<tr><td>File Version</td><td>" + $fileInfo.VersionInfo.FileVersion + "</td></tr>"
                $htmlContent += "<tr><td>Product Version</td><td>" + $fileInfo.VersionInfo.ProductVersion + "</td></tr>"
                $htmlContent += "<tr><td>Install Date</td><td>" + $fileInfo.CreationTime + "</td></tr>"
                $htmlContent += "<tr><td>Last Modified</td><td>" + $fileInfo.LastWriteTime + "</td></tr>"
                $htmlContent += "</table>"
            }
            else {
                # ERROR DISPLAY: CSS-styled error message
                $htmlContent += "<p class='status-error'>Visual Studio Code not found in standard locations</p>"
            } # End if-else VS Code path validation
        }
        catch {
            # EXCEPTION DISPLAY: HTML-formatted error message
            $htmlContent += "<p class='status-error'>Error retrieving VS Code installation information: " + $_.Exception.Message + "</p>"
        } # End try-catch for installation info
        
        $htmlContent += "</div>"        # Add configuration directories
        $htmlContent += "<h2>Configuration Directories</h2>"
        $htmlContent += "<table><tr><th>Directory Type</th><th>Path</th><th>Size (MB)</th><th>Status</th></tr>"
        
        try {
            $configDirs = @{
                "User Data Directory" = "${env:APPDATA}\Code"
                "User Settings" = "${env:APPDATA}\Code\User"
                "Extensions Directory" = "${env:USERPROFILE}\.vscode\extensions"
                "Workspace Storage" = "${env:APPDATA}\Code\User\workspaceStorage"
                "Logs Directory" = "${env:APPDATA}\Code\logs"
            }
            
            foreach ($dirType in $configDirs.Keys) {
                $dirPath = $configDirs[$dirType]
                try {
                    if (Test-Path $dirPath) {
                        $files = Get-ChildItem -Path $dirPath -Recurse -File -ErrorAction SilentlyContinue
                        if ($files) {
                            $dirSize = ($files | Measure-Object -Property Length -Sum).Sum
                        } else {
                            $dirSize = 0
                        }
                        # HTML TABLE ROW: Status with CSS class for styling
                        $htmlContent += "<tr><td>" + $dirType + "</td><td>" + $dirPath + "</td><td>" + [math]::Round($dirSize / 1MB, 2) + "</td><td class='status-installed'>Found</td></tr>"
                    }
                    else {
                        $htmlContent += "<tr><td>" + $dirType + "</td><td>" + $dirPath + "</td><td>-</td><td class='status-error'>Not Found</td></tr>"
                    }
                }
                catch {
                    # INDIVIDUAL DIRECTORY ERROR: Handle errors for specific directories
                    $htmlContent += "<tr><td>" + $dirType + "</td><td>" + $dirPath + "</td><td>-</td><td class='status-error'>Error: " + $_.Exception.Message + "</td></tr>"
                } # End try-catch for individual directory
            } # End foreach configuration directory
        }
        catch {
            # SECTION ERROR: Handle errors for entire configuration section
            $htmlContent += "<tr><td colspan='4'>Error retrieving configuration directories: " + $_.Exception.Message + "</td></tr>"
        } # End try-catch for configuration directories
        
        $htmlContent += "</table>"

        # EXTENSIONS SECTION: Comprehensive extension analysis
        if ($ExtensionResults.Count -gt 0) {
            try {
                # STATISTICAL CALCULATIONS: Aggregate metrics for dashboard
                $totalSize = ($ExtensionResults | Measure-Object -Property Size -Sum).Sum
                $publishers = $ExtensionResults | Group-Object Publisher | Sort-Object Count -Descending
                $avgSize = [math]::Round($totalSize / $ExtensionResults.Count / 1MB, 2)
                
                # DASHBOARD METRICS: Visual statistics display
                $htmlContent += "<h2>Extensions Overview</h2>"
                $htmlContent += "<div class='summary-card'>"
                $htmlContent += "<div class='metric'><span class='metric-label'>Total Extensions</span><span class='metric-value'>" + $ExtensionResults.Count + "</span></div>"
                $htmlContent += "<div class='metric'><span class='metric-label'>Total Size</span><span class='metric-value'>" + [math]::Round($totalSize / 1MB, 1) + " MB</span></div>"
                $htmlContent += "<div class='metric'><span class='metric-label'>Average Size</span><span class='metric-value'>" + $avgSize + " MB</span></div>"
                $htmlContent += "<div class='metric'><span class='metric-label'>Publishers</span><span class='metric-value'>" + $publishers.Count + "</span></div>"
                $htmlContent += "</div>"                # Top publishers
                $htmlContent += "<h3>Top Publishers</h3>"
                $htmlContent += "<table><tr><th>Publisher</th><th>Extensions</th><th>Percentage</th></tr>"
                foreach ($pub in $publishers | Select-Object -First 10) {
                    $percentage = [math]::Round(($pub.Count / $ExtensionResults.Count) * 100, 1)
                    $htmlContent += "<tr><td>" + $pub.Name + "</td><td>" + $pub.Count + "</td><td>" + $percentage + "%</td></tr>"
                }
                $htmlContent += "</table>"                # Extensions table
                $htmlContent += "<h2>Extensions Details</h2>"
                $htmlContent += "<table><tr><th>Extension</th><th>Publisher</th><th>Version</th><th>Author</th><th>Size (MB)</th><th>Install Date</th><th>Links</th></tr>"
                
                foreach ($ext in $ExtensionResults | Sort-Object DisplayName) {
                    try {
                        # DATA FORMATTING: Prepare data for HTML display
                        $sizeInMB = [math]::Round($ext.Size / 1MB, 2)
                        $installDate = $ext.InstallDate.ToString("yyyy-MM-dd")
                        
                        # LINK GENERATION: Create clickable links for external resources
                        $links = "<a href='" + $ext.MarketplaceUrl + "' target='_blank' title='VS Code Marketplace'>Marketplace</a>"
                        if ($ext.Homepage) {
                            $links += " | <a href='" + $ext.Homepage + "' target='_blank' title='Homepage'>Home</a>"
                        }
                        if ($ext.Repository) {
                            # URL CLEANING: Remove git+ prefix and .git suffix for cleaner URLs
                            $repoUrl = $ext.Repository -replace "git\+", "" -replace "\.git$", ""
                            $links += " | <a href='" + $repoUrl + "' target='_blank' title='Repository'>Repo</a>"
                        }
                        
                        # HTML TABLE ROW: Multi-line cell content with formatting
                        $htmlContent += "<tr>"
                        $htmlContent += "<td><strong>" + $ext.DisplayName + "</strong><br><small>" + $ext.Name + "</small></td>"
                        $htmlContent += "<td>" + $ext.Publisher + "</td>"
                        $htmlContent += "<td>" + $ext.Version + "</td>"
                        $htmlContent += "<td>" + $ext.Author + "</td>"
                        $htmlContent += "<td>" + $sizeInMB + "</td>"
                        $htmlContent += "<td>" + $installDate + "</td>"
                        $htmlContent += "<td>" + $links + "</td>"
                        $htmlContent += "</tr>"
                    }
                    catch {
                        # INDIVIDUAL EXTENSION ERROR: Handle errors for specific extensions
                        $htmlContent += "<tr><td colspan='7'>Error processing extension " + $ext.DisplayName + ": " + $_.Exception.Message + "</td></tr>"
                    } # End try-catch for individual extension
                } # End foreach extension details
                
                $htmlContent += "</table>"
            }
            catch {
                # EXTENSIONS SECTION ERROR: Handle errors in entire extensions section
                $htmlContent += "<h2>Extensions</h2>"
                $htmlContent += "<div class='summary-card'>"
                $htmlContent += "<p class='status-error'>Error processing extensions: " + $_.Exception.Message + "</p>"
                $htmlContent += "</div>"
            } # End try-catch for extensions processing
        }
        else {
            # NO EXTENSIONS FOUND: Display appropriate message
            $htmlContent += "<h2>Extensions</h2>"
            $htmlContent += "<div class='summary-card'>"
            $htmlContent += "<p class='status-error'>No extensions found</p>"
            $htmlContent += "</div>"
        } # End if-else extensions exist

        # HTML DOCUMENT CLOSURE: Properly close HTML tags
        $htmlContent += "</div></body></html>"

        # FILE OUTPUT: Write HTML content to file with UTF-8 encoding
        # UTF-8 encoding ensures proper display of special characters
        $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Host "VS Code information exported to HTML: $OutputPath" -ForegroundColor Green
    }
    catch {
        # HTML EXPORT ERROR: Handle file system or generation errors
        Write-Host "Error exporting VS Code information to HTML: $($_.Exception.Message)" -ForegroundColor Red
    } # End main try-catch for HTML export
} # End function Export-VSCodeInfoToHTML

# MAIN SCRIPT EXECUTION
# ADVANCED CONCEPTS:
# - Clear-Host for clean console start
# - Consistent error handling throughout main execution
# - Variable scoping and timestamp generation
# - Function orchestration and data flow
# - Comprehensive error reporting with stack traces

# CONSOLE CLEARING: Start with clean screen for better user experience
Clear-Host

# SCRIPT HEADER: Professional presentation with consistent formatting
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  VISUAL STUDIO CODE CONFIGURATION CHECKER" -ForegroundColor Cyan
Write-Host "  Starting analysis..." -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

try {
    # TIMESTAMP GENERATION: Create consistent timestamp for file naming
    # Format: YYYYMMDD_HHMMSS (sortable and filesystem-safe)
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

    # PREREQUISITE CHECK: Verify VS Code installation before proceeding
    $vscodeInstalled = Get-VSCodeInstallationInfo

    if ($vscodeInstalled) {
        try {
            # SEQUENTIAL EXECUTION: Run analysis functions in logical order
            # Get configuration directories
            Get-VSCodeConfigDirectories
            
            # Get user settings
            Get-VSCodeUserSettings
            
            # Get profiles
            Get-VSCodeProfiles
            
            # EXTENSIONS ANALYSIS: Main data collection for reports
            $extensionResults = Get-VSCodeExtensions
            
            # EXPORT OPERATIONS: Generate both text and HTML reports
            # Export to text file
            Export-VSCodeInfoToText -ExtensionResults $extensionResults -OutputPath ".\VSCodeInfo_$timestamp.txt"
            
            # Export to HTML file
            Export-VSCodeInfoToHTML -ExtensionResults $extensionResults -OutputPath ".\VSCodeInfo_$timestamp.html"
            
            # COMPLETION MESSAGE: Inform user of successful completion
            Write-Host "=================================================" -ForegroundColor Green
            Write-Host "  ANALYSIS COMPLETE" -ForegroundColor Green
            Write-Host "  Check the generated files for detailed reports" -ForegroundColor Green
            Write-Host "=================================================" -ForegroundColor Green
        }
        catch {
            # ANALYSIS ERROR HANDLING: Handle errors during main analysis
            Write-Host "Error during VS Code analysis: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        } # End try-catch for main analysis
    }
    else {
        # PREREQUISITE FAILURE: Cannot continue without VS Code installation
        Write-Host "Cannot continue analysis - VS Code installation not found" -ForegroundColor Red
    } # End if-else VS Code installation check
}
catch {
    # CRITICAL ERROR HANDLING: Handle unexpected errors in main execution
    Write-Host "Critical error in script execution: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
} # End main try-catch block

# END OF SCRIPT: No cleanup required as all resources are automatically managed
