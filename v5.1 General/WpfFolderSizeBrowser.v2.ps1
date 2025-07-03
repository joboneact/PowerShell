# WPF Folder Size Browser v2
# This script creates a WPF application using PowerShell to display folder sizes and allows navigation through folders.

<#
.SYNOPSIS
    WPF Folder Size Browser v2 - Displays folder sizes and allows navigation through folders.

.DESCRIPTION
    This script creates a WPF application using PowerShell to display folder sizes and allows navigation through folders.
    It includes features such as a progress dialog, wait cursor, sortable columns, and double-click navigation.
    
    Key Features:
    - Real-time folder size calculation with progress indication
    - Recursive and non-recursive folder size scanning options
    - Sortable columns with visual indicators
    - Navigation through folder hierarchy with Up button and double-click
    - Integration with Windows Explorer
    - Clipboard functionality for path copying
    - Responsive UI layout that adapts to window resizing

.PARAMETER None
    No parameters are required for this script.

.EXAMPLE
    Run the script directly in PowerShell:
        .\WpfFolderSizeBrowser.v2.ps1

.NOTES
    - Compatible with PowerShell 5.1 and .NET 6.0 or earlier.
    - Requires Windows Presentation Framework (WPF) support.
    - Ensure the script is run with appropriate permissions to access folder paths.
    - Performance may vary based on folder structure and recursion settings.

.LINK
    https://github.com/joboneact
#>

# Import required .NET assemblies for WPF functionality
# These assemblies provide the core WPF classes and controls
Add-Type -AssemblyName PresentationFramework  # Core WPF framework
Add-Type -AssemblyName PresentationCore       # WPF core components
Add-Type -AssemblyName WindowsBase            # Base WPF classes

<#
.SYNOPSIS
    Retrieves folder sizes for immediate child folders.

.DESCRIPTION
    This function calculates the size of immediate child folders within the specified path.
    It returns a collection of folder objects with comprehensive size information including
    bytes, megabytes, gigabytes, and human-readable display formats.

.PARAMETER Path
    The file system path of the folder to analyze for child folder sizes.

.EXAMPLE
    Get-FolderSizes -Path "C:\Users"
    Retrieves the sizes of all immediate child folders within "C:\Users".

.NOTES
    - Uses Get-ChildItem and Measure-Object to calculate folder sizes recursively.
    - Handles errors silently for inaccessible folders using -ErrorAction SilentlyContinue.
    - Returns sorted results by size in descending order for better visibility.
    - Includes multiple size format options for different display needs.
#>
function Get-FolderSizes {
    param([string]$Path)
    
    # Get all directories in the specified path and process each one
    Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        # Calculate total size by recursively getting all files and summing their lengths
        $folderSize = (Get-ChildItem -Path $_.FullName -Recurse -File -ErrorAction SilentlyContinue | 
                       Measure-Object -Property Length -Sum).Sum
        
        # Handle null values from empty folders or access denied scenarios
        if ($folderSize -eq $null) { $folderSize = 0 }
        
        # Create a custom object with comprehensive folder information
        [PSCustomObject]@{
            Name = $_.Name                                    # Folder display name
            FullPath = $_.FullName                           # Complete file system path
            SizeBytes = $folderSize                          # Raw size in bytes
            SizeMB = [math]::Round($folderSize / 1MB, 2)     # Size in megabytes (rounded)
            SizeGB = [math]::Round($folderSize / 1GB, 3)     # Size in gigabytes (rounded)
            # Human-readable size with appropriate unit suffix
            DisplaySize = if ($folderSize -gt 1GB) { 
                "$([math]::Round($folderSize / 1GB, 2)) GB" 
            } elseif ($folderSize -gt 1MB) { 
                "$([math]::Round($folderSize / 1MB, 2)) MB" 
            } elseif ($folderSize -gt 1KB) { 
                "$([math]::Round($folderSize / 1KB, 2)) KB" 
            } else { 
                "$folderSize bytes" 
            }
        }
    } | Sort-Object SizeBytes -Descending  # Sort by size for better visual hierarchy
}

<#
.SYNOPSIS
    Sorts folder data based on the specified column and direction.

.DESCRIPTION
    This function provides flexible sorting capabilities for folder data collections.
    It supports both ascending and descending sort orders for any specified column property.

