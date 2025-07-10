# GetModulesWpf.ps1
# PowerShell 5.1 WPF application to display loaded modules information
# 
# This script demonstrates advanced PowerShell-WPF integration concepts:
# - XAML parsing and object model creation
# - Event-driven programming with ScriptBlock delegates  
# - Data binding between .NET objects and WPF controls
# - PowerShell module system introspection
# - Cross-platform web integration

# Load required .NET assemblies for WPF functionality
# PresentationFramework: Core WPF classes (Window, Button, DataGrid, etc.)
# PresentationCore: Low-level WPF rendering and input systems
# WindowsBase: Base WPF infrastructure (DependencyObject, DispatcherObject)
# System.Web: Provides HttpUtility for URL encoding
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Web

# Function to get DLL count for a module
# Advanced Concept: This function demonstrates file system enumeration with error handling
# and PowerShell's implicit return behavior (last expression becomes return value)
function Get-ModuleDllCount {
    param($Module)  # Accepts a module object (PSModuleInfo type)
    
    try {
        # Defensive programming: Check both property existence and path validity
        # ModuleBase property contains the root directory where module files are stored
        if ($Module.ModuleBase -and (Test-Path $Module.ModuleBase)) {
            # Recursive file enumeration with specific filter
            # -Recurse: Searches all subdirectories
            # -ErrorAction SilentlyContinue: Suppresses access denied errors for protected paths
            $dllFiles = Get-ChildItem -Path $Module.ModuleBase -Filter "*.dll" -Recurse -ErrorAction SilentlyContinue
            return $dllFiles.Count  # Count property returns number of items in collection
        }
        return 0  # Default return for modules without valid paths
    } # End try block
    catch {
        # Catch block handles any unexpected exceptions (I/O errors, access violations, etc.)
        return 0  # Graceful degradation - return 0 instead of failing
    } # End catch block
} # End function Get-ModuleDllCount

# Function to check if module is importable
# Intermediate Concept: This demonstrates PowerShell's module discovery system
# and the difference between loaded modules vs. available modules
function Test-ModuleImportable {
    param($ModuleName)  # String parameter - module name to test
    
    try {
        # Get-Module -ListAvailable searches PSModulePath locations for module manifests
        # This checks if the module can be imported (exists in searchable locations)
        # -ErrorAction SilentlyContinue prevents cmdlet errors from bubbling up
        $availableModule = Get-Module -Name $ModuleName -ListAvailable -ErrorAction SilentlyContinue
        
        # Advanced PowerShell: Using comparison operator with $null on left side
        # This follows PowerShell best practices and PSScriptAnalyzer recommendations
        # Returns boolean: true if module exists in PSModulePath, false otherwise
        return ($null -ne $availableModule)
    } # End try block
    catch {
        # Fallback for any unexpected errors during module discovery
        return $false  # Conservative approach - assume not importable if error occurs
    } # End catch block
} # End function Test-ModuleImportable

# Function to get detailed module information
# Advanced Concept: This function demonstrates PowerShell's introspection capabilities
# and here-string usage for multi-line text formatting
function Get-DetailedModuleInfo {
    param($ModuleName)  # Module name to analyze
    
    try {
        # Two-stage module lookup: first check loaded modules, then available modules
        # This pattern ensures we get the most current information available
        $module = Get-Module -Name $ModuleName -ErrorAction SilentlyContinue
        if (-not $module) {
            # Fallback to available modules if not currently loaded
            # Select-Object -First 1 ensures we get only the first match (handles multiple versions)
            $module = Get-Module -Name $ModuleName -ListAvailable -ErrorAction SilentlyContinue | Select-Object -First 1
        } # End if block for module fallback lookup
        
        if ($module) {
            # Command enumeration for the module - demonstrates cmdlet discovery
            $commands = Get-Command -Module $ModuleName -ErrorAction SilentlyContinue
            
            # Conditional logic to handle different module command counting methods
            # ExportedCommands is a hashtable property, while $commands is an array
            $exportedCommands = if ($module.ExportedCommands) { $module.ExportedCommands.Count } else { $commands.Count }
            
            # Here-string (@"..."@) usage for multi-line string with variable expansion
            # Advanced technique: Embedded expressions $(expression) within here-strings
            # This creates a formatted report with conditional content
            $details = @"
Module: $($module.Name)
Version: $($module.Version)
GUID: $($module.Guid)
Author: $($module.Author)
Company: $($module.CompanyName)
Copyright: $($module.Copyright)
Description: $($module.Description)
Module Type: $($module.ModuleType)
PowerShell Version: $($module.PowerShellVersion)
CLR Version: $($module.ClrVersion)
Processor Architecture: $($module.ProcessorArchitecture)
Path: $($module.ModuleBase)
Manifest Path: $($module.Path)
Exported Commands: $exportedCommands
Required Modules: $(if ($module.RequiredModules) { ($module.RequiredModules.Name -join ', ') } else { 'None' })
Nested Modules: $(if ($module.NestedModules) { ($module.NestedModules -join ', ') } else { 'None' })
"@
            return $details  # Return the formatted here-string
        } # End if block for module existence check
        return "Module information not available"  # Fallback message
    } # End try block
    catch {
        # Exception handling with automatic variable $_ containing ErrorRecord
        return "Error retrieving module information: $($_.Exception.Message)"
    } # End catch block
} # End function Get-DetailedModuleInfo

