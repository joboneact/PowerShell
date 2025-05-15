# Xaml-Parameters.Sample.ps1
# Import the required .NET assemblies for WPF
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Define the XAML for the dialog
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Parameter Input Dialog" Height="300" Width="400" WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <!-- String Input -->
        <Label Grid.Row="0" Grid.Column="0" Margin="5" VerticalAlignment="Center">Enter a string:</Label>
        <TextBox x:Name="StringInput" Grid.Row="0" Grid.Column="1" Margin="5"/>

        <!-- Number Input -->
        <Label Grid.Row="1" Grid.Column="0" Margin="5" VerticalAlignment="Center">Enter a number:</Label>
        <TextBox x:Name="NumberInput" Grid.Row="1" Grid.Column="1" Margin="5"/>

        <!-- Dropdown -->
        <Label Grid.Row="2" Grid.Column="0" Margin="5" VerticalAlignment="Center">Select an option:</Label>
        <ComboBox x:Name="DropdownInput" Grid.Row="2" Grid.Column="1" Margin="5">
            <ComboBoxItem Content="Option 1"/>
            <ComboBoxItem Content="Option 2"/>
            <ComboBoxItem Content="Option 3"/>
        </ComboBox>

        <!-- Checkbox -->
        <CheckBox x:Name="CheckboxInput" Grid.Row="3" Grid.Column="1" Margin="5" Content="Enable feature"/>

        <!-- Buttons -->
        <StackPanel Grid.Row="4" Grid.ColumnSpan="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="5">
            <Button x:Name="OkButton" Width="75" Margin="5">OK</Button>
            <Button x:Name="CancelButton" Width="75" Margin="5">Cancel</Button>
        </StackPanel>
    </Grid>
</Window>
"@

# Parse the XAML
$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get references to the controls
$stringInput = $window.FindName("StringInput")
$numberInput = $window.FindName("NumberInput")
$dropdownInput = $window.FindName("DropdownInput")
$checkboxInput = $window.FindName("CheckboxInput")
$okButton = $window.FindName("OkButton")
$cancelButton = $window.FindName("CancelButton")

# Define the OK button click event
$okButton.Add_Click({
    # Collect the input values
    $stringValue = $stringInput.Text
    $numberValue = $numberInput.Text
    $dropdownValue = $dropdownInput.SelectedItem.Content
    $checkboxValue = $checkboxInput.IsChecked

    # Display the collected values (or process them as needed)
    [System.Windows.MessageBox]::Show("String: $stringValue`nNumber: $numberValue`nDropdown: $dropdownValue`nCheckbox: $checkboxValue")

    # Close the window
    $window.Close()
})

# Define the Cancel button click event
$cancelButton.Add_Click({
    # Close the window without doing anything
    $window.Close()
})

# Show the dialog
$window.ShowDialog()