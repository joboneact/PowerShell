# WpfEdgeFieldReader - Detailed Documentation Log

**Generated:** April 20, 2026  
**Purpose:** Formatted documentation of the WpfEdgeFieldReader.ps1 script with comprehensive inline comments

---

## Overview

This log contains a fully commented version of the **WpfEdgeFieldReader.ps1** script, a WPF-based PowerShell 5.1 utility for extracting and managing form fields from Microsoft Edge browser.

---

## Complete Annotated Script

```powershell
# WpfEdgeFieldReader.ps1
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
# Add the Win32Api class to the current PowerShell session
Add-Type -TypeDefinition $win32 -PassThru | Out-Null

# ============================================================================
# Function: Get-ForegroundWindowHandle
# ============================================================================
# Returns the window handle (IntPtr) of the currently active/focused window
# This is used to detect if Edge is the active application
function Get-ForegroundWindowHandle {
    return [NativeMethods.Win32Api]::GetForegroundWindow()
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
    # Call Win32 API to retrieve the process ID; use [ref] to pass by reference
    [NativeMethods.Win32Api]::GetWindowThreadProcessId($hwnd, [ref]$processId) | Out-Null
    return $processId
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
# Function: Get-ActiveEdgeWindow
# ============================================================================
# Finds and returns the UI Automation element for the active Microsoft Edge window
# First checks if Edge is the foreground window, then falls back to searching all Edge processes
# Returns: AutomationElement for Edge window, or $null if not found
function Get-ActiveEdgeWindow {
    # Get the root of the UI Automation tree
    $root = [System.Windows.Automation.AutomationElement]::RootElement
    
    # Strategy 1: Check if Edge is the currently active (foreground) window
    $foreground = Get-ForegroundWindowHandle
    if ($foreground -ne [IntPtr]::Zero) {
        $processId = Get-ProcessIdFromHwnd -hwnd $foreground
        try {
            $proc = Get-Process -Id $processId -ErrorAction Stop
            # If the foreground window is Edge, find it in the automation tree and return it
            if ($proc.ProcessName -match '^msedge$') {
                $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $processId)
                $window = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
                if ($window) { return $window }
            }
        } catch {
            # Silently continue if process lookup fails
        }
    }

    # Strategy 2: Search for any running Edge process if it's not the foreground window
    $edgePids = Get-Process -Name msedge -ErrorAction SilentlyContinue | ForEach-Object { $_.Id }
    if (-not $edgePids) { return $null }

    # Search all top-level UI windows and match against Edge process IDs
    $childWindows = $root.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)
    foreach ($child in $childWindows) {
        if ($edgePids -contains $child.Current.ProcessId) {
            return $child
        }
    }
    return $null
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
# Function: Get-EdgeFieldEntries
# ============================================================================
# Scans the active Edge window for all accessible form fields and text elements
# Creates custom objects containing field metadata (name, type, value, etc.)
# Returns: Array of PSCustomObjects sorted by field name and index
function Get-EdgeFieldEntries {
    # Locate the active Edge window in the UI Automation tree
    $window = Get-ActiveEdgeWindow
    if (-not $window) {
        return @()
    }

    # Define conditions to search for specific control types:
    # Edit = text input fields, Document = text areas, Image = image elements
    $editCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Edit)
    $documentCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Document)
    $imageCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Image)
    # Combine conditions with OR logic (match any of the three types)
    $condition = New-Object System.Windows.Automation.OrCondition($editCondition, $documentCondition, $imageCondition)

    # Search recursively for all descendant elements matching the condition
    $items = $window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition)
    $list = @()
    
    # Process each found item and extract metadata
    for ($i = 0; $i -lt $items.Count; $i++) {
        $item = $items[$i]
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
    }

    # Return sorted list of fields (empty array if no fields found)
    if (-not $list) { return @() }
    return $list | Sort-Object FieldName, Index
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
# WPF window layout with three main sections:
# 1. Top: Buttons for Refresh and Copy, plus status text
# 2. Middle: ListBox showing discovered Edge form fields
# 3. Bottom: RichTextBox displaying preview of selected fields
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Edge Browser Field Reader"
        Width="950"
        Height="700"
        MinWidth="780"
        MinHeight="520"
        WindowStartupLocation="CenterScreen"
        Background="#FFF2F5FB">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="2*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <StackPanel Grid.Row="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,0,10">
            <Button x:Name="RefreshButton" Content="Refresh Edge Fields" Width="160" Height="32" Margin="0,0,10,0"/>
            <Button x:Name="CopyButton" Content="Copy Selected" Width="120" Height="32" Margin="0,0,10,0"/>
            <TextBlock x:Name="StatusText" VerticalAlignment="Center" FontSize="12" Foreground="#FF2B2B2B"/> 
        </StackPanel>

        <Border Grid.Row="1" Background="White" BorderBrush="#FFB0C4DE" BorderThickness="1" CornerRadius="6" Padding="10">
            <StackPanel>
                <TextBlock Text="Edge page fields" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                <ListBox x:Name="FieldsListBox" SelectionMode="Extended" Height="320" DisplayMemberPath="Display"/>
            </StackPanel>
        </Border>

        <TextBlock Grid.Row="2" Text="Current selection preview" FontSize="13" FontWeight="SemiBold" Margin="0,10,0,6"/>

        <Border Grid.Row="3" Background="White" BorderBrush="#FFB0C4DE" BorderThickness="1" CornerRadius="6" Padding="8">
            <RichTextBox x:Name="SelectionRichText" IsReadOnly="True" VerticalScrollBarVisibility="Auto"/>
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
$fieldsListBox = $window.FindName('FieldsListBox')
$selectionRichText = $window.FindName('SelectionRichText')
$statusText = $window.FindName('StatusText')

# Script-scoped variable to store discovered Edge field entries (persistent during session)
$script:EdgeFieldEntries = @()

# ============================================================================
# Function: Update-Status
# ============================================================================
# Updates the status text in the UI window
# Uses Dispatcher to ensure thread-safe UI updates
function Update-Status {
    param([string]$message)
    $statusText.Text = $message
    # Invoke on the UI thread to ensure safe updates
    $window.Dispatcher.Invoke([action]{} )
}

# ============================================================================
# Function: Update-Fields
# ============================================================================
# Refreshes the list of Edge form fields by calling Get-EdgeFieldEntries
# Updates UI to display found fields or error message
# Clears the selection preview
function Update-Fields {
    try {
        Update-Status 'Locating active Edge window...'
        # Scan the active Edge window for accessible form fields
        $script:EdgeFieldEntries = Get-EdgeFieldEntries
        if (-not $script:EdgeFieldEntries -or $script:EdgeFieldEntries.Count -eq 0) {
            # No fields found - clear the list and show message
            $fieldsListBox.ItemsSource = $null
            Update-Status 'No accessible Edge fields found. Make sure Edge is open and the page is active.'
            $selectionRichText.Document = Build-SelectionDocument @()
            return
        }

        # Display found fields in the ListBox
        $fieldsListBox.ItemsSource = $script:EdgeFieldEntries
        Update-Status "Found $($script:EdgeFieldEntries.Count) field(s) in Edge. Select one or more items."
        # Clear the preview since no items are yet selected
        $selectionRichText.Document = Build-SelectionDocument @()
    } catch {
        # Catch and display any errors
        $fieldsListBox.ItemsSource = $null
        Update-Status "Error reading Edge fields: $($_.Exception.Message)"
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
# Event Handler Registrations
# ============================================================================
# Refresh button: Scan for Edge fields when clicked
$refreshButton.Add_Click({ Update-Fields })

# Copy button: Export selected fields to clipboard
$copyButton.Add_Click({
    $selectedItems = @($fieldsListBox.SelectedItems)
    # Validate that items are selected
    if (-not $selectedItems -or $selectedItems.Count -eq 0) {
        Update-Status 'No items selected to copy.'
        return
    }
    # Format selected items as plain text
    $text = Get-SelectedTextForClipboard -selectedItems $selectedItems
    if ($text) {
        # Copy formatted text to system clipboard
        [System.Windows.Clipboard]::SetText($text)
        Update-Status "Copied $($selectedItems.Count) selected item(s) to clipboard."
    }
})

# ListBox selection changed: Update the preview pane with selected items
$fieldsListBox.Add_SelectionChanged({ Update-SelectionPreview })

# ============================================================================
# Additional Event Handlers and Main Execution
# ============================================================================
# Window activated: Auto-scan fields when window is activated if none were loaded yet
$window.Add_Activated({
    if (-not $script:EdgeFieldEntries -or $script:EdgeFieldEntries.Count -eq 0) {
        Update-Fields
    }
})

# Initialize the preview pane with an empty document
$selectionRichText.Document = Build-SelectionDocument @()

# Display the window as a modal dialog (blocks until window is closed)
$window.ShowDialog() | Out-Null
```

