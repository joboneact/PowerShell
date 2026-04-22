# WpfEdgeFieldReader.lap6.ps1
# Tue 4-21-2026 branched
#
# Sun 4-19-2026
# A WPF-based PowerShell 5.1 utility for extracting and managing form fields from Microsoft Edge

#requires -Version 5.1
<##
.SYNOPSIS
  WPF PowerShell 5.1 tool to read current Edge browser page fields.
.DESCRIPTION
  - Finds the active Microsoft Edge window.
  - Reads accessible form fields and inline text elements.
  - Shows field tag/name and value in a multi-select list.
  - Copies selected items to clipboard.
  - Displays the current selection in a RichTextBox.
.NOTES
  Run with STA mode:
    powershell.exe -STA -File .\EdgeFieldReader.ps1
##>

# ============================================================================
# Configuration and Setup
# ============================================================================
# Enable strict mode to catch undefined variables and other errors early
Set-StrictMode -Version Latest
# Stop execution on first error rather than continuing
$ErrorActionPreference = 'Stop'

# Validate that the script is running in STA (Single-Threaded Apartment) mode
# This is required for WPF and UI Automation to function properly
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne [System.Threading.ApartmentState]::STA) {
    throw 'This script must run in STA mode. Use: powershell.exe -STA -File .\EdgeFieldReader.ps1'
}

# ============================================================================
# Load Required .NET Assemblies
# ============================================================================
# WPF (Windows Presentation Foundation) framework for UI
Add-Type -AssemblyName PresentationFramework
# Core WPF types and functionality
Add-Type -AssemblyName PresentationCore
# Base WPF window and control types
Add-Type -AssemblyName WindowsBase
# UI Automation client library for reading UI elements (forms, fields, etc.)
Add-Type -AssemblyName UIAutomationClient
# UI Automation type definitions
Add-Type -AssemblyName UIAutomationTypes

# ============================================================================
# Win32 API Interop Definition
# ============================================================================
# Define P/Invoke methods to interact with Windows API for window management
# These allow us to find and identify the active Edge window process
$win32 = @"
using System;
using System.Runtime.InteropServices;
public static class Win32Api {
    // Get handle to the currently active (foreground) window
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    // Get the process ID associated with a specific window handle
    [DllImport("user32.dll")]
    public static extern int GetWindowThreadProcessId(IntPtr hWnd, out int lpdwProcessId);
}
"@
# Add the Win32Api class to the current PowerShell session, but only if it doesn't already exist
try {
    if (-not ([System.Management.Automation.PSTypeName]'Win32Api').Type) {
        Add-Type -TypeDefinition $win32 -PassThru | Out-Null
    }
} catch {
    # Type might already exist from a previous run, try to use it directly
    try {
        $null = [Win32Api]::GetForegroundWindow()
    } catch {
        throw "Failed to load Win32Api class: $($_.Exception.Message)"
    }
}

# ============================================================================
# Function: Write-Log
# ============================================================================
# Writes messages to the log console with timestamps
# Parameters: $message - Message to log
#            $level - Log level (Info, Warning, Error)
function Write-Log {
    param([string]$message, [string]$level = 'Info')
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $logEntry = "[$timestamp] [$level] $message"
    $logTextBox.AppendText("$logEntry`r`n")
    $logTextBox.ScrollToEnd()
    # Also update status for immediate feedback
    Update-Status $message
}

# ============================================================================
# Function: Get-AllEdgeWindows
# ============================================================================
# Finds all Microsoft Edge windows and their tabs
# Returns: Array of custom objects with window and tab information
function Get-AllEdgeWindows {
    Write-Log 'Scanning for all Edge windows and tabs...'
    $root = [System.Windows.Automation.AutomationElement]::RootElement
    $edgePids = Get-Process -Name msedge -ErrorAction SilentlyContinue | ForEach-Object { $_.Id }
    if (-not $edgePids) {
        Write-Log 'No Edge processes found' 'Warning'
        return @()
    }

    $windows = @()
    $childWindows = $root.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)
    
    foreach ($child in $childWindows) {
        if ($edgePids -contains $child.Current.ProcessId) {
            try {
                $windowTitle = $child.Current.Name
                Write-Log "Found Edge window: '$windowTitle'"
                
                # Try to find tabs within this window
                $tabCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::TabItem)
                $tabs = $child.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tabCondition)
                
                $tabList = @()
                if ($tabs.Count -gt 0) {
                    for ($i = 0; $i -lt $tabs.Count; $i++) {
                        $tab = $tabs[$i]
                        $tabName = $tab.Current.Name
                        if ($tabName -and $tabName.Trim()) {
                            $tabList += [PSCustomObject]@{
                                Name = $tabName.Trim()
                                Element = $tab
                                WindowElement = $child
                            }
                            Write-Log "  Tab: '$tabName'"
                        }
                    }
                } else {
                    # No tabs found, treat window as single tab
                    $tabList += [PSCustomObject]@{
                        Name = $windowTitle
                        Element = $child
                        WindowElement = $child
                    }
                }
                
                $windows += [PSCustomObject]@{
                    WindowTitle = $windowTitle
                    ProcessId = $child.Current.ProcessId
                    Element = $child
                    Tabs = $tabList
                }
            } catch {
                Write-Log "Error processing Edge window: $($_.Exception.Message)" 'Error'
            }
        }
    }
    
    Write-Log "Found $($windows.Count) Edge window(s) with $($windows | ForEach-Object { $_.Tabs.Count } | Measure-Object -Sum | Select-Object -ExpandProperty Sum) total tab(s)"
    return $windows
}

