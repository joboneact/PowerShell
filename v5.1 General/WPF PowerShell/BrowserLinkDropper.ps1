#Requires -Version 5.1
<#
Known issues
insertion jumps to next rich edit when copy is clicked.
Still no captions for Brave or Edge.

.SYNOPSIS
    Browser Link Dropper - WPF Application for drag-and-drop link collection from browsers
.DESCRIPTION
    Accepts links from Edge, Firefox, and Brave browsers via drag-and-drop.
    Displays caption and URL in 8 rich text boxes with copy and clear functionality.
#>

param()

# Load required assemblies
[System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework') | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName('WindowsFormsIntegration') | Out-Null

# Load UI Automation assemblies for browser info
[System.Reflection.Assembly]::LoadWithPartialName('UIAutomationClient') | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName('UIAutomationTypes') | Out-Null

Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Diagnostics;
public static class User32 {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern IntPtr GetWindow(IntPtr hWnd, uint uCmd);

    public const uint GW_HWNDNEXT = 2;
}

public static class BrowserHelper {
    public static string GetBrowserTabTitle(string processName) {
        try {
            var processes = Process.GetProcessesByName(processName);
            foreach (var proc in processes) {
                if (!string.IsNullOrEmpty(proc.MainWindowTitle)) {
                    return proc.MainWindowTitle;
                }
            }
        }
        catch {
            // Ignore errors
        }
        return null;
    }
}
"@ -ErrorAction SilentlyContinue

function Get-ActiveBrowserTitle {
    try {
        $hwnd = [User32]::GetForegroundWindow()
        if ($hwnd -eq [IntPtr]::Zero) { return $null }

        $processId = 0
        [User32]::GetWindowThreadProcessId($hwnd, [ref]$processId) | Out-Null

        if ($processId -gt 0) {
            $proc = Get-Process -Id $processId -ErrorAction SilentlyContinue
            if ($proc -and ($proc.ProcessName -match '^(msedge|firefox|brave|chrome)$')) {
                $titleLength = [User32]::GetWindowTextLength($hwnd)
                if ($titleLength -gt 0) {
                    $buffer = New-Object System.Text.StringBuilder ($titleLength + 1)
                    [User32]::GetWindowText($hwnd, $buffer, $buffer.Capacity) | Out-Null
                    return $buffer.ToString().Trim()
                }
            }
        }
    }
    catch {
        # Silently continue
    }
    return $null
}

function Get-BrowserInfo {
    param([string]$ProcessName)
    
    try {
        $proc = Get-Process $ProcessName -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle } | Select-Object -First 1
        if (-not $proc) { return "Browser process not found or no window active." }

        # Get root automation element for the browser window
        $root = [System.Windows.Automation.AutomationElement]::FromHandle($proc.MainWindowHandle)
        
        # Define condition for the Address Bar (Chromium standard)
        $condition = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty, 
            [System.Windows.Automation.ControlType]::Edit
        )
        
        # Search for the address bar element
        $addressBar = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
        
        $title = $proc.MainWindowTitle
        $url = if ($addressBar) { $addressBar.Current.Value } else { "URL could not be retrieved" }

        return "Title: $title`r`nURL: $url"
    }
    catch {
        return "Error: $($_.Exception.Message)"
    }
}

# Define XAML file path
$xamlPath = "$PSScriptRoot\BrowserLinkDropper.xaml"

if (-not (Test-Path $xamlPath)) {
    Write-Error "XAML file not found at $xamlPath"
    exit 1
}

# Read XAML
$xaml = Get-Content -Path $xamlPath -Raw

# Create XML namespace manager for proper parsing
$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get references to all RichTextBoxes
$richTextBoxes = @(
    $window.FindName('RichTextBox1'),
    $window.FindName('RichTextBox2'),
    $window.FindName('RichTextBox3'),
    $window.FindName('RichTextBox4'),
    $window.FindName('RichTextBox5'),
    $window.FindName('RichTextBox6'),
    $window.FindName('RichTextBox7'),
    $window.FindName('RichTextBox8')
)

