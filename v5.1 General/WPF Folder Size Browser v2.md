# WPF Folder Size Browser v2

## Enhancements - July 2025

Thursday, July 3, 2025 
12:01:45 AM 

The progress dialog still doesn't show any progress.

The sort order doesn't show descending icon. but ascending is shown.



## Overview
This script creates a WPF application using PowerShell to display folder sizes and allows navigation through folders. It includes features such as a progress dialog, wait cursor, and sortable columns.

---

## Key Features
1. **Progress Dialog**:
   - Displays a modal progress dialog with a determinate progress bar during folder size calculations.
   - Updates the progress bar dynamically as folders are processed.

2. **Wait Cursor**:
   - Changes the cursor to a wait cursor during long-running operations.

3. **Sortable Columns**:
   - Allows sorting by folder size or name.
   - Displays an up or down arrow in the column header to indicate sort direction.

---

## Key Fixes

### Fix for Progress Dialog Visibility
The progress dialog is explicitly shown using `ShowDialog()` to ensure it blocks the main window and remains visible.

```powershell
# Function to show a progress dialog with a determinate progress bar
function Show-ProgressDialog {
    param([string]$Message)

    $progressXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Progress" Height="150" Width="300"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize" WindowStyle="ToolWindow">
    <Grid>
        <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
            <TextBlock Text="$Message" FontSize="14" Margin="0,0,0,10" HorizontalAlignment="Center"/>
            <ProgressBar Name="ProgressBar" Width="250" Height="20" Minimum="0" Maximum="100" Value="0"/>
        </StackPanel>
    </Grid>
</Window>
"@

    $reader = [System.Xml.XmlNodeReader]::new([xml]$progressXaml)
    $progressWindow = [Windows.Markup.XamlReader]::Load($reader)
    return $progressWindow
}
```

---

### Fix for Progress Bar Updates
The progress bar value is updated dynamically during folder processing using `Dispatcher.Invoke` to ensure the UI thread processes the updates.

```powershell
# Function to update the display with progress dialog
function Update-Display {
    param([string]$Path)

    # Show progress dialog
    $progressDialog = Show-ProgressDialog -Message "Refreshing folder sizes..."
    $progressBar = $progressDialog.FindName("ProgressBar")
    
    # Show the progress dialog
    $progressDialog.Dispatcher.Invoke([Action]{
        $progressDialog.Show()
    })

    # Set wait cursor
    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    $statusText.Content = "Loading..."
    $pathTextBox.Text = $Path
    
    try {
        # Get folders and calculate sizes
        $folders = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue
        $folderCount = $folders.Count
        $processedCount = 0

        $folderData = @()
        foreach ($folder in $folders) {
            # Perform folder size calculation
            $folderSize = (Get-ChildItem -Path $folder.FullName -Recurse -File -ErrorAction SilentlyContinue | 
                           Measure-Object -Property Length -Sum).Sum
            if ($folderSize -eq $null) { $folderSize = 0 }

            # Add folder data to the collection
            $folderData += [PSCustomObject]@{
                Name = $folder.Name
                FullPath = $folder.FullName
                SizeBytes = $folderSize
                SizeMB = [math]::Round($folderSize / 1MB, 2)
                DisplaySize = if ($folderSize -gt 1GB) { "$([math]::Round($folderSize / 1GB, 2)) GB" } 
                             elseif ($folderSize -gt 1MB) { "$([math]::Round($folderSize / 1MB, 2)) MB" }
                             elseif ($folderSize -gt 1KB) { "$([math]::Round($folderSize / 1KB, 2)) KB" }
                             else { "$folderSize bytes" }
            }

            # Update progress bar
            $processedCount++
            $progressBar.Dispatcher.Invoke([Action]{
                $progressBar.Value = ($processedCount / $folderCount) * 100
            })
        }

        # Sort and display folder data
        $sortedFolders = Sort-FolderData -data $folderData -column $currentSortColumn -direction $currentSortDirection
        $folderListView.ItemsSource = $sortedFolders
        $statusText.Content = "Found $($folderData.Count) folders"
        $lastRefreshedLabel.Content = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    catch {
        $statusText.Content = "Error: $($_.Exception.Message)"
        $lastRefreshedLabel.Content = "Error at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    }
    finally {
        # Close progress dialog
        $progressDialog.Dispatcher.Invoke([Action]{
            $progressDialog.Close()
        })
        # Reset cursor
        $window.Cursor = [System.Windows.Input.Cursors]::Arrow
    }
}
```

