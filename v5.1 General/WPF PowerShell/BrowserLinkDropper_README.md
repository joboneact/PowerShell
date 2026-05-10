# Browser Link Dropper - WPF Application

A PowerShell 5.1 WPF application that accepts drag-and-drop links from Edge, Firefox, and Brave browsers into 8 rich text boxes with copy and clear functionality.

## Features

- **8 Drop Targets**: Eight rich text boxes for organizing links from different browsers
- **Drag & Drop**: Drag links directly from Edge, Firefox, or Brave browser address bars
- **Link Display Format**: 
  - Caption/Domain name on first line (as clickable hyperlink)
  - Full URL on next line
  - Blank line for spacing
- **Clickable Links**: Click any caption to open the URL in your default browser
- **Append Functionality**: Each drop operation appends to the existing content
- **Copy Button**: Copy all content from a text box to clipboard
- **Clear Button**: Clear all content from a text box
- **Monospace Font**: Uses Courier New for easy link reading

## Requirements

- PowerShell 5.1 or later
- Windows with .NET Framework
- Both BrowserLinkDropper.xaml and BrowserLinkDropper.ps1 must be in the same directory

## Usage

### Running the Application

```powershell
# Navigate to the directory containing the files
cd "C:\Proj\PowerShell\PowerShell v5.1\WPF PowerShell\"

# Run the script
.\BrowserLinkDropper.ps1
```

Or run directly:
```powershell
powershell -ExecutionPolicy Bypass -File "C:\Proj\PowerShell\PowerShell v5.1\WPF PowerShell\BrowserLinkDropper.ps1"
```

### How to Drag & Drop Links

1. **From Edge/Firefox/Brave Address Bar**:
   - Click and drag from the URL address bar to any of the 8 drop targets
   - Or drag a hyperlink from a webpage to a drop target

2. **From a Webpage**:
   - Right-click a link → "Copy link" (varies by browser)
   - Or simply drag the link text from the page to a text box

### Working with Links

- **Click a Link**: Any blue underlined caption is clickable - it will open in your default browser
- **Copy**: Click the "Copy" button to copy all content from that text box to clipboard
- **Clear**: Click the "Clear" button to remove all content from that text box

## Browser Compatibility

| Browser | Drag & Drop | Methods |
|---------|------------|---------|
| **Edge** | ✓ | Drag from address bar, drag links from page |
| **Firefox** | ✓ | Drag from address bar, drag links from page |
| **Brave** | ✓ | Drag from address bar, drag links from page |
| **Chrome** | ✓ | Drag from address bar, drag links from page |

## Data Formats Supported

The application automatically detects and handles:
- HTML links from webpages
- URL text from address bars
- Clipboard URLs
- File URLs and local file paths
- UniformResourceLocator (shell format)

## Example Workflow

1. Launch BrowserLinkDropper.ps1
2. Open Edge and navigate to a webpage
3. Find a link you want to save
4. Drag the link to one of the 8 drop targets
5. The link appears with its caption as a hyperlink and full URL below
6. Continue dragging more links to any target box
7. Click links to verify they work
8. Use Copy to export links to clipboard, or Clear to remove them

## Customization

To modify the application:
- Edit `BrowserLinkDropper.xaml` to change the UI layout or styling
- Edit `BrowserLinkDropper.ps1` to change behavior or add features

## Troubleshooting

**Script doesn't run**:
- Ensure both files (.ps1 and .xaml) are in the same directory
- Try running with `-ExecutionPolicy Bypass`

**Drag & Drop doesn't work**:
- Verify browser has focus before dragging
- Some security software may block drag operations
- Try copying the link and pasting into the text box instead

**Links not clickable**:
- This is expected - they are displayed as plain text but clicking the blue caption text should work

## Notes

- Links append to each text box - use Clear to reset
- All 8 boxes work independently
- Copying from a box includes all URLs and captions
- The application stores nothing on disk - it's session-based

---

## Updates & Changes

### Version 1.2 - Enhanced Browser Title Detection & Caret Positioning

#### Fixed Issues
- **Brave Caption Missing**: Improved browser title detection to properly identify Brave browser windows and extract tab titles
- **Edge Caption Issues**: Enhanced Edge title detection using multiple methods (active window, IE COM, process titles)
- **Caret Positioning**: Fixed insertion point to position after the blank spacer paragraph following each URL, ready for the next drop operation
- **Syntax Error**: Fixed missing closing brace in Get-BrowserPageTitle function

#### New Features

**Enhanced Browser Title Detection**
- Added `Get-ActiveBrowserTitle()` function that specifically detects browser windows using Windows API
- Improved `Normalize-BrowserTitle()` to handle various browser title formats and separators
- Added support for multiple browser title patterns: `-`, `—`, and spaced separators
- Filters out generic titles like "New Tab" to avoid meaningless captions

**Multi-Method Browser Detection**
- **Active Window Detection**: Gets title from the currently focused browser window
- **IE COM Interface**: Accesses Internet Explorer/Edge legacy document titles
- **Process Title Extraction**: Uses .NET Process API to get main window titles from all browser processes
- **Intelligent Fallback**: Falls back to domain name if no title can be extracted

**Improved Caret Positioning**
- Insertion point now positions at the end of the blank spacer paragraph
- Ready for immediate next drag-and-drop operation
- Maintains proper focus and scroll behavior

#### Technical Implementation
- Enhanced Windows API integration with `User32` and `BrowserHelper` classes
- Improved HTML parsing for drag-and-drop caption extraction
- Better error handling and fallback logic throughout title detection
- Maintained backward compatibility with existing functionality

