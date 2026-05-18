#Requires -Version 5.1
## ShellMeta:Title    Console
## ShellMeta:Icon     ⚡
## ShellMeta:Version  1.0
## ShellMeta:Author   WpfShell
<#
.SYNOPSIS
    Module Tab: Live PS Console.
    Discovered automatically via ShellMeta header — no shell registration needed.
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

    <DockPanel Margin="24,20,24,20" LastChildFill="True">

        <TextBlock DockPanel.Dock="Top"
                   Text="PS Console"
                   FontSize="20" FontWeight="Bold"
                   Foreground="$($Theme.Text)"
                   Margin="0,0,0,14"/>

        <!-- Input bar -->
        <DockPanel DockPanel.Dock="Bottom" Margin="0,10,0,0">
            <Button x:Name="BtnClear"
                    Content="Clear"
                    DockPanel.Dock="Right"
                    Margin="8,0,0,0"
                    Padding="12,7"
                    Background="$($Theme.Surface)"
                    Foreground="$($Theme.TextMuted)"
                    BorderThickness="0"
                    Cursor="Hand"/>
            <Button x:Name="BtnRun"
                    Content="▶  Run"
                    DockPanel.Dock="Right"
                    Margin="8,0,0,0"
                    Padding="12,7"
                    Background="$($Theme.Accent)"
                    Foreground="#FFFFFF"
                    BorderThickness="0"
                    Cursor="Hand"/>
            <TextBox x:Name="TxtInput"
                     Background="$($Theme.Surface)"
                     Foreground="$($Theme.Text)"
                     CaretBrush="$($Theme.Text)"
                     BorderThickness="0"
                     Padding="10,8"
                     FontFamily="Consolas"
                     FontSize="13"
                     AcceptsReturn="False"
                     ToolTip="Type a PowerShell command and press Enter or click Run"/>
        </DockPanel>

        <!-- Output -->
        <Border Background="$($Theme.Surface)" CornerRadius="6">
            <RichTextBox x:Name="RtbOutput"
                         Background="Transparent"
                         Foreground="$($Theme.Text)"
                         FontFamily="Consolas"
                         FontSize="12"
                         IsReadOnly="True"
                         BorderThickness="0"
                         Padding="12"
                         VerticalScrollBarVisibility="Auto"/>
        </Border>

    </DockPanel>
</UserControl>
"@

    $Reader  = [System.Xml.XmlNodeReader]::new($Xaml)
    $Control = [Windows.Markup.XamlReader]::Load($Reader)

    $TxtInput  = $Control.FindName("TxtInput")
    $RtbOutput = $Control.FindName("RtbOutput")
    $BtnRun    = $Control.FindName("BtnRun")
    $BtnClear  = $Control.FindName("BtnClear")

    $Doc       = $RtbOutput.Document
    $Doc.Blocks.Clear()

    function Append-Output {
        param([string]$Text, [string]$Color = "#CDD6F4")
        $Para = [System.Windows.Documents.Paragraph]::new()
        $Para.Margin = [System.Windows.Thickness]::new(0)
        $Run  = [System.Windows.Documents.Run]::new($Text)
        $Run.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($Color)
        [void]$Para.Inlines.Add($Run)
        [void]$Doc.Blocks.Add($Para)
        $RtbOutput.ScrollToEnd()
    }

    function Run-Command {
        $Cmd = $TxtInput.Text.Trim()
        if ([string]::IsNullOrEmpty($Cmd)) { return }

        Append-Output "PS> $Cmd" "#7C6AF7"

        try {
            $Result = Invoke-Expression $Cmd 2>&1 | Out-String
            if ($Result.Trim()) {
                Append-Output $Result.Trim()
            } else {
                Append-Output "(no output)" "#7F849C"
            }
        }
        catch {
            Append-Output "ERROR: $($_.Exception.Message)" "#F38BA8"
        }
        $TxtInput.Clear()
    }

    $BtnRun.Add_Click({ Run-Command })
    $BtnClear.Add_Click({ $Doc.Blocks.Clear() })
    $TxtInput.Add_KeyDown({
        param($s,$e)
        if ($e.Key -eq "Return") { Run-Command }
    })

    Append-Output "PowerShell $($PSVersionTable.PSVersion) Console ready." "#A6E3A1"
    Append-Output "Type a command and press Enter or click ▶ Run." "#7F849C"

    return $Control
}
