#Requires -Version 5.1
<#
.SYNOPSIS
    Tabbed WPF PowerShell Shell — Auto-Discovery Edition

ZERO PRE-REGISTRATION.  The shell:
  1. Scans modules\Tab-*.ps1  (no knowledge of content needed)
  2. Reads a lightweight metadata header from the first ~25 lines of each file
  3. Sorts tabs: saved-order first, then any NEW files newest-first on the left
  4. Persists tab order to JSON on every reorder / close
  5. Supports drag-to-reorder tabs with live visual feedback

────────────────────────────────────────────────────────────
MODULE CONTRACT  (the only thing a module must do)
────────────────────────────────────────────────────────────
Optionally declare a metadata block in your first 25 lines:

    ## ShellMeta:Title    My Tool
    ## ShellMeta:Icon     🔧
    ## ShellMeta:Version  1.2
    ## ShellMeta:Author   You

Then expose ONE function:

    function Get-ModuleUI {
        param([PSCustomObject]$ShellContext)
        ...
        return $SomeUIElement
    }

That's it.  File must be named  Tab-Something.ps1
────────────────────────────────────────────────────────────
#>

Set-StrictMode -Off
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# ─────────────────────────────────────────────────────────────
# PATHS
# ─────────────────────────────────────────────────────────────
$ShellRoot   = $PSScriptRoot
$ModulesPath = Join-Path $ShellRoot "modules"
$StatePath   = Join-Path $env:APPDATA "WpfShell"
$OrderFile   = Join-Path $StatePath  "tab-order.json"

if (-not (Test-Path $StatePath)) {
    New-Item -ItemType Directory -Path $StatePath -Force | Out-Null
}

# ─────────────────────────────────────────────────────────────
# GLOBAL SHELL CONTEXT  (passed to every module)
# ─────────────────────────────────────────────────────────────
$Global:ShellContext = [PSCustomObject]@{
    Version     = "2.0"
    RootPath    = $ShellRoot
    ModulesPath = $ModulesPath
    StatePath   = $StatePath
    Theme       = @{
        Background  = "#1E1E2E"
        Surface     = "#2A2A3E"
        Accent      = "#7C6AF7"
        AccentHover = "#9D8FFF"
        Text        = "#CDD6F4"
        TextMuted   = "#7F849C"
        Border      = "#45475A"
        Danger      = "#F38BA8"
        Success     = "#A6E3A1"
    }
    Window          = $null
    TabControl      = $null
    StatusBar       = $null
    CommonInfo      = $null
    DiagnosticsBox  = $null
    CopyToClipboard = $null
    CommonSettings  = [PSCustomObject]@{
        OutputCopyFormat = "Text"
        AvailableFormats  = @("Text","PSObject","JSON","Markdown","HTML")
        Mode             = "Dark"
    }
    SetCommonSetting = $null
}

