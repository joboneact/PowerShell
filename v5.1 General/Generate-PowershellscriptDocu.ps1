<#
    .SYNOPSIS
    Create PowerShell Script Documentation
   
   	Christian Reetz
    (Updated by Christian Reetz to support Exchange Server 2013)
	
	THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE 
	RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
	
	26.02.2016
	
    .DESCRIPTION

    This scripts take the synopsis from powershell files and build a html-based documentation
	
	PARAMETER export
    path to export the html-documentation-file...
	
	EXAMPLES
    .\Generate-PowershellscriptDocu.ps1 -export c:\temp\my-powershell-html-documentation.html

    #>

Param (
	[Parameter(Mandatory=$true)] $export
)

# Get a list of definded script pathes

$scriptpaths = @()
do {
$input = (Read-Host "Define the path of your script-folder(s)")
if ($input -ne '') {$scriptpaths += $input}
}
until ($input -eq '')

# Import ps1 Files in this pathes

foreach ($scriptpath in $scriptpaths)
{
$scripts += $(Get-ChildItem -recurse $scriptpath\*.ps1)
}

#html start, head

$htmlstart = "<html>
<head>
 <script language=""JavaScript"" type=""text/javascript"">
			        <!--
			        function toggleDiv(element){
			        if(document.getElementById(element).style.display == 'none')
			        document.getElementById(element).style.display = 'block';
			        else
    			    document.getElementById(element).style.display = 'none';
			        }
			        //-->
			        </script>
<style type=""text/css"">
    BODY{
    font-family: Segoe UI WPC Light, Segoe UI Light, Tahoma, Microsoft Sans Serif, Verdana,sans-serif;
    font-size: 12pt;
    }
    table{
    border-color: #CCD3D6; 
    border-width: 1px; 
    border-style: solid;
    }
    H1{
    font-family: Segoe UI WPC Light, Segoe UI Light, Tahoma, Microsoft Sans Serif, Verdana,sans-serif;
    color: #0072C6;
    font-weight: normal;
    font-size: 18px;
    }
    H2{
    font-family: Segoe UI WPC Light, Segoe UI Light, Tahoma, Microsoft Sans Serif, Verdana,sans-serif;
    font-weight: normal;
    font-size: 16px;
    }
</style>
</head>
<body>
<h1>PowerShell-Script Documentation</h1>
<h2>from: $(Get-Date -Format dd.MM.yyyy)</h2>
"

#HTML Body and entries

foreach ($script in $scripts)
{
    $synopsis=@()
    $i++
    $flag=0
    Get-Content $($script.versioninfo.filename) |
    foreach {
        Switch -wildcard ($_) {
            "*.synopsis*" {$flag=1}
            "*#>*" {$flag=0}
        }
        if ($flag -eq 1) {
            $synopsis += "$_ <br />"
        }
    }
    if ($synopsis.count -le 1)
    {
        Get-Content $($script.versioninfo.filename) |
        foreach {
            Switch -wildcard ($_) {
                "*#*" {$flag=1}
                default {$flag=0}
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
}
#Html End

$htmlend = "</body>
</html>"

#Build html-file

$htmlcode = $htmlstart + $htmlbody + $htmlend

#Export as HTML-File

$htmlcode > $export