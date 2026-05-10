#Requires -Version 5.1
<#
.SYNOPSIS
    Show active Brave and Edge title and try to read the URL from the active browser address bar.
.DESCRIPTION
    Uses Win32 and UI Automation to inspect the active window and browser process windows.
    This script is intended as a helper for drag-and-drop caption debugging.
#>

param()

Add-Type -AssemblyName UIAutomationClient | Out-Null
Add-Type -AssemblyName UIAutomationTypes | Out-Null

Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class User32 {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
}
"@ -ErrorAction SilentlyContinue

function Get-ActiveWindowHandle {
    try {
        return [User32]::GetForegroundWindow()
    }
    catch {
        return [IntPtr]::Zero
    }
}

function Get-WindowTitle {
    param([IntPtr]$Handle)
    if ($Handle -eq [IntPtr]::Zero) { return $null }
    $length = [User32]::GetWindowTextLength($Handle)
    if ($length -le 0) { return $null }
    $buffer = New-Object System.Text.StringBuilder ($length + 1)
    [User32]::GetWindowText($Handle, $buffer, $buffer.Capacity) | Out-Null
    return $buffer.ToString().Trim()
}

function Get-ProcessNameFromHandle {
    param([IntPtr]$Handle)
    try {
        [uint32]$pid = 0
        [User32]::GetWindowThreadProcessId($Handle, [ref]$pid) | Out-Null
        if ($pid -gt 0) {
            $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
            if ($proc) {
                return $proc.ProcessName
            }

            # Fallback: search processes by main window handle
            $proc = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -eq $Handle } | Select-Object -First 1
            return $proc?.ProcessName
        }
    }
    catch {
    }
    return $null
}

function Get-AddressBarUrl {
    param([IntPtr]$Handle)
    try {
        $root = [System.Windows.Automation.AutomationElement]::FromHandle($Handle)
        if (-not $root) { return $null }

        $editType = [System.Windows.Automation.ControlType]::Edit
        $nameCondition = New-Object System.Windows.Automation.OrCondition(
            (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, 'Address and search bar')),
            (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, 'Address bar')),
            (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, 'Search or enter address'))
        )
        $findCondition = New-Object System.Windows.Automation.AndCondition(
            (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $editType)),
            $nameCondition
        )

        $addressElement = $root.FindFirst([System.Windows.Automation.TreeScope]::Subtree, $findCondition)
        if ($addressElement) {
            $valuePattern = $addressElement.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
            return $valuePattern.Current.Value
        }

        $allEdits = $root.FindAll([System.Windows.Automation.TreeScope]::Subtree,
            (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $editType)))
        foreach ($edit in $allEdits) {
            $name = $edit.Current.Name
            if ($name -and $name -match '(Address|URL|Search)') {
                try {
                    $valuePattern = $edit.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
                    if ($valuePattern) {
                        $value = $valuePattern.Current.Value
                        if ($value -and $value -match '^(https?://)') {
                            return $value
                        }
                    }
                }
                catch {
                }
            }
        }
    }
    catch {
    }
    return $null
}

function Normalize-BrowserTitle {
    param([string]$Title)
    if (-not $Title) { return $null }
    $title = $Title.Trim()
    $suffixes = @(
        ' - Microsoft Edge',
        ' - Brave',
        ' - Mozilla Firefox',
        ' - Google Chrome',
        ' - Chromium',
        ' — Microsoft Edge',
        ' — Brave',
        ' — Mozilla Firefox',
        ' — Google Chrome'
    )
    foreach ($suffix in $suffixes) {
        if ($title.EndsWith($suffix)) {
            return $title.Substring(0, $title.Length - $suffix.Length).Trim()
        }
    }
    $title = $title -replace '\s*[-—]\s*(Microsoft Edge|Brave|Mozilla Firefox|Google Chrome|Chromium)$', ''
    return $title.Trim()
}

function Show-BrowserInfo {
    Write-Host "=== ACTIVE BROWSER INFO ===" -ForegroundColor Cyan
    $hwnd = Get-ActiveWindowHandle
    if ($hwnd -eq [IntPtr]::Zero) {
        Write-Host "No active window found." -ForegroundColor Red
        return
    }

    $title = Get-WindowTitle -Handle $hwnd
    $processName = Get-ProcessNameFromHandle -Handle $hwnd
    Write-Host "Active window title: $title" -ForegroundColor White
    Write-Host "Active process name: $processName" -ForegroundColor White

    if ($processName -and $processName -match '^(msedge|brave)$') {
        $browserTitle = Normalize-BrowserTitle -Title $title
        Write-Host "Normalized browser title: $browserTitle" -ForegroundColor Green
        $url = Get-AddressBarUrl -Handle $hwnd
        if ($url) {
            Write-Host "Detected active URL: $url" -ForegroundColor White
        }
        else {
            Write-Host "Could not detect address bar URL via UI Automation." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "Active window is not Edge or Brave. Focus your browser window and rerun." -ForegroundColor Yellow
    }

    Write-Host "";
    Write-Host "=== BRAVE AND EDGE WINDOWS ===" -ForegroundColor Cyan
    foreach ($browser in @('msedge', 'brave')) {
        $processes = Get-Process -Name $browser -ErrorAction SilentlyContinue
        if ($processes) {
            Write-Host "$browser windows:" -ForegroundColor Magenta
            foreach ($proc in $processes) {
                if ($proc.MainWindowTitle) {
                    $normalized = Normalize-BrowserTitle -Title $proc.MainWindowTitle
                    Write-Host "  PID $($proc.Id): $($proc.MainWindowTitle)" -ForegroundColor White
                    Write-Host "    Normalized: $normalized" -ForegroundColor Green
                }
            }
            Write-Host "";
        }
    }

    Write-Host "If you want the active browser title to be used in drag/drop captions, make sure the browser window is active while beginning the drag." -ForegroundColor Cyan
}

Show-BrowserInfo