# ─────────────────────────────────────────────────────────────
# METADATA READER
# Reads up to $HeaderLines lines — NO dot-sourcing.
# Parses:   ## ShellMeta:Key   Value
# Falls back to filename-derived defaults for everything.
# ─────────────────────────────────────────────────────────────
function Read-ModuleMetadata {
    param(
        [System.IO.FileInfo]$File,
        [int]$HeaderLines = 25
    )

    $meta = [ordered]@{
        Title     = ($File.BaseName -replace '^Tab-', '') -replace '_', ' '
        Icon      = "📄"
        Version   = ""
        Author    = ""
        FileName  = $File.Name
        FullPath  = $File.FullName
        LastWrite = $File.LastWriteTime
    }

    try {
        $lines = [System.IO.File]::ReadLines($File.FullName) |
                 Select-Object -First $HeaderLines
        foreach ($line in $lines) {
            if ($line -match '##\s*ShellMeta\s*:\s*(\w+)\s+(.+)') {
                $key = $Matches[1].Trim()
                $val = $Matches[2].Trim()
                if ($meta.Contains($key)) { $meta[$key] = $val }
            }
        }
    }
    catch { <# unreadable file — use defaults #> }

    return [PSCustomObject]$meta
}

# ─────────────────────────────────────────────────────────────
# STATUS HELPER
# ─────────────────────────────────────────────────────────────
function Set-Status {
    param([string]$Msg, [string]$Color = "#7F849C")
    $TxtStatus.Text       = $Msg
    $TxtStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($Color)
}

function Set-Theme {
    param([string]$Mode)

    if ($Mode -eq 'Light') {
        $Global:ShellContext.Theme.Background  = '#F5F5F5'
        $Global:ShellContext.Theme.Surface     = '#FFFFFF'
        $Global:ShellContext.Theme.Accent      = '#2563EB'
        $Global:ShellContext.Theme.AccentHover = '#60A5FA'
        $Global:ShellContext.Theme.Text        = '#111827'
        $Global:ShellContext.Theme.TextMuted   = '#6B7280'
        $Global:ShellContext.Theme.Border      = '#D1D5DB'
        $Global:ShellContext.Theme.Danger      = '#DC2626'
        $Global:ShellContext.Theme.Success     = '#16A34A'
    }
    else {
        $Global:ShellContext.Theme.Background  = '#1E1E2E'
        $Global:ShellContext.Theme.Surface     = '#2A2A3E'
        $Global:ShellContext.Theme.Accent      = '#7C6AF7'
        $Global:ShellContext.Theme.AccentHover = '#9D8FFF'
        $Global:ShellContext.Theme.Text        = '#CDD6F4'
        $Global:ShellContext.Theme.TextMuted   = '#7F849C'
        $Global:ShellContext.Theme.Border      = '#45475A'
        $Global:ShellContext.Theme.Danger      = '#F38BA8'
        $Global:ShellContext.Theme.Success     = '#A6E3A1'
    }

    if ($Window) {
        $Window.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom($Global:ShellContext.Theme.Background)
    }
    if ($HeaderBar) {
        $HeaderBar.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom($Global:ShellContext.Theme.Surface)
    }
    if ($FooterBar) {
        $FooterBar.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom($Global:ShellContext.Theme.Surface)
    }
    if ($TxtStatus) {
        $TxtStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($Global:ShellContext.Theme.TextMuted)
    }
    if ($TxtCommonInfo) {
        $TxtCommonInfo.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($Global:ShellContext.Theme.Text)
    }
    if ($TxtDiagnostics) {
        $TxtDiagnostics.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($Global:ShellContext.Theme.Text)
        $TxtDiagnostics.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom($Global:ShellContext.Theme.Surface)
        $TxtDiagnostics.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFrom($Global:ShellContext.Theme.Border)
    }
    if ($BtnThemeToggle) {
        $BtnThemeToggle.Content = if ($Mode -eq 'Dark') { '🌞 Light' } else { '🌙 Dark' }
    }
}

function Set-CommonSetting {
    param(
        [string]$Name,
        [object]$Value
    )

    switch ($Name) {
        "OutputCopyFormat" {
            $Global:ShellContext.CommonSettings.OutputCopyFormat = $Value
            $TxtCommonInfo.Text = "Selected format: $Value"
            Set-Status "Copy format set to $Value" "#A6E3A1"
            return
        }
        "Mode" {
            $Global:ShellContext.CommonSettings.Mode = $Value
            Set-Theme -Mode $Value
            Set-Status "Mode switched to $Value" "#A6E3A1"
            return
        }
        default {
            $Global:ShellContext.CommonSettings.$Name = $Value
            return
        }
    }
}

function Get-ClipboardTimestamp {
    $now = Get-Date
    $tz = [TimeZoneInfo]::Local
    return "{0} ({1} | {2})" -f $now.ToString('dddd, yyyy-MM-dd HH:mm:ss zzz'), $tz.Id, $tz.DisplayName
}

function ConvertTo-ShellClipboardText {
    param(
        [string]$Title,
        [object]$Data,
        [string]$Format,
        [string]$Timestamp,
        [string]$Source = 'Shell'
    )

    $bodyText = ''
    if ($Data -is [string]) {
        $bodyText = $Data
    }
    elseif ($null -eq $Data) {
        $bodyText = ''
    }
    else {
        $items = @($Data)
        if ($items.Count -gt 1) {
            $bodyText = $items | Format-Table -AutoSize | Out-String -Width 4096
        }
        elseif ($items.Count -eq 1) {
            $bodyText = $items[0] | Format-List * | Out-String -Width 4096
        }
    }

    switch ($Format) {
        'JSON' {
            $payload = [ordered]@{
                Title     = $Title
                Source    = $Source
                Timestamp = $Timestamp
                Data      = $Data
            }
            return $payload | ConvertTo-Json -Depth 12
        }
        'PSObject' {
            $payload = [PSCustomObject]@{
                Title     = $Title
                Source    = $Source
                Timestamp = $Timestamp
                Data      = $Data
            }
            return $payload | Format-List * | Out-String -Width 4096
        }
        'Markdown' {
            $safeBody = if ([string]::IsNullOrWhiteSpace($bodyText)) { '_No content_' } else { @('```text', $bodyText.TrimEnd(), '```') -join [Environment]::NewLine }
            return @(
                "# $Title"
                ""
                "- Source: $Source"
                "- Timestamp: $Timestamp"
                ""
                "## Data"
                $safeBody
            ) -join [Environment]::NewLine
        }
        'HTML' {
            $safeTitle = [System.Security.SecurityElement]::Escape($Title)
            $safeSource = [System.Security.SecurityElement]::Escape($Source)
            $safeTimestamp = [System.Security.SecurityElement]::Escape($Timestamp)

            if ($Data -is [string] -or $null -eq $Data) {
                $safeBody = [System.Security.SecurityElement]::Escape([string]$bodyText)
                return @"
<html><body>
<h1>$safeTitle</h1>
<p><strong>Source:</strong> $safeSource<br/>
<strong>Timestamp:</strong> $safeTimestamp</p>
<pre>$safeBody</pre>
</body></html>
"@
            }

            $table = @($Data) | ConvertTo-Html -Fragment
            return @"
<html><body>
<h1>$safeTitle</h1>
<p><strong>Source:</strong> $safeSource<br/>
<strong>Timestamp:</strong> $safeTimestamp</p>
$table
</body></html>
"@
        }
        default {
            return @(
                "Title: $Title"
                "Source: $Source"
                "Timestamp: $Timestamp"
                ""
                ($bodyText.TrimEnd())
            ) -join [Environment]::NewLine
        }
    }
}

function Copy-ShellDataToClipboard {
    param(
        [string]$Title,
        [object]$Data,
        [string]$Source = 'Shell'
    )

    $format = $Global:ShellContext.CommonSettings.OutputCopyFormat
    $timestamp = Get-ClipboardTimestamp
    $text = ConvertTo-ShellClipboardText -Title $Title -Data $Data -Format $format -Timestamp $timestamp -Source $Source

    Set-Clipboard -Value $text
    $TxtCommonInfo.Text = "Copied '$Title' as $format at $timestamp"
    Set-Status "Copied $Title to clipboard" "#A6E3A1"
}

# ─────────────────────────────────────────────────────────────
# ORDER PERSISTENCE
# tab-order.json = ordered array of FileName strings.
# ─────────────────────────────────────────────────────────────
function Read-TabOrder {
    if (Test-Path $OrderFile) {
        try {
            $raw = Get-Content $OrderFile -Raw | ConvertFrom-Json
            return [System.Collections.Generic.List[string]]($raw)
        }
        catch {}
    }
    return [System.Collections.Generic.List[string]]::new()
}

function Save-TabOrder {
    param([System.Collections.Generic.List[string]]$Order)
    try {
        $Order | ConvertTo-Json -Compress | Set-Content $OrderFile -Encoding UTF8
    }
    catch {}
}

# ─────────────────────────────────────────────────────────────
# DISCOVERY + SORT
#  1.  Scan modules\ for Tab-*.ps1
#  2.  Read metadata header (no dot-source)
#  3.  New files (not in saved order) → prepend, newest-first
#  4.  Saved-order files follow in their saved positions
# ─────────────────────────────────────────────────────────────
function Get-SortedModuleList {
    if (-not (Test-Path $ModulesPath)) { return @() }

    $files = Get-ChildItem -Path $ModulesPath -Filter 'Tab-*.ps1' -File
    if (-not $files) { return @() }

    $metaMap = @{}
    foreach ($f in $files) {
        $metaMap[$f.Name] = (Read-ModuleMetadata -File $f)
    }

    $savedOrder = Read-TabOrder
    $knownNames = [System.Collections.Generic.HashSet[string]]$savedOrder

    # Files on disk that are NOT yet in the saved order (brand-new)
    $newFiles = $files |
        Where-Object { -not $knownNames.Contains($_.Name) } |
        Sort-Object LastWriteTime -Descending   # newest → leftmost

    $result = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Prepend new files
    foreach ($nf in $newFiles) {
        $result.Add($metaMap[$nf.Name])
    }

    # Then the saved-order files that still exist on disk
    foreach ($name in $savedOrder) {
        if ($metaMap.ContainsKey($name)) {
            $result.Add($metaMap[$name])
        }
        # Files deleted from disk are silently skipped
    }

    return $result
}

# ─────────────────────────────────────────────────────────────
# BUILD SHELL WINDOW
# ─────────────────────────────────────────────────────────────
[xml]$ShellXaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="PowerShell WPF Shell"
    Height="720" Width="1100"
    MinHeight="480" MinWidth="700"
    WindowStartupLocation="CenterScreen"
    Background="#1E1E2E"
    Foreground="#CDD6F4"
    FontFamily="Segoe UI"
    FontSize="13">

  <Window.Resources>

    <Style x:Key="ShellTabControl" TargetType="TabControl">
      <Setter Property="Background"        Value="#1E1E2E"/>
      <Setter Property="BorderThickness"   Value="0"/>
      <Setter Property="Padding"           Value="0"/>
      <Setter Property="TabStripPlacement" Value="Top"/>
    </Style>

    <Style x:Key="ShellTabItem" TargetType="TabItem">
      <Setter Property="Background"      Value="#2A2A3E"/>
      <Setter Property="Foreground"      Value="#7F849C"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding"         Value="14,9"/>
      <Setter Property="FontSize"        Value="13"/>
      <Setter Property="Cursor"          Value="Hand"/>
      <Setter Property="AllowDrop"       Value="True"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabItem">
            <Border x:Name="Bd"
                    Background="{TemplateBinding Background}"
                    BorderThickness="0,0,0,2"
                    BorderBrush="Transparent"
                    Padding="{TemplateBinding Padding}"
                    Margin="0,0,1,0">
              <ContentPresenter ContentSource="Header"
                                HorizontalAlignment="Center"
                                VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="Bd" Property="Background"  Value="#1E1E2E"/>
                <Setter TargetName="Bd" Property="BorderBrush" Value="#7C6AF7"/>
                <Setter Property="Foreground"                  Value="#CDD6F4"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#252535"/>
                <Setter Property="Foreground"                 Value="#CDD6F4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Applied to the tab currently being hovered over during a drag -->
    <Style x:Key="TabItem_DropTarget" TargetType="TabItem"
           BasedOn="{StaticResource ShellTabItem}">
      <Setter Property="Background" Value="#3A2A6E"/>
    </Style>

    <Style x:Key="ShellButton" TargetType="Button">
      <Setter Property="Background"      Value="#7C6AF7"/>
      <Setter Property="Foreground"      Value="#FFFFFF"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding"         Value="12,6"/>
      <Setter Property="Cursor"          Value="Hand"/>
      <Setter Property="FontSize"        Value="12"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bd" Background="{TemplateBinding Background}"
                    CornerRadius="4" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center"
                                VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#9D8FFF"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#6457D4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

  </Window.Resources>

  <DockPanel LastChildFill="True">

    <!-- Title bar -->
    <Border x:Name="HeaderBar" DockPanel.Dock="Top" Background="#16161E"
            BorderBrush="#45475A" BorderThickness="0,0,0,1" Padding="16,9">
      <DockPanel>
        <StackPanel DockPanel.Dock="Left" Orientation="Horizontal">
          <TextBlock Text="🧩" FontFamily="Segoe UI Emoji" Foreground="#7C6AF7" FontSize="18"
                     VerticalAlignment="Center" Margin="0,0,8,0"/>
          <TextBlock Text="PowerShell WPF Shell" FontWeight="SemiBold"
                     Foreground="#CDD6F4" FontSize="14" VerticalAlignment="Center"/>
        </StackPanel>
        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal"
                    HorizontalAlignment="Right">
          <Button x:Name="BtnReload" Style="{StaticResource ShellButton}"
              Content="🔄  Reload" Margin="0,0,8,0"
                  ToolTip="Re-scan modules folder and reload all tabs"/>
          <Button x:Name="BtnThemeToggle" Style="{StaticResource ShellButton}"
              Background="#2A2A3E" Content="🌞 Light" Margin="0,0,8,0"
                  ToolTip="Toggle light/dark mode"/>
          <Button x:Name="BtnAddFile" Style="{StaticResource ShellButton}"
              Background="#2A2A3E" Content="➕  Add tab"/>
        </StackPanel>
        <TextBlock x:Name="TxtClock" DockPanel.Dock="Right"
                   Foreground="#7F849C" FontSize="11"
                   VerticalAlignment="Center" HorizontalAlignment="Right"
                   Margin="0,0,16,0"/>
      </DockPanel>
    </Border>

    <!-- Status bar + common info pane -->
    <Border x:Name="FooterBar" DockPanel.Dock="Bottom" Background="#16161E"
            BorderBrush="#45475A" BorderThickness="0,1,0,0" Padding="16,8">
      <StackPanel>
        <DockPanel Margin="0,0,0,6">
          <TextBlock x:Name="TxtStatus"
                     Foreground="#7F849C" FontSize="11"
                     VerticalAlignment="Center" Text="Ready"/>
          <TextBlock x:Name="TxtTabCount" DockPanel.Dock="Right"
                     Foreground="#7F849C" FontSize="11"
                     HorizontalAlignment="Right" VerticalAlignment="Center"/>
        </DockPanel>
        <WrapPanel VerticalAlignment="Center">
          <TextBlock Text="Copy format:" Foreground="#CDD6F4" FontSize="11"
                     VerticalAlignment="Center" Margin="0,0,10,0"/>
          <RadioButton x:Name="RbFormatText" GroupName="ClipboardFormat"
                       Content="Text" Foreground="#CDD6F4" FontSize="11"
                       IsChecked="True" Margin="0,0,8,0"/>
          <RadioButton x:Name="RbFormatPSObject" GroupName="ClipboardFormat"
                       Content="PSObject" Foreground="#CDD6F4" FontSize="11"
                       Margin="0,0,8,0"/>
          <RadioButton x:Name="RbFormatJSON" GroupName="ClipboardFormat"
                       Content="JSON" Foreground="#CDD6F4" FontSize="11"
                       Margin="0,0,8,0"/>
          <RadioButton x:Name="RbFormatMarkdown" GroupName="ClipboardFormat"
                       Content="Markdown" Foreground="#CDD6F4" FontSize="11"
                       Margin="0,0,8,0"/>
          <RadioButton x:Name="RbFormatHTML" GroupName="ClipboardFormat"
                       Content="HTML" Foreground="#CDD6F4" FontSize="11"/>
        </WrapPanel>
        <TextBlock x:Name="TxtCommonInfo"
                   Foreground="#7F849C" FontSize="11"
                   Margin="0,6,0,0"
                   Text="Selected format: Text"/>
        <DockPanel Margin="0,10,0,4">
          <TextBlock Text="Diagnostics:" Foreground="#CDD6F4" FontSize="11"
                 VerticalAlignment="Center"/>
          <Button x:Name="BtnCopyDiagnostics"
              Content="Copy"
              DockPanel.Dock="Right"
              Padding="10,2"
              Background="#2A2A3E"
              Foreground="#CDD6F4"
              BorderThickness="0"
              FontSize="11"
              Cursor="Hand"/>
        </DockPanel>
        <TextBox x:Name="TxtDiagnostics"
                 Height="80"
                 TextWrapping="Wrap"
                 VerticalScrollBarVisibility="Auto"
                 HorizontalScrollBarVisibility="Disabled"
                 IsReadOnly="True"
                 AcceptsReturn="True"
                 Foreground="#CDD6F4"
                 Background="#16161E"
                 BorderBrush="#45475A"
                 BorderThickness="1"
                 FontSize="11"
                 Margin="0,0,0,0"/>
      </StackPanel>
    </Border>

    <TabControl x:Name="MainTabControl"
                Style="{StaticResource ShellTabControl}"/>
  </DockPanel>
</Window>
'@

$Reader = [System.Xml.XmlNodeReader]::new($ShellXaml)
$Window = [Windows.Markup.XamlReader]::Load($Reader)

$TabControl    = $Window.FindName("MainTabControl")
$TxtStatus     = $Window.FindName("TxtStatus")
$TxtTabCount   = $Window.FindName("TxtTabCount")
$TxtClock      = $Window.FindName("TxtClock")
$TxtCommonInfo = $Window.FindName("TxtCommonInfo")
$TxtDiagnostics = $Window.FindName("TxtDiagnostics")
$BtnCopyDiagnostics = $Window.FindName("BtnCopyDiagnostics")
$HeaderBar     = $Window.FindName("HeaderBar")
$FooterBar     = $Window.FindName("FooterBar")

$RbFormatText    = $Window.FindName("RbFormatText")
$RbFormatPSObject= $Window.FindName("RbFormatPSObject")
$RbFormatJSON    = $Window.FindName("RbFormatJSON")
$RbFormatMarkdown= $Window.FindName("RbFormatMarkdown")
$RbFormatHTML    = $Window.FindName("RbFormatHTML")
$BtnThemeToggle  = $Window.FindName("BtnThemeToggle")

$Global:ShellContext.Window      = $Window
$Global:ShellContext.TabControl  = $TabControl
$Global:ShellContext.StatusBar   = $TxtStatus
$Global:ShellContext.CommonInfo  = $TxtCommonInfo
$Global:ShellContext.DiagnosticsBox = $TxtDiagnostics

Set-Theme -Mode $Global:ShellContext.CommonSettings.Mode

$RbFormatText.Add_Checked({ if ($RbFormatText.IsChecked)    { Set-CommonSetting -Name 'OutputCopyFormat' -Value 'Text' } })
$RbFormatPSObject.Add_Checked({ if ($RbFormatPSObject.IsChecked){ Set-CommonSetting -Name 'OutputCopyFormat' -Value 'PSObject' } })
$RbFormatJSON.Add_Checked({ if ($RbFormatJSON.IsChecked)    { Set-CommonSetting -Name 'OutputCopyFormat' -Value 'JSON' } })
$RbFormatMarkdown.Add_Checked({ if ($RbFormatMarkdown.IsChecked){ Set-CommonSetting -Name 'OutputCopyFormat' -Value 'Markdown' } })
$RbFormatHTML.Add_Checked({ if ($RbFormatHTML.IsChecked)    { Set-CommonSetting -Name 'OutputCopyFormat' -Value 'HTML' } })

$BtnThemeToggle.Add_Click({
    $newMode = if ($Global:ShellContext.CommonSettings.Mode -eq 'Dark') { 'Light' } else { 'Dark' }
    Set-CommonSetting -Name 'Mode' -Value $newMode
})

$Global:ShellContext.SetCommonSetting = {
    param($Name, $Value)
    Set-CommonSetting -Name $Name -Value $Value
}

$Global:ShellContext.CopyToClipboard = {
    param($Title, $Data, $Source)
    Copy-ShellDataToClipboard -Title $Title -Data $Data -Source $Source
}

$BtnCopyDiagnostics.Add_Click({
    Copy-ShellDataToClipboard -Title 'Diagnostics' -Data $TxtDiagnostics.Text -Source 'Main Shell'
})

# ─────────────────────────────────────────────────────────────
# ORDER SYNC  — reads current tab positions → writes JSON
# ─────────────────────────────────────────────────────────────
function Sync-TabOrder {
    $order = [System.Collections.Generic.List[string]]::new()
    foreach ($tab in $TabControl.Items) {
        if ($tab.Tag -and $tab.Tag.FileName) {
            $order.Add($tab.Tag.FileName)
        }
    }
    Save-TabOrder -Order $order
}

# ─────────────────────────────────────────────────────────────
# TAB HEADER  (icon + title + close button)
# ─────────────────────────────────────────────────────────────
function New-TabHeader {
    param(
        [PSCustomObject]$Meta,
        [System.Windows.Controls.TabItem]$TabItem
    )

    $panel             = [System.Windows.Controls.StackPanel]::new()
    $panel.Orientation = "Horizontal"

    $iconTxt        = [System.Windows.Controls.TextBlock]::new()
    $iconTxt.Text   = $Meta.Icon
    $iconTxt.Margin = [System.Windows.Thickness]::new(0, 0, 6, 0)
    $iconTxt.FontFamily = [System.Windows.Media.FontFamily]::new('Segoe UI Emoji')
    [void]$panel.Children.Add($iconTxt)

    $titleTxt      = [System.Windows.Controls.TextBlock]::new()
    $titleTxt.Text = $Meta.Title
    [void]$panel.Children.Add($titleTxt)

    $closeBtn                 = [System.Windows.Controls.Button]::new()
    $closeBtn.Content         = " ×"
    $closeBtn.Background      = [System.Windows.Media.Brushes]::Transparent
    $closeBtn.BorderThickness = [System.Windows.Thickness]::new(0)
    $closeBtn.Foreground      = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#7F849C")
    $closeBtn.FontSize        = 14
    $closeBtn.Cursor          = [System.Windows.Input.Cursors]::Hand
    $closeBtn.Padding         = [System.Windows.Thickness]::new(4, 0, 0, 0)
    $closeBtn.Tag             = $TabItem

    $closeBtn.Add_Click({
        param($s, $e)
        $TabControl.Items.Remove($s.Tag)
        Sync-TabOrder
        $TxtTabCount.Text = "$($TabControl.Items.Count) tab(s)"
        $e.Handled = $true
    })
    [void]$panel.Children.Add($closeBtn)

    return $panel
}

# ─────────────────────────────────────────────────────────────
# TAB DRAG-TO-REORDER
# Each TabItem participates as both drag source and drop target.
# ─────────────────────────────────────────────────────────────
$Script:DragSource     = $null
$Script:DragLastTarget = $null
$Script:DragStartPoint = $null
$Script:DragInProgress = $false

function Add-DragHandlers {
    param([System.Windows.Controls.TabItem]$Tab)

    # Record the tab that had its mouse button pressed
    $Tab.Add_PreviewMouseLeftButtonDown({
        param($s, $e)
        if ($e.OriginalSource -is [System.Windows.Controls.Button]) {
            $Script:DragSource = $null
            $Script:DragStartPoint = $null
            return
        }
        $Script:DragSource = $s
        $Script:DragStartPoint = $e.GetPosition($Window)
    })

    $Tab.Add_PreviewMouseLeftButtonUp({
        $Script:DragSource = $null
        $Script:DragStartPoint = $null
    })

    # Start drag once mouse moves past system threshold
    $Tab.Add_PreviewMouseMove({
        param($s, $e)
        if ($e.LeftButton -ne 'Pressed' -or $null -eq $Script:DragSource -or $null -eq $Script:DragStartPoint -or $Script:DragInProgress) { return }

        $minX = [System.Windows.SystemParameters]::MinimumHorizontalDragDistance
        $minY = [System.Windows.SystemParameters]::MinimumVerticalDragDistance
        $pos  = $e.GetPosition($Window)
        if ([Math]::Abs($pos.X - $Script:DragStartPoint.X) -lt $minX -and [Math]::Abs($pos.Y - $Script:DragStartPoint.Y) -lt $minY) { return }

        $data = [System.Windows.DataObject]::new("ShellTabItem", $Script:DragSource)
        $Script:DragInProgress = $true
        try {
            [System.Windows.DragDrop]::DoDragDrop($Script:DragSource, $data, 'Move') | Out-Null
        }
        finally {
            $Script:DragInProgress = $false
            $Script:DragSource = $null
            $Script:DragStartPoint = $null
        }
    })

    # Highlight the tab being dragged over
    $Tab.Add_DragOver({
        param($s, $e)
        if (-not $e.Data.GetDataPresent("ShellTabItem")) { return }
        $src = $e.Data.GetData("ShellTabItem")
        if ($src -eq $s) { $e.Effects = 'None'; $e.Handled = $true; return }

        $e.Effects = 'Move'

        if ($Script:DragLastTarget -and $Script:DragLastTarget -ne $s) {
            $Script:DragLastTarget.Style = $Window.FindResource("ShellTabItem")
        }
        $s.Style = $Window.FindResource("TabItem_DropTarget")
        $Script:DragLastTarget = $s
        $e.Handled = $true
    })

    # Remove highlight when drag leaves
    $Tab.Add_DragLeave({
        param($s, $e)
        $s.Style = $Window.FindResource("ShellTabItem")
        if ($Script:DragLastTarget -eq $s) { $Script:DragLastTarget = $null }
    })

    # Perform the reorder on drop
    $Tab.Add_Drop({
        param($s, $e)
        $s.Style = $Window.FindResource("ShellTabItem")
        $Script:DragLastTarget = $null
        if (-not $e.Data.GetDataPresent("ShellTabItem")) { return }

        $src    = $e.Data.GetData("ShellTabItem")
        if ($src -eq $s) { return }

        $srcIdx = $TabControl.Items.IndexOf($src)
        $dstIdx = $TabControl.Items.IndexOf($s)
        if ($srcIdx -lt 0 -or $dstIdx -lt 0) { return }

        $TabControl.Items.Remove($src)
        $TabControl.Items.Insert($dstIdx, $src)
        $TabControl.SelectedItem = $src

        Sync-TabOrder
        Set-Status "Order saved" "#A6E3A1"
        $e.Handled = $true
    })
}

# ─────────────────────────────────────────────────────────────
# LOAD ONE MODULE  (dot-source + call Get-ModuleUI)
# ─────────────────────────────────────────────────────────────
function Import-ModuleTab {
    param([PSCustomObject]$Meta)

    # Wrap content in a scroll viewer (automatic responsiveness)
    $scroll                                  = [System.Windows.Controls.ScrollViewer]::new()
    $scroll.HorizontalScrollBarVisibility    = "Disabled"
    $scroll.VerticalScrollBarVisibility      = "Auto"
    $scroll.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#1E1E2E")

    try {
        $invoke = [scriptblock]::Create(
            ". '$($Meta.FullPath)'; Get-ModuleUI -ShellContext `$args[0]"
        )
        $ui = & $invoke $Global:ShellContext

        if ($ui -is [System.Windows.UIElement]) {
            $scroll.Content = $ui
        } else {
            throw "Get-ModuleUI returned: $($ui.GetType().FullName)"
        }
    }
    catch {
        $errBlock              = [System.Windows.Controls.TextBlock]::new()
        $errBlock.Text         = "⚠ Could not load: $($Meta.FileName)`n`n$($_.Exception.Message)"
        $errBlock.Foreground   = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#F38BA8")
        $errBlock.Margin       = [System.Windows.Thickness]::new(24)
        $errBlock.TextWrapping = "Wrap"
        $scroll.Content        = $errBlock
    }

    $tab           = [System.Windows.Controls.TabItem]::new()
    $tab.Style     = $Window.FindResource("ShellTabItem")
    $tab.AllowDrop = $true
    $tab.Content   = $scroll
    $tab.Tag       = $Meta      # FileName stored here for Sync-TabOrder
    $tab.Header    = New-TabHeader -Meta $Meta -TabItem $tab

    Add-DragHandlers -Tab $tab
    return $tab
}

# ─────────────────────────────────────────────────────────────
# FULL RELOAD
# ─────────────────────────────────────────────────────────────
function Invoke-ReloadModules {
    $TabControl.Items.Clear()

    $sorted = Get-SortedModuleList
    if (-not $sorted -or @($sorted).Count -eq 0) {
        Set-Status "No Tab-*.ps1 modules found in: $ModulesPath" "#F38BA8"
        return
    }

    $n = 0
    foreach ($meta in $sorted) {
        Set-Status "Loading $($meta.Title)..."
        $tab = Import-ModuleTab -Meta $meta
        [void]$TabControl.Items.Add($tab)
        $n++
    }

    if ($TabControl.Items.Count -gt 0) { $TabControl.SelectedIndex = 0 }
    $TxtTabCount.Text = "$n tab(s) loaded"
    Set-Status "OK: $n module(s) ready" "#A6E3A1"

    Sync-TabOrder   # persist the order that was just established
}

# ─────────────────────────────────────────────────────────────
# ADD TAB FROM FILE PICKER  (➕ button)
# ─────────────────────────────────────────────────────────────
function Add-TabFromFile {
    $ofd                    = [System.Windows.Forms.OpenFileDialog]::new()
    $ofd.Filter             = "PowerShell Module (*.ps1)|*.ps1"
    $ofd.Title              = "Load a module tab"
    $ofd.InitialDirectory   = $ModulesPath
    if ($ofd.ShowDialog() -ne "OK") { return }

    $file = Get-Item $ofd.FileName
    $meta = Read-ModuleMetadata -File $file

    # Already loaded? Just switch to it.
    foreach ($existing in $TabControl.Items) {
        if ($existing.Tag -and $existing.Tag.FileName -eq $file.Name) {
            $TabControl.SelectedItem = $existing
            Set-Status "Already loaded: $($meta.Title)" "#7F849C"
            return
        }
    }

    # Insert at position 0 (newest = leftmost)
    $tab = Import-ModuleTab -Meta $meta
    $TabControl.Items.Insert(0, $tab)
    $TabControl.SelectedItem = $tab
    $TxtTabCount.Text = "$($TabControl.Items.Count) tab(s)"
    Sync-TabOrder
    Set-Status "✓ Loaded: $($meta.Title)" "#A6E3A1"
}

# ─────────────────────────────────────────────────────────────
# CLOCK
# ─────────────────────────────────────────────────────────────
$ClockTimer          = [System.Windows.Threading.DispatcherTimer]::new()
$ClockTimer.Interval = [TimeSpan]::FromSeconds(1)
$ClockTimer.Add_Tick({ $TxtClock.Text = (Get-Date -Format "ddd dd MMM  HH:mm:ss") })
$ClockTimer.Start()

# ─────────────────────────────────────────────────────────────
# BUTTON EVENTS
# ─────────────────────────────────────────────────────────────
$Window.FindName("BtnReload").Add_Click({
    Set-Status "Reloading modules…"
    Invoke-ReloadModules
})

$Window.FindName("BtnAddFile").Add_Click({
    Add-TabFromFile
})

# ─────────────────────────────────────────────────────────────
# PERSIST ON CLOSE
# ─────────────────────────────────────────────────────────────
$Window.Add_Closing({ Sync-TabOrder })

# ─────────────────────────────────────────────────────────────
# GO
# ─────────────────────────────────────────────────────────────
Invoke-ReloadModules
$Window.ShowDialog() | Out-Null
