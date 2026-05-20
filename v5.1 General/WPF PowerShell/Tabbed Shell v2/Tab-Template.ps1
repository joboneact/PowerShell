#Requires -Version 5.1
## ShellMeta:Title    Template
## ShellMeta:Icon     🧩
## ShellMeta:Version  1.0
## ShellMeta:Author   WpfShell
<#
.SYNOPSIS
    Template tab for new shell modules.
    Demonstrates theme switching, clipboard format selection, and shell status output.
#>

Add-Type -AssemblyName PresentationFramework

function Get-ModuleUI {
    param([PSCustomObject]$ShellContext)

    $Theme = $ShellContext.Theme

    function Write-ConsoleLine {
        param(
            [string]$Message,
            [string]$Color = '#CDD6F4'
        )

        $ConsoleBox.AppendText($Message + [Environment]::NewLine)
        $ConsoleBox.ScrollToEnd()
    }

    function Set-ShellMode {
        param([string]$Mode)
        if ($ShellContext.SetCommonSetting) {
            & $ShellContext.SetCommonSetting -Name 'Mode' -Value $Mode
        }
        if ($ShellContext.StatusBar) {
            $ShellContext.StatusBar.Text = "Template mode: $Mode"
        }
        if ($ShellContext.CommonInfo) {
            $ShellContext.CommonInfo.Text = "Template updated the shell mode to $Mode"
        }
        Write-ConsoleLine "Mode switched to $Mode" '#A6E3A1'
    }

    function Set-ClipboardFormat {
        param([string]$Format)
        if ($ShellContext.SetCommonSetting) {
            & $ShellContext.SetCommonSetting -Name 'OutputCopyFormat' -Value $Format
        }
        if ($ShellContext.StatusBar) {
            $ShellContext.StatusBar.Text = "Clipboard format: $Format"
        }
        if ($ShellContext.CommonInfo) {
            $ShellContext.CommonInfo.Text = "Template selected clipboard format $Format"
        }
        Write-ConsoleLine "Clipboard format set to $Format" '#7C6AF7'
    }

    [xml]$Xaml = @"
<UserControl
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Background="$($Theme.Background)">

    <Grid Margin="24,20,24,20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <StackPanel Grid.Row="0" Margin="0,0,0,16">
            <TextBlock Text="Template Tab"
                       FontSize="22"
                       FontWeight="Bold"
                       Foreground="$($Theme.Text)"/>
            <TextBlock Text="Use this as the starting point for new tabs. It shows where theme, clipboard, and shell-status integration belong."
                       Margin="0,6,0,0"
                       Foreground="$($Theme.TextMuted)"
                       TextWrapping="Wrap"/>
        </StackPanel>

        <Border Grid.Row="1" Background="$($Theme.Surface)" CornerRadius="8" Padding="14" Margin="0,0,0,16">
            <WrapPanel>
                <Button x:Name="BtnDark" Content="Dark mode" Margin="0,0,8,8" Padding="12,7" Background="$($Theme.Accent)" Foreground="#FFFFFF" BorderThickness="0" Cursor="Hand"/>
                <Button x:Name="BtnLight" Content="Light mode" Margin="0,0,8,8" Padding="12,7" Background="$($Theme.Surface)" Foreground="$($Theme.Text)" BorderThickness="0" Cursor="Hand"/>
                <Button x:Name="BtnText" Content="Clipboard: Text" Margin="0,0,8,8" Padding="12,7" Background="$($Theme.Surface)" Foreground="$($Theme.Text)" BorderThickness="0" Cursor="Hand"/>
                <Button x:Name="BtnPSObject" Content="Clipboard: PSObject" Margin="0,0,8,8" Padding="12,7" Background="$($Theme.Surface)" Foreground="$($Theme.Text)" BorderThickness="0" Cursor="Hand"/>
                <Button x:Name="BtnJSON" Content="Clipboard: JSON" Margin="0,0,8,8" Padding="12,7" Background="$($Theme.Surface)" Foreground="$($Theme.Text)" BorderThickness="0" Cursor="Hand"/>
                <Button x:Name="BtnMarkdown" Content="Clipboard: Markdown" Margin="0,0,8,8" Padding="12,7" Background="$($Theme.Surface)" Foreground="$($Theme.Text)" BorderThickness="0" Cursor="Hand"/>
                <Button x:Name="BtnHTML" Content="Clipboard: HTML" Margin="0,0,8,8" Padding="12,7" Background="$($Theme.Surface)" Foreground="$($Theme.Text)" BorderThickness="0" Cursor="Hand"/>
            </WrapPanel>
        </Border>

        <Border Grid.Row="2" Background="$($Theme.Surface)" CornerRadius="8" Padding="14" Margin="0,0,0,16">
            <StackPanel>
                <TextBlock Text="What to implement" FontSize="14" FontWeight="SemiBold" Foreground="$($Theme.Text)" Margin="0,0,0,10"/>
                <ItemsControl>
                    <TextBlock Text="- Replace this scaffold with real tab content." Foreground="$($Theme.Text)" Margin="0,0,0,4"/>
                    <TextBlock Text="- Read and respect $ShellContext.CommonSettings.Mode for light and dark styling." Foreground="$($Theme.Text)" Margin="0,0,0,4"/>
                    <TextBlock Text="- Honor $ShellContext.CommonSettings.OutputCopyFormat when copying or exporting data." Foreground="$($Theme.Text)" Margin="0,0,0,4"/>
                    <TextBlock Text="- Use $ShellContext.StatusBar and $ShellContext.CommonInfo for shell-wide feedback." Foreground="$($Theme.Text)" Margin="0,0,0,4"/>
                    <TextBlock Text="- Keep any console or diagnostics output visible in the tab and in the shell bottom area." Foreground="$($Theme.Text)" Margin="0,0,0,4"/>
                </ItemsControl>
            </StackPanel>
        </Border>

        <Border Grid.Row="3" Background="$($Theme.Surface)" CornerRadius="8" Padding="12">
            <DockPanel LastChildFill="True">
                <TextBlock DockPanel.Dock="Top" Text="Console output" Foreground="$($Theme.Text)" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                <TextBox x:Name="ConsoleBox"
                         FontFamily="Consolas"
                         FontSize="12"
                         Foreground="$($Theme.Text)"
                         Background="$($Theme.Background)"
                         BorderBrush="$($Theme.Border)"
                         BorderThickness="1"
                         IsReadOnly="True"
                         AcceptsReturn="True"
                         VerticalScrollBarVisibility="Auto"
                         HorizontalScrollBarVisibility="Disabled"
                         TextWrapping="Wrap"
                         Height="180"/>
            </DockPanel>
        </Border>
    </Grid>
</UserControl>
"@

    $Reader  = [System.Xml.XmlNodeReader]::new($Xaml)
    $Control = [Windows.Markup.XamlReader]::Load($Reader)

    $ConsoleBox = $Control.FindName('ConsoleBox')
    $BtnDark = $Control.FindName('BtnDark')
    $BtnLight = $Control.FindName('BtnLight')
    $BtnText = $Control.FindName('BtnText')
    $BtnPSObject = $Control.FindName('BtnPSObject')
    $BtnJSON = $Control.FindName('BtnJSON')
    $BtnMarkdown = $Control.FindName('BtnMarkdown')
    $BtnHTML = $Control.FindName('BtnHTML')

    $BtnDark.Add_Click({ Set-ShellMode -Mode 'Dark' })
    $BtnLight.Add_Click({ Set-ShellMode -Mode 'Light' })
    $BtnText.Add_Click({ Set-ClipboardFormat -Format 'Text' })
    $BtnPSObject.Add_Click({ Set-ClipboardFormat -Format 'PSObject' })
    $BtnJSON.Add_Click({ Set-ClipboardFormat -Format 'JSON' })
    $BtnMarkdown.Add_Click({ Set-ClipboardFormat -Format 'Markdown' })
    $BtnHTML.Add_Click({ Set-ClipboardFormat -Format 'HTML' })

    Write-ConsoleLine 'Template tab ready.' '#A6E3A1'
    Write-ConsoleLine 'Use the buttons above to preview shell interactions.' '#7F849C'
    Write-ConsoleLine 'Replace this scaffold with your implementation.' '#7F849C'

    if ($ShellContext.StatusBar) {
        $ShellContext.StatusBar.Text = 'Template tab loaded'
    }
    if ($ShellContext.CommonInfo) {
        $ShellContext.CommonInfo.Text = 'Template demonstrates mode, clipboard, and shell-bottom output patterns'
    }

    return $Control
}
