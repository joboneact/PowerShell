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
    Window      = $null
    TabControl  = $null
    StatusBar   = $null
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
    <Border DockPanel.Dock="Top" Background="#16161E"
            BorderBrush="#45475A" BorderThickness="0,0,0,1" Padding="16,9">
      <DockPanel>
        <StackPanel DockPanel.Dock="Left" Orientation="Horizontal">
          <TextBlock Text="⬡" Foreground="#7C6AF7" FontSize="18"
                     VerticalAlignment="Center" Margin="0,0,8,0"/>
          <TextBlock Text="PowerShell WPF Shell" FontWeight="SemiBold"
                     Foreground="#CDD6F4" FontSize="14" VerticalAlignment="Center"/>
        </StackPanel>
        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal"
                    HorizontalAlignment="Right">
          <Button x:Name="BtnReload" Style="{StaticResource ShellButton}"
                  Content="↺  Reload" Margin="0,0,8,0"
                  ToolTip="Re-scan modules folder and reload all tabs"/>
          <Button x:Name="BtnAddFile" Style="{StaticResource ShellButton}"
                  Background="#2A2A3E" Content="＋  Add tab"/>
        </StackPanel>
        <TextBlock x:Name="TxtClock" DockPanel.Dock="Right"
                   Foreground="#7F849C" FontSize="11"
                   VerticalAlignment="Center" HorizontalAlignment="Right"
                   Margin="0,0,16,0"/>
      </DockPanel>
    </Border>

    <!-- Status bar -->
    <Border DockPanel.Dock="Bottom" Background="#16161E"
            BorderBrush="#45475A" BorderThickness="0,1,0,0" Padding="16,4">
      <DockPanel>
        <TextBlock x:Name="TxtStatus"
                   Foreground="#7F849C" FontSize="11"
                   VerticalAlignment="Center" Text="Ready"/>
        <TextBlock x:Name="TxtTabCount" DockPanel.Dock="Right"
                   Foreground="#7F849C" FontSize="11"
                   HorizontalAlignment="Right" VerticalAlignment="Center"/>
      </DockPanel>
    </Border>

    <TabControl x:Name="MainTabControl"
                Style="{StaticResource ShellTabControl}"/>
  </DockPanel>
</Window>
'@

$Reader = [System.Xml.XmlNodeReader]::new($ShellXaml)
$Window = [Windows.Markup.XamlReader]::Load($Reader)

$TabControl  = $Window.FindName("MainTabControl")
$TxtStatus   = $Window.FindName("TxtStatus")
$TxtTabCount = $Window.FindName("TxtTabCount")
$TxtClock    = $Window.FindName("TxtClock")

$Global:ShellContext.Window     = $Window
$Global:ShellContext.TabControl = $TabControl
$Global:ShellContext.StatusBar  = $TxtStatus

# ─────────────────────────────────────────────────────────────
# STATUS HELPER
# ─────────────────────────────────────────────────────────────
function Set-Status {
    param([string]$Msg, [string]$Color = "#7F849C")
    $TxtStatus.Text       = $Msg
    $TxtStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($Color)
}

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

function Add-DragHandlers {
    param([System.Windows.Controls.TabItem]$Tab)

    # Record the tab that had its mouse button pressed
    $Tab.Add_PreviewMouseLeftButtonDown({
        param($s, $e)
        $Script:DragSource = $s
    })

    $Tab.Add_PreviewMouseLeftButtonUp({
        $Script:DragSource = $null
    })

    # Start drag once mouse moves past system threshold
    $Tab.Add_PreviewMouseMove({
        param($s, $e)
        if ($e.LeftButton -ne 'Pressed' -or $null -eq $Script:DragSource) { return }

        $minX = [System.Windows.SystemParameters]::MinimumHorizontalDragDistance
        $minY = [System.Windows.SystemParameters]::MinimumVerticalDragDistance
        $pos  = $e.GetPosition($s)
        if ([Math]::Abs($pos.X) -lt $minX -and [Math]::Abs($pos.Y) -lt $minY) { return }

        $data = [System.Windows.DataObject]::new("ShellTabItem", $Script:DragSource)
        [System.Windows.DragDrop]::DoDragDrop($Script:DragSource, $data, 'Move') | Out-Null
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
        Set-Status "Loading $($meta.Title)…"
        $tab = Import-ModuleTab -Meta $meta
        [void]$TabControl.Items.Add($tab)
        $n++
    }

    if ($TabControl.Items.Count -gt 0) { $TabControl.SelectedIndex = 0 }
    $TxtTabCount.Text = "$n tab(s) loaded"
    Set-Status "✓ $n module(s) ready" "#A6E3A1"

    Sync-TabOrder   # persist the order that was just established
}

# ─────────────────────────────────────────────────────────────
# ADD TAB FROM FILE PICKER  (＋ button)
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
