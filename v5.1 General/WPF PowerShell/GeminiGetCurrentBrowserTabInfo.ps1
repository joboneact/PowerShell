[System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework') | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName('PresentationCore') | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName('WindowsBase') | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName('System.Xaml') | Out-Null

# Load UI Automation assemblies
[System.Reflection.Assembly]::LoadWithPartialName('UIAutomationClient') | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName('UIAutomationTypes') | Out-Null

$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        Title='Browser Tracker' Height='300' Width='500' Background='#F0F0F0'>
    <StackPanel Margin='20'>
        <TextBlock Text='Active Edge Tab:' FontWeight='Bold' Margin='0,5,0,0'/>
        <TextBox Name='EdgeOutput' Height='60' TextWrapping='Wrap' VerticalScrollBarVisibility='Auto' IsReadOnly='True' Margin='0,5'/>
        
        <TextBlock Text='Active Brave Tab:' FontWeight='Bold' Margin='0,15,0,0'/>
        <TextBox Name='BraveOutput' Height='60' TextWrapping='Wrap' VerticalScrollBarVisibility='Auto' IsReadOnly='True' Margin='0,5'/>
        
        <Button Name='RefreshBtn' Content='Refresh Status' Height='30' Margin='0,15,0,0'/>
    </StackPanel>
</Window>
"@

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Map UI Controls
$edgeBox = $window.FindName("EdgeOutput")
$braveBox = $window.FindName("BraveOutput")
$btn = $window.FindName("RefreshBtn")

function Get-BrowserInfo($ProcessName) {
    try {
        $proc = Get-Process $ProcessName -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle } | Select-Object -First 1
        if (-not $proc) { return "Browser process not found or no window active." }

        # Get root automation element for the browser window
        $root = [System.Windows.Automation.AutomationElement]::FromHandle($proc.MainWindowHandle)
        
        # Define condition for the Address Bar (Chromium standard)
        $condition = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty, 
            [System.Windows.Automation.ControlType]::Edit
        )
        
        # Search for the address bar element
        $addressBar = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
        
        $title = $proc.MainWindowTitle
        $url = if ($addressBar) { $addressBar.Current.Value } else { "URL could not be retrieved" }

        return "Title: $title`r`nURL: $url"
    }
    catch {
        return "Error: $($_.Exception.Message)"
    }
}

$btn.Add_Click({
    $edgeBox.Text = Get-BrowserInfo "msedge"
    $braveBox.Text = Get-BrowserInfo "brave"
})

$window.ShowDialog() | Out-Null