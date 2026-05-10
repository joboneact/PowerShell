#Requires -Version 5.1
<#
.SYNOPSIS
    Browser Info Helper - Get current URL and title from active browser windows
.DESCRIPTION
    Displays information about active browser windows including titles and attempts to extract URLs
#>

param()

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

    public static string GetActiveBrowserTitle() {
        try {
            IntPtr hwnd = User32.GetForegroundWindow();
            if (hwnd == IntPtr.Zero) { return null; }

            uint processId = 0;
            User32.GetWindowThreadProcessId(hwnd, out processId);

            if (processId > 0) {
                Process proc = Process.GetProcessById((int)processId);
                if (proc != null && (proc.ProcessName.Contains("msedge") ||
                                     proc.ProcessName.Contains("firefox") ||
                                     proc.ProcessName.Contains("brave") ||
                                     proc.ProcessName.Contains("chrome"))) {
                    int titleLength = User32.GetWindowTextLength(hwnd);
                    if (titleLength > 0) {
                        System.Text.StringBuilder buffer = new System.Text.StringBuilder(titleLength + 1);
                        User32.GetWindowText(hwnd, buffer, buffer.Capacity);
                        return buffer.ToString().Trim();
                    }
                }
            }
        }
        catch {
            // Silently continue
        }
        return null;
    }
}
"@ -ErrorAction SilentlyContinue

function Get-ActiveWindowTitle {
    try {
        $hwnd = [User32]::GetForegroundWindow()
        if ($hwnd -eq [IntPtr]::Zero) { return $null }
        $buffer = New-Object System.Text.StringBuilder 512
        if ([User32]::GetWindowText($hwnd, $buffer, $buffer.Capacity) -gt 0) {
            return $buffer.ToString().Trim()
        }
    }
    catch {
        # Silently continue
    }
    return $null
}

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

function Get-BrowserInfo {
    Write-Host "=== BROWSER INFO HELPER ===" -ForegroundColor Cyan
    Write-Host ""

    # Get active window
    Write-Host "ACTIVE WINDOW:" -ForegroundColor Yellow
    $activeTitle = Get-ActiveWindowTitle
    if ($activeTitle) {
        Write-Host "  Title: $activeTitle" -ForegroundColor White
        $normalized = Normalize-BrowserTitle -Title $activeTitle
        if ($normalized -and $normalized -ne $activeTitle) {
            Write-Host "  Normalized: $normalized" -ForegroundColor Green
        }
    } else {
        Write-Host "  No active window title found" -ForegroundColor Red
    }
    Write-Host ""

    # Get active browser specifically
    Write-Host "ACTIVE BROWSER WINDOW:" -ForegroundColor Yellow
    $activeBrowserTitle = [BrowserHelper]::GetActiveBrowserTitle()
    if ($activeBrowserTitle) {
        Write-Host "  Title: $activeBrowserTitle" -ForegroundColor White
        $normalized = Normalize-BrowserTitle -Title $activeBrowserTitle
        if ($normalized) {
            Write-Host "  Normalized: $normalized" -ForegroundColor Green
        }
    } else {
        Write-Host "  No active browser window found" -ForegroundColor Red
    }
    Write-Host ""

    # Get all browser processes
    $browserNames = @('msedge', 'firefox', 'brave', 'chrome')
    Write-Host "ALL BROWSER PROCESSES:" -ForegroundColor Yellow

    foreach ($browserName in $browserNames) {
        try {
            $processes = Get-Process -Name $browserName -ErrorAction SilentlyContinue
            if ($processes) {
                Write-Host "  $browserName processes:" -ForegroundColor Magenta
                foreach ($proc in $processes) {
                    if ($proc.MainWindowTitle) {
                        Write-Host "    PID $($proc.Id): $($proc.MainWindowTitle)" -ForegroundColor White
                        $normalized = Normalize-BrowserTitle -Title $proc.MainWindowTitle
                        if ($normalized -and $normalized -ne $proc.MainWindowTitle) {
                            Write-Host "      Normalized: $normalized" -ForegroundColor Green
                        }
                    }
                }
            }
        }
        catch {
            Write-Host "    Error getting $browserName processes: $_" -ForegroundColor Red
        }
    }
    Write-Host ""

    # Try IE COM for Edge
    Write-Host "IE COM INTERFACE (for Edge/IE):" -ForegroundColor Yellow
    try {
        $ieApp = New-Object -ComObject InternetExplorer.Application -ErrorAction SilentlyContinue
        if ($ieApp) {
            try {
                Write-Host "  IE COM Available: Yes" -ForegroundColor Green
                if ($ieApp.Document -and $ieApp.Document.title) {
                    Write-Host "  Document Title: $($ieApp.Document.title)" -ForegroundColor White
                } else {
                    Write-Host "  No document title available" -ForegroundColor Red
                }
                if ($ieApp.LocationURL) {
                    Write-Host "  Location URL: $($ieApp.LocationURL)" -ForegroundColor White
                } else {
                    Write-Host "  No location URL available" -ForegroundColor Red
                }
            }
            finally {
                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($ieApp) | Out-Null
            }
        } else {
            Write-Host "  IE COM Available: No" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  IE COM Error: $_" -ForegroundColor Red
    }
    Write-Host ""

    Write-Host "INSTRUCTIONS:" -ForegroundColor Cyan
    Write-Host "1. Make sure your browser window is active (focused)" -ForegroundColor White
    Write-Host "2. Run this script to see current browser information" -ForegroundColor White
    Write-Host "3. The 'Normalized' titles are what would be used as captions" -ForegroundColor White
    Write-Host "4. For drag-and-drop, the script tries to get the active browser title" -ForegroundColor White
    Write-Host ""

    Write-Host "Press any key to refresh, or Ctrl+C to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Clear-Host
    Get-BrowserInfo
}

# Start the monitoring
Get-BrowserInfo