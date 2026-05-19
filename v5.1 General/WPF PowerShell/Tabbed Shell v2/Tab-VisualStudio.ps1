#Requires -Version 5.1
## ShellMeta:Title    Visual Studio
## ShellMeta:Icon     🧰
## ShellMeta:Version  1.0
## ShellMeta:Author   WpfShell
<#
.SYNOPSIS
    Module Tab: Visual Studio Inventory.
    Shows installed Visual Studio instances, settings, and extensions.
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

    function Get-VSWherePath {
        $default = Join-Path $env:ProgramFiles 'Microsoft Visual Studio\Installer\vswhere.exe'
        if (-not (Test-Path $default) -and $env:ProgramFiles(x86)) {
            $default = Join-Path $env:ProgramFiles(x86) 'Microsoft Visual Studio\Installer\vswhere.exe'
        }
        if (Test-Path $default) { return $default }
        return $null
    }

    function Get-VisualStudioInstances {
        $vswhere = Get-VSWherePath
        $instances = @()
        if ($vswhere) {
            try {
                $json = & $vswhere -all -prerelease -format json 2>$null
                if ($json) {
                    $records = $json | ConvertFrom-Json
                    foreach ($instance in $records) {
                        [void]$instances.Add([PSCustomObject]@{
                            Name             = $instance.displayName
                            ChannelId        = $instance.channelId
                            ProductId        = $instance.productId
                            Version          = $instance.installationVersion
                            Path             = $instance.installationPath
                            ProductLine      = $instance.productLine || ''
                            IsPrerelease     = if ($instance.isPrerelease) { 'Yes' } else { 'No' }
                            InstallDate      = ($instance.installationDate -as [datetime]).ToString('yyyy-MM-dd HH:mm:ss')
                            CatalogBuild     = $instance.catalog.buildVersion
                        })
                    }
                }
            }
            catch {}
        }

        if (-not $instances) {
            $searchRoot = Join-Path $env:ProgramFiles 'Microsoft Visual Studio'
            if (-not (Test-Path $searchRoot) -and $env:ProgramFiles(x86)) {
                $searchRoot = Join-Path $env:ProgramFiles(x86) 'Microsoft Visual Studio'
            }
            if (Test-Path $searchRoot) {
                $paths = Get-ChildItem -Path $searchRoot -Directory -ErrorAction SilentlyContinue
                foreach ($p in $paths) {
                    $devexe = Join-Path $p.FullName 'Common7\IDE\devenv.exe'
                    if (Test-Path $devexe) {
                        [void]$instances.Add([PSCustomObject]@{
                            Name = $p.Name
                            ChannelId = ''
                            ProductId = ''
                            Version = ''
                            Path = $p.FullName
                            ProductLine = ''
                            IsPrerelease = ''
                            InstallDate = ''
                            CatalogBuild = ''
                        })
                    }
                }
            }
        }

        if (-not $instances) {
            [void]$instances.Add([PSCustomObject]@{ Name = 'No Visual Studio installations found'; ChannelId=''; ProductId=''; Version=''; Path=''; ProductLine=''; IsPrerelease=''; InstallDate=''; CatalogBuild='' })
        }

        return $instances
    }

    function Get-VSSettingsFiles {
        $settings = @()
        $searchPaths = Get-ChildItem -Path "$env:USERPROFILE\Documents\Visual Studio *\Settings" -Directory -ErrorAction SilentlyContinue
        foreach ($folder in $searchPaths) {
            foreach ($file in Get-ChildItem -Path $folder.FullName -Filter '*.vssettings' -File -ErrorAction SilentlyContinue) {
                [void]$settings.Add([PSCustomObject]@{
                    Instance = $folder.Parent.Name
                    File     = $file.Name
                    Path     = $file.FullName
                    Modified = $file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
                })
            }
        }

        if (-not $settings) {
            [void]$settings.Add([PSCustomObject]@{ Instance = 'None found'; File = ''; Path = ''; Modified = '' })
        }
        return $settings
    }

    function Get-VSExtensionManifestData {
        param([string]$ManifestPath)
        try {
            $xml = [xml](Get-Content $ManifestPath -Raw)
            $identity = $xml.PackageManifest.Metadata.Identity
            $display = $xml.PackageManifest.Metadata.DisplayName
            $moreInfo = $xml.PackageManifest.Metadata.MoreInfo
            return [ordered]@{
                Id          = $identity.Id
                Version     = $identity.Version
                DisplayName = if ($display) { $display.'#text' } else { $identity.Id }
                URL         = if ($moreInfo) { $moreInfo.'#text' } else { '' }
            }
        }
        catch {
            return $null
        }
    }

    function Get-VSExtensions {
        $extensions = @()
        $instances = Get-VisualStudioInstances

        foreach ($instance in $instances) {
            if (-not $instance.Path) { continue }
            $candidateRoots = @(
                Join-Path $instance.Path 'Common7\IDE\Extensions',
                Join-Path $env:LOCALAPPDATA "Microsoft\VisualStudio\$($instance.Version)\Extensions",
                Join-Path $env:LOCALAPPDATA "Microsoft\VisualStudio\$($instance.ProductId)\Extensions"
            )
            foreach ($root in $candidateRoots) {
                if (-not (Test-Path $root)) { continue }
                $manifests = Get-ChildItem -Path $root -Recurse -Filter '*.vsixmanifest' -File -ErrorAction SilentlyContinue
                foreach ($manifest in $manifests) {
                    $meta = Get-VSExtensionManifestData -ManifestPath $manifest.FullName
                    if (-not $meta) { continue }
                    $folder = $manifest.Directory.FullName
                    $state = if ($folder -match '\.disabled$') { 'Disabled' } else { 'Installed' }
                    [void]$extensions.Add([PSCustomObject]@{
                        Instance          = $instance.Name
                        Name              = $meta.DisplayName
                        Id                = $meta.Id
                        InstalledVersion  = $meta.Version
                        AvailableVersion  = $meta.Version
                        State             = $state
                        Path              = $folder
                        URL               = if ($meta.URL) { $meta.URL } else { '' }
                        Security          = 'Unknown'
                    })
                }
            }
        }

        if (-not $extensions) {
            [void]$extensions.Add([PSCustomObject]@{ Instance='None'; Name='No Visual Studio extensions found'; Id=''; InstalledVersion=''; AvailableVersion=''; State=''; Path=''; URL=''; Security='' })
        }

        return $extensions | Sort-Object Instance, Name
    }

    $VSInstances  = Get-VisualStudioInstances
    $VSSettings   = Get-VSSettingsFiles
    $VSExtensions = Get-VSExtensions

    [xml]$Xaml = @"
