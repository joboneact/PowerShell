# File Manager WPF Application
# This script creates a WPF window to display and manage files in the current directory.
# Features:
# - Display files/folders with properties (name, type, size, creation/modification date, comment).
# - Edit comments stored in NTFS Alternate Data Streams.
# - Add today's date to comments.
# - Navigate folders and refresh the view.

# Load required .NET assemblies for WPF functionality
Add-Type -AssemblyName PresentationFramework   # Provides WPF controls like Window, MessageBox, etc.
Add-Type -AssemblyName PresentationCore       # Provides core WPF functionality.
Add-Type -AssemblyName WindowsBase            # Provides base classes for WPF.

# Define a custom class to represent file information
class FileItem {
    [string]$Name                # File or folder name
    [string]$Type                # Type: "File" or "Folder"
    [string]$Size                # File size (formatted as B, KB, MB, GB)
    [DateTime]$CreationTime      # File creation date/time
    [DateTime]$ModificationTime  # File modification date/time
    [string]$Comment             # Comment stored in NTFS Alternate Data Stream
    [string]$FullPath            # Full absolute path to the file/folder

    # Constructor: Initializes the FileItem object based on a FileSystemInfo object
    FileItem([System.IO.FileSystemInfo]$item) {
        $this.Name = $item.Name
        $this.FullPath = $item.FullName
        $this.CreationTime = $item.CreationTime
        $this.ModificationTime = $item.LastWriteTime

        # Determine if the item is a folder or file
        if ($item -is [System.IO.DirectoryInfo]) {
            $this.Type = "Folder"
            $this.Size = "<DIR>"  # Folders don't have a size
        } else {
            $this.Type = "File"
            $this.Size = $this.FormatFileSize($item.Length)  # Format file size
        }

        # Use Get-FileComment to retrieve the comment
        $this.Comment = Get-FileComment -Path $this.FullPath
    }

    # Formats file size into human-readable units (B, KB, MB, GB)
    [string] FormatFileSize([long]$bytes) {
        if ($bytes -lt 1KB) { return "$bytes B" }
        elseif ($bytes -lt 1MB) { return "{0:N2} KB" -f ($bytes / 1KB) }
        elseif ($bytes -lt 1GB) { return "{0:N2} MB" -f ($bytes / 1MB) }
        else { return "{0:N2} GB" -f ($bytes / 1GB) }
    }

    # Retrieves the comment from the NTFS Alternate Data Stream
    [string] GetComment() {
        try {
            if (Test-Path $this.FullPath) {
                $stream = Get-Content -Path $this.FullPath -Stream "Comment" -ErrorAction SilentlyContinue
                return if ($stream) { $stream } else { "" }
            }
        } catch {
            # Return empty if the stream is not supported or fails
        }
        return ""
    }

    # Sets or removes the comment in the NTFS Alternate Data Stream
    [void] SetComment([string]$comment) {
        try {
            if (Test-Path $this.FullPath) {
                if ([string]::IsNullOrWhiteSpace($comment)) {
                    # Remove the comment stream if the comment is empty
                    Remove-Item -Path "$($this.FullPath):Comment" -ErrorAction SilentlyContinue
                } else {
                    # Set the comment in the alternate data stream
                    Set-Content -Path $this.FullPath -Stream "Comment" -Value $comment
                }
                $this.Comment = $comment
            }
        } catch {
            throw "Failed to save comment: $($_.Exception.Message)"
        }
    }

    # Updates the comment using Set-FileComment
    [void] UpdateComment([string]$comment) {
        # Use Set-FileComment to update the comment
        $errorMessage = Set-FileComment -Path $this.FullPath -Comment $comment
        if (-not [string]::IsNullOrWhiteSpace($errorMessage)) {
            throw $errorMessage
        }
        $this.Comment = $comment
    }
}

