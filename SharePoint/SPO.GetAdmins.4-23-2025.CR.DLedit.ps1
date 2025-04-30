# SPO.GetAdmins.4-23-2025.CR.DLedit.ps1

# Variables for processing
$AdminCenterURL = "https://bartxo-admin.sharepoint.com"
$ReportOutput = "C:\Tmp\SPO\SiteCollectionAdminsResults.csv"

Try {
    # Connect to SharePoint Online
    Connect-SPOService -Url $AdminCenterURL

    # Retrieve all site collections
    $Sites = Get-SPOSite -Limit All
    $SiteData = @()

    # Get Site Collection Administrators for each site
    foreach ($Site in $Sites) {
        try {
            Write-Host -ForegroundColor Yellow "Processing Site Collection: $($Site.Url)"

            # Get all Site Collection Administrators
            $SiteAdmins = Get-SPOUser -Site $Site.Url -Limit ALL |
                          Where-Object { $_.IsSiteAdmin -eq $True } |
                          Select-Object DisplayName, LoginName

            Write-Host $SiteAdmins

            # Process Site Collection Administrators
            $SiteAdmins | ForEach-Object {
                if ($_.LoginName -ne "mcloudgrpproprodsvc@irsgov.onmicrosoft.com") {
                    $SiteData += New-Object PSObject -Property @{
                        'TempID'                = $Site.Id
                        'URL'                   = $Site.Url
                        'Site Collection Admins' = "$($_.DisplayName) ($($_.LoginName));"
                    }
                }
            }
        } catch {
            Write-Host -ForegroundColor Red "Error: $($_.Exception.Message)"
            $SiteData += New-Object PSObject -Property @{
                'TempID'                = $Site.Id
                'URL'                   = $Site.Url
                'Site Collection Admins' = "Error: $($_.Exception.Message)"
            }
        }
    }

    # Export the data to a CSV file
    $SiteData | Export-Csv -Path $ReportOutput -NoTypeInformation
    Write-Host -ForegroundColor Green "Site Collection Administrators Data Exported to CSV!"
} catch {
    Write-Host -ForegroundColor Red "Error: $($_.Exception.Message)"
}


