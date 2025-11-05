<#
.SYNOPSIS
    Touch files via WPF UI with drag & drop.
#>

if ($Host.Runspace.ApartmentState -ne 'STA') {
    $psi = New-Object System.Diagnostics.ProcessStartInfo -Property @{
        FileName = (Get-Process -Id $PID).Path
        Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        UseShellExecute = $true
    }
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    exit
}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase

if (-not ([System.Management.Automation.PSTypeName]'TouchFileItem').Type) {
    Add-Type @"
using System;
using System.ComponentModel;

public class TouchFileItem : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler PropertyChanged;
    string fullPath, displayPath, lastModified, size, attributes;
    bool isSelected;

    void Notify(string name)
    {
        var handler = PropertyChanged;
        if (handler != null)
        {
            handler(this, new PropertyChangedEventArgs(name));
        }
    }

    public string FullPath
    {
        get { return fullPath; }
        set { if (fullPath != value) { fullPath = value; Notify("FullPath"); } }
    }

    public string DisplayPath
    {
        get { return displayPath; }
        set { if (displayPath != value) { displayPath = value; Notify("DisplayPath"); } }
    }

    public string LastModified
    {
        get { return lastModified; }
        set { if (lastModified != value) { lastModified = value; Notify("LastModified"); } }
    }

    public string Size
    {
        get { return size; }
        set { if (size != value) { size = value; Notify("Size"); } }
    }

    public string Attributes
    {
        get { return attributes; }
        set { if (attributes != value) { attributes = value; Notify("Attributes"); } }
    }

    public bool IsSelected
    {
        get { return isSelected; }
        set { if (isSelected != value) { isSelected = value; Notify("IsSelected"); } }
    }
}
"@
}

function Format-Size {
    param([long]$Bytes)
    switch ($Bytes) {
        {$_ -lt 1KB} { return "$Bytes B" }
        {$_ -lt 1MB} { return "{0:N1} KB" -f ($Bytes/1KB) }
        {$_ -lt 1GB} { return "{0:N1} MB" -f ($Bytes/1MB) }
        default      { return "{0:N1} GB" -f ($Bytes/1GB) }
    }
}

function Get-AttributeLetters {
    param([System.IO.FileAttributes]$Attributes)
    $map = @{
        Archive    = 'A'
        ReadOnly   = 'R'
        Hidden     = 'H'
        System     = 'S'
        Compressed = 'C'
    }
    $letters = foreach ($entry in $map.GetEnumerator()) {
        if ($Attributes.HasFlag([System.IO.FileAttributes]::$($entry.Key))) { $entry.Value }
    }
    if ($letters) { ($letters -join '') } else { 'N' }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$xamlPath  = Join-Path $scriptDir 'WpfTouchFiles5ChatGPT5.xaml'

[xml]$xaml = Get-Content $xamlPath
$reader   = New-Object System.Xml.XmlNodeReader $xaml
$window   = [Windows.Markup.XamlReader]::Load($reader)

$btnAdd    = $window.FindName('BtnAdd')
$btnTouch  = $window.FindName('BtnTouch')
$btnToggle = $window.FindName('BtnToggleCompression')
$btnClear  = $window.FindName('BtnClear')
$fileList  = $window.FindName('FileListView')
$lblStatus = $window.FindName('LblStatus')
$lblNow    = $window.FindName('LblNow')
$chkSelectAll = $window.FindName('ChkSelectAll')

$script:suppressSelectAllEvent = $false
$script:bulkSelectionUpdate   = $false
$itemPropertyChangedHandler   = [System.ComponentModel.PropertyChangedEventHandler]{
    param($sender,$eventArgs)
    if ($eventArgs.PropertyName -eq 'IsSelected' -and -not $script:bulkSelectionUpdate) {
        Update-UiState
    }
}

$fileItems = New-Object 'System.Collections.ObjectModel.ObservableCollection[TouchFileItem]'
$fileList.ItemsSource = $fileItems
$collectionView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($fileItems)

function Refresh-View { $collectionView.Refresh() }

function Get-SelectedItems {
    @($fileItems | Where-Object { $_.IsSelected })
}

function Sync-SelectAll {
    if (-not $chkSelectAll) { return }
    $script:suppressSelectAllEvent = $true
    $selected = (Get-SelectedItems).Count
    switch ($selected) {
        0 { $chkSelectAll.IsChecked = $false }
        { $_ -eq $fileItems.Count } { $chkSelectAll.IsChecked = $true }
        default { $chkSelectAll.IsChecked = $null }
    }
    $script:suppressSelectAllEvent = $false
}

function Set-AllSelection {
    param([bool]$Select)
    if ($fileItems.Count -eq 0) { return }
    $script:bulkSelectionUpdate = $true
    foreach ($item in $fileItems) { $item.IsSelected = $Select }
    $script:bulkSelectionUpdate = $false
    Update-UiState
}

function Update-UiState {
    $btnTouch.IsEnabled  = $true
    $btnToggle.IsEnabled = $true
    $btnClear.IsEnabled  = $fileItems.Count -gt 0
    $lblStatus.Text = if ($fileItems.Count) { "Files loaded: $($fileItems.Count)" } else { "Ready" }
    Sync-SelectAll
}

function Add-Files {
    param([string[]]$Paths)
    $added = 0
    $script:bulkSelectionUpdate = $true
    foreach ($path in $Paths) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $full = (Get-Item -LiteralPath $path).FullName
        if ($fileItems | Where-Object { $_.FullPath -eq $full }) { continue }
        $info = Get-Item -LiteralPath $full
        $item = New-Object TouchFileItem
        $item.FullPath     = $info.FullName
        $item.DisplayPath  = $info.FullName
        $item.LastModified = $info.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        $item.Size         = Format-Size $info.Length
        $item.Attributes   = Get-AttributeLetters -Attributes $info.Attributes
        $item.IsSelected   = $true
        $item.add_PropertyChanged($itemPropertyChangedHandler)
        $fileItems.Add($item)
        $added++
    }
    $script:bulkSelectionUpdate = $false
    if ($added) { $lblStatus.Text = "Added $added file(s)" }
    Update-UiState
}