# Get references to all buttons
$copyButtons = @(
    $window.FindName('CopyButton1'),
    $window.FindName('CopyButton2'),
    $window.FindName('CopyButton3'),
    $window.FindName('CopyButton4'),
    $window.FindName('CopyButton5'),
    $window.FindName('CopyButton6'),
    $window.FindName('CopyButton7'),
    $window.FindName('CopyButton8')
)

$clearButtons = @(
    $window.FindName('ClearButton1'),
    $window.FindName('ClearButton2'),
    $window.FindName('ClearButton3'),
    $window.FindName('ClearButton4'),
    $window.FindName('ClearButton5'),
    $window.FindName('ClearButton6'),
    $window.FindName('ClearButton7'),
    $window.FindName('ClearButton8')
)

# Get references to browser info controls
$edgeTextBox = $window.FindName('EdgeTextBox')
$braveTextBox = $window.FindName('BraveTextBox')
$edgeRefreshButton = $window.FindName('EdgeRefreshButton')
$braveRefreshButton = $window.FindName('BraveRefreshButton')

# Function to normalize browser window titles by removing browser suffixes
function Normalize-BrowserTitle {
    param([string]$Title)
    if (-not $Title) { return $null }
    $title = $Title.Trim()

    # Remove common browser suffixes
    $suffixes = @(
        ' - Microsoft Edge',
        ' - Brave',
        ' - Mozilla Firefox',
        ' - Google Chrome',
        ' - Chromium',
        ' — Mozilla Firefox',
        ' — Brave',
        ' — Microsoft Edge',
        ' — Google Chrome'
    )

    foreach ($suffix in $suffixes) {
        if ($title.EndsWith($suffix)) {
            $title = $title.Substring(0, $title.Length - $suffix.Length)
            break
        }
    }

    # Also handle cases where the suffix might be separated differently
    $title = $title -replace '\s*[-—]\s*(Microsoft Edge|Brave|Mozilla Firefox|Google Chrome|Chromium)$', ''

    return $title.Trim()
}