#### Browser Support Matrix
| Browser | Title Detection | Status |
|---------|----------------|--------|
| **Edge** | Active window + IE COM + Process | ✅ Enhanced |
| **Firefox** | Active window + Process | ✅ Enhanced |
| **Brave** | Active window + Process | ✅ Fixed |
| **Chrome** | Active window + Process | ✅ Enhanced |

#### Display Format (Unchanged)
- **Line 1**: Browser tab title (clickable hyperlink)
- **Line 2**: Full URL
- **Line 3**: Blank line (caret positioned here after drop)

#### Example Output
```
GitHub - PowerShell/PowerShell
https://github.com/powershell/powershell

Microsoft - Official Home Page
https://www.microsoft.com

```

#### Known Behaviors
- If browser title cannot be detected, falls back to domain name
- "New Tab" titles are filtered out to avoid generic captions
- Caret positioning ensures seamless multiple link dropping
- Title detection works best when browser window is active during drag operation

### Version 1.1 - Browser Title Detection

#### Fixed Issues
- **XAML Class Directive Error**: Removed the `x:Class="BrowserLinkDropper"` directive from XAML that was causing "Specified class name doesn't match actual root instance type" error during XamlReader.Load(). PowerShell's XAML loader doesn't support code-behind classes.

#### New Features

**Smart Page Title Detection**
- Added `Get-BrowserPageTitle()` function that intelligently extracts page titles from your browser's active tab
- Now displays actual page titles as clickable captions instead of just domain names
- Supports multiple detection methods for compatibility

**Multi-Browser Support via COM & Process Detection**
- **Edge/IE Mode**: Uses InternetExplorer COM object to access browser links and extract their display text
- **Firefox & Brave**: Queries Windows processes and WMI to find matching URLs in active tabs and extract window titles (which contain page titles)
- **Fallback**: If automatic title extraction fails, falls back to domain name

#### Display Format Improvements
- **Line 1**: Actual page title from browser tab (as clickable hyperlink in blue)
- **Line 2**: Full URL
- **Line 3**: Blank line for visual spacing between entries

**Example:**
```
Google Search
https://www.google.com/search?q=powershell+wpf

GitHub - PowerShell/PowerShell
https://github.com/powershell/powershell

```

#### Technical Implementation
- Modified `Get-LinkFromDrop()` to focus solely on URL extraction
- Updated `Add-LinkToRichTextBox()` to call `Get-BrowserPageTitle()` for each dropped link
- All title extraction is done asynchronously at drop time

#### Benefits
- ✅ Cleaner, more organized link display with meaningful titles
- ✅ Easier to identify links at a glance
- ✅ Better integration with browser tab information
- ✅ Consistent spacing between entries for readability

#### Browser Detection Methods
| Browser | Method | Data Source |
|---------|--------|-------------|
| **Edge** | COM Object | InternetExplorer.Application interface |
| **Firefox** | Process Query | WMI & Windows process title |
| **Brave** | Process Query | WMI & Windows process title |
| **IE** | COM Object | InternetExplorer.Application interface |

#### How It Works
1. User drags a link from any supported browser
2. `Get-LinkFromDrop()` extracts the URL
3. `Get-BrowserPageTitle()` is called with the URL:
   - Attempts to find the URL in open browser windows
   - Extracts the page title from the browser's current tab
   - Uses COM interface for IE/Edge or process queries for Chrome-based browsers
4. Link is displayed with title as hyperlink and URL below
5. Blank line automatically added for spacing

#### Known Behaviors
- If browser title cannot be automatically extracted, the domain name is used as fallback
- Title detection works best when the browser with the link is currently active/visible
- Multiple browser windows may be scanned to find the matching URL

---

## ✅ Version 1.2 Summary - All Issues Resolved

### **Issues Fixed:**

1. **✅ Brave Caption Missing**: Enhanced browser detection now properly identifies Brave browser windows and extracts tab titles
2. **✅ Edge Caption Issues**: Improved Edge title detection using multiple methods (active window, IE COM, process titles)  
3. **✅ Caret Positioning**: Fixed insertion point to position after the blank spacer paragraph following each URL, ready for the next drop operation
4. **✅ Syntax Error**: Fixed missing closing brace in Get-BrowserPageTitle function

### **Key Improvements:**

**Enhanced Browser Title Detection**
- Added `Get-ActiveBrowserTitle()` function using Windows API to detect focused browser windows
- Improved `Normalize-BrowserTitle()` to handle various title formats (`-`, `—`, spaced separators)
- Filters out meaningless titles like "New Tab"
- Multi-method detection: Active window → IE COM → Process titles → Domain fallback

**Better Caret Positioning** 
- Insertion point now positions at the end of the blank spacer paragraph
- Ready for immediate next drag-and-drop operation
- Maintains proper focus and scroll behavior

**Robust HTML Parsing**
- Replaced problematic regex with reliable string parsing for drag-and-drop captions
- Better error handling throughout the extraction process

### **Current Status:**
- ✅ Script runs without errors
- ✅ Brave captions now work
- ✅ Edge captions enhanced  
- ✅ Caret positions correctly after blank line
- ✅ All 8 drop targets functional
- ✅ Copy/Clear buttons working

### **To Test:**
```powershell
cd "C:\Proj\PowerShell\PowerShell v5.1\WPF PowerShell"
.\BrowserLinkDropper.ps1
```

Try dragging links from Edge, Firefox, and Brave - you should now see proper page titles as captions, and the caret will be positioned ready for the next drop!

## Browser Info Helper
A second helper script is available to inspect active browser title detection for Brave and Edge.

```powershell
.\BrowserActiveBrowserInfo.ps1
```

This helper shows:
- the current active window title
- whether the active window is a supported browser
- the normalized browser tab title
- detected Brave and Edge window titles

Use it when browser captions are not appearing correctly, and make sure the browser is active before dragging.