# Define the XAML for the WPF window
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="File Manager - Current Directory" 
        Height="600" Width="1000"
        WindowStartupLocation="CenterScreen">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Current Directory Display -->
        <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="10">
            <TextBlock Text="Current Directory: " FontWeight="Bold" VerticalAlignment="Center"/>
            <TextBlock Name="CurrentDirTextBlock" VerticalAlignment="Center" Foreground="Blue"/>
            <Button Name="RefreshButton" Content="Refresh" Margin="20,0,0,0" Padding="10,5"/>
        </StackPanel>
        
        <!-- DataGrid for files -->
        <DataGrid Grid.Row="1" Name="FilesDataGrid" 
                  AutoGenerateColumns="False" 
                  CanUserAddRows="False"
                  CanUserDeleteRows="False"
                  SelectionMode="Single"
                  GridLinesVisibility="All"
                  AlternatingRowBackground="LightGray"
                  Margin="10">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="200" IsReadOnly="True"/>
                <DataGridTextColumn Header="Type" Binding="{Binding Type}" Width="80" IsReadOnly="True"/>
                <DataGridTextColumn Header="Size" Binding="{Binding Size}" Width="100" IsReadOnly="True"/>
                <DataGridTextColumn Header="Creation Date" Binding="{Binding CreationTime, StringFormat='{}{0:yyyy-MM-dd HH:mm:ss}'}" Width="150" IsReadOnly="True"/>
                <DataGridTextColumn Header="Modification Date" Binding="{Binding ModificationTime, StringFormat='{}{0:yyyy-MM-dd HH:mm:ss}'}" Width="150" IsReadOnly="True"/>
                <DataGridTextColumn Header="Comment" Binding="{Binding Comment}" Width="*" IsReadOnly="False"/>
            </DataGrid.Columns>
        </DataGrid>
        
        <!-- Comment editing section -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="10">
            <TextBlock Text="Edit Comment for Selected File:" FontWeight="Bold" VerticalAlignment="Center" Margin="0,0,10,0"/>
            <TextBox Name="CommentTextBox" Width="400" Height="25" VerticalAlignment="Center"/>
            <Button Name="UpdateCommentButton" Content="Update Comment" Margin="10,0,0,0" Padding="10,5"/>
            <Button Name="AddDateButton" Content="Add Today's Date" Margin="10,0,0,0" Padding="10,5"/>
        </StackPanel>
        
        <!-- Status bar -->
        <StatusBar Grid.Row="3">
            <StatusBarItem>
                <TextBlock Name="StatusTextBlock" Text="Ready"/>
            </StatusBarItem>
        </StatusBar>
    </Grid>
</Window>
"@

# Load the XAML and create the WPF window
$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get references to controls in the XAML
$currentDirTextBlock = $window.FindName("CurrentDirTextBlock")
$filesDataGrid = $window.FindName("FilesDataGrid")
$commentTextBox = $window.FindName("CommentTextBox")
$updateCommentButton = $window.FindName("UpdateCommentButton")
$addDateButton = $window.FindName("AddDateButton")
$refreshButton = $window.FindName("RefreshButton")
$statusTextBlock = $window.FindName("StatusTextBlock")

# Global variables
$script:fileItems = @()                     # Stores the list of FileItem objects
$script:currentDirectory = Get-Location     # Stores the current directory