# ============================================================================
# Function: Get-ProcessIdFromHwnd
# ============================================================================
# Converts a window handle (HWND) to its associated process ID (PID)
# Parameters: $hwnd - Window handle to query
# Returns: Integer process ID
function Get-ProcessIdFromHwnd {
    param([IntPtr]$hwnd)
    $processId = 0
    try {
        # Call Win32 API to retrieve the process ID; use [ref] to pass by reference
        [Win32Api]::GetWindowThreadProcessId($hwnd, [ref]$processId) | Out-Null
        return $processId
    } catch {
        Write-Log "Error accessing Win32Api.GetWindowThreadProcessId: $($_.Exception.Message)" 'Error'
        return 0
    }
}

# ============================================================================
# Function: Convert-ToHtmlSafe
# ============================================================================
# Escapes special HTML characters in text to prevent HTML injection or rendering issues
# Parameters: $text - String to escape
# Returns: HTML-safe escaped string
function Convert-ToHtmlSafe {
    param([string]$text)
    # Return empty string if input is null or empty
    if (-not $text) { return '' }
    # Replace HTML special characters with their entity equivalents
    return $text.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;').Replace("'",'&#39;')
}

# ============================================================================
# Function: Get-ForegroundWindowHandle
# ============================================================================
# Returns the window handle (IntPtr) of the currently active/focused window
# This is used to detect if Edge is the active application
function Get-ForegroundWindowHandle {
    try {
        return [Win32Api]::GetForegroundWindow()
    } catch {
        Write-Log "Error accessing Win32Api.GetForegroundWindow: $($_.Exception.Message)" 'Error'
        return [IntPtr]::Zero
    }
}

# ============================================================================
# Function: Get-ActiveEdgeWindow
# ============================================================================
# Finds and returns the UI Automation element for the active Microsoft Edge window
# First checks if Edge is the foreground window, then falls back to searching all Edge processes
# Returns: AutomationElement for Edge window, or $null if not found
function Get-ActiveEdgeWindow {
    Write-Log 'Locating active Edge window...'
    try {
        # Get the root of the UI Automation tree
        $root = [System.Windows.Automation.AutomationElement]::RootElement
        
        # Strategy 1: Check if Edge is the currently active (foreground) window
        $foreground = Get-ForegroundWindowHandle
        if ($foreground -ne [IntPtr]::Zero) {
            $processId = Get-ProcessIdFromHwnd -hwnd $foreground
            if ($processId -gt 0) {
                try {
                    $proc = Get-Process -Id $processId -ErrorAction Stop
                    # If the foreground window is Edge, find it in the automation tree and return it
                    if ($proc.ProcessName -match '^msedge$') {
                        Write-Log "Found active Edge process (PID: $processId)"
                        $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $processId)
                        $window = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
                        if ($window) {
                            Write-Log "Active Edge window found: '$($window.Current.Name)'"
                            return $window
                        } else {
                            Write-Log 'Active Edge window not found in automation tree' 'Warning'
                        }
                    } else {
                        Write-Log "Foreground window is not Edge (process: $($proc.ProcessName))"
                    }
                } catch {
                    Write-Log "Error checking foreground process: $($_.Exception.Message)" 'Error'
                }
            }
        } else {
            Write-Log 'No foreground window detected'
        }

        # Strategy 2: Search for any running Edge process if it's not the foreground window
        Write-Log 'Searching for any Edge processes...'
        $edgePids = Get-Process -Name msedge -ErrorAction SilentlyContinue | ForEach-Object { $_.Id }
        if (-not $edgePids) {
            Write-Log 'No Edge processes running' 'Warning'
            return $null
        }

        Write-Log "Found $($edgePids.Count) Edge process(es): $($edgePids -join ', ')"
        
        # Search all top-level UI windows and match against Edge process IDs
        $childWindows = $root.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)
        foreach ($child in $childWindows) {
            if ($edgePids -contains $child.Current.ProcessId) {
                Write-Log "Found Edge window: '$($child.Current.Name)'"
                return $child
            }
        }
        
        Write-Log 'No accessible Edge windows found' 'Warning'
        return $null
    } catch {
        Write-Log "Error in Get-ActiveEdgeWindow: $($_.Exception.Message)" 'Error'
        return $null
    }
}