---

## Recent Updates (April 20, 2026 - Filter Addition)

### New Features Added

1. **Field Type Filter**: Added checkboxes above the fields listbox to filter displayed fields by type:
   - **Graphics**: Shows/hides image elements ([image] tags)
   - **Text Areas**: Shows/hides textarea elements ([textarea] tags)
   - **Other Types**: Shows/hides input fields and any other element types ([input] and others)
   - By default, only "Other Types" (input fields) are checked and visible
   - All checkboxes unchecked by default except "Other Types"
   - Dynamic filtering: checking/unchecking immediately updates the fields list
   - Selection is cleared when filter changes to avoid showing hidden items

2. **Enhanced Fields List Management**:
   - New `Update-FieldsList` function handles filtering logic
   - Filters based on element tags: 'image', 'textarea', or other
   - Maintains selection preview consistency when filtering

### UI Layout Changes

- Added a `WrapPanel` with three `CheckBox` controls between the "Edge page fields" TextBlock and the FieldsListBox
- Checkboxes are horizontally arranged for compact display

### New Functions Added

- `Update-FieldsList`: Filters and updates the fields ListBox based on checkbox states

### Enhanced Functions

- `Update-Fields`: Now calls `Update-FieldsList` instead of directly setting ItemsSource
- Added event handlers for checkbox Checked/Unchecked events to trigger filtering