.PARAMETER data
    The collection of folder data objects to sort.

.PARAMETER column
    The property name to sort by (e.g., "Name", "SizeBytes", "SizeMB").

.PARAMETER direction
    The sort direction - either "Ascending" or "Descending".

.EXAMPLE
    Sort-FolderData -data $folderData -column "SizeBytes" -direction "Descending"
    Sorts the folder data by size in descending order (largest first).

.EXAMPLE
    Sort-FolderData -data $folderData -column "Name" -direction "Ascending"
    Sorts the folder data alphabetically by name.

.NOTES
    - Uses PowerShell's Sort-Object cmdlet for reliable sorting.
    - Maintains object integrity during sorting operations.
    - Essential for column header click sorting functionality.
#>
function Sort-FolderData {
    param($data, $column, $direction)
    
    # Apply sorting based on direction parameter
    if ($direction -eq "Ascending") {
        $result = @($data | Sort-Object $column)
    } else {
        $result = @($data | Sort-Object $column -Descending)
    }
    return $result
}

<#
.SYNOPSIS
    Displays a modal progress dialog with a determinate progress bar.

.DESCRIPTION
    This function creates and displays a WPF progress dialog window with a progress bar
    that can be updated during long-running operations. The dialog provides visual
    feedback to users during folder size calculation processes.

.PARAMETER Message
    The descriptive message to display above the progress bar.

.EXAMPLE
    Show-ProgressDialog -Message "Refreshing folder sizes..."
    Displays a progress dialog with the specified message.

.NOTES
    - Uses inline XAML to define the dialog structure.
    - Returns a window object that can be manipulated by the caller.
    - Progress bar is determinate (0-100%) for accurate progress indication.
    - Dialog is modal and centered on screen for better user experience.
#>
function Show-ProgressDialog {
    param([string]$Message)

    # Define the XAML structure for the progress dialog window
    $progressXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Progress" Height="150" Width="300"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize" WindowStyle="ToolWindow">
    <Grid>
        <!-- Center all content vertically and horizontally -->
        <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
            <!-- Display the progress message with appropriate styling -->
            <TextBlock Text="$Message" FontSize="14" Margin="0,0,0,10" HorizontalAlignment="Center"/>
            <!-- Determinate progress bar with 0-100 range -->
            <ProgressBar Name="ProgressBar" Width="250" Height="20" Minimum="0" Maximum="100" Value="0"/>
        </StackPanel>
    </Grid>
</Window>
"@

    # Parse XAML and create the window object
    $reader = [System.Xml.XmlNodeReader]::new([xml]$progressXaml)
    $progressWindow = [Windows.Markup.XamlReader]::Load($reader)
    return $progressWindow
}

<#
.SYNOPSIS
    Displays a detailed exception dialog with clipboard functionality.

.DESCRIPTION
    This function creates and displays a modal dialog showing exception details
    with options to copy the error information to the clipboard for troubleshooting.

.PARAMETER Exception
    The exception object containing error details to display.

.PARAMETER Context
    Additional context information about when/where the error occurred.

.EXAMPLE
    Show-ExceptionDialog -Exception $_.Exception -Context "Folder size calculation"
    Displays an exception dialog with the error details and context.

.NOTES
    - Modal dialog blocks user interaction until dismissed
    - Provides copy to clipboard functionality for error reporting
    - Shows detailed error information for troubleshooting