# ============================================================================
# Function: Get-ElementValue
# ============================================================================
# Extracts the text content or value from a UI Automation element
# Tries multiple patterns in order: ValuePattern (for inputs), TextPattern (for rich text), then element Name
# Parameters: $element - UI Automation element to extract value from
# Returns: String representation of the element's value or content
function Get-ElementValue {
    param([System.Windows.Automation.AutomationElement]$element)
    # Return empty string if element is null
    if (-not $element) { return '' }
    $value = ''

    # Method 1: Try ValuePattern (typically used by text input fields and controls)
    $valuePattern = $null
    if ($element.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern, [ref]$valuePattern)) {
        try { $value = $valuePattern.Current.Value } catch {}
    }

    # Method 2: If no value found, try TextPattern (used by text areas and rich text controls)
    if (-not $value) {
        $textPattern = $null
        if ($element.TryGetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern, [ref]$textPattern)) {
            try { 
                # Get full document text and trim null terminators
                $value = $textPattern.DocumentRange.GetText(-1).TrimEnd([char]0) 
            } catch {}
        }
    }

    # Method 3: Fallback to the element's Name property if no value was extracted
    if (-not $value) {
        $value = $element.Current.Name
    }

    # Ensure the result is a string type
    return $value -as [string]
}

# ============================================================================
# Function: Get-EdgePageInfo
# ============================================================================
# Reads the current page title and URL from the selected Edge window/tab.
# Uses the selected tab name as the preferred title and searches likely address
# bar controls for a URL-like value.
function Get-EdgePageInfo {
    param(
        [System.Windows.Automation.AutomationElement]$window,
        [string]$tabTitle = ''
    )

    $pageTitle = ''
    $pageUrl = ''

    if (-not $window) {
        return [PSCustomObject]@{
            Title = ''
            Url = ''
        }
    }

    if ($tabTitle -and $tabTitle.Trim()) {
        $pageTitle = $tabTitle.Trim()
    } elseif ($window.Current.Name) {
        $pageTitle = ($window.Current.Name -replace '\s+- Microsoft Edge$', '').Trim()
    }

    try {
        $editCondition = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            [System.Windows.Automation.ControlType]::Edit
        )
        $comboBoxCondition = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            [System.Windows.Automation.ControlType]::ComboBox
        )
        $documentCondition = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            [System.Windows.Automation.ControlType]::Document
        )
        $customCondition = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            [System.Windows.Automation.ControlType]::Custom
        )
        $urlCondition = New-Object System.Windows.Automation.OrCondition(
            $editCondition,
            $comboBoxCondition,
            $documentCondition,
            $customCondition
        )

        $candidates = $window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $urlCondition)
        for ($index = 0; $index -lt $candidates.Count; $index++) {
            $candidate = $candidates[$index]
            $candidateName = $candidate.Current.Name
            $automationId = $candidate.Current.AutomationId
            $value = (Get-ElementValue -element $candidate).Trim()

            if (-not $value) {
                continue
            }

            $looksLikeUrl = $value -match '^(https?|file|edge|about|chrome)://|^www\.'
            $looksLikeAddressBar = (($candidateName -match 'address|search') -or ($automationId -match 'address|search'))
            if ($looksLikeUrl -or $looksLikeAddressBar) {
                $pageUrl = $value
                break
            }
        }
    } catch {
        Write-Log "Unable to read page URL: $($_.Exception.Message)" 'Warning'
    }

    return [PSCustomObject]@{
        Title = $pageTitle
        Url = $pageUrl
    }
}

# ============================================================================
# Function: Update-CurrentPageInfo
# ============================================================================
# Updates the read-only title and URL controls from the selected Edge window/tab.
function Update-CurrentPageInfo {
    param(
        [System.Windows.Automation.AutomationElement]$window,
        [object]$selectedTab = $null
    )

    $tabTitle = ''
    if ($selectedTab -and $selectedTab.Tab -and $selectedTab.Tab.Name) {
        $tabTitle = $selectedTab.Tab.Name
    }

    $pageInfo = Get-EdgePageInfo -window $window -tabTitle $tabTitle
    $pageTitleTextBox.Text = $pageInfo.Title
    $pageUrlTextBox.Text = $pageInfo.Url
}