$fileList.Add_PreviewDragOver({
    param($sender,$e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $e.Effects = [System.Windows.DragDropEffects]::Copy
    } else {
        $e.Effects = [System.Windows.DragDropEffects]::None
    }
    $e.Handled = $true
})

$fileList.Add_Drop({
    param($sender,$e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $files = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
        Add-Files -Paths $files
    }
    $e.Handled = $true
})

$btnAdd.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Multiselect = $true
    if ($dlg.ShowDialog()) {
        Add-Files -Paths $dlg.FileNames
    }
})

$btnTouch.Add_Click({
    $selected = Get-SelectedItems
    if (-not $selected) {
        $lblStatus.Text = "Select one or more files to touch"
        return
    }
    $now = Get-Date
    $touched = 0
    foreach ($item in $selected) {
        if (-not (Test-Path -LiteralPath $item.FullPath -PathType Leaf)) { continue }
        $file = Get-Item -LiteralPath $item.FullPath
        $file.LastWriteTime = $now
        $item.LastModified = $file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        $item.Size = Format-Size $file.Length
        $item.Attributes = Get-AttributeLetters -Attributes $file.Attributes
        $touched++
    }
    $lblStatus.Text = if ($touched) { "Touched $touched selected file(s)" } else { "No selected files touched" }
    Update-UiState
})

$btnToggle.Add_Click({
    $selected = Get-SelectedItems
    if (-not $selected) { return }
    foreach ($item in $selected) {
        if (-not (Test-Path -LiteralPath $item.FullPath -PathType Leaf)) { continue }
        $file = Get-Item -LiteralPath $item.FullPath
        $isCompressed = $file.Attributes.HasFlag([System.IO.FileAttributes]::Compressed)
        $args = if ($isCompressed) { @('/U','/I','/Q',"`"$($file.FullName)`"") } else { @('/C','/I','/Q',"`"$($file.FullName)`"") }
        Start-Process -FilePath "$env:SystemRoot\System32\compact.exe" -ArgumentList $args -NoNewWindow -Wait | Out-Null
        $file = Get-Item -LiteralPath $item.FullPath
        $item.Attributes = Get-AttributeLetters -Attributes $file.Attributes
        $item.Size = Format-Size $file.Length
    }
    $lblStatus.Text = "Toggled compression on $($selected.Count) file(s)"
    Update-UiState
})

$btnClear.Add_Click({
    $fileItems.Clear()
    Update-UiState
})

$chkSelectAll.Add_Click({
    if ($script:suppressSelectAllEvent) { return }
    Set-AllSelection -Select ($chkSelectAll.IsChecked -eq $true)
})

Update-UiState
$lblNow.Text = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({ $lblNow.Text = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') })
$timer.Start()

try { $window.ShowDialog() | Out-Null }
finally { $timer.Stop() }