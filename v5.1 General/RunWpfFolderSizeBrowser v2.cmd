@echo off
REM Batch file to run the WPF Folder Size Browser PowerShell script
REM filepath: c:\Proj\PowerShell\PowerShell v5.1\RunWpfFolderSizeBrowser.cmd

REM Set the path to the PowerShell script
set SCRIPT_PATH="c:\Proj\PowerShell\PowerShell v5.1\WpfFolderSizeBrowser.v2.ps1"

REM Check if the script exists
if not exist %SCRIPT_PATH% (
    echo PowerShell script not found at %SCRIPT_PATH%.
    exit /b 1
)

REM Run the PowerShell script
powershell.exe -NoProfile -ExecutionPolicy Bypass -File %SCRIPT_PATH%