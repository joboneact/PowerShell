## May 19, 2026 - Parser Error Fix Summary

### Issue
- PowerShell parser error in Main-Shell.ps1:
	- Missing closing '}' in statement block or type definition.
	- Reported at line 690, column 31 on function Invoke-ReloadModules.

### Root Cause
- The function block itself was structurally valid.
- Corrupted non-ASCII/mojibake characters inside status strings in Invoke-ReloadModules caused PowerShell 5.1 parsing to break, which surfaced as a misleading missing brace error.

### Changes Made
- Updated the loading status text to ASCII-safe content:
	- Loading $($meta.Title)...
- Updated the ready status text to ASCII-safe content:
	- OK: $n module(s) ready
- Removed a temporary diagnostic extra brace added during troubleshooting.

### Validation
- Re-parsed Main-Shell.ps1 using System.Management.Automation.Language.Parser.
- Result: No parser errors found.
- Diagnostics check for Main-Shell.ps1: no errors.

### Notes
- Additional comments/labels still include non-ASCII decorative characters. These do not currently produce parser errors, but normalizing them to ASCII may reduce future encoding-related issues in Windows PowerShell 5.1.

## May 19, 2026 - Tab Icons and Template Tab Summary

### Issue
- Tab header icons were not rendering correctly.
- File Manager row glyphs on the left were showing incorrectly.
- A reusable template tab was needed to show shell integration patterns.

### Changes Made
- Updated tab header rendering in Main-Shell.ps1 to use an emoji-capable font for the metadata icon.
- Updated File Manager to use a dedicated icon column with an emoji-capable font instead of prefixing the file name.
- Added Main-Shell.ReadME.md as the renamed main documentation file.
- Added Tab-Template.ps1 as a starter tab module that demonstrates:
	- light and dark mode handling
	- clipboard format selection through the shell common area
	- shell status/common info updates
	- console-style output inside the tab

### Validation
- Main-Shell.ps1 parsed cleanly after the icon rendering change.
- Tab-Console.ps1, Tab-Dashboard.ps1, Tab-FileManager.ps1, Tab-VisualStudio.ps1, and Tab-Template.ps1 were validated to return UI elements from Get-ModuleUI.

### Notes
- The rename should be treated as a normal tracked file move in Git when staged with the rename in the same change set.

## May 19, 2026 - Template Tab Runtime Fix

### Issue
- Tab-Template.ps1 loaded with a runtime error because the XAML was not being instantiated before FindName calls.

### Changes Made
- Restored the missing XAML reader and XamlReader.Load block in Tab-Template.ps1.
- Kept the console area as a plain TextBox and continued using shell context callbacks for mode and clipboard format changes.

### Validation
- Tab-Template.ps1 now parses cleanly and returns a valid WPF UIElement from Get-ModuleUI.

### Git Note
- The README rename is still best treated as a staged move in Git so history and rename detection remain clean.

## May 19, 2026 - VS Code and Visual Studio Inventory Update

### Changes Made
- Fixed VS Code extension names that were showing localization placeholders such as `%displayName%` by resolving package.nls.json tokens.
- Corrected VS Code extension version reporting so AvailableVersion shows the actual version instead of a boolean result.
- Expanded Visual Studio inventory to show multiple installed versions in one tab with display version, full version, package count, workloads, components, and extension summaries.
- Updated the main shell title bar and actions to use emoji glyphs instead of symbol-style placeholders.
- Kept the template tab in sync as a discoverable starter module under modules/.

### Validation
- Main-Shell.ps1 parsed cleanly.
- modules/Tab-VSCode.ps1, modules/Tab-VisualStudio.ps1, and modules/Tab-Template.ps1 all returned UI elements from Get-ModuleUI.

### Notes
- The Visual Studio tab now surfaces instance details in one tab rather than splitting versions across different views.
- The README rename remains a normal Git rename-move candidate when staged together.

## May 19, 2026 - VS Code Version Detail and Dashboard Telemetry Update

### Changes Made
- Updated [Tab-VSCode.ps1](Tab-VSCode.ps1) extension version columns to show two lines each:
	- Installed: version + local installed timestamp
	- Available: marketplace version + marketplace last-updated timestamp
- Updated [Tab-Dashboard.ps1](Tab-Dashboard.ps1) with additional telemetry blocks:
	- networking section with adapter, IPv4, gateway, and DNS details
	- process section listing top processes by memory with CPU seconds and working set
	- expanded CPU summary to include physical and logical core counts

### Validation
- Non-interactive runtime validation passed for top-level files:
	- Tab-VSCode.ps1 -> Runtime OK (UIElement)
	- Tab-Dashboard.ps1 -> Runtime OK (UIElement)

### Notes
- Per your constraint, only top-level files were modified; no changes were made under modules/.

