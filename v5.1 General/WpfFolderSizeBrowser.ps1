# WpfFolder Size Browser


#
# Wed 7-2-2025
#
# PowerShell 5.1 compatible - does not need 7.x but should run on it.
# .NET 6.0 or earlier compatible.
# WPF Windows Presentation Framework should work
#
# PowerShell script to create a WPF application that displays folder sizes
# and allows navigation through folders.
#



<#


add a wpf dialog that shows current immediate child folders and their sizes and then let me click to drill down. the whole powershell script should work with powershell 5.1 and .net 6 or earlier.

add a last refreshed date and time stamp plus make the folder size column sortable by the actual size.

https://github.com/joboneact

#>


Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Function to get folder sizes
function Get-FolderSizes {
    param([string]$Path)
    
    Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $folderSize = (Get-ChildItem -Path $_.FullName -Recurse -File -ErrorAction SilentlyContinue | 
                       Measure-Object -Property Length -Sum).Sum
        
        if ($folderSize -eq $null) { $folderSize = 0 }
        
        [PSCustomObject]@{
            Name = $_.Name
            FullPath = $_.FullName
            SizeBytes = $folderSize
            SizeMB = [math]::Round($folderSize / 1MB, 2)
            SizeGB = [math]::Round($folderSize / 1GB, 3)
            DisplaySize = if ($folderSize -gt 1GB) { "$([math]::Round($folderSize / 1GB, 2)) GB" } 
                         elseif ($folderSize -gt 1MB) { "$([math]::Round($folderSize / 1MB, 2)) MB" }
                         elseif ($folderSize -gt 1KB) { "$([math]::Round($folderSize / 1KB, 2)) KB" }
                         else { "$folderSize bytes" }
        }
    } | Sort-Object SizeBytes -Descending
}

# Create WPF Window
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Folder Size Browser" Height="550" Width="750"
        WindowStartupLocation="CenterScreen">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="10">
            <Label Content="Current Path:" VerticalAlignment="Center"/>
            <TextBox Name="PathTextBox" Width="400" Margin="5,0" IsReadOnly="True"/>
            <Button Name="UpButton" Content="Up" Width="50" Margin="5,0"/>
            <Button Name="RefreshButton" Content="Refresh" Width="70" Margin="5,0"/>
        </StackPanel>
        
        <ListView Name="FolderListView" Grid.Row="1" Margin="10">
            <ListView.View>
                <GridView>
                    <GridViewColumn Header="Folder Name" Width="300" DisplayMemberBinding="{Binding Name}"/>
                    <GridViewColumn Header="Size" Width="150" DisplayMemberBinding="{Binding DisplaySize}">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <TextBlock Text="{Binding DisplaySize}" Tag="{Binding SizeBytes}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header="Size (MB)" Width="100" DisplayMemberBinding="{Binding SizeMB}"/>
                </GridView>
            </ListView.View>
        </ListView>
        
        <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="10,5">
            <Label Content="Last Refreshed:" FontWeight="Bold"/>
            <Label Name="LastRefreshedLabel" Content="Never"/>
        </StackPanel>
        
        <StatusBar Grid.Row="3">
            <StatusBarItem Name="StatusText" Content="Ready"/>
        </StatusBar>
    </Grid>
</Window>
"@

# Load XAML
$reader = [System.Xml.XmlNodeReader]::new([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$pathTextBox = $window.FindName("PathTextBox")
$upButton = $window.FindName("UpButton")
$refreshButton = $window.FindName("RefreshButton")
$folderListView = $window.FindName("FolderListView")
$statusText = $window.FindName("StatusText")
$lastRefreshedLabel = $window.FindName("LastRefreshedLabel")

# Initialize current path
$currentPath = Get-Location
$currentSortColumn = "SizeBytes"
$currentSortDirection = "Descending"

# Function to sort data
function Sort-FolderData {
    param($data, $column, $direction)
    
    if ($direction -eq "Ascending") {
        return $data | Sort-Object $column
    } else {
        return $data | Sort-Object $column -Descending
    }
}

# Function to update the display
function Update-Display {
    param([string]$Path)
    
    $statusText.Content = "Loading..."
    $pathTextBox.Text = $Path
    
    try {
        $folders = Get-FolderSizes -Path $Path
        $sortedFolders = Sort-FolderData -data $folders -column $currentSortColumn -direction $currentSortDirection
        $folderListView.ItemsSource = $sortedFolders
        $statusText.Content = "Found $($folders.Count) folders"
        $lastRefreshedLabel.Content = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    catch {
        $statusText.Content = "Error: $($_.Exception.Message)"
        $lastRefreshedLabel.Content = "Error at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    }
}

# Add column header click event for sorting
$folderListView.AddHandler([System.Windows.Controls.GridViewColumnHeader]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($sender, $e)
    
    $header = $e.OriginalSource
    if ($header -is [System.Windows.Controls.GridViewColumnHeader] -and $header.Content) {
        $columnName = switch ($header.Content) {
            "Folder Name" { "Name" }
            "Size" { "SizeBytes" }
            "Size (MB)" { "SizeMB" }
            default { "SizeBytes" }
        }
        
        # Toggle sort direction if same column, otherwise default to descending
        if ($currentSortColumn -eq $columnName) {
            $script:currentSortDirection = if ($currentSortDirection -eq "Ascending") { "Descending" } else { "Ascending" }
        } else {
            $script:currentSortColumn = $columnName
            $script:currentSortDirection = if ($columnName -eq "Name") { "Ascending" } else { "Descending" }
        }
        
        # Re-sort current data
        $currentData = $folderListView.ItemsSource
        if ($currentData) {
            $sortedData = Sort-FolderData -data $currentData -column $currentSortColumn -direction $currentSortDirection
            $folderListView.ItemsSource = $sortedData
        }
    }
})

# Event handlers
$upButton.Add_Click({
    $parent = Split-Path -Parent $currentPath
    if ($parent -and (Test-Path $parent)) {
        $script:currentPath = $parent
        Update-Display $currentPath
    }
})

$refreshButton.Add_Click({
    Update-Display $currentPath
})

$folderListView.Add_MouseDoubleClick({
    $selectedItem = $folderListView.SelectedItem
    if ($selectedItem) {
        $script:currentPath = $selectedItem.FullPath
        Update-Display $currentPath
    }
})

# Handle key events for navigation
$folderListView.Add_KeyDown({
    if ($_.Key -eq "Return") {
        $selectedItem = $folderListView.SelectedItem
        if ($selectedItem) {
            $script:currentPath = $selectedItem.FullPath
            Update-Display $currentPath
        }
    }
})

# Initial load
Update-Display $currentPath

# Show the window
$window.ShowDialog()