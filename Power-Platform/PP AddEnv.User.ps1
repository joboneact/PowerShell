# Install the Power Platform Admin module if not already installed
Install-Module -Name Microsoft.PowerPlatform.Admin.PowerShell -Force -AllowClobber

# Import the module
Import-Module Microsoft.PowerPlatform.Admin.PowerShell

# Authenticate to Power Platform
Add-PowerAppsAccount

# Define environment details
$environmentName = "MyNewEnvironment"
$region = "unitedstates"  # Specify the region (e.g., unitedstates, europe, etc.)
$environmentType = "Sandbox"  # Options: Production, Sandbox, Trial, etc.

# Create the environment
New-AdminPowerAppEnvironment -DisplayName $environmentName -Location $region -EnvironmentType $environmentType

Write-Host "Environment '$environmentName' created successfully."


# Optionally, you can set the environment as default for the user
Set-AdminPowerAppEnvironmentDefault -EnvironmentName $environmentName


Write-Host "Environment '$environmentName' set as default for the user."
# Optionally, you can assign security roles or permissions to users in the new environment


# Example: Assigning a user to the environment with a specific role
$environmentId = (Get-AdminPowerAppEnvironment -DisplayName $environmentName).EnvironmentId
$userEmail = "mymail@domain.com"  # Replace with the user's email
$roleName = "Environment Maker"  # Replace with the desired role name

# Check if the role exists in the environment
$role = Get-AdminPowerAppEnvironmentRole -EnvironmentName $environmentName | Where-Object { $_.DisplayName -eq $roleName }
if ($role) {
    $roleId = $role.RoleId

    # Assign the role to the user
    Set-AdminPowerAppEnvironmentRoleAssignment -EnvironmentName $environmentName -PrincipalObjectId $userEmail -RoleId $roleId
    Write-Host "User '$userEmail' assigned to role '$roleName' in environment '$environmentName'."
} else {
    Write-Host "Role '$roleName' not found in environment '$environmentName'."
}

<# 

Explanation:
Retrieve Role: The Get-AdminPowerAppEnvironmentRole cmdlet retrieves the roles available in the environment. The script checks if the specified role exists.
Assign Role: The Set-AdminPowerAppEnvironmentRoleAssignment cmdlet assigns the role to the user in the specified environment.
Error Handling: If the role does not exist, the script outputs a message.
Notes:
Replace mymail@domain.com with the actual email of the user.
Ensure the user exists in Azure AD and has access to the Power Platform tenant.
The PrincipalObjectId parameter in Set-AdminPowerAppEnvironmentRoleAssignment can accept the user's email or object ID.
#>