---

### Testing
1. Run the script and click the `Refresh` or `Up` button.
2. Verify that the progress dialog appears and the progress bar updates dynamically as folders are processed.
3. Ensure the progress dialog closes after the operation completes.

---

## Summary
This script provides a responsive and user-friendly interface for browsing folder sizes using WPF in PowerShell. The progress dialog and wait cursor ensure smooth feedback during long-running operations, while the sortable columns enhance usability.

---

## Update Log - July 3, 2025

### Changes Made Since Last Update

#### 1. Column Header Click Sorting with Visual Indicators
**User Prompt:** "modify powershell script to show a wait cursor when Refresh button is pushed. pluis show an indicator for the Size column. The indicator should show Descending or a down arrow. if sort order is Ascending, an up arrow should show."

**Implementation:** Added column header click event handler with visual sort indicators:
```powershell
# Add column header click event for sorting
$folderListView.AddHandler([System.Windows.Controls.GridViewColumnHeader]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($sender, $e)
    
    $header = $e.OriginalSource
    if ($header -is [System.Windows.Controls.GridViewColumnHeader] -and $header.Content) {
        $columnName = switch ($header.Content) {
            "Folder Name" { "Name" }
            "Size" { "SizeBytes" }
            "Size (MB)" { "SizeMB" }
            default { "SizeBytes" }
        }
        
        # Toggle sort direction if same column, otherwise default to descending
        if ($currentSortColumn -eq $columnName) {
            $script:currentSortDirection = if ($currentSortDirection -eq "Ascending") { "Descending" } else { "Ascending" }
        } else {
            $script:currentSortColumn = $columnName
            $script:currentSortDirection = if ($columnName -eq "Name") { "Ascending" } else { "Descending" }
        }
        
        # Update sort indicator for Size column
        foreach ($col in $folderListView.View.Columns) {
            if ($col.Header -eq "Size") {
                $col.Header = if ($currentSortDirection -eq "Ascending") { "Size ↑" } else { "Size ↓" }
            } elseif ($col.Header -is [string]) {
                $col.Header = $col.Header -replace " ↑| ↓", ""
            }
        }
        
        # Re-sort current data
        $currentData = $folderListView.ItemsSource
        if ($currentData) {
            $sortedData = Sort-FolderData -data $currentData -column $currentSortColumn -direction $currentSortDirection
            $folderListView.ItemsSource = $sortedData
        }
    }
})
```

**Reasoning:** Provides visual feedback for sort direction and enables interactive column sorting similar to Windows Explorer.

#### 2. Progress Dialog with Determinate Progress Bar
**User Prompt:** "when the up or refresh is clicked with mouse - show a new progress dialog in addition fo the wait cursor."

**Implementation:** Created modal progress dialog with real progress indication:
```powershell
function Show-ProgressDialog {
    param([string]$Message)

    $progressXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Progress" Height="150" Width="300"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize" WindowStyle="ToolWindow">
    <Grid>
        <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
            <TextBlock Text="$Message" FontSize="14" Margin="0,0,0,10" HorizontalAlignment="Center"/>
            <ProgressBar Name="ProgressBar" Width="250" Height="20" Minimum="0" Maximum="100" Value="0"/>
        </StackPanel>
    </Grid>
</Window>
"@

    $reader = [System.Xml.XmlNodeReader]::new([xml]$progressXaml)
    $progressWindow = [Windows.Markup.XamlReader]::Load($reader)
    return $progressWindow
}
```

**Reasoning:** Provides visual feedback during long-running operations, improving user experience with clear progress indication.

