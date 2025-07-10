# GetModulesWpf.ps1
# PowerShell 5.1 WPF application to display loaded modules information

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Function to get DLL count for a module
function Get-ModuleDllCount {
    param($Module)
    
    try {
        if ($Module.ModuleBase -and (Test-Path $Module.ModuleBase)) {
            $dllFiles = Get-ChildItem -Path $Module.ModuleBase -Filter "*.dll" -Recurse -ErrorAction SilentlyContinue
            return $dllFiles.Count
        }
        return 0
    }
    catch {
        return 0
    }
}

# Function to check if module is importable
function Test-ModuleImportable {
    param($ModuleName)
    
    try {
        $availableModule = Get-Module -Name $ModuleName -ListAvailable -ErrorAction SilentlyContinue
        return ($availableModule -ne $null)
    }
    catch {
        return $false
    }
}

# Function to get module data
function Get-ModuleData {
    $modules = Get-Module
    $moduleData = @()
    
    foreach ($module in $modules) {
        $dllCount = Get-ModuleDllCount -Module $module
        $isImportable = Test-ModuleImportable -ModuleName $module.Name
        
        $moduleInfo = [PSCustomObject]@{
            Name = $module.Name
            Version = $module.Version.ToString()
            ReferenceCount = if ($module.ReferenceCount) { $module.ReferenceCount } else { "N/A" }
            DllCount = $dllCount
            Importable = if ($isImportable) { "Yes" } else { "No" }
            ModuleType = $module.ModuleType
            Path = $module.ModuleBase
        }
        
        $moduleData += $moduleInfo
    }
    
    return $moduleData
}

# Function to refresh the data grid
function Refresh-ModuleData {
    param($DataGrid)
    
    $moduleData = Get-ModuleData
    $DataGrid.ItemsSource = $moduleData
    
    # Update status
    $statusLabel.Content = "Modules loaded: $($moduleData.Count) | Last updated: $(Get-Date -Format 'HH:mm:ss')"
}

# Create the main window
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PowerShell Modules Viewer" Height="600" Width="1000"
        WindowStartupLocation="CenterScreen">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Toolbar -->
        <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="10,10,10,5" Background="LightGray">
            <Button Name="RefreshButton" Content="Refresh" Width="80" Height="30" Margin="5"/>
            <Button Name="ExportButton" Content="Export CSV" Width="80" Height="30" Margin="5"/>
            <Separator Width="10"/>
            <TextBox Name="SearchBox" Width="200" Height="25" Margin="5" 
                     VerticalContentAlignment="Center"/>
            <Label Content="Search:" VerticalAlignment="Center" Margin="0,0,5,0"/>
        </StackPanel>
        
        <!-- Data Grid -->
        <DataGrid Grid.Row="1" Name="ModulesDataGrid" Margin="10,5,10,5"
                  AutoGenerateColumns="False" 
                  CanUserAddRows="False" 
                  CanUserDeleteRows="False"
                  IsReadOnly="True"
                  GridLinesVisibility="All"
                  HeadersVisibility="Column"
                  AlternatingRowBackground="LightBlue"
                  SelectionMode="Single">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Module Name" Binding="{Binding Name}" Width="200"/>
                <DataGridTextColumn Header="Version" Binding="{Binding Version}" Width="100"/>
                <DataGridTextColumn Header="Reference Count" Binding="{Binding ReferenceCount}" Width="120"/>
                <DataGridTextColumn Header="DLL Count" Binding="{Binding DllCount}" Width="80"/>
                <DataGridTextColumn Header="Importable" Binding="{Binding Importable}" Width="80"/>
                <DataGridTextColumn Header="Type" Binding="{Binding ModuleType}" Width="100"/>
                <DataGridTextColumn Header="Path" Binding="{Binding Path}" Width="*"/>
            </DataGrid.Columns>
        </DataGrid>
        
        <!-- Status Bar -->
        <StatusBar Grid.Row="2" Height="25">
            <Label Name="StatusLabel" Content="Ready"/>
        </StatusBar>
    </Grid>
</Window>
"@

# Parse XAML and create window
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$dataGrid = $window.FindName("ModulesDataGrid")
$refreshButton = $window.FindName("RefreshButton")
$exportButton = $window.FindName("ExportButton")
$searchBox = $window.FindName("SearchBox")
$statusLabel = $window.FindName("StatusLabel")

# Store original data for filtering
$script:originalData = @()

# Event handlers
$refreshButton.Add_Click({
    $statusLabel.Content = "Refreshing..."
    try {
        $script:originalData = Get-ModuleData
        $dataGrid.ItemsSource = $script:originalData
        $statusLabel.Content = "Modules loaded: $($script:originalData.Count) | Last updated: $(Get-Date -Format 'HH:mm:ss')"
    }
    catch {
        $statusLabel.Content = "Error refreshing data: $($_.Exception.Message)"
    }
})

$exportButton.Add_Click({
    try {
        $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveDialog.Filter = "CSV files (*.csv)|*.csv|All files (*.*)|*.*"
        $saveDialog.DefaultExt = "csv"
        $saveDialog.FileName = "PowerShell_Modules_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        
        if ($saveDialog.ShowDialog() -eq $true) {
            $script:originalData | Export-Csv -Path $saveDialog.FileName -NoTypeInformation
            $statusLabel.Content = "Data exported to: $($saveDialog.FileName)"
        }
    }
    catch {
        $statusLabel.Content = "Error exporting data: $($_.Exception.Message)"
    }
})

# Search functionality
$searchBox.Add_TextChanged({
    $searchText = $searchBox.Text
    
    if ([string]::IsNullOrWhiteSpace($searchText)) {
        $dataGrid.ItemsSource = $script:originalData
    }
    else {
        $filteredData = $script:originalData | Where-Object {
            $_.Name -like "*$searchText*" -or
            $_.Version -like "*$searchText*" -or
            $_.ModuleType -like "*$searchText*" -or
            $_.Path -like "*$searchText*"
        }
        $dataGrid.ItemsSource = $filteredData
    }
})

# Double-click to show module details
$dataGrid.Add_MouseDoubleClick({
    $selectedItem = $dataGrid.SelectedItem
    if ($selectedItem) {
        $details = @"
Module Details:

Name: $($selectedItem.Name)
Version: $($selectedItem.Version)
Type: $($selectedItem.ModuleType)
Reference Count: $($selectedItem.ReferenceCount)
DLL Count: $($selectedItem.DllCount)
Importable: $($selectedItem.Importable)
Path: $($selectedItem.Path)
"@
        [System.Windows.MessageBox]::Show($details, "Module Details", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

# Initial data load
$statusLabel.Content = "Loading modules..."
try {
    $script:originalData = Get-ModuleData
    $dataGrid.ItemsSource = $script:originalData
    $statusLabel.Content = "Modules loaded: $($script:originalData.Count) | Last updated: $(Get-Date -Format 'HH:mm:ss')"
}
catch {
    $statusLabel.Content = "Error loading initial data: $($_.Exception.Message)"
}

# Show the window
$window.ShowDialog() | Out-Null
