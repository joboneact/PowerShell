# PP.All.AddEnv.User.ps1

# Install the Power Platform Admin module if not already installed
# This module provides cmdlets to manage Power Platform environments and resources
Install-Module -Name Microsoft.PowerPlatform.Admin.PowerShell -Force -AllowClobber

# Import the Power Platform Admin module
Import-Module Microsoft.PowerPlatform.Admin.PowerShell

# Function to resolve UPN to Object ID
function Resolve-UPNToObjectId {
    <#
    Explanation:
Function Purpose:

The Resolve-UPNToObjectId function takes a UPN (email address) as input and resolves it to the corresponding Azure AD object ID using the Get-AzureADUser cmdlet.


The Get-AzureADUser cmdlet requires the AzureAD module. Install it using:
Install-Module -Name AzureAD -Force

Error Handling:

The function uses a try-catch block to handle errors gracefully, such as if the user is not found or if there are connectivity issues with Azure AD.
Return Value:

If the user is found, the function returns the ObjectId of the user.
If the user is not found or an error occurs, it returns $null.
Integration:

This function can be used in the main script to resolve the OwnerEmail (UPN) to an object ID before assigning roles in the environment. For example:
    #>
    param (
        [string]$UserPrincipalName
    )

    # Use Azure AD cmdlet to retrieve the user object
    try {

        $user = Get-AzureADUser -Filter "UserPrincipalName eq '$UserPrincipalName'" -ErrorAction Stop
        if ($user) {
            Write-Host "Object ID for UPN '$UserPrincipalName' is '$($user.ObjectId)'."
            return $user.ObjectId
        } else {
            Write-Host "User with UPN '$UserPrincipalName' not found."
            return $null
        }
    } catch {
        Write-Host "Error resolving UPN '$UserPrincipalName': $_"
        return $null
    }
}


# Example usage of the Resolve-UPNToObjectId function
# Uncomment the following line to test the function
# $objectId = Resolve-UPNToObjectId -UserPrincipalName "sampleowner@domain.com"
# Write-Host "Resolved Object ID: $objectId"

<#
$ownerObjectId = Resolve-UPNToObjectId -UserPrincipalName $OwnerEmail
if ($ownerObjectId) {
    Set-AdminPowerAppEnvironmentRoleAssignment -EnvironmentName $EnvironmentName -PrincipalObjectId $ownerObjectId -RoleId $roleId
} else {
    Write-Host "Unable to assign role. Object ID for '$OwnerEmail' could not be resolved."
}
#>

function Create-SampleEnvironment {
    param (
        [string]$EnvironmentName = "SampleEnvironment",
        [string]$Region = "unitedstates",
        [string]$EnvironmentType = "Sandbox",
        [string]$OwnerEmail = "owner@domain.com",
        [string]$RoleName = "Environment Maker",
        [string]$WorkspaceName = "SampleWorkspace"
    )

    # Authenticate to Power Platform
    Add-PowerAppsAccount

    # Create the environment
    Write-Host "Creating environment '$EnvironmentName'..."
    New-AdminPowerAppEnvironment -DisplayName $EnvironmentName -Location $Region -EnvironmentType $EnvironmentType
    Write-Host "Environment '$EnvironmentName' created successfully."

    # Set the environment as default
    Set-AdminPowerAppEnvironmentDefault -EnvironmentName $EnvironmentName
    Write-Host "Environment '$EnvironmentName' set as default for the user."

    # Retrieve the environment ID
    $environmentId = (Get-AdminPowerAppEnvironment -DisplayName $EnvironmentName).EnvironmentId

    # Assign the owner as a member with the specified role
    Write-Host "Assigning owner '$OwnerEmail' to role '$RoleName' in environment '$EnvironmentName'..."
    $role = Get-AdminPowerAppEnvironmentRole -EnvironmentName $EnvironmentName | Where-Object { $_.DisplayName -eq $RoleName }
    if ($role) {
        $roleId = $role.RoleId
        Set-AdminPowerAppEnvironmentRoleAssignment -EnvironmentName $EnvironmentName -PrincipalObjectId $OwnerEmail -RoleId $roleId
        Write-Host "Owner '$OwnerEmail' assigned to role '$RoleName' in environment '$EnvironmentName'."
    } else {
        Write-Host "Role '$RoleName' not found in environment '$EnvironmentName'."
    }

    # Grant access to Power BI workspace
    Write-Host "Granting owner access to Power BI workspace '$WorkspaceName'..."
    $workspace = Get-PowerBIWorkspace -Name $WorkspaceName -ErrorAction SilentlyContinue
    if ($workspace) {
        Add-PowerBIWorkspaceUser -Id $workspace.Id -UserPrincipalName $OwnerEmail -AccessRight Member
        Write-Host "Owner '$OwnerEmail' added as a member to Power BI workspace '$WorkspaceName'."
    } else {
        Write-Host "Power BI workspace '$WorkspaceName' not found."
    }

    # Confirm completion
    Write-Host "Sample environment '$EnvironmentName' created and owner '$OwnerEmail' configured successfully."
}