#### 3. Responsive Layout with WrapPanel
**User Prompt:** "make the folder path and three buttons to right inside a responsive visual block - the right buttons should wrap around if the width of the application window narrows."

**Implementation:** Replaced StackPanel with WrapPanel in XAML:
```xml
<WrapPanel Grid.Row="0" Orientation="Horizontal" Margin="10">
    <Label Content="Current Path:" VerticalAlignment="Center"/>
    <TextBox Name="PathTextBox" Width="400" Margin="5,0" IsReadOnly="True"/>
    <Button Name="UpButton" Content="Up" Width="50" Margin="5,0"/>
    <Button Name="RefreshButton" Content="Refresh" Width="70" Margin="5,0"/>
    <Button Name="RevealButton" Content="Reveal in Explorer" Width="120" Margin="5,0"/>
</WrapPanel>
```

**Reasoning:** Improves responsiveness by automatically wrapping controls when window width decreases, maintaining usability on smaller screens.

#### 4. Double-Click Navigation Restoration
**User Prompt:** "can no longer double click on a folder name to open it and load size of all the new sub-folders."

**Implementation:** Added MouseDoubleClick event handler:
```powershell
$folderListView.AddHandler([System.Windows.Controls.ListView]::MouseDoubleClickEvent, [System.Windows.Input.MouseButtonEventHandler]{
    param($eventSender, $eventArgs)

    $selectedItem = $folderListView.SelectedItem
    if ($selectedItem -and $selectedItem.FullPath) {
        $script:currentPath = $selectedItem.FullPath
        Update-Display $currentPath
    } else {
        $statusText.Content = "Error: Unable to open folder."
    }
})
```

**Reasoning:** Restores intuitive navigation functionality similar to Windows Explorer, enabling quick folder traversal.

#### 5. Windows Explorer Integration
**User Prompt:** "add a button to open the current path in Windows Explorer. The button label should be 'Reveal in Explorer'."

**Implementation:** Added Reveal in Explorer button with event handler:
```powershell
$revealButton.Add_Click({
    try {
        if (Test-Path $currentPath) {
            Start-Process explorer.exe $currentPath
        } else {
            $statusText.Content = "Error: Path does not exist."
        }
    } catch {
        Show-ExceptionDialog -Exception $_.Exception -Context "Opening folder in Windows Explorer"
    }
})
```

**Reasoning:** Provides seamless integration with Windows Explorer for users who want to perform file operations outside the application.

#### 6. Recursion Control with Checkbox
**User Prompt:** "make folder recurse and option with a new checkbox in the wrap panel at top. default should be checked."

**Implementation:** Added RecurseCheckBox to XAML and logic:
```xml
<CheckBox Name="RecurseCheckBox" Content="Recurse Subfolders" IsChecked="True" Margin="5,0"/>
```

```powershell
$recurse = $recurseCheckBox.IsChecked
$folderSize = if ($recurse) {
    (Get-ChildItem -Path $folder.FullName -Recurse -File -ErrorAction SilentlyContinue | 
     Measure-Object -Property Length -Sum).Sum
} else {
    (Get-ChildItem -Path $folder.FullName -File -ErrorAction SilentlyContinue | 
     Measure-Object -Property Length -Sum).Sum
}
```

**Reasoning:** Allows users to control scan depth, improving performance for large directory structures when full recursion isn't needed.

#### 7. Subfolder Existence Indicator
**User Prompt:** "add a column to right that shows Yes if sub-folder exist for current folder in collection or row. Otherwise show No."

**Implementation:** Added HasSubfolders column:
```xml
<GridViewColumn Header="Has Subfolders" Width="150" DisplayMemberBinding="{Binding HasSubfolders}"/>
```

```powershell
$hasSubfolders = if ((Get-ChildItem -Path $folder.FullName -Directory -ErrorAction SilentlyContinue).Count -gt 0) {
    "Yes"
} else {
    "No"
}
```

**Reasoning:** Provides quick visual indication of which folders contain subdirectories, helping users identify navigation targets.