# ============================================================================
# Function: Get-EdgeFieldEntries
# ============================================================================
# Scans the active Edge window for all accessible form fields and text elements
# Creates custom objects containing field metadata (name, type, value, etc.)
# Returns: Array of PSCustomObjects sorted by field name and index
function Get-EdgeFieldEntries {
    param([System.Windows.Automation.AutomationElement]$window = $null)
    
    if (-not $window) {
        $window = Get-ActiveEdgeWindow
    }
    
    if (-not $window) {
        Write-Log 'No Edge window available for field scanning' 'Warning'
        return @()
    }

    Write-Log "Scanning window '$($window.Current.Name)' for form fields..."
    
    try {
        # Define conditions to search for specific control types:
        # Existing: Edit, Document, Image
        # Added: Text, Pane, Group, Custom, Hyperlink, Button, ComboBox, ListItem
        $editCondition      = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Edit)
        $documentCondition  = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Document)
        $imageCondition     = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Image)
        $textCondition      = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Text)
        $paneCondition      = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Pane)
        $groupCondition     = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Group)
        $customCondition    = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Custom)
        $hyperlinkCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Hyperlink)
        $buttonCondition    = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
        $comboBoxCondition  = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::ComboBox)
        $listItemCondition  = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::ListItem)

        # Combine conditions with OR logic
        $condition = New-Object System.Windows.Automation.OrCondition(
            $editCondition,
            $documentCondition,
            $imageCondition,
            $textCondition,
            $paneCondition,
            $groupCondition,
            $customCondition,
            $hyperlinkCondition,
            $buttonCondition,
            $comboBoxCondition,
            $listItemCondition
        )

        # Search recursively for all descendant elements matching the condition
        Write-Log 'Searching for form elements...'
        $items = $window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition)
        Write-Log "Found $($items.Count) potential form elements"
        Update-ScanProgress -Current 0 -Total $items.Count -Message "Loading element 0 of $($items.Count)"
        
        $list = @()
        
        # Process each found item and extract metadata
        for ($i = 0; $i -lt $items.Count; $i++) {
            try {
                $item = $items[$i]
            Update-ScanProgress -Current ($i + 1) -Total $items.Count
                # Extract UI element properties
                $name = $item.Current.Name
                $controlType = $item.Current.LocalizedControlType
                $automationId = $item.Current.AutomationId
                $className = $item.Current.ClassName
                
                $value = Get-ElementValue -element $item
                
                # Map UI control types to HTML-like tags for display
                $tag = switch ($controlType.ToLower()) {
                    'edit' { 'input' }
                    'document' { 'textarea' }
                    'image' { 'image' }
                    'text' { 'text' }
                    'pane' { 'div' }
                    'group' { 'div' }
                    'custom' { 'custom' }
                    'hyperlink' { 'a' }
                    'button' { 'button' }
                    'combo box' { 'select' }
                    'list item' { 'li' }
                    default { $controlType }
                }

                # Determine the best label/name for the field
                # Priority: element Name > automation ID > control type + class name
                $label = if ($name -and $name.Trim()) { $name.Trim() }
                         elseif ($automationId -and $automationId.Trim()) { $automationId.Trim() }
                         else { "[$tag] $className" }

                # Create display string and HTML-safe value
                $display = "[$tag] $label"
                $safeHtml = Convert-ToHtmlSafe -text $value

                # Add field entry to the list as a custom object
                $list += [PSCustomObject]@{
                    Index      = $i + 1
                    Tag        = $tag
                    FieldName  = $label
                    Value      = $value
                    HtmlValue  = $safeHtml
                    Display    = $display
                    RawElement = $item
                }
            } catch {
                Write-Log "Error processing element $i : $($_.Exception.Message)" 'Warning'
            }
        }

        # Return sorted list of fields (empty array if no fields found)
        if (-not $list) { 
            Write-Log 'No accessible form fields found' 'Warning'
            return @() 
        }
        
        $sortedList = $list | Sort-Object FieldName, Index
        Update-ScanProgress -Current $items.Count -Total $items.Count -Message "Loaded $($sortedList.Count) field(s) from $($items.Count) elements"
        Write-Log "Successfully processed $($sortedList.Count) form field(s)"
        return $sortedList
    } catch {
        Write-Log "Error scanning for form fields: $($_.Exception.Message)" 'Error'
        return @()
    }
}

# ============================================================================
# Function: Build-SelectionDocument
# ============================================================================
# Creates a formatted WPF FlowDocument (rich text document) displaying selected field entries
# Shows field names in bold followed by their values in a monospace font
# Parameters: $selectedItems - Collection of field objects to display
# Returns: FlowDocument suitable for display in a RichTextBox
function Build-SelectionDocument {
    param([System.Collections.IList]$selectedItems)
    # Create a new flow document with specified font and padding
    $document = New-Object System.Windows.Documents.FlowDocument
    $document.FontFamily = New-Object System.Windows.Media.FontFamily('Segoe UI')
    $document.PagePadding = New-Object System.Windows.Thickness(10)

    # Handle empty selection case
    if (-not $selectedItems -or $selectedItems.Count -eq 0) {
        $emptyParagraph = New-Object System.Windows.Documents.Paragraph
        $emptyParagraph.Inlines.Add((New-Object System.Windows.Documents.Run('No fields selected.')))
        $document.Blocks.Add($emptyParagraph)
        return $document
    }

    # Build document content for each selected item
    foreach ($item in $selectedItems) {
        # Add field name as bold text
        $labelParagraph = New-Object System.Windows.Documents.Paragraph
        $labelParagraph.Margin = New-Object System.Windows.Thickness(0, 0, 0, 2)
        $labelRun = New-Object System.Windows.Documents.Run("$($item.FieldName)`r`n")
        $labelRun.FontWeight = [System.Windows.FontWeights]::Bold
        $labelParagraph.Inlines.Add($labelRun)
        $document.Blocks.Add($labelParagraph)

        # Add field value in monospace font (Consolas) with bottom margin for spacing
        $valueParagraph = New-Object System.Windows.Documents.Paragraph
        $valueParagraph.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
        $valueRun = New-Object System.Windows.Documents.Run($item.Value)
        $valueRun.FontFamily = New-Object System.Windows.Media.FontFamily('Consolas')
        $valueParagraph.Inlines.Add($valueRun)
        $document.Blocks.Add($valueParagraph)
    }

    return $document
}

