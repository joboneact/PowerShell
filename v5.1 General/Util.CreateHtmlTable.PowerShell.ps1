<#
.SYNOPSIS
    Extracts structured help-comments from PowerShell scripts in the current directory and generates an HTML file.

.DESCRIPTION
    This script scans all `.ps1` files in the current directory, extracts structured help-comments (e.g., `.SYNOPSIS`, `.DESCRIPTION`, `.OUTPUTS`),
    and generates an HTML file displaying the comments in a single table. Each script name is linked to its file.

.PARAMETER None
    No parameters are required for this script.

.OUTPUTS
    Generates an HTML file named `HelpComments.html` in the current directory.

.NOTES
    Author: Your Name
    Date: May 4, 2025
    Version: 2.1
#>

# Define the output HTML file path
$outputHtml = "HelpComments.html"

# Function to initialize the HTML structure
function Initialize-HTML {
    <#
    .SYNOPSIS
        Initializes the HTML structure with a header and basic styling.

    .OUTPUTS
        Returns the initial HTML content as a string.
    #>
    return @"
<!DOCTYPE html>
<html>
<head>
    <title>PowerShell Script Help Comments</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; }
        h1 { color: #333; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f4f4f4; }
        a { color: #007BFF; text-decoration: none; }
        a:hover { text-decoration: underline; }
        td.content { font-family: Consolas, monospace; font-size: 0.9em; }
    </style>
</head>
<body>
    <h1>PowerShell Script Help Comments</h1>
    <table>
        <tr>
            <th>Script Name</th>
            <th>Type</th>
            <th>Content</th>
        </tr>
"@
}

# Function to process a single script file and extract structured help-comments
function Process-ScriptFile {
    param (
        [string]$FilePath,
        [ref]$LastScriptName
    )
    <#
    .SYNOPSIS
        Processes a single script file to extract structured help-comments.

    .PARAMETER FilePath
        The full path of the script file to process.

    .PARAMETER LastScriptName
        A reference variable to track the last processed script name.

    .OUTPUTS
        Returns the HTML rows for the script's help-comments as a string.
    #>

    # Read the content of the script file
    $content = Get-Content -Path $FilePath

    # Extract structured help-comments
    $helpComments = @{
        SYNOPSIS    = ($content -match '(?<=\.SYNOPSIS).*' | ForEach-Object { $_.Trim() })
        DESCRIPTION = ($content -match '(?<=\.DESCRIPTION).*' | ForEach-Object { $_.Trim() })
        PARAMETERS  = ($content -match '(?<=\.PARAMETER).*' | ForEach-Object { $_.Trim() })
        OUTPUTS     = ($content -match '(?<=\.OUTPUTS).*' | ForEach-Object { $_.Trim() })
        NOTES       = ($content -match '(?<=\.NOTES).*' | ForEach-Object { $_.Trim() })
    }

    # Skip files with no help-comments
    if (-not ($helpComments.SYNOPSIS -or $helpComments.DESCRIPTION -or $helpComments.OUTPUTS)) {
        return ""
    }

    # Generate HTML rows for the script
    $scriptName = [System.IO.Path]::GetFileName($FilePath)
    $scriptUrl = "./$scriptName" # Relative URL to the script file
    $html = ""

    # Check if this is a new script and add a colored row
    if ($LastScriptName.Value -ne $scriptName) {
        $html += "<tr style='background-color: #f0f8ff;'>"
        $html += "<td colspan='3'><strong>$scriptName</strong></td>"
        $html += "</tr>"
        $LastScriptName.Value = $scriptName
    }

    foreach ($key in $helpComments.Keys) {
        if ($helpComments[$key]) {
            $html += "<tr>"
            $html += "<td><a href='$scriptUrl'>$scriptName</a></td>"
            $html += "<td>$key</td>"
            $html += "<td class='content'>$($helpComments[$key] -join '<br>')</td>"
            $html += "</tr>"
        }
    }

    return $html
}

# Function to finalize the HTML structure
function Finalize-HTML {
    <#
    .SYNOPSIS
        Finalizes the HTML structure by closing the tags.

    .OUTPUTS
        Returns the closing HTML content as a string.
    #>
    return @"
    </table>
</body>
</html>
"@
}

# Main script logic
function Generate-HelpCommentsHTML {
    <#
    .SYNOPSIS
        Main function to generate the HTML file with structured help-comments.

    .OUTPUTS
        Writes the HTML content to the output file.
    #>

    # Initialize the HTML content
    $htmlContent = Initialize-HTML

    # Get all .ps1 files in the current directory
    $scriptFiles = Get-ChildItem -Path . -Filter *.ps1

    # Track the last script name for colored rows
    $lastScriptName = [ref] ""

    # Process each script file
    foreach ($file in $scriptFiles) {
        $htmlContent += Process-ScriptFile -FilePath $file.FullName -LastScriptName $lastScriptName
    }

    # Finalize the HTML content
    $htmlContent += Finalize-HTML

    # Write the HTML content to the output file
    $htmlContent | Set-Content -Path $outputHtml -Encoding UTF8

    # Inform the user
    Write-Host "Help comments extracted and saved to $outputHtml"
}

# Execute the main function
Generate-HelpCommentsHTML


<#


Key Changes:
Single Table for All Scripts:

All scripts are included in a single table, with each script contributing multiple rows (one for each help-comment type).
Columns:

The table includes three columns: Script Name, Type (e.g., .SYNOPSIS, .DESCRIPTION), and Content.
Clickable Script Links:

The Script Name column contains clickable links to the corresponding .ps1 files.
Improved HTML Structure:

The table is initialized in Initialize-HTML and finalized in Finalize-HTML.
Result:
Running this script will generate an HelpComments.html file in the current directory. The file will contain a single table listing all .ps1 files, their help-comment types, and the corresponding content. Each script name will be a clickable link to the file.



Key Changes:
Tracking Script Name:

Added a $LastScriptName reference variable to track the last processed script name.
Colored Row for New Script:

Inserted a row with a light blue background (#f0f8ff) and a colspan="3" whenever a new script is encountered.
Updated Function Parameters:

The Process-ScriptFile function now accepts a reference to $LastScriptName to determine when a new script starts.
Result:
When you run the script, the generated HTML will include a colored row at the start of each new script, making it visually distinct. The row will span all three columns and display the script name in bold.



Key Changes:
CSS Update:

Added a new CSS class td.content for the "Content" column.
Set the font family to Consolas, monospace and reduced the font size to 0.9em.
HTML Class Assignment:

Applied the class='content' attribute to the <td> element for the "Content" column in the Process-ScriptFile function.
Result:
When you run the script, the "Content" column in the generated HTML will use a smaller, monospaced font (like Consolas), making it easier to read code or structured text.

#>