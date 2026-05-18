#Requires -Version 5.1
## ShellMeta:Title    Files
## ShellMeta:Icon     📁
## ShellMeta:Version  1.0
## ShellMeta:Author   WpfShell
<#
.SYNOPSIS
    Module Tab: File Manager.
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

        <!-- Top bar -->
        <StackPanel DockPanel.Dock="Top" Margin="0,0,0,14">
            <TextBlock Text="File Manager" FontSize="20" FontWeight="Bold"
                       Foreground="$($Theme.Text)" Margin="0,0,0,12"/>
            <DockPanel>
                <Button x:Name="BtnUp"
                        Content="⬆  Up"
                        DockPanel.Dock="Right"
                        Margin="8,0,0,0"
                        Padding="12,6"
                        Background="$($Theme.Surface)"
                        Foreground="$($Theme.Text)"
                        BorderThickness="0"
                        Cursor="Hand"/>
                <Button x:Name="BtnRefresh"
                        Content="↺  Refresh"
                        DockPanel.Dock="Right"
                        Padding="12,6"
                        Background="$($Theme.Surface)"
                        Foreground="$($Theme.Text)"
                        BorderThickness="0"
                        Cursor="Hand"/>
                <TextBox x:Name="TxtPath"
                         Background="$($Theme.Surface)"
                         Foreground="$($Theme.Text)"
                         CaretBrush="$($Theme.Text)"
                         BorderThickness="0"
                         Padding="10,6"
                         FontFamily="Consolas"
                         FontSize="12"
                         Text="C:\"/>
            </DockPanel>
        </StackPanel>

        <!-- Status bar -->
        <TextBlock DockPanel.Dock="Bottom"
                   x:Name="TxtInfo"
                   Foreground="$($Theme.TextMuted)"
                   FontSize="11"
                   Margin="0,8,0,0"/>

        <!-- File list -->
        <Border Background="$($Theme.Surface)" CornerRadius="6">
            <ListView x:Name="FileList"
                      Background="Transparent"
                      BorderThickness="0"
                      Foreground="$($Theme.Text)"
                      FontSize="12">
                <ListView.View>
                    <GridView>
                        <GridViewColumn Header="Name"       Width="260" DisplayMemberBinding="{Binding Name}"/>
                        <GridViewColumn Header="Type"       Width="80"  DisplayMemberBinding="{Binding Type}"/>
                        <GridViewColumn Header="Size"       Width="90"  DisplayMemberBinding="{Binding Size}"/>
                        <GridViewColumn Header="Modified"   Width="150" DisplayMemberBinding="{Binding Modified}"/>
                    </GridView>
                </ListView.View>
            </ListView>
        </Border>

    </DockPanel>
</UserControl>
"@

    $Reader  = [System.Xml.XmlNodeReader]::new($Xaml)
    $Control = [Windows.Markup.XamlReader]::Load($Reader)

    $FileList  = $Control.FindName("FileList")
    $TxtPath   = $Control.FindName("TxtPath")
    $TxtInfo   = $Control.FindName("TxtInfo")
    $BtnUp     = $Control.FindName("BtnUp")
    $BtnRefresh= $Control.FindName("BtnRefresh")

    function Load-Directory {
        param([string]$Path)
        if (-not (Test-Path $Path -PathType Container)) { return }
        $TxtPath.Text = $Path
        $FileList.Items.Clear()

        try {
            $Items = Get-ChildItem -Path $Path -ErrorAction Stop | Sort-Object { -not $_.PSIsContainer }, Name
            foreach ($Item in $Items) {
                $Size = if ($Item.PSIsContainer) { "<DIR>" } else {
                    if ($Item.Length -ge 1MB) { "{0:N1} MB" -f ($Item.Length/1MB) }
                    elseif ($Item.Length -ge 1KB) { "{0:N1} KB" -f ($Item.Length/1KB) }
                    else { "$($Item.Length) B" }
                }
                [void]$FileList.Items.Add([PSCustomObject]@{
                    Name     = ("$(if($Item.PSIsContainer){'📁 '}else{'📄 '})") + $Item.Name
                    Type     = if ($Item.PSIsContainer) { "Folder" } else { $Item.Extension }
                    Size     = $Size
                    Modified = $Item.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
                    FullPath = $Item.FullName
                    IsDir    = $Item.PSIsContainer
                })
            }
            $TxtInfo.Text = "$($FileList.Items.Count) items in $Path"

            # Report to shell status bar
            $ShellContext.StatusBar.Text = "Files: $Path"
        }
        catch {
            $TxtInfo.Text = "⚠ Cannot read: $_"
        }
    }

    # Double-click to navigate
    $FileList.Add_MouseDoubleClick({
        $Selected = $FileList.SelectedItem
        if ($Selected -and $Selected.IsDir) {
            Load-Directory -Path $Selected.FullPath
        }
    })

    # Up button
    $BtnUp.Add_Click({
        $Parent = Split-Path $TxtPath.Text -Parent
        if ($Parent) { Load-Directory -Path $Parent }
    })

    # Refresh / navigate on Enter
    $BtnRefresh.Add_Click({ Load-Directory -Path $TxtPath.Text })
    $TxtPath.Add_KeyDown({
        param($s,$e)
        if ($e.Key -eq "Return") { Load-Directory -Path $TxtPath.Text }
    })

    Load-Directory -Path "C:\"
    return $Control
}
