# PowerShell WPF Shell — Auto-Discovery Edition

Zero pre-registration. Drop a file in `modules\` and it appears as a tab.

---

## Quick start

```powershell
.\Main-Shell.ps1
```

---

## How the shell discovers tabs

On startup (and on every **↺ Reload**) the shell:

1. Scans `modules\Tab-*.ps1` — no other configuration needed
2. Reads a lightweight **metadata header** from the **first 25 lines** of each file (no dot-source, no execution)
3. Sorts and loads tabs:
   - Files **already known** from a previous session → restored in their saved order
   - **New files** (never seen before) → inserted at the **left** (position 0), sorted newest-first by `LastWriteTime`
4. Persists the current order to `%APPDATA%\WpfShell\tab-order.json`

---

## Metadata header

Declare any of these in your **first 25 lines**. All are optional — the shell
fills in defaults from the filename if they're absent.

```powershell
## ShellMeta:Title    My Tool
## ShellMeta:Icon     🔧
## ShellMeta:Version  1.2
## ShellMeta:Author   Your Name
```

| Key | Default (if omitted) | Notes |
|---|---|---|
| `Title` | Filename minus `Tab-` prefix | Spaces replace underscores |
| `Icon` | 📄 | Any single emoji or Unicode char |
| `Version` | *(empty)* | Displayed on hover (future) |
| `Author` | *(empty)* | Informational |

---

## Module contract

Every module must expose **one function**:

```powershell
function Get-ModuleUI {
    param([PSCustomObject]$ShellContext)
    # ... build your WPF UI ...
    return $SomeUIElement   # any UIElement
}
```

Full minimal example:

```powershell
#Requires -Version 5.1
## ShellMeta:Title    Hello World
## ShellMeta:Icon     👋

Add-Type -AssemblyName PresentationFramework

function Get-ModuleUI {
    param([PSCustomObject]$ShellContext)

    [xml]$xaml = @"
<UserControl xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             Background="$($ShellContext.Theme.Background)">
    <TextBlock Text="Hello from auto-discovered tab!"
               Foreground="$($ShellContext.Theme.Text)"
               FontSize="20" Margin="32"/>
</UserControl>
"@
    $reader  = [System.Xml.XmlNodeReader]::new($xaml)
    $control = [Windows.Markup.XamlReader]::Load($reader)
    return $control
}
```

Save as `modules\Tab-HelloWorld.ps1`. Run the shell or click **↺ Reload** — done.

---

## Tab ordering

- **Drag a tab header** left or right to reorder. The new order is saved immediately.
- **New tabs** always start at the leftmost position.
- **Order persists** across restarts in `%APPDATA%\WpfShell\tab-order.json`.
- **Deleted files** are silently removed from the saved order on next load.
- **↺ Reload** re-scans the folder: new files prepend (newest first), existing tabs reload in saved order.

---

## Shell Context reference

`$ShellContext` is passed to every module:

| Property | Type | Description |
|---|---|---|
| `Theme` | `Hashtable` | Color palette — Background, Surface, Accent, Text, TextMuted, etc. |
| `Window` | `Window` | The host WPF Window |
| `TabControl` | `TabControl` | The main TabControl |
| `StatusBar` | `TextBlock` | Write: `$ShellContext.StatusBar.Text = "my message"` |
| `RootPath` | `string` | Directory of Main-Shell.ps1 |
| `ModulesPath` | `string` | Path to `modules\` |
| `StatePath` | `string` | `%APPDATA%\WpfShell\` — use for your own module state files |

---

## Naming convention

| Pattern | Effect |
|---|---|
| `modules\Tab-*.ps1` | Auto-discovered on startup and reload |
| Any other `.ps1` | Not auto-discovered; loadable via **＋ Add tab** button |

---

## Requirements

- Windows PowerShell 5.1 **or** PowerShell 7+ on Windows
- .NET Framework 4.x / .NET 6+ (WPF is Windows-only)
