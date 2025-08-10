# PowerShell-WPF-CSV-Viewer/src/Main.ps1

Add-Type -AssemblyName PresentationFramework

# Load the CsvHandler module
Import-Module -Name .\src\modules\CsvHandler.psm1

# Function to create the WPF window
function New-Window {
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="CSV Viewer" Height="500" Width="600">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*" />
            <ColumnDefinition Width="Auto" />
            <ColumnDefinition Width="Auto" />
        </Grid.ColumnDefinitions>

        <!-- SearchBox -->
        <TextBox Name="SearchBox" Grid.Row="0" Grid.Column="0" Height="25" Margin="10" />

        <!-- SearchButton -->
        <Button Name="SearchButton" Grid.Row="0" Grid.Column="1" Height="25" Margin="5,10,5,10" 
                Content="Search" />

        <!-- ClearSelectionButton -->
        <Button Name="ClearSelectionButton" Grid.Row="0" Grid.Column="2" Height="25" Margin="5,10,10,10" 
                Content="Clear Selection" />

        <!-- DataGrid -->
        <DataGrid Name="DataGrid" Grid.Row="1" Grid.ColumnSpan="3" Margin="10" AutoGenerateColumns="True" 
                  SelectionMode="Extended" SelectionUnit="FullRow" />

        <!-- SubmitButton -->
        <Button Name="SubmitButton" Grid.Row="2" Grid.Column="0" Height="25" Margin="10" 
                Content="Submit" HorizontalAlignment="Left" />

        <!-- OutputBox -->
        <TextBox Name="OutputBox" Grid.Row="2" Grid.Column="1" Grid.ColumnSpan="2" Height="80" Margin="10" 
                 IsReadOnly="True" TextWrapping="Wrap" VerticalAlignment="Bottom" />
    </Grid>
</Window>
"@

    $stringReader = New-Object System.IO.StringReader $xaml
    $xmlReader = [System.Xml.XmlReader]::Create($stringReader)
    $window = [Windows.Markup.XamlReader]::Load($xmlReader)

    return $window
}

# Load CSV data
$csvPath = Join-Path -Path $PSScriptRoot -ChildPath "assets\sample-data.csv"
if (-Not (Test-Path -Path $csvPath)) {
    Write-Error "CSV file not found at path: $csvPath"
    exit 1
}
Write-Host "CSV Path: $csvPath"

$csvData = Import-CsvData -FilePath $csvPath

# Create the WPF window
$window = New-Window

# Retrieve controls
$dataGrid = $window.FindName("DataGrid")
$searchBox = $window.FindName("SearchBox")
$searchButton = $window.FindName("SearchButton")
$clearSelectionButton = $window.FindName("ClearSelectionButton")
$outputBox = $window.FindName("OutputBox")
$submitButton = $window.FindName("SubmitButton")

if (-not $dataGrid -or -not $searchBox -or -not $searchButton -or -not $clearSelectionButton -or -not $outputBox -or -not $submitButton) {
    Write-Error "Failed to find one or more controls in the XAML."
    exit 1
}

# Set the DataGrid's ItemsSource to the CSV data
$dataGrid.ItemsSource = $csvData

# Search functionality
function Perform-Search {
    param ($filter)

    if (-not $filter) {
        [System.Windows.MessageBox]::Show("Please enter text to search.", "Search")
        return
    }

    foreach ($row in $dataGrid.Items) {
        if ($row -ne $null) {
            foreach ($property in $row.PSObject.Properties) {
                if ($property.Value -and $property.Value.ToString() -match [regex]::Escape($filter)) {
                    if (-not $dataGrid.SelectedItems.Contains($row)) {
                        $dataGrid.SelectedItems.Add($row)
                    }
                    break
                }
            }
        }
    }

    if ($dataGrid.SelectedItems.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No matching rows found.", "Search")
    }
}

# Search button functionality
$searchButton.Add_Click({
    Perform-Search -filter $searchBox.Text
})

# Add KeyDown event to SearchBox for Enter key
$searchBox.Add_KeyDown({
    if ($_.Key -eq "Enter") {
        Perform-Search -filter $searchBox.Text
    }
})

# Clear selection button functionality
$clearSelectionButton.Add_Click({
    $dataGrid.SelectedItems.Clear()
})

# Submit button functionality
$submitButton.Add_Click({
    $selectedRows = $dataGrid.SelectedItems
    $output = @()

    foreach ($row in $selectedRows) {
        $output += [PSCustomObject]@{
            Name        = $row.Name
            Description = $row.Description
            NickName    = $row.NickName
            OwnerUPN    = $row.OwnerUPN
        }
    }

    # Output selected rows as JSON
    $jsonOutput = $output | ConvertTo-Json -Depth 3
    $outputBox.Text = $jsonOutput
    [System.Windows.MessageBox]::Show("Results displayed in the output box.", "Submit")
})

# Show the window
$window.ShowDialog() | Out-Null