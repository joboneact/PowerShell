#Requires -Version 5.1
## ShellMeta:Title    VS Code
## ShellMeta:Icon     🧑‍💻
## ShellMeta:Version  1.0
## ShellMeta:Author   WpfShell
<#
.SYNOPSIS
    Module Tab: VS Code Inventory.
    Shows VS Code release info, settings and installed extensions.
#>

Add-Type -AssemblyName PresentationFramework

function Get-ModuleUI {
    param([PSCustomObject]$ShellContext)

    $Theme = $ShellContext.Theme

    function Convert-Value {
        param($Value)
        if ($null -eq $Value) { return '' }
        if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
            return ($Value | ConvertTo-Json -Compress -Depth 3)
        }
        return $Value.ToString()
    }

    function Get-CodeCommand {
        $command = Get-Command code -CommandType Application -ErrorAction SilentlyContinue
        if (-not $command) { $command = Get-Command code.cmd -CommandType Application -ErrorAction SilentlyContinue }
        return $command
    }

    function Get-VSCodeInfo {
        $info = [ordered]@{
            'Tool'            = 'Visual Studio Code'
            'CLI Available'   = 'No'
            'CLI Path'        = ''
            'Version'         = 'Unknown'
            'Commit'          = 'Unknown'
            'Settings Path'   = 'Not found'
            'Extensions Path' = 'Not found'
        }

        $codeCmd = Get-CodeCommand
        if ($codeCmd) {
            $info['CLI Available'] = 'Yes'
            $info['CLI Path']      = $codeCmd.Source
            try {
                $versionLines = & $codeCmd.Source --version 2>$null | Select-Object -First 3
                if ($versionLines) {
                    $info['Version'] = $versionLines[0].Trim()
                    if ($versionLines.Count -gt 1) { $info['Commit'] = $versionLines[1].Trim() }
                }
            }
            catch {}
        }

        $settingsCandidates = @(
            Join-Path $env:APPDATA 'Code\User\settings.json',
            Join-Path $env:APPDATA 'Code - Insiders\User\settings.json'
        )
        foreach ($candidate in $settingsCandidates) {
            if (Test-Path $candidate) {
                $info['Settings Path'] = $candidate
                break
            }
        }

        $extensionsRoot = Join-Path $env:USERPROFILE '.vscode\extensions'
        if (Test-Path $extensionsRoot) {
            $info['Extensions Path'] = $extensionsRoot
        }

        return $info
    }

    function Get-VSCodeSettings {
        $settings = @()
        $settingsPath = Get-VSCodeInfo()['Settings Path']
        if ($settingsPath -and (Test-Path $settingsPath)) {
            try {
                $obj = Get-Content $settingsPath -Raw | ConvertFrom-Json -ErrorAction Stop
                foreach ($prop in $obj.PSObject.Properties | Sort-Object Name) {
                    [void]$settings.Add([PSCustomObject]@{
                        Name  = $prop.Name
                        Value = Convert-Value $prop.Value
                    })
                }
            }
            catch {
                [void]$settings.Add([PSCustomObject]@{ Name = 'Error'; Value = $_.Exception.Message })
            }
        }
        else {
            [void]$settings.Add([PSCustomObject]@{ Name = 'Info'; Value = 'No VS Code settings file found.' })
        }
        return $settings
    }

    function Get-VSCodeMarketplaceVersion {
        param([string]$ExtensionId)
        try {
            $body = [ordered]@{
                filters = @(
                    [ordered]@{
                        criteria = @(
                            [ordered]@{ filterType = 7; value = $ExtensionId }
                        )
                        pageNumber = 1
                        pageSize   = 1
                        sortBy     = 0
                        sortOrder  = 0
                    }
                )
                flags = 914
            }
            $response = Invoke-RestMethod -Uri 'https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery?api-version=3.0-preview.1' -Method Post -ContentType 'application/json' -Body (ConvertTo-Json $body) -TimeoutSec 15 -ErrorAction Stop
            $ext = $response.results[0].extensions[0]
            if ($ext) {
                return $ext.versions[0].version
            }
        }
        catch {
            return $null
        }
        return $null
    }

    function Get-VSCodeExtensions {
        $enabled = @{}
        $extensions = @()
        $codeCmd = Get-CodeCommand
        if ($codeCmd) {
            try {
                $lines = & $codeCmd.Source --list-extensions --show-versions 2>$null
                foreach ($line in $lines) {
                    if ($line -match '^(.+?)@(.+)$') {
                        $enabled[$Matches[1]] = $Matches[2]
                    }
                }
            }
            catch {}
        }

        $root = Join-Path $env:USERPROFILE '.vscode\extensions'
        $localFolders = @()
        if (Test-Path $root) {
            $localFolders = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue
        }

        foreach ($folder in $localFolders) {
            $packageJson = Join-Path $folder.FullName 'package.json'
            if (-not (Test-Path $packageJson)) { continue }
            try {
                $pkg = Get-Content $packageJson -Raw | ConvertFrom-Json -ErrorAction Stop
            }
            catch { continue }

            $id = "$($pkg.publisher).$($pkg.name)"
            $installedVersion = $pkg.version
            $remoteVersion = Get-VSCodeMarketplaceVersion -ExtensionId $id
            $sourceUrl = if ($pkg.repository -and $pkg.repository.url) { $pkg.repository.url } elseif ($pkg.homepage) { $pkg.homepage } else { "https://marketplace.visualstudio.com/items?itemName=$id" }
            $security = if ($pkg.enableProposedApi) { 'Proposed API / elevated' } else { 'Standard' }
            $state = if ($enabled.ContainsKey($id)) { 'Enabled' } else { 'Installed / disabled?' }
            [void]$extensions.Add([PSCustomObject]@{
                Extension         = $pkg.displayName -or $id
                Id                = $id
                InstalledVersion  = $installedVersion
                AvailableVersion  = ($remoteVersion -or $installedVersion)
                State             = $state
                URL               = $sourceUrl
                Security          = $security
            })
        }

        foreach ($id in $enabled.Keys) {
            if ($extensions.Id -notcontains $id) {
                [void]$extensions.Add([PSCustomObject]@{
                    Extension         = $id
                    Id                = $id
                    InstalledVersion  = $enabled[$id]
                    AvailableVersion  = $enabled[$id]
                    State             = 'Enabled'
                    URL               = "https://marketplace.visualstudio.com/items?itemName=$id"
                    Security          = 'Standard'
                })
            }
        }

        if (-not $extensions) {
            [void]$extensions.Add([PSCustomObject]@{
                Extension = 'No extensions found'
                Id = ''
                InstalledVersion = ''
                AvailableVersion = ''
                State = ''
                URL = ''
                Security = ''
            })
        }

        return $extensions | Sort-Object Extension
    }

    $VSCodeInfo   = Get-VSCodeInfo
    $VSCodeSettings = Get-VSCodeSettings
    $VSCodeExtensions = Get-VSCodeExtensions

    [xml]$Xaml = @"