#>
function Show-ExceptionDialog {
    param(
        [System.Exception]$Exception,
        [string]$Context = "Application Error"
    )

    # Create detailed error message with context and technical details
    $errorDetails = @"
Context: $Context
Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Error Message: $($Exception.Message)

Exception Type: $($Exception.GetType().FullName)

Stack Trace:
$($Exception.StackTrace)

PowerShell Version: $($PSVersionTable.PSVersion)
OS Version: $([System.Environment]::OSVersion.VersionString)
"@

    # Define XAML for the exception dialog window
    $exceptionXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Application Error" Height="400" Width="600"
        WindowStartupLocation="CenterScreen" ResizeMode="CanResize">
    <Grid>
        <!-- Define 3-row layout for organized error display -->
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>  <!-- Header with error icon and title -->
            <RowDefinition Height="*"/>     <!-- Main content area with error details -->
            <RowDefinition Height="Auto"/>  <!-- Button panel for user actions -->
        </Grid.RowDefinitions>
        
        <!-- Header section with error information -->
        <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="10" Background="#FFF3CD">
            <!-- Error icon for visual indication -->
            <TextBlock Text="⚠️" FontSize="24" Margin="5" VerticalAlignment="Center"/>
            <!-- Error title and brief description -->
            <StackPanel Margin="10,5">
                <TextBlock Text="An Error Occurred" FontSize="16" FontWeight="Bold"/>
                <TextBlock Text="$Context" FontSize="12" Foreground="DarkRed"/>
            </StackPanel>
        </StackPanel>
        
        <!-- Main content area with scrollable error details -->
        <ScrollViewer Grid.Row="1" Margin="10" VerticalScrollBarVisibility="Auto">
            <!-- Text box containing full error information -->
            <TextBox Name="ErrorTextBox" Text="$errorDetails" 
                     IsReadOnly="True" TextWrapping="Wrap" 
                     FontFamily="Consolas" FontSize="10"
                     Background="LightGray" BorderThickness="1"/>
        </ScrollViewer>
        
        <!-- Button panel for user actions -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" 
                    HorizontalAlignment="Right" Margin="10">
            <!-- Copy to clipboard button -->
            <Button Name="CopyButton" Content="Copy to Clipboard" 
                    Width="120" Height="30" Margin="5"/>
            <!-- Close dialog button -->
            <Button Name="CloseButton" Content="Close" 
                    Width="80" Height="30" Margin="5"/>
        </StackPanel>
    </Grid>
</Window>
"@

    try {
        # Parse XAML and create the exception dialog window
        $reader = [System.Xml.XmlNodeReader]::new([xml]$exceptionXaml)
        $exceptionWindow = [Windows.Markup.XamlReader]::Load($reader)
        
        # Get references to dialog controls
        $errorTextBox = $exceptionWindow.FindName("ErrorTextBox")
        $copyButton = $exceptionWindow.FindName("CopyButton")
        $closeButton = $exceptionWindow.FindName("CloseButton")
        
        # Event handler for copy to clipboard button
        $copyButton.Add_Click({
            try {
                # Copy error details to system clipboard
                Set-Clipboard -Value $errorDetails
                
                # Provide visual feedback of successful copy
                $copyButton.Content = "Copied!"
                $copyButton.IsEnabled = $false
                
                # Reset button after 2 seconds
                $timer = New-Object System.Windows.Threading.DispatcherTimer
                $timer.Interval = [TimeSpan]::FromSeconds(2)
                $timer.Add_Tick({
                    $copyButton.Content = "Copy to Clipboard"
                    $copyButton.IsEnabled = $true
                    $timer.Stop()
                })
                $timer.Start()
            } catch {
                # Handle clipboard access errors
                $copyButton.Content = "Copy Failed"
            }
        })
        
        # Event handler for close button
        $closeButton.Add_Click({
            $exceptionWindow.Close()
        })
        
        # Display the exception dialog as modal
        $exceptionWindow.ShowDialog()
        
    } catch {
        # Fallback: If dialog creation fails, show basic message box
        [System.Windows.MessageBox]::Show(
            "Error Details:`n$($Exception.Message)", 
            "Application Error", 
            [System.Windows.MessageBoxButton]::OK, 
            [System.Windows.MessageBoxImage]::Error
        )
    }
}

