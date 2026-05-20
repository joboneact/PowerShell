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
        $programFilesX86 = [System.Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
        $default = Join-Path $env:ProgramFiles 'Microsoft Visual Studio\Installer\vswhere.exe'
        if (-not (Test-Path $default) -and $programFilesX86) {
            $default = Join-Path $programFilesX86 'Microsoft Visual Studio\Installer\vswhere.exe'
        }
        if (Test-Path $default) { return $default }
        return $null
    }

    function Get-VisualStudioInstances {
        $vswhere = Get-VSWherePath
        $instances = [System.Collections.Generic.List[object]]::new()
        if ($vswhere) {
            try {
                $json = & $vswhere -all -prerelease -format json 2>$null
                if ($json) {
                    $records = $json | ConvertFrom-Json
                    foreach ($instance in $records) {
                        $packages = @($instance.packages)
                        $workloads = @($packages | Where-Object { $_.type -eq 'Workload' } | ForEach-Object { $_.id })
                        $components = @($packages | Where-Object { $_.type -like '*Component*' } | ForEach-Object { $_.id })
                        $extensions = @($packages | Where-Object { $_.isExtension -eq $true } | ForEach-Object { $_.id })
                        $displayVersion = if ($instance.catalog.productDisplayVersion) { $instance.catalog.productDisplayVersion } else { $instance.installationVersion }
                        [void]$instances.Add([PSCustomObject]@{
                            Name                = if ([string]::IsNullOrWhiteSpace($instance.displayName)) { $instance.productId } else { $instance.displayName }
                            Edition             = $instance.productId
                            ChannelId           = $instance.channelId
                            ProductId           = $instance.productId
                            DisplayVersion      = $displayVersion
                            Version             = $instance.installationVersion
                            Path                = $instance.installationPath
                            ProductLine         = if ([string]::IsNullOrWhiteSpace($instance.productLine)) { '' } else { $instance.productLine }
                            IsPrerelease        = if ($instance.isPrerelease) { 'Yes' } else { 'No' }
                            InstallDate         = ($instance.installationDate -as [datetime]).ToString('yyyy-MM-dd HH:mm:ss')
                            CatalogBuild        = $instance.catalog.buildVersion
                            Workloads           = if ($workloads) { ($workloads -join ', ') } else { 'None' }
                            Components          = if ($components) { ($components -join ', ') } else { 'None' }
                            Extensions          = if ($extensions) { ($extensions -join ', ') } else { 'None' }
                            PackageCount        = $packages.Count
                        })
                    }
                }
            }
            catch {}
        }

        if (-not $instances) {
            $programFilesX86 = [System.Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
            $searchRoot = Join-Path $env:ProgramFiles 'Microsoft Visual Studio'
            if (-not (Test-Path $searchRoot) -and $programFilesX86) {
                $searchRoot = Join-Path $programFilesX86 'Microsoft Visual Studio'
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

        return $instances | Sort-Object Version -Descending
    }

    function Get-VSSettingsFiles {
        $settings = [System.Collections.Generic.List[object]]::new()
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
        $extensions = [System.Collections.Generic.List[object]]::new()
        $instances = Get-VisualStudioInstances

        foreach ($instance in $instances) {
            if (-not $instance.Path) { continue }
            $candidateRoots = @(
                (Join-Path $instance.Path 'Common7\IDE\Extensions')
                (Join-Path $env:LOCALAPPDATA "Microsoft\VisualStudio\$($instance.Version)\Extensions")
                (Join-Path $env:LOCALAPPDATA "Microsoft\VisualStudio\$($instance.ProductId)\Extensions")
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
                        InstanceVersion   = $instance.DisplayVersion
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

    function Format-InstanceDetails {
        param([object]$Instance)

        if (-not $Instance) { return 'Select a Visual Studio installation to view details.' }

        $lines = @(
            "Name: $($Instance.Name)",
            "Edition: $($Instance.Edition)",
            "Display version: $($Instance.DisplayVersion)",
            "Installation version: $($Instance.Version)",
            "Channel: $($Instance.ChannelId)",
            "Product line: $($Instance.ProductLine)",
            "Install path: $($Instance.Path)",
            "Install date: $($Instance.InstallDate)",
            "Prerelease: $($Instance.IsPrerelease)",
            "Catalog build: $($Instance.CatalogBuild)",
            "Package count: $($Instance.PackageCount)",
            "Workloads: $($Instance.Workloads)",
            "Components: $($Instance.Components)",
            "Extensions: $($Instance.Extensions)"
        )

        return $lines -join [Environment]::NewLine
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
                <StackPanel>
                    <TextBlock Text="Visual Studio Instances" FontSize="14" FontWeight="SemiBold" Foreground="$($Theme.Text)" Margin="0,0,0,10"/>
                    <ListView x:Name="InstanceList" Background="Transparent" BorderThickness="0" Foreground="$($Theme.Text)" FontSize="12" Height="180">
                        <ListView.View>
                            <GridView>
                                <GridViewColumn Header="Name" Width="220" DisplayMemberBinding="{Binding Name}"/>
                                <GridViewColumn Header="Display Version" Width="120" DisplayMemberBinding="{Binding DisplayVersion}"/>
                                <GridViewColumn Header="Full Version" Width="120" DisplayMemberBinding="{Binding Version}"/>
                                <GridViewColumn Header="Channel" Width="120" DisplayMemberBinding="{Binding ChannelId}"/>
                                <GridViewColumn Header="Prerelease" Width="90" DisplayMemberBinding="{Binding IsPrerelease}"/>
                                <GridViewColumn Header="Packages" Width="90" DisplayMemberBinding="{Binding PackageCount}"/>
                            </GridView>
                        </ListView.View>
                    </ListView>
                    <TextBlock Text="Selected instance details" FontSize="12" FontWeight="SemiBold" Foreground="$($Theme.Text)" Margin="0,12,0,8"/>
                    <TextBox x:Name="TxtInstanceDetails"
                             Height="170"
                             TextWrapping="Wrap"
                             VerticalScrollBarVisibility="Auto"
                             HorizontalScrollBarVisibility="Disabled"
                             IsReadOnly="True"
                             AcceptsReturn="True"
                             Foreground="$($Theme.Text)"
                             Background="$($Theme.Background)"
                             BorderBrush="$($Theme.Border)"
                             BorderThickness="1"
                             FontFamily="Consolas"
                             FontSize="11"/>
                </StackPanel>
            </Border>

            <Border Background="$($Theme.Surface)" CornerRadius="6" Padding="12" Margin="0,0,0,14">
                <StackPanel>
                    <TextBlock Text="Settings Files" FontSize="14" FontWeight="SemiBold" Foreground="$($Theme.Text)" Margin="0,0,0,10"/>
                    <ListView x:Name="SettingsList" Background="Transparent" BorderThickness="0" Foreground="$($Theme.Text)" FontSize="12" Height="180">
                        <ListView.View>
                            <GridView>
                                <GridViewColumn Header="Instance" Width="160" DisplayMemberBinding="{Binding Instance}"/>
                                <GridViewColumn Header="File" Width="220" DisplayMemberBinding="{Binding File}"/>
                                <GridViewColumn Header="Path" Width="420" DisplayMemberBinding="{Binding Path}"/>
                                <GridViewColumn Header="Modified" Width="170" DisplayMemberBinding="{Binding Modified}"/>
                            </GridView>
                        </ListView.View>
                    </ListView>
                </StackPanel>
            </Border>

            <Border Background="$($Theme.Surface)" CornerRadius="6" Padding="12" Margin="0,0,0,0">
                <StackPanel>
                    <TextBlock Text="Extensions" FontSize="14" FontWeight="SemiBold" Foreground="$($Theme.Text)" Margin="0,0,0,10"/>
                    <ListView x:Name="ExtensionsList" Background="Transparent" BorderThickness="0" Foreground="$($Theme.Text)" FontSize="12" Height="320">
                        <ListView.View>
                            <GridView>
                                <GridViewColumn Header="Instance" Width="140" DisplayMemberBinding="{Binding Instance}"/>
                                <GridViewColumn Header="VS Version" Width="110" DisplayMemberBinding="{Binding InstanceVersion}"/>
                                <GridViewColumn Header="Name" Width="220" DisplayMemberBinding="{Binding Name}"/>
                                <GridViewColumn Header="Version" Width="120" DisplayMemberBinding="{Binding InstalledVersion}"/>
                                <GridViewColumn Header="State" Width="110" DisplayMemberBinding="{Binding State}"/>
                                <GridViewColumn Header="Path" Width="300" DisplayMemberBinding="{Binding Path}"/>
                                <GridViewColumn Header="URL" Width="260" DisplayMemberBinding="{Binding URL}"/>
                            </GridView>
                        </ListView.View>
                    </ListView>
                </StackPanel>
            </Border>

        </StackPanel>
    </ScrollViewer>
</UserControl>
"@

    $Reader  = [System.Xml.XmlNodeReader]::new($Xaml)
    $Control = [Windows.Markup.XamlReader]::Load($Reader)

    $InstanceList   = $Control.FindName('InstanceList')
    $TxtInstanceDetails = $Control.FindName('TxtInstanceDetails')
    $SettingsList   = $Control.FindName('SettingsList')
    $ExtensionsList = $Control.FindName('ExtensionsList')
    $BtnRefresh     = $Control.FindName('BtnRefresh')

    function Update-InstanceDetails {
        $selected = $InstanceList.SelectedItem
        if ($TxtInstanceDetails) {
            $TxtInstanceDetails.Text = Format-InstanceDetails -Instance $selected
        }
    }

    function Load-Content {
        $InstanceList.Items.Clear()
        foreach ($instance in $VSInstances) { [void]$InstanceList.Items.Add($instance) }
        if ($InstanceList.Items.Count -gt 0 -and $null -eq $InstanceList.SelectedItem) {
            $InstanceList.SelectedIndex = 0
        }
        Update-InstanceDetails

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
        Update-InstanceDetails
    })

    $InstanceList.Add_SelectionChanged({ Update-InstanceDetails })

    Load-Content
    return $Control
}