<UserControl
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Background="$($Theme.Background)">

    <ScrollViewer HorizontalScrollBarVisibility="Disabled" VerticalScrollBarVisibility="Auto">
        <StackPanel Margin="24,20,24,20">

            <TextBlock Text="VS Code Inventory"
                       FontSize="22" FontWeight="Bold"
                       Foreground="$($Theme.Text)"
                       Margin="0,0,0,12"/>

            <DockPanel Margin="0,0,0,14">
                <TextBlock Text="Refresh to reload current VS Code info, settings, and extensions."
                           Foreground="$($Theme.TextMuted)"
                           VerticalAlignment="Center"/>
                <Button x:Name="BtnRefresh"
                        Content="↺ Refresh"
                        DockPanel.Dock="Right"
                        Padding="10,6"
                        Background="$($Theme.Surface)"
                        Foreground="$($Theme.Text)"
                        BorderThickness="0"
                        Cursor="Hand"/>
            </DockPanel>

            <Border Background="$($Theme.Surface)" CornerRadius="6" Padding="12" Margin="0,0,0,14">
                <TextBlock Text="VS Code Info" FontSize="14" FontWeight="SemiBold" Foreground="$($Theme.Text)" Margin="0,0,0,10"/>
                <ListView x:Name="InfoList" Background="Transparent" BorderThickness="0" Foreground="$($Theme.Text)" FontSize="12" Height="180">
                    <ListView.View>
                        <GridView>
                            <GridViewColumn Header="Property" Width="220" DisplayMemberBinding="{Binding Name}"/>
                            <GridViewColumn Header="Value" Width="760" DisplayMemberBinding="{Binding Value}"/>
                        </GridView>
                    </ListView.View>
                </ListView>
            </Border>

            <Border Background="$($Theme.Surface)" CornerRadius="6" Padding="12" Margin="0,0,0,14">
                <TextBlock Text="Settings" FontSize="14" FontWeight="SemiBold" Foreground="$($Theme.Text)" Margin="0,0,0,10"/>
                <ListView x:Name="SettingsList" Background="Transparent" BorderThickness="0" Foreground="$($Theme.Text)" FontSize="12" Height="240">
                    <ListView.View>
                        <GridView>
                            <GridViewColumn Header="Setting" Width="260" DisplayMemberBinding="{Binding Name}"/>
                            <GridViewColumn Header="Value" Width="680" DisplayMemberBinding="{Binding Value}"/>
                        </GridView>
                    </GridView>
                </ListView>
            </Border>

            <Border Background="$($Theme.Surface)" CornerRadius="6" Padding="12" Margin="0,0,0,0">
                <TextBlock Text="Extensions" FontSize="14" FontWeight="SemiBold" Foreground="$($Theme.Text)" Margin="0,0,0,10"/>
                <ListView x:Name="ExtensionsList" Background="Transparent" BorderThickness="0" Foreground="$($Theme.Text)" FontSize="12" Height="320">
                    <ListView.View>
                        <GridView>
                            <GridViewColumn Header="Extension" Width="220" DisplayMemberBinding="{Binding Extension}"/>
                            <GridViewColumn Header="Installed" Width="110" DisplayMemberBinding="{Binding InstalledVersion}"/>
                            <GridViewColumn Header="Available" Width="110" DisplayMemberBinding="{Binding AvailableVersion}"/>
                            <GridViewColumn Header="State" Width="130" DisplayMemberBinding="{Binding State}"/>
                            <GridViewColumn Header="Source" Width="260" DisplayMemberBinding="{Binding URL}"/>
                            <GridViewColumn Header="Security" Width="120" DisplayMemberBinding="{Binding Security}"/>
                        </GridView>
                    </ListView.View>
                </ListView>
            </Border>

        </StackPanel>
    </ScrollViewer>