# Define the main application window using XAML
# This creates a comprehensive file browser interface with responsive design
$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Folder Size Browser (WPF) July 2025 v2" Height="550" Width="750"
        WindowStartupLocation="CenterScreen">
    <Grid>
        <!-- Define a 4-row grid layout for organized content structure -->
        <Grid.RowDefinitions>
            <!-- Row 0: Navigation controls and options (Auto-sized based on content) -->
            <RowDefinition Height="Auto"/>
            <!-- Row 1: Main content area with folder list (Takes remaining space) -->
            <RowDefinition Height="*"/>
            <!-- Row 2: Status information display (Auto-sized) -->
            <RowDefinition Height="Auto"/>
            <!-- Row 3: Application status bar (Auto-sized) -->
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Navigation and control panel with responsive wrapping layout -->
        <!-- WrapPanel automatically wraps controls to new lines when window width decreases -->
        <WrapPanel Grid.Row="0" Orientation="Horizontal" Margin="10">
            <!-- Current path label with vertical centering -->
            <Label Content="Current Path:" VerticalAlignment="Center"/>
            <!-- Read-only text box showing the current folder path -->
            <!-- Width set to accommodate typical path lengths -->
            <TextBox Name="PathTextBox" Width="400" Margin="5,0" IsReadOnly="True"/>
            <!-- Navigation button to move up one folder level -->
            <Button Name="UpButton" Content="Up" Width="50" Margin="5,0"/>
            <!-- Manual refresh button to recalculate folder sizes -->
            <Button Name="RefreshButton" Content="Refresh" Width="70" Margin="5,0"/>
            <!-- Integration button to open current folder in Windows Explorer -->
            <Button Name="RevealButton" Content="Reveal in Explorer" Width="120" Margin="5,0"/>
            <!-- Utility button to copy current path to clipboard -->
            <Button Name="CopyPathButton" Content="Copy Path" Width="80" Margin="5,0"/>
            <!-- Option checkbox to enable/disable recursive folder scanning -->
            <!-- Default checked for comprehensive size calculation -->
            <CheckBox Name="RecurseCheckBox" Content="Recurse Subfolders" IsChecked="True" Margin="5,0"/>
        </WrapPanel>
        
        <!-- Main data display area using ListView with GridView for tabular data -->
        <ListView Name="FolderListView" Grid.Row="1" Margin="10">
            <ListView.View>
                <!-- GridView provides column-based data presentation -->
                <GridView>
                    <!-- Primary column showing folder names -->
                    <!-- Wider width to accommodate longer folder names -->
                    <GridViewColumn Header="Folder Name" Width="300" DisplayMemberBinding="{Binding Name}"/>
                    <!-- Human-readable size column with automatic unit formatting -->
                    <GridViewColumn Header="Size" Width="150" DisplayMemberBinding="{Binding DisplaySize}"/>
                    <!-- Numeric size column in megabytes for precise comparison -->
                    <GridViewColumn Header="Size (MB)" Width="100" DisplayMemberBinding="{Binding SizeMB}"/>
                    <!-- Information column indicating presence of subdirectories -->
                    <GridViewColumn Header="Has Subfolders" Width="150" DisplayMemberBinding="{Binding HasSubfolders}"/>
                </GridView>
            </ListView.View>
        </ListView>
        
        <!-- Status information panel showing last refresh timestamp -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="10,5">
            <!-- Bold label for visual emphasis -->
            <Label Content="Last Refreshed:" FontWeight="Bold"/>
            <!-- Dynamic label updated with each refresh operation -->
            <Label Name="LastRefreshedLabel" Content="Never"/>
        </StackPanel>
        
        <!-- Application status bar for operation feedback and error messages -->
        <StatusBar Grid.Row="3">
            <!-- Single status item for general application messages -->
            <StatusBarItem Name="StatusText" Content="Ready"/>
        </StatusBar>
    </Grid>
</Window>
"@

# Parse the XAML and create the main window object
# XmlNodeReader provides efficient XAML parsing
$reader = [System.Xml.XmlNodeReader]::new([xml]$XAML)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Retrieve references to named controls for event handling and manipulation
# These references enable programmatic control of UI elements
$pathTextBox = $window.FindName("PathTextBox")           # Path display textbox
$upButton = $window.FindName("UpButton")                 # Parent folder navigation
$refreshButton = $window.FindName("RefreshButton")       # Manual refresh trigger
$revealButton = $window.FindName("RevealButton")         # Explorer integration
$copyPathButton = $window.FindName("CopyPathButton")     # Clipboard functionality
$recurseCheckBox = $window.FindName("RecurseCheckBox")   # Recursion option control
$folderListView = $window.FindName("FolderListView")     # Main data display
$statusText = $window.FindName("StatusText")             # Status message display
$lastRefreshedLabel = $window.FindName("LastRefreshedLabel") # Timestamp display