# Function to open web search for module
# Advanced Concept: Cross-platform web integration and URL encoding
function Open-ModuleWebSearch {
    param($ModuleName)  # Module name to search for
    
    try {
        # String interpolation to create search query
        $searchQuery = "PowerShell module $ModuleName documentation"
        
        # URL encoding using .NET HttpUtility class
        # Advanced: This converts special characters to percent-encoded format (%20 for spaces, etc.)
        # Essential for proper HTTP URL construction when query contains spaces or special chars
        $encodedQuery = [System.Web.HttpUtility]::UrlEncode($searchQuery)
        
        # Construct search URL with encoded query parameter
        $searchUrl = "https://www.bing.com/search?q=$encodedQuery"
        
        # Start-Process launches default web browser with the URL
        # This demonstrates PowerShell's ability to interact with external applications
        Start-Process $searchUrl
    } # End try block
    catch {
        # WPF MessageBox for error display - more user-friendly than Write-Error
        # Advanced: Using .NET Framework classes directly from PowerShell
        # MessageBoxButton and MessageBoxImage are enumerations from System.Windows
        [System.Windows.MessageBox]::Show("Error opening web search: $($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    } # End catch block
} # End function Open-ModuleWebSearch

# Function to get module data (enhanced to include more modules)
# Advanced Concept: This function demonstrates PowerShell pipeline operations,
# collection management, and custom object creation for data binding
function Get-ModuleData {
    # Get currently loaded modules from the PowerShell session
    # These are modules imported via Import-Module or auto-imported
    $loadedModules = Get-Module
    
    # Get all available modules from PSModulePath locations
    # Advanced pipeline usage: Where-Object with complex filtering logic
    # -notin operator performs collection membership testing (inverse of -in)
    $availableModules = Get-Module -ListAvailable | Where-Object { 
        $_.Name -notin $loadedModules.Name 
    } # End Where-Object pipeline filter
    
    # Array combination using + operator and subexpression syntax @()
    # Advanced technique: Limiting results to prevent UI performance issues
    # Select-Object -First 50 implements pagination-like behavior
    $allModules = @($loadedModules) + @($availableModules | Select-Object -First 50)  # Limit available modules to prevent overwhelming display
    
    # Initialize empty array for collecting processed module data
    # This will contain PSCustomObject instances for data binding
    $moduleData = @()
    
    # ForEach loop processing each module object
    foreach ($module in $allModules) {
        # Function calls for additional module analysis
        $dllCount = Get-ModuleDllCount -Module $module
        $isImportable = Test-ModuleImportable -ModuleName $module.Name
        
        # Collection membership testing using -in operator
        # Determines if current module is in the loaded modules collection
        $isLoaded = $module.Name -in $loadedModules.Name
        
        # PSCustomObject creation for WPF data binding
        # Advanced Concept: Creating .NET objects with specific properties for UI binding
        # Each property here corresponds to a DataGrid column binding
        $moduleInfo = [PSCustomObject]@{
            Name = $module.Name                    # Primary identifier
            Version = $module.Version.ToString()   # Convert Version object to string
            # Conditional logic using ternary-like operator pattern
            ReferenceCount = if ($module.ReferenceCount) { $module.ReferenceCount } else { if ($isLoaded) { "N/A" } else { "Not Loaded" } }
            DllCount = $dllCount                   # Result from custom function
            Importable = if ($isImportable) { "Yes" } else { "No" }  # Boolean to string conversion
            ModuleType = $module.ModuleType        # Enum value (Script, Binary, etc.)
            Path = $module.ModuleBase             # File system path
            Status = if ($isLoaded) { "Loaded" } else { "Available" }  # Custom status field
        } # End PSCustomObject hash table definition
        
        # Array concatenation using += operator
        # Note: This creates a new array each time (not efficient for large datasets)
        $moduleData += $moduleInfo
    } # End foreach loop
    
    # Return the complete array of module objects
    return $moduleData
} # End function Get-ModuleData

# Function to refresh the data grid
# Intermediate Concept: This function demonstrates WPF data binding update patterns
function Update-ModuleData {
    param($DataGrid)  # WPF DataGrid control reference
    
    # Retrieve fresh module data by calling our data collection function
    $moduleData = Get-ModuleData
    
    # WPF Data Binding: Setting ItemsSource triggers automatic UI update
    # Advanced: WPF's data binding engine uses INotifyPropertyChanged pattern internally
    $DataGrid.ItemsSource = $moduleData
    
    # Status label update - demonstrates UI feedback patterns
    # Note: $statusLabel is accessed from parent scope (script scope)
    $statusLabel.Content = "Modules loaded: $($moduleData.Count) | Last updated: $(Get-Date -Format 'HH:mm:ss')"
} # End function Update-ModuleData

# Create the main window
# Advanced Concept: XAML (eXtensible Application Markup Language) definition
# This here-string contains the complete WPF window layout in declarative XML format
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PowerShell Modules Viewer" Height="600" Width="1000"
        WindowStartupLocation="CenterScreen">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="10,10,10,5" Background="LightGray">
            <Button Name="RefreshButton" Content="Refresh" Width="80" Height="30" Margin="5"/>
            <Button Name="ExportButton" Content="Export CSV" Width="80" Height="30" Margin="5"/>
            <Button Name="GetInfoButton" Content="Get Info" Width="80" Height="30" Margin="5"/>
            <Separator Width="10"/>
            <TextBox Name="SearchBox" Width="200" Height="25" Margin="5" VerticalContentAlignment="Center"/>
            <Label Content="Search:" VerticalAlignment="Center" Margin="0,0,5,0"/>
            <Separator Width="10"/>
            <CheckBox Name="ShowOnlyLoadedCheckBox" Content="Show Only Loaded" VerticalAlignment="Center" Margin="5"/>
        </StackPanel>
        
        <DataGrid Grid.Row="1" Name="ModulesDataGrid" Margin="10,5,10,5"
                  AutoGenerateColumns="False" 
                  CanUserAddRows="False" 
                  CanUserDeleteRows="False"
                  IsReadOnly="True"
                  GridLinesVisibility="All"
                  HeadersVisibility="Column"
                  AlternatingRowBackground="LightBlue"
                  SelectionMode="Single">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Module Name" Binding="{Binding Name}" Width="200"/>
                <DataGridTextColumn Header="Version" Binding="{Binding Version}" Width="100"/>
                <DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="80"/>
                <DataGridTextColumn Header="Reference Count" Binding="{Binding ReferenceCount}" Width="120"/>
                <DataGridTextColumn Header="DLL Count" Binding="{Binding DllCount}" Width="80"/>
                <DataGridTextColumn Header="Importable" Binding="{Binding Importable}" Width="80"/>
                <DataGridTextColumn Header="Type" Binding="{Binding ModuleType}" Width="100"/>
                <DataGridTextColumn Header="Path" Binding="{Binding Path}" Width="*"/>
            </DataGrid.Columns>
        </DataGrid>
        
        <StatusBar Grid.Row="2" Height="25">
            <Label Name="StatusLabel" Content="Ready"/>
        </StatusBar>
    </Grid>
</Window>
"@

# Parse XAML and create window
# Advanced Concept: Runtime XAML parsing and WPF object model creation
# This demonstrates the multi-stage process of converting XML to .NET objects

try {
    # Stage 1: Create XmlReader from string content
    # StringReader wraps the XAML string for stream-based reading
    # XmlReader provides low-level XML parsing capabilities
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$xaml)

    # Stage 2: XAML to Object Model Conversion
    # XamlReader.Load performs the complex process of:
    # 1. Lexical analysis (tokenizing XAML elements)
    # 2. Syntactic analysis (validating XML structure)  
    # 3. Object instantiation (creating .NET objects from XAML elements)
    # 4. Property setting (converting attributes to object properties)
    # 5. Building the visual tree (establishing parent-child relationships)
    $window = [Windows.Markup.XamlReader]::Load($reader)
    
    # Clean up the reader
    $reader.Close()
} # End try block for XAML parsing
catch {
    # XAML parsing error handling
    Write-Error "Failed to parse XAML: $($_.Exception.Message)"
    Write-Error "XAML Content: $xaml"
    exit 1
} # End catch block for XAML parsing

# Verify window was created successfully
if (-not $window) {
    Write-Error "Window object was not created successfully"
    exit 1
} # End window verification

# Get controls from the parsed XAML window
# Advanced Concept: Named element lookup in WPF visual tree
# FindName() searches the logical tree for elements with x:Name attributes
try {
    $dataGrid = $window.FindName("ModulesDataGrid")              # Main data display control
    $refreshButton = $window.FindName("RefreshButton")           # Data refresh trigger
    $exportButton = $window.FindName("ExportButton")            # CSV export functionality  
    $getInfoButton = $window.FindName("GetInfoButton")          # Detailed info display
    $searchBox = $window.FindName("SearchBox")                  # Search/filter input
    $showOnlyLoadedCheckBox = $window.FindName("ShowOnlyLoadedCheckBox")  # Filter checkbox
    $statusLabel = $window.FindName("StatusLabel")              # Status display area

    # Verify all controls were found
    $controls = @{
        "ModulesDataGrid" = $dataGrid
        "RefreshButton" = $refreshButton
        "ExportButton" = $exportButton
        "GetInfoButton" = $getInfoButton
        "SearchBox" = $searchBox
        "ShowOnlyLoadedCheckBox" = $showOnlyLoadedCheckBox
        "StatusLabel" = $statusLabel
    }
    
    foreach ($controlName in $controls.Keys) {
        if (-not $controls[$controlName]) {
            Write-Error "Failed to find control: $controlName"
            exit 1
        } # End control verification
    } # End foreach control check
} # End try block for control lookup
catch {
    Write-Error "Error finding controls: $($_.Exception.Message)"
    exit 1
} # End catch block for control lookup

# Script-scoped variables for data management
# Advanced Concept: PowerShell variable scoping and state management
# $script: scope ensures variables persist across function calls within this script
$script:originalData = @()  # Currently filtered/displayed data
$script:allData = @()      # Complete unfiltered dataset

# Function to apply filters to the module data
# Intermediate Concept: Functional programming approach to data filtering
# This function demonstrates pipeline-based data transformation
function Set-ModuleFilters {
    # Verify required controls exist before proceeding
    if (-not $script:allData -or -not $dataGrid -or -not $searchBox -or -not $showOnlyLoadedCheckBox) {
        Write-Warning "Required controls or data not available for filtering"
        return
    } # End control verification
    
    # Start with complete dataset
    $filteredData = $script:allData
    
    # Apply search filter using pipeline operations
    # Get current search text from UI control
    try {
        $searchText = $searchBox.Text
        if (-not [string]::IsNullOrWhiteSpace($searchText)) {
            # Advanced pipeline filtering with complex Where-Object conditions
            # Uses -like operator with wildcard matching (*text* pattern)
            # Multiple -or conditions create comprehensive search across properties
            $filteredData = $filteredData | Where-Object {
                $_.Name -like "*$searchText*" -or
                $_.Version -like "*$searchText*" -or
                $_.ModuleType -like "*$searchText*" -or
                $_.Path -like "*$searchText*" -or
                $_.Status -like "*$searchText*"
            } # End Where-Object pipeline filter
        } # End if block for search text filtering
    } # End try block for search filtering
    catch {
        Write-Warning "Error applying search filter: $($_.Exception.Message)"
    } # End catch block for search filtering
    
    # Apply loaded modules filter based on checkbox state
    # Advanced: Accessing WPF control properties directly
    try {
        if ($showOnlyLoadedCheckBox.IsChecked) {
            # Additional pipeline filtering - can chain multiple Where-Object operations
            $filteredData = $filteredData | Where-Object { $_.Status -eq "Loaded" }
        } # End if block for loaded modules filter
    } # End try block for checkbox filtering
    catch {
        Write-Warning "Error applying checkbox filter: $($_.Exception.Message)"
    } # End catch block for checkbox filtering
    
    # Update UI with filtered data
    # WPF data binding: Setting ItemsSource triggers automatic UI refresh
    try {
        $dataGrid.ItemsSource = $filteredData
        
        # Update script-scoped variable to maintain current view state
        $script:originalData = $filteredData
    } # End try block for UI update
    catch {
        Write-Warning "Error updating DataGrid: $($_.Exception.Message)"
    } # End catch block for UI update
} # End function Set-ModuleFilters

# Event handlers - Advanced Concept: Event-driven programming with ScriptBlock delegates
# WPF uses the observer pattern where controls expose events and we attach handlers

# Only attach event handlers if controls were found successfully
if ($refreshButton) {
    # Refresh Button Click Event Handler
    # Add_Click() method accepts a ScriptBlock that becomes an EventHandler delegate
    $refreshButton.Add_Click({
        # User feedback: Update status to show operation in progress
        if ($statusLabel) { $statusLabel.Content = "Refreshing..." }
        
        try {
            # Data refresh operation
            $script:allData = Get-ModuleData        # Reload complete dataset
            Set-ModuleFilters                      # Apply current filters to new data
            
            # Success feedback with data statistics
            # String interpolation with subexpressions for dynamic content
            if ($statusLabel) {
                $statusLabel.Content = "Modules loaded: $($script:allData.Count) | Displayed: $($script:originalData.Count) | Last updated: $(Get-Date -Format 'HH:mm:ss')"
            } # End status update
        } # End try block
        catch {
            # Error handling with user-friendly feedback
            # $_ automatic variable contains the ErrorRecord object
            $errorMsg = "Error refreshing data: $($_.Exception.Message)"
            if ($statusLabel) { $statusLabel.Content = $errorMsg }
        } # End catch block
    }) # End refresh button click handler
} # End refresh button check

if ($exportButton) {
    # Export Button Click Event Handler
    $exportButton.Add_Click({
        try {
            # Advanced: .NET SaveFileDialog usage from PowerShell
            # Demonstrates PowerShell's seamless .NET integration
            $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
            
            # Dialog configuration using object properties
            $saveDialog.Filter = "CSV files (*.csv)|*.csv|All files (*.*)|*.*"  # File type filter
            $saveDialog.DefaultExt = "csv"                                        # Default extension
            
            # Dynamic filename with timestamp - PowerShell date formatting
            $saveDialog.FileName = "PowerShell_Modules_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            
            # Modal dialog display - ShowDialog() returns boolean result
            if ($saveDialog.ShowDialog() -eq $true) {
                # PowerShell Export-Csv cmdlet - converts objects to CSV format
                # -NoTypeInformation prevents .NET type headers in output
                $script:originalData | Export-Csv -Path $saveDialog.FileName -NoTypeInformation
                
                # Success feedback showing full file path
                if ($statusLabel) { $statusLabel.Content = "Data exported to: $($saveDialog.FileName)" }
            } # End if block for dialog result
        } # End try block
        catch {
            # Error handling for file operations
            $errorMsg = "Error exporting data: $($_.Exception.Message)"
            if ($statusLabel) { $statusLabel.Content = $errorMsg }
        } # End catch block
    }) # End export button click handler
} # End export button check

if ($getInfoButton -and $dataGrid) {
    # Get Info Button Click Event Handler
    # Advanced Concept: UI selection handling and conditional logic
    $getInfoButton.Add_Click({
        # Get currently selected item from DataGrid
        # SelectedItem property returns the bound data object (PSCustomObject)
        $selectedItem = $dataGrid.SelectedItem
        
        if ($selectedItem) {
            try {
                # Retrieve detailed module information using custom function
                $detailedInfo = Get-DetailedModuleInfo -ModuleName $selectedItem.Name
                
                # Advanced MessageBox usage with multiple buttons and return value checking
                # This creates a Yes/No dialog and captures the user's choice
                $result = [System.Windows.MessageBox]::Show(
                    "$detailedInfo`n`nWould you like to search for this module online?",  # Message text with line breaks
                    "Module Details - $($selectedItem.Name)",                            # Window title with interpolation
                    [System.Windows.MessageBoxButton]::YesNo,                           # Button configuration enum
                    [System.Windows.MessageBoxImage]::Information                       # Icon type enum
                ) # End MessageBox.Show method call
                
                # Conditional action based on user response
                # MessageBoxResult enum comparison
                if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                    # Invoke web search function if user chose Yes
                    Open-ModuleWebSearch -ModuleName $selectedItem.Name
                } # End if block for Yes result
            } # End try block
            catch {
                # Error handling for module info retrieval
                # Multi-line MessageBox call with different icon for errors
                [System.Windows.MessageBox]::Show(
                    "Error retrieving module information: $($_.Exception.Message)", 
                    "Error", 
                    [System.Windows.MessageBoxButton]::OK, 
                    [System.Windows.MessageBoxImage]::Error
                ) # End error MessageBox.Show
            } # End catch block
        } # End if block for selected item check
        else {
            # User guidance when no selection is made
            # Information-style message box for user education
            [System.Windows.MessageBox]::Show(
                "Please select a module from the list first.", 
                "No Selection", 
                [System.Windows.MessageBoxButton]::OK, 
                [System.Windows.MessageBoxImage]::Information
            ) # End no selection MessageBox.Show
        } # End else block for no selection
    }) # End get info button click handler
} # End get info button check