# ============================================================================
# Function: Get-SelectedTextForClipboard
# ============================================================================
# Formats selected field entries as plain text suitable for clipboard export
# Format: Field Name: followed by value on the next line, with blank lines between entries
# Parameters: $selectedItems - Collection of field objects to format
# Returns: Plain text string ready to copy to clipboard
function Get-SelectedTextForClipboard {
    param([System.Collections.IList]$selectedItems)
    # Return empty string if no items selected
    if (-not $selectedItems -or $selectedItems.Count -eq 0) { return '' }
    # Use StringBuilder for efficient string concatenation
    $builder = New-Object System.Text.StringBuilder
    foreach ($item in $selectedItems) {
        # Append field name as a label
        $builder.AppendLine("$($item.FieldName):") | Out-Null
        # Append field value
        $builder.AppendLine($item.Value) | Out-Null
        # Add blank line for spacing between entries
        $builder.AppendLine() | Out-Null
    }
    # Return formatted text with trailing whitespace removed
    return $builder.ToString().TrimEnd()
}

# ============================================================================
# XAML UI Definition
# ============================================================================
# WPF window layout with six main sections:
# 1. Top: Buttons for Refresh and Copy, plus status text
# 2. Tab/Window selector listbox
# 3. Middle: ListBox showing discovered Edge form fields
# 4. Preview label
# 5. RichTextBox displaying preview of selected fields
# 6. Log console at bottom
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Edge Browser Field Reader"
        Width="950"
        Height="800"
        MinWidth="780"
        MinHeight="620"
        WindowStartupLocation="CenterScreen"
        Background="#FFF2F5FB">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="2*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="120"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <StackPanel Grid.Row="0" Margin="0,0,0,10">
            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                <Button x:Name="RefreshButton" Content="Refresh Edge Fields" Width="160" Height="32" Margin="0,0,10,0"/>
                <Button x:Name="CopyButton" Content="Copy Selected" Width="120" Height="32" Margin="0,0,10,0"/>
                <Button x:Name="CopyLogButton" Content="Copy Log" Width="100" Height="32" Margin="0,0,10,0"/>
                <TextBox x:Name="StatusText" IsReadOnly="True" BorderThickness="0" Background="Transparent" VerticalAlignment="Center" FontSize="12" Foreground="#FF2B2B2B"/>
            </StackPanel>
            <ProgressBar x:Name="BusyProgressBar" Height="8" Margin="0,8,0,0" Minimum="0" Maximum="100" Value="0" IsIndeterminate="True" Visibility="Collapsed"/>
        </StackPanel>

        <Border Grid.Row="1" Background="White" BorderBrush="#FFB0C4DE" BorderThickness="1" CornerRadius="6" Padding="10" Margin="0,0,0,10">
            <StackPanel>
                <TextBlock Text="Edge windows and tabs" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                <ListBox x:Name="WindowsTabsListBox" Height="80" DisplayMemberPath="DisplayName"/>
            </StackPanel>
        </Border>

        <Border Grid.Row="2" Background="White" BorderBrush="#FFB0C4DE" BorderThickness="1" CornerRadius="6" Padding="10">
            <StackPanel>
                <TextBlock Text="Current page title" FontSize="12" FontWeight="SemiBold" Margin="0,0,0,4"/>
                <TextBox x:Name="PageTitleTextBox" IsReadOnly="True" Margin="0,0,0,8" Background="#FFF8F8F8" BorderBrush="#FFD6DCE5"/>
                <TextBlock Text="Current page URL" FontSize="12" FontWeight="SemiBold" Margin="0,0,0,4"/>
                <TextBox x:Name="PageUrlTextBox" IsReadOnly="True" Margin="0,0,0,10" Background="#FFF8F8F8" BorderBrush="#FFD6DCE5" TextWrapping="Wrap" MinHeight="48"/>
                <TextBlock Text="Edge Web Page Fields:" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                <WrapPanel Margin="0,0,0,8">
                    <CheckBox x:Name="GraphicsCheckBox" Content="Graphics" IsChecked="False" Margin="0,0,10,0"/>
                    <CheckBox x:Name="TextAreasCheckBox" Content="Text Areas" IsChecked="True" Margin="0,0,10,0"/>
                    <CheckBox x:Name="TextCheckBox" Content="Text" IsChecked="True" Margin="0,0,10,0"/>
                    <CheckBox x:Name="ListItemsCheckBox" Content="List Items" IsChecked="True" Margin="0,0,10,0"/>
                    <CheckBox x:Name="OtherTypesCheckBox" Content="Other Types" IsChecked="True"/>
                </WrapPanel>
                <ListBox x:Name="FieldsListBox" SelectionMode="Extended" Height="280" DisplayMemberPath="Display"/>
            </StackPanel>
        </Border>

        <TextBlock Grid.Row="3" Text="Current selection preview" FontSize="13" FontWeight="SemiBold" Margin="0,10,0,6"/>

        <Border Grid.Row="4" Background="White" BorderBrush="#FFB0C4DE" BorderThickness="1" CornerRadius="6" Padding="8">
            <RichTextBox x:Name="SelectionRichText" IsReadOnly="True" VerticalScrollBarVisibility="Auto"/>
        </Border>

        <Border Grid.Row="5" Background="White" BorderBrush="#FFB0C4DE" BorderThickness="1" CornerRadius="6" Padding="8" Margin="0,10,0,0">
            <StackPanel>
                <TextBlock Text="Log Console" FontSize="13" FontWeight="SemiBold" Margin="0,0,0,6"/>
                <TextBox x:Name="LogTextBox" IsReadOnly="True" VerticalScrollBarVisibility="Auto" FontFamily="Consolas" FontSize="10" Background="#FFF8F8F8"/>
            </StackPanel>
        </Border>
    </Grid>
