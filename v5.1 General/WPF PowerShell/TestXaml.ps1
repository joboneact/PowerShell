# Test XAML parsing
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Test Window" Height="300" Width="400">
    <Grid>
        <Button Name="TestButton" Content="Test" Width="100" Height="30"/>
    </Grid>
</Window>
"@

try {
    Write-Host "Creating XmlReader..."
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$xaml)
    Write-Host "Loading XAML..."
    $window = [Windows.Markup.XamlReader]::Load($reader)
    Write-Host "XAML loaded successfully"
    $reader.Close()
    
    $testButton = $window.FindName("TestButton")
    if ($testButton) {
        Write-Host "Control found successfully"
    } else {
        Write-Host "Control not found"
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host "Full error: $_"
}