# Initialize application state variables
# These variables maintain the current application state across operations
$currentPath = Get-Location                              # Start with current working directory
$currentSortColumn = "SizeBytes"                         # Default sort by size
$currentSortDirection = "Descending"                     # Largest folders first

<#
.SYNOPSIS
    Updates the main display with current folder sizes and comprehensive progress feedback.

.DESCRIPTION
    This is the core function that orchestrates the folder scanning process. It provides
    visual feedback through a progress dialog, calculates folder sizes based on recursion
    settings, and updates the main ListView with sorted results.

.PARAMETER Path
    The file system path to analyze and display folder information for.

.EXAMPLE
    Update-Display -Path "C:\Users"
    Analyzes and displays folder sizes for all immediate subdirectories of C:\Users.

.NOTES
    - Shows modal progress dialog during operation for user feedback
    - Respects the recursion checkbox setting for size calculation depth
    - Updates progress bar incrementally for better user experience
    - Handles errors gracefully with appropriate user messaging
    - Automatically sorts results based on current sort settings
#>
function Update-Display {
    param([string]$Path)

    # Initialize and display progress dialog for user feedback
    $progressDialog = Show-ProgressDialog -Message "Refreshing folder sizes..."
    $progressBar = $progressDialog.FindName("ProgressBar")
    
    # Show progress dialog on UI thread to ensure immediate visibility
    $progressDialog.Dispatcher.Invoke([Action]{
        $progressDialog.Show()
    })

    # Set visual indicators for ongoing operation
    $window.Cursor = [System.Windows.Input.Cursors]::Wait  # Change cursor to indicate processing
    $statusText.Content = "Loading..."                      # Update status message
    $pathTextBox.Text = $Path                              # Display current path being processed
    
    try {
        # Get immediate subdirectories for analysis
        $folders = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue
        $folderCount = $folders.Count    # Total folders for progress calculation
        $processedCount = 0              # Counter for progress tracking

        # Initialize collection for processed folder data
        $folderData = @()
        
        # Process each folder individually for size calculation and metadata
        foreach ($folder in $folders) {
            try {
                # Check recursion setting to determine scanning depth
                $recurse = $recurseCheckBox.IsChecked
                
                # Calculate folder size based on recursion setting
                $folderSize = if ($recurse) {
                    # Recursive: Include all files in subdirectories
                    (Get-ChildItem -Path $folder.FullName -Recurse -File -ErrorAction SilentlyContinue | 
                     Measure-Object -Property Length -Sum).Sum
                } else {
                    # Non-recursive: Only immediate files in the folder
                    (Get-ChildItem -Path $folder.FullName -File -ErrorAction SilentlyContinue | 
                     Measure-Object -Property Length -Sum).Sum
                }

                # Handle null results from empty folders or access issues
                if ($null -eq $folderSize) { $folderSize = 0 }

                # Check for presence of immediate subdirectories
                $hasSubfolders = if ((Get-ChildItem -Path $folder.FullName -Directory -ErrorAction SilentlyContinue).Count -gt 0) {
                    "Yes"  # Subdirectories found
                } else {
                    "No"   # No subdirectories
                }

                # Create comprehensive folder data object
                $folderData += [PSCustomObject]@{
                    Name = $folder.Name                           # Display name
                    FullPath = $folder.FullName                   # Complete path for navigation
                    SizeBytes = $folderSize                       # Raw byte count
                    SizeMB = [math]::Round($folderSize / 1MB, 2)  # Megabytes (rounded)
                    # Human-readable size with intelligent unit selection
                    DisplaySize = if ($folderSize -gt 1GB) { 
                        "$([math]::Round($folderSize / 1GB, 2)) GB" 
                    } elseif ($folderSize -gt 1MB) { 
                        "$([math]::Round($folderSize / 1MB, 2)) MB" 
                    } elseif ($folderSize -gt 1KB) { 
                        "$([math]::Round($folderSize / 1KB, 2)) KB" 
                    } else { 
                        "$folderSize bytes" 
                    }
                    HasSubfolders = $hasSubfolders                # Subdirectory indicator
                }
            }
            catch {
                # Handle individual folder processing errors
                Write-Warning "Error processing folder '$($folder.Name)': $($_.Exception.Message)"
                # Continue processing other folders
            }

            # Update progress bar with current completion percentage
            $processedCount++
            $progressBar.Dispatcher.Invoke([Action]{
                $progressBar.Value = ($processedCount / $folderCount) * 100
            })
        }

        # Apply current sort settings to the processed data
        $sortedFolders = Sort-FolderData -data $folderData -column $currentSortColumn -direction $currentSortDirection
        
        # Ensure the result is always an array for proper ItemsSource binding
        if ($sortedFolders -isnot [Array]) {
            $sortedFolders = @($sortedFolders)
        }
        
        # Update the main display with sorted results
        $folderListView.ItemsSource = $sortedFolders
        
        # Update status information with operation results
        $statusText.Content = "Found $($folderData.Count) folders"
        $lastRefreshedLabel.Content = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    catch {
        # Handle critical errors during the scanning process
        $statusText.Content = "Error: $($_.Exception.Message)"
        $lastRefreshedLabel.Content = "Error at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        
        # Show detailed exception dialog with clipboard functionality
        Show-ExceptionDialog -Exception $_.Exception -Context "Folder size calculation for path: $Path"
    }
    finally {
        # Cleanup operations that must execute regardless of success/failure
        
        # Close progress dialog on UI thread
        $progressDialog.Dispatcher.Invoke([Action]{
            $progressDialog.Close()
        })
        
        # Reset cursor to normal state
        $window.Cursor = [System.Windows.Input.Cursors]::Arrow
    }
}

# Event handler for Up button - navigates to parent directory
# Automatically disables recursion for better performance when navigating up
$upButton.Add_Click({
    # Get parent directory path
    $parent = Split-Path -Parent $currentPath
    
    # Verify parent exists and is accessible
    if ($parent -and (Test-Path $parent)) {
        # Update current path to parent directory
        $script:currentPath = $parent
        
        # Disable recursion when navigating up to improve performance
        # Large parent directories can be slow with recursion enabled
        $recurseCheckBox.IsChecked = $false
        
        # Refresh display with new path
        Update-Display $currentPath
    }
})

# Event handler for Refresh button - recalculates current directory
$refreshButton.Add_Click({
    Update-Display $currentPath
})

# Event handler for Copy Path button - copies current path to system clipboard
$copyPathButton.Add_Click({
    try {
        # Use PowerShell clipboard functionality to copy path
        Set-Clipboard -Value $currentPath
        
        # Provide user confirmation of successful copy operation
        $statusText.Content = "Path copied to clipboard: $currentPath"
    } catch {
        # Show detailed exception dialog for clipboard errors
        Show-ExceptionDialog -Exception $_.Exception -Context "Copying path to clipboard"
    }
})

# Event handler for Reveal in Explorer button - opens current path in Windows Explorer
$revealButton.Add_Click({
    try {
        # Verify path exists before attempting to open
        if (Test-Path $currentPath) {
            # Launch Windows Explorer with current path
            Start-Process explorer.exe $currentPath
        } else {
            # Display error message for invalid paths
            $statusText.Content = "Error: Path does not exist."
        }
    } catch {
        # Show detailed exception dialog for Explorer launch errors
        Show-ExceptionDialog -Exception $_.Exception -Context "Opening folder in Windows Explorer"
    }
})

# Event handler for ListView double-click - enables folder navigation by double-clicking
# This provides intuitive navigation similar to Windows Explorer
$folderListView.AddHandler([System.Windows.Controls.ListView]::MouseDoubleClickEvent, [System.Windows.Input.MouseButtonEventHandler]{
    param($eventSender, $eventArgs)

    # Get the currently selected folder item
    $selectedItem = $folderListView.SelectedItem
    
    # Verify a valid folder is selected with a complete path
    if ($selectedItem -and $selectedItem.FullPath) {
        # Update current path to the selected folder
        $script:currentPath = $selectedItem.FullPath
        
        # Refresh display to show contents of selected folder
        Update-Display $currentPath
    } else {
        # Display error message for invalid selections
        $statusText.Content = "Error: Unable to open folder."
    }
})

# Perform initial application load with current working directory
Update-Display $currentPath

# Display the main window and start the WPF message loop
# ShowDialog() makes the window modal and blocks until closed
$window.ShowDialog()