</Window>
'@

# ============================================================================
# XAML Compilation and UI Element References
# ============================================================================
# Parse XAML string and create WPF window instance
[xml]$xamlXml = $xaml
$reader = New-Object System.Xml.XmlNodeReader $xamlXml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get references to named UI elements for event binding and manipulation
$refreshButton = $window.FindName('RefreshButton')
$copyButton = $window.FindName('CopyButton')
$copyLogButton = $window.FindName('CopyLogButton')
$windowsTabsListBox = $window.FindName('WindowsTabsListBox')
$fieldsListBox = $window.FindName('FieldsListBox')
$selectionRichText = $window.FindName('SelectionRichText')
$pageTitleTextBox = $window.FindName('PageTitleTextBox')
$pageUrlTextBox = $window.FindName('PageUrlTextBox')
$statusText = $window.FindName('StatusText')
$logTextBox = $window.FindName('LogTextBox')
$busyProgressBar = $window.FindName('BusyProgressBar')
$graphicsCheckBox = $window.FindName('GraphicsCheckBox')
$textAreasCheckBox = $window.FindName('TextAreasCheckBox')
$textCheckBox = $window.FindName('TextCheckBox')
$listItemsCheckBox = $window.FindName('ListItemsCheckBox')
$otherTypesCheckBox = $window.FindName('OtherTypesCheckBox')

<#
.SYNOPSIS
    Registers event handlers for the graphics checkbox control.

.DESCRIPTION
    Attaches event handlers to the graphics checkbox that trigger the Update-FieldsList function
    whenever the checkbox state changes. This allows the field list to be dynamically filtered
    based on whether graphics (image) elements should be displayed.

.NOTES
    - The condition checks if $graphicsCheckBox exists before attempting to bind events
    - Both Checked and Unchecked events call the same Update-FieldsList function
    - This ensures the filtered view is immediately updated when the user toggles the checkbox
    - Similar event binding patterns are used for $textAreasCheckBox and $otherTypesCheckBox
#>
if ($graphicsCheckBox) {
    $graphicsCheckBox.Add_Checked({ Update-FieldsList })
    $graphicsCheckBox.Add_Unchecked({ Update-FieldsList })
}
if ($textAreasCheckBox) {
    $textAreasCheckBox.Add_Checked({ Update-FieldsList })
    $textAreasCheckBox.Add_Unchecked({ Update-FieldsList })
}
if ($textCheckBox) {
    $textCheckBox.Add_Checked({ Update-FieldsList })
    $textCheckBox.Add_Unchecked({ Update-FieldsList })
}
if ($listItemsCheckBox) {
    $listItemsCheckBox.Add_Checked({ Update-FieldsList })
    $listItemsCheckBox.Add_Unchecked({ Update-FieldsList })
}
if ($otherTypesCheckBox) {
    $otherTypesCheckBox.Add_Checked({ Update-FieldsList })
    $otherTypesCheckBox.Add_Unchecked({ Update-FieldsList })
}

# Script-scoped variables to store discovered Edge field entries and window/tab data (persistent during session)
$script:EdgeFieldEntries = @()
$script:EdgeWindows = @()
$script:CurrentWindow = $null

# ============================================================================
# Function: Update-Status
# ============================================================================
# Updates the status text in the UI window
# Uses Dispatcher to ensure thread-safe UI updates
function Update-Status {
    param([string]$message)
    try {
        if ($window.Dispatcher.CheckAccess()) {
            $statusText.Text = $message
        } else {
            $window.Dispatcher.Invoke([Action[string]] { param($msg) $statusText.Text = $msg }, $message)
        }
    } catch {
        # If Dispatcher not available, set directly
        $statusText.Text = $message
    }
}

function Invoke-UiRefresh {
    try {
        $null = $window.Dispatcher.Invoke(
            [System.Windows.Threading.DispatcherPriority]::Render,
            [Action]{}
        )
    } catch {
        # Ignore repaint failures; they should not stop the scan.
    }
}

function Set-BusyState {
    param(
        [bool]$IsBusy,
        [string]$Message = ''
    )

    if ($Message) {
        Update-Status $Message
    }

    [System.Windows.Input.Mouse]::OverrideCursor = if ($IsBusy) { [System.Windows.Input.Cursors]::Wait } else { $null }
    $window.Cursor = $null
    $refreshButton.IsEnabled = -not $IsBusy
    $copyButton.IsEnabled = -not $IsBusy
    $copyLogButton.IsEnabled = -not $IsBusy
    $windowsTabsListBox.IsEnabled = -not $IsBusy
    $fieldsListBox.IsEnabled = -not $IsBusy
    $graphicsCheckBox.IsEnabled = -not $IsBusy
    $textAreasCheckBox.IsEnabled = -not $IsBusy
    $textCheckBox.IsEnabled = -not $IsBusy
    $listItemsCheckBox.IsEnabled = -not $IsBusy
    $otherTypesCheckBox.IsEnabled = -not $IsBusy
    $busyProgressBar.Visibility = if ($IsBusy) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    $busyProgressBar.IsIndeterminate = $IsBusy
    $busyProgressBar.Minimum = 0
    $busyProgressBar.Maximum = 100
    $busyProgressBar.Value = 0

    Invoke-UiRefresh
}

