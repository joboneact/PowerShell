#Requires -Version 5.1
## ShellMeta:Title    Dashboard
## ShellMeta:Icon     ⬡
## ShellMeta:Version  1.0
## ShellMeta:Author   WpfShell
<#
.SYNOPSIS
    Module Tab: Dashboard — system stats overview.
    Shell discovers this tab automatically from the ShellMeta header above.
    No registration in Main-Shell.ps1 needed.
#>

Add-Type -AssemblyName PresentationFramework

function Get-ModuleUI {
    param([PSCustomObject]$ShellContext)

    $Theme = $ShellContext.Theme

    [xml]$Xaml = @"
<UserControl
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Background="$($Theme.Background)">

    <ScrollViewer HorizontalScrollBarVisibility="Disabled"
                  VerticalScrollBarVisibility="Auto">
        <StackPanel Margin="28,24,28,24">

            <!-- Header -->
            <TextBlock Text="Dashboard"
                       FontSize="22" FontWeight="Bold"
                       Foreground="$($Theme.Text)"
                       Margin="0,0,0,4"/>
            <TextBlock x:Name="TxtSubhead"
                       FontSize="12"
                       Foreground="$($Theme.TextMuted)"
                       Margin="0,0,0,24"/>

            <!-- Stat Cards (WrapPanel so they're responsive) -->
            <WrapPanel x:Name="StatsPanel" Margin="0,0,0,28"/>

            <!-- Recent Activity -->
            <TextBlock Text="System Snapshot"
                       FontSize="14" FontWeight="SemiBold"
                       Foreground="$($Theme.Text)"
                       Margin="0,0,0,10"/>
            <Border Background="$($Theme.Surface)"
                    CornerRadius="6"
                    Padding="16">
                <TextBlock x:Name="TxtSnapshot"
                           Foreground="$($Theme.Text)"
                           FontFamily="Consolas"
                           FontSize="12"
                           TextWrapping="Wrap"/>
            </Border>

        </StackPanel>
    </ScrollViewer>
</UserControl>
"@

    $Reader  = [System.Xml.XmlNodeReader]::new($Xaml)
    $Control = [Windows.Markup.XamlReader]::Load($Reader)

    $StatsPanel  = $Control.FindName("StatsPanel")
    $TxtSubhead  = $Control.FindName("TxtSubhead")
    $TxtSnapshot = $Control.FindName("TxtSnapshot")

    # ── Build a stat card helper ──────────────
    function New-StatCard {
        param([string]$Label, [string]$Value, [string]$Icon, [string]$Color)

        $Card = [System.Windows.Controls.Border]::new()
        $Card.Background    = [System.Windows.Media.BrushConverter]::new().ConvertFrom($Theme.Surface)
        $Card.CornerRadius  = [System.Windows.CornerRadius]::new(8)
        $Card.Padding       = [System.Windows.Thickness]::new(20,16,20,16)
        $Card.Margin        = [System.Windows.Thickness]::new(0,0,12,12)
        $Card.MinWidth      = 160

        $Stack = [System.Windows.Controls.StackPanel]::new()

        $Row = [System.Windows.Controls.DockPanel]::new()

        $IconTxt = [System.Windows.Controls.TextBlock]::new()
        $IconTxt.Text      = $Icon
        $IconTxt.FontSize  = 20
        $IconTxt.Margin    = [System.Windows.Thickness]::new(0,0,0,8)
        [void]$Stack.Children.Add($IconTxt)

        $ValTxt = [System.Windows.Controls.TextBlock]::new()
        $ValTxt.Text       = $Value
        $ValTxt.FontSize   = 24
        $ValTxt.FontWeight = "Bold"
        $ValTxt.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($Color)
        [void]$Stack.Children.Add($ValTxt)

        $LblTxt = [System.Windows.Controls.TextBlock]::new()
        $LblTxt.Text       = $Label
        $LblTxt.FontSize   = 11
        $LblTxt.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($Theme.TextMuted)
        $LblTxt.Margin     = [System.Windows.Thickness]::new(0,2,0,0)
        [void]$Stack.Children.Add($LblTxt)

        $Card.Child = $Stack
        return $Card
    }

    # ── Populate data ─────────────────────────
    $OS      = [System.Environment]::OSVersion.VersionString
    $Machine = $env:COMPUTERNAME
    $User    = $env:USERNAME
    $PSVer   = $PSVersionTable.PSVersion.ToString()
    $Uptime  = (Get-Date) - [System.Diagnostics.Process]::GetCurrentProcess().StartTime
    $CPU     = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue |
                Select-Object -First 1).Name
    $RAM     = [math]::Round((Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).TotalPhysicalMemory / 1GB, 1)
    $FreeRAM = [math]::Round((Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).FreePhysicalMemory / 1MB, 1)

    $TxtSubhead.Text = "Host: $Machine  ·  User: $User  ·  PowerShell $PSVer"

    # Cards
    [void]$StatsPanel.Children.Add((New-StatCard -Label "Total RAM"   -Value "${RAM} GB"  -Icon "🧠" -Color $Theme.Accent))
    [void]$StatsPanel.Children.Add((New-StatCard -Label "Free RAM"    -Value "${FreeRAM} GB" -Icon "💾" -Color $Theme.Success))
    [void]$StatsPanel.Children.Add((New-StatCard -Label "PS Version"  -Value $PSVer        -Icon "⚡" -Color $Theme.AccentHover))
    [void]$StatsPanel.Children.Add((New-StatCard -Label "Shell PID"   -Value $PID          -Icon "🔢" -Color $Theme.TextMuted))

    $TxtSnapshot.Text = @"
OS       : $OS
Machine  : $Machine
User     : $User
CPU      : $CPU
RAM      : $RAM GB total  /  $FreeRAM GB free
"@

    return $Control
}