### Technical Improvements

- **Dynamic Filtering**: Real-time UI updates when filter options change
- **Selection Management**: Automatic clearing of selection when items are filtered out
- **Preview Synchronization**: Selection preview updates automatically after filtering

---

## Usage Instructions

Run with STA mode (required for WPF):
```powershell
powershell.exe -STA -File .\WpfEdgeFieldReader.ps1
```

### New Workflow:
1. Launch the application
2. The log console shows initialization and scanning progress
3. Select a window/tab from the "Edge windows and tabs" list
4. Fields are automatically loaded for the selected window/tab
5. Select fields and use "Copy Selected" to export to clipboard
6. Use "Refresh Edge Fields" to rescan the current window/tab
7. Monitor all operations in the log console

---

**End of Recent Updates**

---

## UI Locking Issue Resolution (April 20, 2026)

The UI locking issue has been addressed by adding safety checks to prevent null reference exceptions when accessing the checkbox properties. The event handlers are now only added if the controls are successfully found, and the filtering logic safely handles cases where controls might be null.

The updated script should now allow clicking on the checkboxes and the fields listbox without the UI freezing. The checkboxes will dynamically filter the displayed fields based on their type (Graphics for images, Text Areas for textareas, Other Types for inputs), with "Other Types" checked by default to show input fields initially. If no fields are present (e.g., Edge not running), the listbox will be empty but still interactive, and the checkboxes will be functional for future filtering when fields are loaded.

---

## Recent Updates (April 21, 2026 - Expanded Edge Field Discovery)

### Summary

Expanded UI Automation discovery and tag mapping so more webpage content is captured, especially content exposed as non-form UIA controls.

### Why This Change Was Needed

The previous scanner only searched for three UIA control types:
- Edit
- Document
- Image

Many visible webpage elements in Edge are surfaced as other control types (for example, Text, Pane, Group, or Custom), so they did not appear in the field list.

### Scanner Expansion

The discovery condition now includes these additional UIA control types:
- Text
- Pane
- Group
- Custom
- Hyperlink
- Button
- ComboBox
- ListItem

### Tag Mapping Expansion

UIA control types are now mapped to more useful HTML-like tags:
- pane, group -> div
- text -> text
- hyperlink -> a
- button -> button
- combo box -> select
- list item -> li
- custom -> custom

Existing mappings are preserved:
- edit -> input
- document -> textarea
- image -> image

### Selected Tab Scan Improvement

When a tab is selected from the windows/tabs list, the scan target now uses the tab's parent window element instead of the tab item element. This improves coverage because Edge content is not always exposed under the TabItem subtree.

### Expected Result

- More visible page text and structure is discovered.
- Fewer missing entries on modern websites.
- Better consistency when switching between tabs and windows.

### Checkbox Filter Update Summary

Four changes made:
- XAML: Added `TextCheckBox` ("Text") and `ListItemsCheckBox` ("List Items"), both `IsChecked="True"`; also set `TextAreasCheckBox` to `IsChecked="True"`
- Variable references: Added `$textCheckBox` and `$listItemsCheckBox` bindings
- Event handlers: Registered `Checked`/`Unchecked` for both new checkboxes
- Filter logic: Added separate conditions for `text` and `li` tags; `Other Types` now excludes all four explicit types (`image`, `textarea`, `text`, `li`)

### Busy State And Top List Update

Updated `WpfEdgeFieldReader.lap6.ps1` to show a busy state while scans run: the window now switches to a wait cursor, an indeterminate progress bar appears under the top buttons, and the main interactive controls are temporarily disabled during loading.

I also changed the windows/tabs refresh path so the top listbox is populated and explicitly repainted before the expensive field scan continues, and it now auto-selects the first discovered item when available. That addresses the most likely reason the top list appeared blank: the UI thread was staying busy long enough that the list never rendered before the scan finished.

Validation: the file parses cleanly. The only remaining editor-reported issue is the pre-existing unapproved verb warning for `Build-SelectionDocument`, which is unrelated to this change.

If the top list is still empty after this, the next useful step is to inspect what `Get-AllEdgeWindows` is actually finding in the log, because that would mean UI Automation is not discovering Edge windows/tabs on that machine rather than the listbox failing to render.

### Wait Cursor And Loading Counter Update

Implemented a real mouse wait cursor during scans using WPF `Mouse.OverrideCursor` so the pointer consistently shows a busy state while loading is in progress.

Enhanced progress behavior by switching the top progress bar from indeterminate to determinate once the scan knows the total element count.

Added live status updates during scanning in the format `Loading element X of Y`.

Removed per-element informational log spam that was constantly overwriting the status area, so progress feedback remains stable and readable.

Validation: script parse check returned `Parse OK`; only the existing analyzer warning about `Build-SelectionDocument` (unapproved verb) remains.