function Update-ScanProgress {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Message = ''
    )

    if ($Total -le 0) {
        $busyProgressBar.IsIndeterminate = $true
        $busyProgressBar.Minimum = 0
        $busyProgressBar.Maximum = 100
        $busyProgressBar.Value = 0
        if ($Message) {
            Update-Status $Message
        }
        Invoke-UiRefresh
        return
    }

    $safeCurrent = [Math]::Min([Math]::Max($Current, 0), $Total)
    $busyProgressBar.IsIndeterminate = $false
    $busyProgressBar.Minimum = 0
    $busyProgressBar.Maximum = $Total
    $busyProgressBar.Value = $safeCurrent

    if (-not $Message) {
        $Message = "Loading element $safeCurrent of $Total"
    }

    Update-Status $Message

    if ($safeCurrent -eq 0 -or $safeCurrent -eq $Total -or ($safeCurrent % 10) -eq 0) {
        Invoke-UiRefresh
    }
}

# ============================================================================
# Function: Update-WindowsTabsList
# ============================================================================
# Populates the windows and tabs listbox with all available Edge windows and tabs
function Update-WindowsTabsList {
    Write-Log 'Updating windows and tabs list...'
    try {
        $script:EdgeWindows = Get-AllEdgeWindows
        if (-not $script:EdgeWindows -or $script:EdgeWindows.Count -eq 0) {
            $windowsTabsListBox.ItemsSource = $null
            $windowsTabsListBox.SelectedIndex = -1
            Write-Log 'No Edge windows found' 'Warning'
            return
        }

        $displayItems = @()
        foreach ($edgeWin in $script:EdgeWindows) {
            foreach ($tab in $edgeWin.Tabs) {
                $displayItems += [PSCustomObject]@{
                    DisplayName = "$($edgeWin.WindowTitle) - $($tab.Name)"
                    Window = $edgeWin
                    Tab = $tab
                    Element = $tab.WindowElement
                }
            }
        }
        
        $windowsTabsListBox.ItemsSource = $displayItems
        if ($displayItems.Count -gt 0 -and $windowsTabsListBox.SelectedIndex -lt 0) {
            $windowsTabsListBox.SelectedIndex = 0
        }
        Invoke-UiRefresh
        Write-Log "Populated list with $($displayItems.Count) window/tab combinations"
    } catch {
        Write-Log "Error updating windows/tabs list: $($_.Exception.Message)" 'Error'
    }
}

# ============================================================================
# Function: Update-Fields
# ============================================================================
# Refreshes the list of Edge form fields by calling Get-EdgeFieldEntries
# Updates UI to display found fields or error message
# Clears the selection preview
function Update-Fields {
    try {
        Set-BusyState -IsBusy $true -Message 'Loading Edge windows and fields...'

        # Update the windows/tabs list first
        Update-WindowsTabsList
        
        # Determine which window to scan
        $targetWindow = $script:CurrentWindow
        if (-not $targetWindow) {
            $selectedListItem = $windowsTabsListBox.SelectedItem
            if ($selectedListItem) {
                Write-Log "Using selected window/tab: $($selectedListItem.DisplayName)"
                $targetWindow = $selectedListItem.Element
                $script:CurrentWindow = $targetWindow
            } else {
                Write-Log 'No specific window selected, using active window'
                $targetWindow = Get-ActiveEdgeWindow
                $script:CurrentWindow = $targetWindow
            }
        }
        
        if (-not $targetWindow) {
            $fieldsListBox.ItemsSource = $null
            Update-CurrentPageInfo -window $null
            Write-Log 'No Edge window available for field scanning' 'Warning'
            $selectionRichText.Document = Build-SelectionDocument @()
            return
        }

        Update-CurrentPageInfo -window $targetWindow -selectedTab $windowsTabsListBox.SelectedItem

        # Update window title in the UI
        $windowTitle = $targetWindow.Current.Name
        if ($windowTitle) {
            $window.Title = "Edge Browser Field Reader - $windowTitle"
        }

        # Scan the target window for accessible form fields
        $script:EdgeFieldEntries = Get-EdgeFieldEntries -window $targetWindow
        if (-not $script:EdgeFieldEntries -or $script:EdgeFieldEntries.Count -eq 0) {
            # No fields found - clear the list and show message
            $fieldsListBox.ItemsSource = $null
            Write-Log 'No accessible Edge fields found. Make sure Edge is open and the page is active.' 'Warning'
            $selectionRichText.Document = Build-SelectionDocument @()
            return
        }

        # Display found fields in the ListBox (filtered)
        Update-FieldsList
        Write-Log "Found $($script:EdgeFieldEntries.Count) field(s) in Edge. Select one or more items."
        # Clear the preview since no items are yet selected
        $selectionRichText.Document = Build-SelectionDocument @()
    } catch {
        # Catch and display any errors
        $fieldsListBox.ItemsSource = $null
        Write-Log "Error reading Edge fields: $($_.Exception.Message)" 'Error'
    } finally {
        Set-BusyState -IsBusy $false
    }
}