</UserControl>
"@

    $Reader  = [System.Xml.XmlNodeReader]::new($Xaml)
    $Control = [Windows.Markup.XamlReader]::Load($Reader)

    $InfoList       = $Control.FindName('InfoList')
    $SettingsList   = $Control.FindName('SettingsList')
    $ExtensionsList = $Control.FindName('ExtensionsList')
    $BtnRefresh     = $Control.FindName('BtnRefresh')

    function Load-Content {
        $InfoList.Items.Clear()
        foreach ($entry in $VSCodeInfo.GetEnumerator()) {
            [void]$InfoList.Items.Add([PSCustomObject]@{ Name = $entry.Key; Value = Convert-Value $entry.Value })
        }

        $SettingsList.Items.Clear()
        foreach ($setting in $VSCodeSettings) {
            [void]$SettingsList.Items.Add($setting)
        }

        $ExtensionsList.Items.Clear()
        foreach ($extension in $VSCodeExtensions) {
            [void]$ExtensionsList.Items.Add($extension)
        }
    }

    $BtnRefresh.Add_Click({
        $freshInfo = Get-VSCodeInfo
        $freshSettings = Get-VSCodeSettings
        $freshExtensions = Get-VSCodeExtensions
        $InfoList.Items.Clear()
        foreach ($entry in $freshInfo.GetEnumerator()) {
            [void]$InfoList.Items.Add([PSCustomObject]@{ Name = $entry.Key; Value = Convert-Value $entry.Value })
        }
        $SettingsList.Items.Clear()
        foreach ($setting in $freshSettings) { [void]$SettingsList.Items.Add($setting) }
        $ExtensionsList.Items.Clear()
        foreach ($extension in $freshExtensions) { [void]$ExtensionsList.Items.Add($extension) }
    })

    Load-Content
    return $Control
}