if ($searchBox) {
    # Search functionality - Real-time filtering as user types
    # Advanced Concept: TextChanged event provides immediate feedback
    $searchBox.Add_TextChanged({
        # Invoke filtering function whenever text changes
        # This provides real-time search results as the user types
        Set-ModuleFilters
    }) # End search box text changed handler
} # End search box check

if ($showOnlyLoadedCheckBox) {
    # Show only loaded checkbox functionality
    # Intermediate Concept: Checkbox state change event handling
    $showOnlyLoadedCheckBox.Add_Checked({
        # Checkbox checked event - apply filters when user checks the box
        Set-ModuleFilters
    }) # End checkbox checked handler

    $showOnlyLoadedCheckBox.Add_Unchecked({
        # Checkbox unchecked event - reapply filters when user unchecks the box
        Set-ModuleFilters
    }) # End checkbox unchecked handler
} # End checkbox check

if ($dataGrid) {
    # Double-click to show module details
    # Advanced Concept: Mouse event handling for enhanced user interaction
    $dataGrid.Add_MouseDoubleClick({
        # Get the currently selected item when user double-clicks
        $selectedItem = $dataGrid.SelectedItem
        
        if ($selectedItem) {
            # Retrieve and display detailed module information
            # This provides an alternative to the Get Info button
            $detailedInfo = Get-DetailedModuleInfo -ModuleName $selectedItem.Name
            
            # Simple information display without web search option
            [System.Windows.MessageBox]::Show(
                $detailedInfo, 
                "Module Details - $($selectedItem.Name)", 
                [System.Windows.MessageBoxButton]::OK, 
                [System.Windows.MessageBoxImage]::Information
            ) # End MessageBox.Show for double-click details
        } # End if block for selected item check
    }) # End DataGrid mouse double-click handler
} # End DataGrid check