# Function to get page title from browsers via COM or active browser window
function Get-BrowserPageTitle {
    param([string]$Url)

    # First try the active browser window title
    try {
        $activeTitle = Get-ActiveBrowserTitle
        if ($activeTitle) {
            $normalized = Normalize-BrowserTitle -Title $activeTitle
            if ($normalized -and $normalized -ne "New Tab" -and $normalized -ne "New tab") {
                return $normalized
            }
        }
    }
    catch {
        # Continue
    }

    # Try to get from Internet Explorer / Edge legacy if available
    try {
        $ieApp = New-Object -ComObject InternetExplorer.Application -ErrorAction SilentlyContinue
        if ($ieApp) {
            try {
                if ($ieApp.Document -and $ieApp.Document.title) {
                    $title = $ieApp.Document.title.Trim()
                    if ($title) {
                        return $title
                    }
                }
            }
            finally {
                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($ieApp) | Out-Null
            }
        }
    }
    catch {
        # Silently continue if IE COM fails
    }

    # Use captured browser title if available
    if (-not [string]::IsNullOrWhiteSpace($script:capturedBrowserTitle)) {
        return $script:capturedBrowserTitle
    }

    # Try to get from browser processes - check all browser windows
    try {
        $browserNames = @('msedge', 'firefox', 'brave', 'chrome')
        foreach ($browserName in $browserNames) {
            $title = [BrowserHelper]::GetBrowserTabTitle($browserName)
            if ($title) {
                $normalized = Normalize-BrowserTitle -Title $title
                if ($normalized -and $normalized -ne "New Tab" -and $normalized -ne "New tab") {
                    return $normalized
                }
            }
        }
    }
    catch {
        # Continue to next method
    }

    # Try to extract domain name from URL as fallback
    try {
        $uri = [System.Uri]$Url
        return $uri.Host
    }
    catch {
        return "Link"
    }
}
function Get-LinkFromDrop {
    param([System.Windows.Forms.IDataObject]$DataObject)
    
    $url = $null
    $caption = $null
    
    # Try HTML format first for drag-and-drop captions
    if ($DataObject.GetDataPresent([System.Windows.Forms.DataFormats]::Html) -or $DataObject.GetDataPresent('text/html')) {
        try {
            if ($DataObject.GetDataPresent([System.Windows.Forms.DataFormats]::Html)) {
                $htmlData = $DataObject.GetData([System.Windows.Forms.DataFormats]::Html)
            }
            else {
                $htmlData = $DataObject.GetData('text/html')
            }
            $hrefStart = $htmlData.IndexOf('href="')
            if ($hrefStart -lt 0) {
                $hrefStart = $htmlData.IndexOf("href='")
                $quoteChar = "'"
            }
            else {
                $hrefStart += 6
                $quoteChar = '"'
            }

            if ($hrefStart -ge 0) {
                $urlEnd = $htmlData.IndexOf($quoteChar, $hrefStart)
                if ($urlEnd -gt $hrefStart) {
                    $url = $htmlData.Substring($hrefStart, $urlEnd - $hrefStart)
                }
            }

            if ($url) {
                $anchorStart = $htmlData.IndexOf('>', $urlEnd)
                $anchorEnd = $htmlData.IndexOf('</a>', $anchorStart)
                if ($anchorStart -ge 0 -and $anchorEnd -gt $anchorStart) {
                    $innerText = $htmlData.Substring($anchorStart + 1, $anchorEnd - $anchorStart - 1).Trim()
                    if ($innerText) {
                        $caption = $innerText -replace '<[^>]+>', ''
                        $caption = $caption.Trim()
                    }
                }
            }
        }
        catch {
        }
    }
    
    # Try to get URL from plain text if no HTML URL found
    if (-not $url -and $DataObject.GetDataPresent([System.Windows.Forms.DataFormats]::Text)) {
        $rawText = $DataObject.GetData([System.Windows.Forms.DataFormats]::Text)
        if ($rawText -match '^(https?|ftp)://') {
            $url = $rawText.Trim()
        }
    }
    
    # Try shell URL list format
    if (-not $url -and $DataObject.GetDataPresent('UniformResourceLocator')) {
        try {
            $url = $DataObject.GetData('UniformResourceLocator')
        }
        catch {
            # Continue
        }
    }
    
    # Try file drop data
    if (-not $url -and $DataObject.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        try {
            $files = $DataObject.GetData([System.Windows.Forms.DataFormats]::FileDrop)
            if ($files -and $files.Count -gt 0) {
                $file = $files[0]
                if ($file -match '^(https?|ftp)://' -or (Test-Path $file)) {
                    $url = $file
                    if (-not $caption) {
                        $caption = [System.IO.Path]::GetFileName($file)
                    }
                }
            }
        }
        catch {
            # Continue
        }
    }
    
    return @{
        Url = $url
        Caption = $caption
    }
}