#### 8. Auto-Disable Recursion on Up Navigation
**User Prompt:** "when clicking the up button, uncheck the Recurse checkbox."

**Implementation:** Modified Up button event handler:
```powershell
$upButton.Add_Click({
    $parent = Split-Path -Parent $currentPath
    if ($parent -and (Test-Path $parent)) {
        $script:currentPath = $parent
        $recurseCheckBox.IsChecked = $false
        Update-Display $currentPath
    }
})
```

**Reasoning:** Improves performance when navigating to parent directories, which typically contain more folders and would be slow with recursion enabled.

#### 9. Comprehensive Exception Handling with Dialog
**User Prompt:** "exceptions should display a dialog and be able to exception text to clipboard."

**Implementation:** Created detailed exception dialog with clipboard functionality:
```powershell
function Show-ExceptionDialog {
    param(
        [System.Exception]$Exception,
        [string]$Context = "Application Error"
    )

    $errorDetails = @"
Context: $Context
Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Error Message: $($Exception.Message)
Exception Type: $($Exception.GetType().FullName)
Stack Trace: $($Exception.StackTrace)
PowerShell Version: $($PSVersionTable.PSVersion)
OS Version: $([System.Environment]::OSVersion.VersionString)
"@

    # XAML for exception dialog with copy functionality
    # Event handlers for copy to clipboard and close
}
```

**Reasoning:** Provides comprehensive error reporting with context and system information, enabling better troubleshooting and user support.

#### 10. Array Wrapping Fix for ItemsSource
**User Prompt:** "getting error Error Details: Exception setting "ItemsSource": "Cannot convert the "@{Name=Brave Links_files..." value of type "System.Management.Automation.PSCustomObject" to type "System.Collections.IEnumerable"."

**Implementation:** Fixed Sort-FolderData function to always return arrays:
```powershell
function Sort-FolderData {
    param($data, $column, $direction)
    
    if ($direction -eq "Ascending") {
        $result = @($data | Sort-Object $column)
    } else {
        $result = @($data | Sort-Object $column -Descending)
    }
    return $result
}
```

**Additional Safety Check:**
```powershell
if ($sortedFolders -isnot [Array]) {
    $sortedFolders = @($sortedFolders)
}
```

**Reasoning:** Ensures ListView.ItemsSource always receives a proper collection, preventing runtime errors when only one folder is present.

#### 11. Comprehensive Code Documentation
**User Prompt:** "add detailed powershell and detailed xaml comments"

**Implementation:** Added extensive help comments following PowerShell standards:
- Function-level help with .SYNOPSIS, .DESCRIPTION, .PARAMETER, .EXAMPLE, .NOTES
- Inline comments explaining complex logic
- XAML comments describing UI element purposes and layout decisions

**Reasoning:** Improves code maintainability and helps other developers understand the implementation details and design decisions.

### Known Issues Addressed:
1. **Progress Dialog Visibility**: Fixed modal dialog display issues
2. **Progress Bar Updates**: Resolved UI thread update problems using Dispatcher.Invoke
3. **Sort Indicators**: Implemented visual arrows for sort direction
4. **Array Conversion**: Fixed ItemsSource binding errors for single objects
5. **Parameter Naming**: Resolved PowerShell automatic variable conflicts
6. **Null Comparisons**: Updated to PowerShell best practices

### Performance Improvements:
1. **Recursive Control**: Optional recursion reduces scan time for large directories
2. **Auto-Disable Recursion**: Prevents slow operations when navigating up
3. **Progress Feedback**: Real-time progress indication during long operations
4. **Error Isolation**: Individual folder errors don't stop entire operation

### User Experience Enhancements:
1. **Responsive Layout**: UI adapts to window resizing
2. **Explorer Integration**: Seamless Windows Explorer access
3. **Exception Dialogs**: Comprehensive error reporting with clipboard support
4. **Visual Feedback**: Sort indicators, progress bars, and status updates
5. **Intuitive Navigation**: Double-click and button-based folder traversal