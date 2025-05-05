# SPO Create Sample Sites.ps1
# Import the PnP PowerShell module
Import-Module PnP.PowerShell -ErrorAction Stop

# Connect to SharePoint Online
$AdminCenterURL = "https://yourtenant-admin.sharepoint.com"  # Replace with your tenant admin center URL
$AdminCenterURL = "https://bartco1-admin.sharepoint.com/"


Connect-PnPOnline -Url $AdminCenterURL -UseWebLogin

# Variables
$SitePrefix = "https://yourtenant.sharepoint.com/sites/SampleSite"  # Replace with your tenant URL
$SitePrefix = "https://bartco1-admin.sharepoint.com/sites/SampleSite"

$AdminEmailDomain = "yourtenant.onmicrosoft.com"  # Replace with your tenant domain

$AdminEmailDomain = "bartco1.onmicrosoft.com"




#$AdminCenterURL = ""
#$SitePrefix = ""
#$AdminEmailDomain = ""


#$TotalSites = 2800
$TotalSites = 400

$BatchSize = 100  # Number of sites to create in each batch
$SiteTemplate = "STS#3"  # Team site template

# Function to create a single site
function New-SampleSite {
    param (
        [string]$SiteUrl,
        [string]$SiteTitle,
        [string]$AdminEmail
    )

    try {
        Write-Host "Creating site: $SiteUrl with admin: $AdminEmail" -ForegroundColor Cyan
        New-PnPSite -Url $SiteUrl -Title $SiteTitle -Owner $AdminEmail -Template $SiteTemplate -ErrorAction Stop
        New-PnPSite -
    } catch {
        Write-Host "Error creating site $SiteUrl : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Generate and create sites in batches
for ($i = 1; $i -le $TotalSites; $i += $BatchSize) {
    $BatchEnd = [math]::Min($i + $BatchSize - 1, $TotalSites)
    Write-Host "Processing batch $i to $BatchEnd..." -ForegroundColor Yellow

    for ($j = $i; $j -le $BatchEnd; $j++) {
        $SiteUrl = "$($SitePrefix)$($j)"
        $SiteTitle = "Sample Site $($j)"
        $AdminEmail = "admin$($j)@$($AdminEmailDomain)"

        # Create the site
        New-SampleSite -SiteUrl $SiteUrl -SiteTitle $SiteTitle -AdminEmail $AdminEmail
    }
}

Write-Host "All sample sites created successfully!" -ForegroundColor Green

function Test-Local()
{
    $SiteUrl = "https://bartco1-admin.sharepoint.com/sites/SampleSite1"
    $SiteTitle = "Sample Site 1"
    $AdminEmail = "admin1@bartco1.onmicrosoft.com"
    New-SampleSite -SiteUrl $SiteUrl -SiteTitle $SiteTitle -AdminEmail $AdminEmail
}