# Initial data load - Application startup sequence
# This code executes when the script first runs, before showing the window
try {
    if ($statusLabel) {
        $statusLabel.Content = "Loading modules..."  # User feedback during startup
    } # End status label check

    # Initial data collection and UI setup
    $script:allData = Get-ModuleData     # Load all module data
    Set-ModuleFilters                   # Apply default filters (none initially)
    
    # Success status with comprehensive information
    # Shows total modules loaded and currently displayed count
    if ($statusLabel) {
        $statusLabel.Content = "Modules loaded: $($script:allData.Count) | Displayed: $($script:originalData.Count) | Last updated: $(Get-Date -Format 'HH:mm:ss')"
    } # End status label update
} # End try block for initial load
catch {
    # Startup error handling - critical for application reliability
    $errorMsg = "Error loading initial data: $($_.Exception.Message)"
    Write-Error $errorMsg
    if ($statusLabel) {
        $statusLabel.Content = $errorMsg
    } # End status label error update
} # End catch block for initial load

# Show the window - Final application startup step
# Advanced Concept: Modal dialog display and application message loop
# ShowDialog() creates a modal window and starts the WPF message pump
# Returns nullable boolean: true (OK), false (Cancel), or null (closed via X)
# Out-Null suppresses the return value since we don't need it
try {
    if ($window) {
        $window.ShowDialog() | Out-Null
    } else {
        Write-Error "Window object is null - cannot display application"
        exit 1
    } # End window existence check
} # End try block for window display
catch {
    Write-Error "Error displaying window: $($_.Exception.Message)"
    exit 1
} # End catch block for window display

# End of script execution
# When ShowDialog() returns, the window has been closed and the application terminates
# WPF automatically handles cleanup of UI resources and event handlers
