<#
Generate-PowershellscriptDocu.DL.ps1

.SYNOPSIS
    Create PowerShell Script Documentation.

.DESCRIPTION
    This script extracts the synopsis from PowerShell files and builds an HTML-based documentation.

.PARAMETER export
    Path to export the HTML documentation file.

.EXAMPLES
    .\Generate-PowershellscriptDocu.ps1 -export c:\temp\my-powershell-html-documentation.html

.NOTES
    Author: Christian Reetz
    Updated: 26.02.2016
    Updated to support Exchange Server 2013.
    THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND.
#>

Param (
    [Parameter(Mandatory = $true)]
    [string]$export
)

# Prompt the user to define script folder paths
$scriptpaths = @()
do {
    $input = Read-Host "Define the path of your script-folder(s) (leave blank to finish)"
    if ($input -ne '') {
        $scriptpaths += $input
    }
} until ($input -eq '')

# Collect all .ps1 files from the specified paths
$scripts = @()
foreach ($scriptpath in $scriptpaths) {
    $scripts += Get-ChildItem -Recurse -Filter *.ps1 -Path $scriptpath
}

# HTML Start: Define the HTML structure and styles
$htmlstart = @"
<html>
<head>
    <script language="JavaScript" type="text/javascript">
        function toggleDiv(element) {
            if (document.getElementById(element).style.display == 'none') {
                document.getElementById(element).style.display = 'block';
            } else {
                document.getElementById(element).style.display = 'none';
            }
        }
    </script>
    <style type="text/css">
        body {
            font-family: Segoe UI Light, Tahoma, Verdana, sans-serif;
            font-size: 12pt;
        }
        table {
            border-color: #CCD3D6;
            border-width: 1px;
            border-style: solid;
        }
        h1 {
            font-family: Segoe UI Light, Tahoma, Verdana, sans-serif;
            color: #0072C6;
            font-weight: normal;
            font-size: 18px;
        }
        h2 {
            font-family: Segoe UI Light, Tahoma, Verdana, sans-serif;
            font-weight: normal;
            font-size: 16px;
        }
    </style>
</head>
<body>
    <h1>PowerShell Script Documentation</h1>
    <h2>Generated on: $(Get-Date -Format dd.MM.yyyy)</h2>
"@

# HTML Body: Process each script and extract synopsis
$htmlbody = ""
$i = 0
foreach ($script in $scripts) {
    $synopsis = @()
    $i++
    $flag = 0

    # Extract lines marked as .SYNOPSIS
    Get-Content $script.FullName | ForEach-Object {
        switch -wildcard ($_){
            "*.synopsis*" { $flag = 1 }
            "*#>*" { $flag = 0 }
        }
        if ($flag -eq 1) {
            $synopsis += "$_ <br />"
        }
    }

    # If no .SYNOPSIS is found, extract all comment lines
    if ($synopsis.Count -le 1) {
        Get-Content $script.FullName | ForEach-Object {
            switch -wildcard ($_){
                "*#*" { $flag = 1 }
                default { $flag = 0 }
            }
            if ($flag -eq 1) {
                $synopsis += "$_ <br />"
            }
        }
    }

    
    $htmlbody += "<div id=""divstyle$i"">
    <a href=""javascript:toggleDiv('hidestyle$i');"" title=""collapse/expand"" style=""display:block;"">
    $($script.versioninfo.filename)</a>
    <div id=""hidestyle$i"" style=""display:none; width: 800px;"">
    <table cellpadding=""5"">
    <tr><th>Scriptname</th><th>LastWriteDate</th><th>CreationTime</th></tr>
    <tr><td>$($script.name)</td><td>$($script.LastWriteTime)</td><td>$($script.CreationTime)</td></tr>
    </table>
    $synopsis
    </div></div>"

    <#
    Some quote or escape error  5-4-2025

    # Build the HTML for the current script
    $htmlbody += @"
    <div id="divstyle$i">
        <a href="javascript:toggleDiv('hidestyle$i');" title="collapse/expand" style="display:block;">
            $($script.FullName)
        </a>
        <div id="hidestyle$i" style="display:none; width: 800px;">
            <table cellpadding="5">
                <tr>
                    <th>Script Name</th>
                    <th>Last Write Date</th>
                    <th>Creation Time</th>
                </tr>
                <tr>
                    <td>$($script.Name)</td>
                    <td>$($script.LastWriteTime)</td>
                    <td>$($script.CreationTime)</td>
                </tr>
            </table>
            $synopsis
        </div>
    </div>
    "@


    #>

}

# HTML End: Close the HTML structure
$htmlend = @"
</body>
</html>
"@

# Combine all parts of the HTML
$htmlcode = $htmlstart + $htmlbody + $htmlend

# Export the HTML to the specified file
$htmlcode | Set-Content -Path $export -Encoding UTF8

# Inform the user
Write-Host "HTML documentation has been generated and saved to $export"