# Function to add link to RichTextBox
function Add-LinkToRichTextBox {
    param(
        [System.Windows.Controls.RichTextBox]$RichTextBox,
        [string]$Caption,
        [string]$Url
    )
    
    if ([string]::IsNullOrWhiteSpace($Url)) {
        return
    }
    
    # Prefer the captured browser title from drag operation
    $pageTitle = $null
    if (-not [string]::IsNullOrWhiteSpace($script:capturedBrowserTitle)) {
        $pageTitle = $script:capturedBrowserTitle
        $script:capturedBrowserTitle = $null
    }
    
    if ([string]::IsNullOrWhiteSpace($pageTitle)) {
        $pageTitle = Get-BrowserPageTitle -Url $Url
    }

    if ([string]::IsNullOrWhiteSpace($pageTitle)) {
        $pageTitle = "Link"
    }
    
    $displayText = if (-not [string]::IsNullOrWhiteSpace($Caption)) { $Caption } else { $pageTitle }
    
    # Create paragraph for page title as hyperlink
    $paragraph = New-Object System.Windows.Documents.Paragraph
    $paragraph.Margin = New-Object System.Windows.Thickness(0)
    
    $hyperlink = New-Object System.Windows.Documents.Hyperlink
    $hyperlink.NavigateUri = $Url
    $hyperlink.Foreground = [System.Windows.Media.Brushes]::Blue
    $hyperlink.TextDecorations = [System.Windows.TextDecorations]::Underline
    
    $titleRun = New-Object System.Windows.Documents.Run
    $titleRun.Text = $displayText
    $hyperlink.Inlines.Add($titleRun)
    $paragraph.Inlines.Add($hyperlink)
    
    # Add hyperlink click handler
    $hyperlink.add_RequestNavigate({
        param($sender, $e)
        [System.Diagnostics.Process]::Start($e.Uri.OriginalString)
        $e.Handled = $true
    })
    
    $RichTextBox.Document.Blocks.Add($paragraph)
    
    # Add URL on next line
    $urlParagraph = New-Object System.Windows.Documents.Paragraph
    $urlParagraph.Margin = New-Object System.Windows.Thickness(0)
    $urlRun = New-Object System.Windows.Documents.Run
    $urlRun.Text = $Url
    $urlParagraph.Inlines.Add($urlRun)
    $RichTextBox.Document.Blocks.Add($urlParagraph)
    
    # Add empty paragraph for spacing
    $spaceParagraph = New-Object System.Windows.Documents.Paragraph
    $spaceParagraph.Margin = New-Object System.Windows.Thickness(0)
    $RichTextBox.Document.Blocks.Add($spaceParagraph)
    
    # Move insertion point to the end of the blank spacer paragraph (ready for next drop)
    $RichTextBox.CaretPosition = $spaceParagraph.ContentEnd
    $RichTextBox.Focus()
    $RichTextBox.ScrollToEnd()
}

# Function to get text content from RichTextBox
function Get-RichTextBoxContent {
    param([System.Windows.Controls.RichTextBox]$RichTextBox)
    
    $textRange = New-Object System.Windows.Documents.TextRange(
        $RichTextBox.Document.ContentStart,
        $RichTextBox.Document.ContentEnd
    )
    return $textRange.Text
}

# Function to copy RichTextBox content to clipboard
function Copy-RichTextBoxToClipboard {
    param([System.Windows.Controls.RichTextBox]$RichTextBox)
    
    $content = Get-RichTextBoxContent -RichTextBox $RichTextBox
    if (-not [string]::IsNullOrWhiteSpace($content)) {
        [System.Windows.Forms.Clipboard]::SetText($content.Trim())
    }
}

# Function to clear RichTextBox
function Clear-RichTextBox {
    param([System.Windows.Controls.RichTextBox]$RichTextBox)
    
    $RichTextBox.Document.Blocks.Clear()
}

# Global variable to store captured browser title during drag
$capturedBrowserTitle = $null