# Function to load files from the current directory
function Load-Files {
    try {
        $statusTextBlock.Text = "Loading files..."
        $currentDirTextBlock.Text = $script:currentDirectory.Path

        # Get all items in the current directory
        $items = Get-ChildItem -Path $script:currentDirectory.Path | Sort-Object PSIsContainer, Name

        # Convert items to FileItem objects
        $script:fileItems = @()
        foreach ($item in $items) {
            $script:fileItems += [FileItem]::new($item)
        }

        # Bind the FileItem objects to the DataGrid
        $filesDataGrid.ItemsSource = $script:fileItems

        $statusTextBlock.Text = "Loaded $($script:fileItems.Count) items"
    } catch {
        [System.Windows.MessageBox]::Show("Error loading files: $($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        $statusTextBlock.Text = "Error loading files"
    }
}

# Function to get today's date in the requested format
function Get-TodayDateString {
    $today = Get-Date
    $dayOfWeek = $today.ToString("ddd")      # Get abbreviated day of the week (e.g., Sun)
    $dateString = $today.ToString("MM-dd-yyyy") # Format date as MM-DD-YYYY
    return "$dayOfWeek $dateString"
}

# Function to get the comment from a file
function Get-FileComment {
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    $comment = ""
    try {
        if (Test-Path $Path) {
            $shell = New-Object -ComObject Shell.Application
            $folderPath = Split-Path -Path $Path -Parent
            $fileName = Split-Path -Path $Path -Leaf
            $fileBaseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
            $fileExtension = [System.IO.Path]::GetExtension($fileName)


            $folder = $shell.Namespace($folderPath)
            $file = $folder.ParseName($fileName)
            $comment = $folder.GetDetailsOf($file, 14)

            $shell = $null
            <# 
            $stream = Get-Content -Path $Path -Stream "Comment" -ErrorAction SilentlyContinue
            return if ($stream) { $stream } else { "" }
            #>
        }
    } catch {
        # Return empty if the stream is not supported or fails
    }
    return $comment
}

# Function to set or remove the comment for a file
function Set-FileComment {
    param (
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$Comment
    )
    try {
        if (Test-Path $Path) {
            if ([string]::IsNullOrWhiteSpace($Comment)) {
                # Remove the comment stream if the comment is empty
                Remove-Item -Path "$Path:Comment" -ErrorAction SilentlyContinue
            } else {
                # Set the comment in the alternate data stream
                Set-Content -Path $Path -Stream "Comment" -Value $Comment
            }
            return $null
        } else {
            return "File not found: $Path"
        }
    } catch {
        return "Failed to save comment: $($_.Exception.Message)"
    }
} # End of Set-FileComment: Sets or removes the comment alternate data stream for a file, returns error

# Event handlers for UI interactions
$filesDataGrid.Add_SelectionChanged({
    $selectedItem = $filesDataGrid.SelectedItem
    if ($selectedItem) {
        $commentTextBox.Text = $selectedItem.Comment
        $statusTextBlock.Text = "Selected: $($selectedItem.Name)"
    } else {
        $commentTextBox.Text = ""
        $statusTextBlock.Text = "Ready"
    }
})

$updateCommentButton.Add_Click({
    $selectedItem = $filesDataGrid.SelectedItem
    if ($selectedItem) {
        $newComment = $commentTextBox.Text
        try {
            $selectedItem.UpdateComment($newComment)
            $filesDataGrid.Items.Refresh()
            $statusTextBlock.Text = "Comment updated for: $($selectedItem.Name)"
        } catch {
            [System.Windows.MessageBox]::Show($_, "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    } else {
        [System.Windows.MessageBox]::Show("Please select a file first.", "No Selection", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

$addDateButton.Add_Click({
    $selectedItem = $filesDataGrid.SelectedItem
    if ($selectedItem) {
        $todayDate = Get-TodayDateString
        $currentComment = $commentTextBox.Text
        
        # Add today's date to the existing comment
        if ([string]::IsNullOrWhiteSpace($currentComment)) {
            $newComment = $todayDate
        } else {
            $newComment = "$currentComment $todayDate"
        }
        
        $commentTextBox.Text = $newComment
        $selectedItem.SetComment($newComment)
        
        # Refresh the DataGrid to show the updated comment
        $filesDataGrid.Items.Refresh()
        $statusTextBlock.Text = "Date added to comment for: $($selectedItem.Name)"
    } else {
        [System.Windows.MessageBox]::Show("Please select a file first.", "No Selection", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

$refreshButton.Add_Click({
    Load-Files
})

# Handle double-click on DataGrid to navigate into folders
$filesDataGrid.Add_MouseDoubleClick({
    $selectedItem = $filesDataGrid.SelectedItem
    if ($selectedItem -and $selectedItem.Type -eq "Folder") {
        try {
            Set-Location -Path $selectedItem.FullPath
            $script:currentDirectory = Get-Location
            Load-Files
        } catch {
            [System.Windows.MessageBox]::Show("Cannot access folder: $($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    }
})

# Handle window closing
$window.Add_Closing({
    # Restore original location
    Set-Location -Path $script:currentDirectory.Path
})


function TestScript
{
    # "C:\Proj\PowerShell\PowerShell v5.1\WPF PowerShell\New Microsoft Word Document.docx"
    # "C:\Proj\PowerShell\PowerShell v5.1\WPF PowerShell\New Microsoft Word Document.docx - Shortcut.lnk"
$shortcutPath = "C:\Path\To\Your\Shortcut.lnk"
$shortcutPath = "C:\Proj\PowerShell\PowerShell v5.1\WPF PowerShell\New Microsoft Word Document.docx - Shortcut.lnk"
# New Microsoft Word Document.docx - Shortcut
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$comment = $shortcut.Comment
Write-Output "Comment: $comment"
# write "Album" wrong field

# how do I get the existing shortcut file comment


    $shortcutPath = "C:\Proj\PowerShell\PowerShell v5.1\WPF PowerShell\New Microsoft Word Document.docx - Shortcut.lnk"
    if (Test-Path $shortcutPath) {
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $comment = $shortcut.Description
        Write-Output "Shortcut comment: $comment"

        $shortcut.Description = (Get-Date).ToString()
        $shortcut.Save()
        Write-Output "Updated shortcut comment to: $($shortcut.Description)"
    } else {
        Write-Output "Shortcut does not exist."
        # Create the shortcut if it doesn't exist
        #$shortcut.TargetPath = "C:\Path\To\Your\Target\File.docx"
        #$shortcut.Save()
    }

} # function TestScript

# Initialize the application
Load-Files

# Show the window
$window.ShowDialog() | Out-Null