# ============================================================================
# Function: Update-SelectionPreview
# ============================================================================
# Updates the preview panel (RichTextBox) with the currently selected fields
# Called whenever the selection in the ListBox changes
function Update-SelectionPreview {
    # Get the current selection from the ListBox (as array for consistency)
    $selectedItems = @($fieldsListBox.SelectedItems)
    # Build and display formatted document with selected field details
    $selectionRichText.Document = Build-SelectionDocument -selectedItems $selectedItems
    # Update status to show number of selected items
    Update-Status "Selected $($selectedItems.Count) item(s)."
}

# ============================================================================
# Function: Update-FieldsList
# ============================================================================
# Filters the Edge field entries based on the checkbox states and updates the ListBox
function Update-FieldsList {
    if (-not $script:EdgeFieldEntries) {
        $fieldsListBox.ItemsSource = $null
        return
    }
    $filtered = @($script:EdgeFieldEntries | Where-Object {
        # Determine the field type based on the Tag property and apply filters according to checkbox states
        $tag = $_.Tag
        (($tag -eq 'image')    -and $graphicsCheckBox   -and $graphicsCheckBox.IsChecked)   -or
        (($tag -eq 'textarea') -and $textAreasCheckBox  -and $textAreasCheckBox.IsChecked)  -or
        (($tag -eq 'text')     -and $textCheckBox       -and $textCheckBox.IsChecked)       -or
        (($tag -eq 'li')       -and $listItemsCheckBox  -and $listItemsCheckBox.IsChecked)  -or
        (($tag -notin @('image','textarea','text','li')) -and $otherTypesCheckBox -and $otherTypesCheckBox.IsChecked)
    })
    $fieldsListBox.ItemsSource = $filtered
    Write-Log "Filtered fields: $($filtered.Count) shown"
}

# ============================================================================
# Event Handler Registrations
# ============================================================================
# Refresh button: Scan for Edge fields when clicked
$refreshButton.Add_Click({
    Write-Log 'Refresh button clicked'
    Update-Fields
})

# Copy button: Export selected fields to clipboard
$copyButton.Add_Click({
    Write-Log 'Copy button clicked'
    $selectedItems = @($fieldsListBox.SelectedItems)
    # Validate that items are selected
    if (-not $selectedItems -or $selectedItems.Count -eq 0) {
        Write-Log 'No items selected to copy' 'Warning'
        return
    }
    # Format selected items as plain text
    $text = Get-SelectedTextForClipboard -selectedItems $selectedItems
    if ($text) {
        # Copy formatted text to system clipboard
        [System.Windows.Clipboard]::SetText($text)
        Write-Log "Copied $($selectedItems.Count) selected item(s) to clipboard"
    } else {
        Write-Log 'Failed to format text for clipboard' 'Warning'
    }
})

# Copy Log button: Copy the entire log to clipboard
$copyLogButton.Add_Click({
    Write-Log 'Copy Log button clicked'
    $logText = $logTextBox.Text
    if ($logText) {
        [System.Windows.Clipboard]::SetText($logText)
        Write-Log 'Log copied to clipboard'
    } else {
        Write-Log 'No log content to copy' 'Warning'
    }
})

# Windows/Tabs listbox selection changed: Load fields for selected window/tab
$windowsTabsListBox.Add_SelectionChanged({
    $selectedItem = $windowsTabsListBox.SelectedItem
    if ($selectedItem) {
        Write-Log "Selected window/tab: $($selectedItem.DisplayName)"
        $script:CurrentWindow = $selectedItem.Element
        Update-CurrentPageInfo -window $script:CurrentWindow -selectedTab $selectedItem
        # Automatically refresh fields for the selected window/tab
        Update-Fields
    }
})

# Fields listbox selection changed: Update the preview pane with selected items
$fieldsListBox.Add_SelectionChanged({ 
    $selectedItems = @($fieldsListBox.SelectedItems)
    $selectionRichText.Document = Build-SelectionDocument -selectedItems $selectedItems
    Write-Log "Selected $($selectedItems.Count) field item(s)"
})

# ============================================================================
# Additional Event Handlers and Main Execution
# ============================================================================
# Window activated: Auto-scan fields when window is activated if none were loaded yet
$window.Add_Activated({
    if (-not $script:EdgeFieldEntries -or $script:EdgeFieldEntries.Count -eq 0) {
        Write-Log 'Window activated - initializing scan'
        Update-Fields
    }
})

# Initialize the log console and UI elements
Write-Log 'Edge Browser Field Reader initialized'
Update-CurrentPageInfo -window $null
$selectionRichText.Document = Build-SelectionDocument @()

# Display the window as a modal dialog (blocks until window is closed)
$window.ShowDialog() | Out-Null