# Setup drop handlers for all RichTextBoxes
for ($i = 0; $i -lt $richTextBoxes.Count; $i++) {
    $rtb = $richTextBoxes[$i]
    
    # DragOver handler
    $rtb.add_DragOver({
        param($sender, $e)
        if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop) -or
            $e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::Text) -or
            $e.Data.GetDataPresent('text/html') -or
            $e.Data.GetDataPresent('UniformResourceLocator')) {
            $e.Effects = [System.Windows.DragDropEffects]::Copy
            
            # Try to capture browser title while dragging (browser should still be active)
            if (-not $script:capturedBrowserTitle) {
                $script:capturedBrowserTitle = Get-ActiveBrowserTitle
                if ($script:capturedBrowserTitle) {
                    $script:capturedBrowserTitle = Normalize-BrowserTitle -Title $script:capturedBrowserTitle
                }
            }
        }
        $e.Handled = $true
    })
    
    # Drop handler
    $rtb.add_Drop({
        param($sender, $e)
        
        try {
            # Convert WPF IDataObject to WinForms IDataObject
            $winFormsData = New-Object System.Windows.Forms.DataObject
            
            # Copy data from WPF to WinForms
            $dataFormats = $e.Data.GetFormats()
            foreach ($format in $dataFormats) {
                try {
                    $data = $e.Data.GetData($format)
                    $winFormsData.SetData($format, $data)
                }
                catch {
                    # Skip formats that can't be copied
                }
            }
            
            # Extract URL and caption
            $linkData = Get-LinkFromDrop -DataObject $winFormsData
            
            if ($linkData.Url) {
                Add-LinkToRichTextBox -RichTextBox $sender -Caption $linkData.Caption -Url $linkData.Url
                $e.Effects = [System.Windows.DragDropEffects]::Copy
            }
            elseif ($winFormsData.GetDataPresent([System.Windows.Forms.DataFormats]::Text)) {
                # Handle plain text drop (from browser info textboxes)
                $plainText = $winFormsData.GetData([System.Windows.Forms.DataFormats]::Text)
                if (-not [string]::IsNullOrWhiteSpace($plainText)) {
                    # Add plain text to RichTextBox
                    $paragraph = New-Object System.Windows.Documents.Paragraph
                    $paragraph.Margin = New-Object System.Windows.Thickness(0)
                    $run = New-Object System.Windows.Documents.Run
                    $run.Text = $plainText
                    $paragraph.Inlines.Add($run)
                    $sender.Document.Blocks.Add($paragraph)
                    
                    # Add empty paragraph for spacing
                    $spaceParagraph = New-Object System.Windows.Documents.Paragraph
                    $spaceParagraph.Margin = New-Object System.Windows.Thickness(0)
                    $sender.Document.Blocks.Add($spaceParagraph)
                    
                    # Move insertion point to the end
                    $sender.CaretPosition = $spaceParagraph.ContentEnd
                    $sender.Focus()
                    $sender.ScrollToEnd()
                    
                    $e.Effects = [System.Windows.DragDropEffects]::Copy
                }
            }
        }
        catch {
            Write-Warning "Drop failed: $_"
        }
        
        $e.Handled = $true
    })
}

# Setup copy and clear button handlers
for ($i = 0; $i -lt $copyButtons.Count; $i++) {
    $copyBtn = $copyButtons[$i]
    $clearBtn = $clearButtons[$i]
    $rtb = $richTextBoxes[$i]
    
    # Copy button click handler
    $copyBtn.add_Click({
        Copy-RichTextBoxToClipboard -RichTextBox $rtb
        $rtb.Focus()
    })
    
    # Clear button click handler
    $clearBtn.add_Click({
        Clear-RichTextBox -RichTextBox $rtb
        $rtb.Focus()
    })
}

# Setup refresh button handlers
$edgeRefreshButton.add_Click({
    $edgeTextBox.Text = Get-BrowserInfo "msedge"
})

$braveRefreshButton.add_Click({
    $braveTextBox.Text = Get-BrowserInfo "brave"
})

# Setup drag handlers for browser textboxes
$edgeTextBox.add_PreviewMouseMove({
    param($sender, $e)
    if ($e.LeftButton -eq [System.Windows.Input.MouseButtonState]::Pressed) {
        $text = $sender.Text
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            [System.Windows.DragDrop]::DoDragDrop($sender, $text, [System.Windows.DragDropEffects]::Copy)
        }
    }
})

$braveTextBox.add_PreviewMouseMove({
    param($sender, $e)
    if ($e.LeftButton -eq [System.Windows.Input.MouseButtonState]::Pressed) {
        $text = $sender.Text
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            [System.Windows.DragDrop]::DoDragDrop($sender, $text, [System.Windows.DragDropEffects]::Copy)
        }
    }
})

# Initialize browser info on startup
$edgeTextBox.Text = Get-BrowserInfo "msedge"
$braveTextBox.Text = Get-BrowserInfo "brave"

# Show the window
$window.ShowDialog() | Out-Null
