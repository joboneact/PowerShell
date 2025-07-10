# Debug version of GetModulesWpf.ps1
try {
    Write-Output "Loading assemblies..."
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Web
    Write-Output "Assemblies loaded successfully"

    Write-Output "Creating XAML..."
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Test Window" Height="300" Width="400">
    <Grid>
        <Button Name="TestButton" Content="Test" Width="100" Height="30"/>
    </Grid>
</Window>
"@

    Write-Output "Parsing XAML..."
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)
    $reader.Close()
    Write-Output "XAML parsed successfully"
    
    Write-Output "Finding controls..."
    $testButton = $window.FindName("TestButton")
    if ($testButton) {
        Write-Output "Control found successfully"
    } else {
        Write-Output "Control not found"
    }
    
    Write-Output "Script completed successfully"
} catch {
    Write-Output "Error occurred: $($_.Exception.Message)"
    Write-Output "Full exception: $_"
}