function Add-EnvironmentsAndUsersFromCSV {
    param (
        [string]$CsvFilePath
    )

    # Check if the CSV file exists
    if (-Not (Test-Path $CsvFilePath)) {
        Write-Host "CSV file '$CsvFilePath' not found. Please provide a valid file path."
        return
    }

    # Import the CSV file
    $csvData = Import-Csv -Path $CsvFilePath

    # Loop through each row in the CSV file
    foreach ($row in $csvData) {
        $environmentName = $row.EnvironmentName
        $region = $row.Region
        $environmentType = $row.EnvironmentType
        $ownerEmail = $row.OwnerEmail
        $roleName = $row.RoleName
        $workspaceName = $row.WorkspaceName

        Write-Host "Processing environment '$environmentName' with owner '$ownerEmail'..."

        try {
            # Create the environment
            New-AdminPowerAppEnvironment -DisplayName $environmentName -Location $region -EnvironmentType $environmentType
            Write-Host "Environment '$environmentName' created successfully."

            # Set the environment as default
            Set-AdminPowerAppEnvironmentDefault -EnvironmentName $environmentName
            Write-Host "Environment '$environmentName' set as default for the user."

            # Retrieve the environment ID
            $environmentId = (Get-AdminPowerAppEnvironment -DisplayName $environmentName).EnvironmentId

            # Resolve the owner's UPN to Object ID
            $ownerObjectId = Resolve-UPNToObjectId -UserPrincipalName $ownerEmail
            if ($ownerObjectId) {
                # Assign the owner as a member with the specified role
                $role = Get-AdminPowerAppEnvironmentRole -EnvironmentName $environmentName | Where-Object { $_.DisplayName -eq $roleName }
                if ($role) {
                    $roleId = $role.RoleId
                    Set-AdminPowerAppEnvironmentRoleAssignment -EnvironmentName $environmentName -PrincipalObjectId $ownerObjectId -RoleId $roleId
                    Write-Host "Owner '$ownerEmail' assigned to role '$roleName' in environment '$environmentName'."
                } else {
                    Write-Host "Role '$roleName' not found in environment '$environmentName'."
                }
            } else {
                Write-Host "Unable to resolve Object ID for owner '$ownerEmail'. Skipping role assignment."
            }

            # Grant access to Power BI workspace
            if ($workspaceName) {
                $workspace = Get-PowerBIWorkspace -Name $workspaceName -ErrorAction SilentlyContinue
                if ($workspace) {
                    Add-PowerBIWorkspaceUser -Id $workspace.Id -UserPrincipalName $ownerEmail -AccessRight Member
                    Write-Host "Owner '$ownerEmail' added as a member to Power BI workspace '$workspaceName'."
                } else {
                    Write-Host "Power BI workspace '$workspaceName' not found."
                }
            }

        } catch {
            Write-Host "Error processing environment '$environmentName': $_"
        }
    }

    Write-Host "All environments and users from the CSV file have been processed."
}

# Example usage of the function
# Add-EnvironmentsAndUsersFromCSV -CsvFilePath "C:\Path\To\InputFile.csv"

# Example usage of the function
Create-SampleEnvironment -EnvironmentName "MySampleEnvironment" -OwnerEmail "sampleowner@domain.com" -WorkspaceName "MySampleWorkspace"