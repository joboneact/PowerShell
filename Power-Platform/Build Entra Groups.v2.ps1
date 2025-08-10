<#

Build Entra Groups.v2.ps1


.SYNOPSIS
    Script to create Entra security groups in bulk and assign owners using Microsoft Graph API.

.DESCRIPTION
    This script reads group details from a CSV file and creates non-mail-enabled Entra security groups 
    in Microsoft Entra ID (formerly Azure AD). It also assigns owners to the groups if specified in the CSV file.

.PARAMETER None
    This script does not take any parameters. Ensure the CSV file path is correctly specified in the script.

.INPUTS
    None. The script reads input from a CSV file.

.OUTPUTS
    None. The script creates groups and assigns owners in Microsoft Entra ID.

.NOTES
    - Requires the Microsoft.Graph PowerShell module.
    - Ensure you are authenticated to Microsoft Graph before running the script.
    - The CSV file should contain the following columns:
        - Name: The display name of the group.
        - Description: A description of the group.
        - MailNickName: The mail nickname for the group.
        - OwnerUPN: The User Principal Name of the group owner (optional).

.EXAMPLE
    Run the script to create groups:
        .\Build Entra Groups.v2.ps1

    This will create groups based on the data in the specified CSV file and assign owners if provided.
#>

# Check if the Microsoft.Graph module is installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Write-Error "The Microsoft.Graph module is not installed. Install it using 'Install-Module -Name Microsoft.Graph' and try again."
    exit 1
} # End of check for Microsoft.Graph module installation

# Import the required module for Microsoft Graph API functionality
try {
    Import-Module Microsoft.Graph -ErrorAction Stop
    Write-Host "Microsoft.Graph module imported successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to import the Microsoft.Graph module. Ensure it is installed and try again."
    exit 1
} # End of try-catch for importing Microsoft.Graph module

# Connect to Microsoft Graph API using the authenticated account
try {
    Connect-MgGraph -ErrorAction Stop
    Write-Host "Connected to Microsoft Graph successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to connect to Microsoft Graph. Ensure you are authenticated and have the necessary permissions."
    exit 1
} # End of try-catch for connecting to Microsoft Graph

# Define the path to the CSV file
$csvFilePath = "C:\Path\bulk-create-groups-example.csv"

# Check if the CSV file exists
if (-not (Test-Path -Path $csvFilePath)) {
    Write-Error "The CSV file '$csvFilePath' does not exist. Ensure the file path is correct and try again."
    exit 1
} # End of check for CSV file existence

# Import the group data from the CSV file
try {
    $groups = Import-Csv -Path $csvFilePath -ErrorAction Stop
    Write-Host "CSV file imported successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to import the CSV file. Ensure the file is in the correct format and try again."
    exit 1
} # End of try-catch for importing CSV file

# Iterate through each group entry in the CSV file
foreach ($group in $groups) {
    try {
        # Validate required fields in the CSV file
        if (-not $group.Name -or -not $group.Description -or -not $group.MailNickName) {
            Write-Warning "Skipping group creation due to missing required fields (Name, Description, or MailNickName)."
            continue
        } # End of validation for required fields

        # Create a new non-mail-enabled Entra security group with the specified properties
        $newGroup = New-MgGroup -DisplayName $group.Name `
                                -Description $group.Description `
                                -MailEnabled:$false `
                                -MailNickname $group.MailNickName `
                                -SecurityEnabled:$true `
                                -GroupTypes @()
        Write-Host "Group '$($group.Name)' created successfully." -ForegroundColor Green

        # Check if an owner is specified for the group
        if ($group.OwnerUPN -ne "") {
            try {
                # Retrieve the user object for the specified owner using their UPN (User Principal Name)
                $owner = Get-MgUser -UserId $group.OwnerUPN -ErrorAction Stop

                # Assign the retrieved user as the owner of the newly created group
                Add-MgGroupOwner -GroupId $newGroup.Id -DirectoryObjectId $owner.Id
                Write-Host "Owner '$($group.OwnerUPN)' assigned to group '$($group.Name)' successfully." -ForegroundColor Green
            } catch {
                Write-Warning "Failed to assign owner '$($group.OwnerUPN)' to group '$($group.Name)'. Ensure the owner UPN is valid."
            } # End of try-catch for assigning group owner
        } # End of check for owner specification
    } catch {
        Write-Warning "Failed to create group '$($group.Name)'. Error: $_"
    } # End of try-catch for group creation
} # End of foreach loop for processing groups

Write-Host "Script execution completed."