<UserControl
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Background="$($Theme.Background)">

    <ScrollViewer HorizontalScrollBarVisibility="Disabled" VerticalScrollBarVisibility="Auto">
        <StackPanel Margin="24,20,24,20">

            <TextBlock Text="Visual Studio Inventory"
                       FontSize="22" FontWeight="Bold"
                       Foreground="$($Theme.Text)"
                       Margin="0,0,0,12"/>

            <DockPanel Margin="0,0,0,14">
                <TextBlock Text="Shows installed Visual Studio instances, discovered settings files, and installed extensions."
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
                <TextBlock Text="Visual Studio Instances" FontSize="14" FontWeight="SemiBold" Foreground="$($Theme.Text)" Margin="0,0,0,10"/>
                <ListView x:Name="InstanceList" Background="Transparent" BorderThickness="0" Foreground="$($Theme.Text)" FontSize="12" Height="180">
                    <ListView.View>
                        <GridView>
                            <GridViewColumn Header="Name" Width="220" DisplayMemberBinding="{Binding Name}"/>
                            <GridViewColumn Header="Version" Width="100" DisplayMemberBinding="{Binding Version}"/>
                            <GridViewColumn Header="Channel" Width="120" DisplayMemberBinding="{Binding ChannelId}"/>
                            <GridViewColumn Header="Install Path" Width="360" DisplayMemberBinding="{Binding Path}"/>
                            <GridViewColumn Header="Prerelease" Width="100" DisplayMemberBinding="{Binding IsPrerelease}"/>
                        </GridView>
                    </ListView.View>
                </ListView>
            </Border>

            <Border Background="$($Theme.Surface)" CornerRadius="6" Padding="12" Margin="0,0,0,14">
                <TextBlock Text="Settings Files" FontSize="14" FontWeight="SemiBold" Foreground="$($Theme.Text)" Margin="0,0,0,10"/>
                <ListView x:Name="SettingsList" Background="Transparent" BorderThickness="0" Foreground="$($Theme.Text)" FontSize="12" Height="180">
                    <ListView.View>
                        <GridView>
                            <GridViewColumn Header="Instance" Width="160" DisplayMemberBinding="{Binding Instance}"/>
                            <GridViewColumn Header="File" Width="220" DisplayMemberBinding="{Binding File}"/>
                            <GridViewColumn Header="Path" Width="420" DisplayMemberBinding="{Binding Path}"/>
                            <GridViewColumn Header="Modified" Width="170" DisplayMemberBinding="{Binding Modified}"/>
                        </GridView>
                    </GridView>
                </ListView>
            </Border>

            <Border Background="$($Theme.Surface)" CornerRadius="6" Padding="12" Margin="0,0,0,0">
                <TextBlock Text="Extensions" FontSize="14" FontWeight="SemiBold" Foreground="$($Theme.Text)" Margin="0,0,0,10"/>
                <ListView x:Name="ExtensionsList" Background="Transparent" BorderThickness="0" Foreground="$($Theme.Text)" FontSize="12" Height="320">
                    <ListView.View>
                        <GridView>
                            <GridViewColumn Header="Instance" Width="140" DisplayMemberBinding="{Binding Instance}"/>
                            <GridViewColumn Header="Name" Width="220" DisplayMemberBinding="{Binding Name}"/>
                            <GridViewColumn Header="Version" Width="120" DisplayMemberBinding="{Binding InstalledVersion}"/>
                            <GridViewColumn Header="State" Width="110" DisplayMemberBinding="{Binding State}"/>
                            <GridViewColumn Header="Path" Width="300" DisplayMemberBinding="{Binding Path}"/>
                            <GridViewColumn Header="URL" Width="260" DisplayMemberBinding="{Binding URL}"/>
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

    $InstanceList   = $Control.FindName('InstanceList')
    $SettingsList   = $Control.FindName('SettingsList')
    $ExtensionsList = $Control.FindName('ExtensionsList')
    $BtnRefresh     = $Control.FindName('BtnRefresh')

    function Load-Content {
        $InstanceList.Items.Clear()
        foreach ($instance in $VSInstances) { [void]$InstanceList.Items.Add($instance) }

        $SettingsList.Items.Clear()
        foreach ($setting in $VSSettings) { [void]$SettingsList.Items.Add($setting) }

        $ExtensionsList.Items.Clear()
        foreach ($extension in $VSExtensions) { [void]$ExtensionsList.Items.Add($extension) }
    }

    $BtnRefresh.Add_Click({
        $freshInstances = Get-VisualStudioInstances
        $freshSettings  = Get-VSSettingsFiles
        $freshExtensions= Get-VSExtensions
        $InstanceList.Items.Clear()
        foreach ($instance in $freshInstances) { [void]$InstanceList.Items.Add($instance) }
        $SettingsList.Items.Clear()
        foreach ($setting in $freshSettings) { [void]$SettingsList.Items.Add($setting) }
        $ExtensionsList.Items.Clear()
        foreach ($extension in $freshExtensions) { [void]$ExtensionsList.Items.Add($extension) }
    })

    Load-Content
    return $Control
}
