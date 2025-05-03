# PP Copy Flow Environment.ps1
# This script exports a Power Automate workflow (flow) from one environment and imports it into another.

# Install the Power Platform Admin module if not already installed
# This module provides cmdlets to manage Power Platform environments and flows.
Install-Module -Name Microsoft.PowerPlatform.Admin.PowerShell -Force -AllowClobber

# Import the Power Platform Admin module
Import-Module Microsoft.PowerPlatform.Admin.PowerShell

# Authenticate to Power Platform
# This command prompts the user to log in with their Microsoft 365 account.
# Ensure the account has sufficient permissions in both source and target environments.
Add-PowerAppsAccount

# Define source and target environments and flow details
# Replace these variables with the appropriate values for your environments and flow.
$sourceEnvironment = "SourceEnvironmentName"  # Name of the source environment
$targetEnvironment = "TargetEnvironmentName"  # Name of the target environment
$flowName = "MyFlow"                          # Name of the flow to be moved
$exportPath = "C:\Temp\MyFlow.zip"            # Path to save the exported flow file

# Export the flow from the source environment
# This step exports the specified flow from the source environment and saves it as a .zip file.
Write-Host "Exporting flow '$flowName' from environment '$sourceEnvironment'..."
Export-AdminPowerAppFlow -EnvironmentName $sourceEnvironment -FlowName $flowName -FilePath $exportPath -ErrorAction Stop
Write-Host "Flow '$flowName' exported successfully to '$exportPath'."

# Import the flow into the target environment
# This step imports the previously exported flow .zip file into the target environment.
Write-Host "Importing flow '$flowName' into environment '$targetEnvironment'..."
Import-AdminPowerAppFlow -EnvironmentName $targetEnvironment -FilePath $exportPath -ErrorAction Stop
Write-Host "Flow '$flowName' imported successfully into environment '$targetEnvironment'."

<#
Explanation:

1. Export Flow:
   - The `Export-AdminPowerAppFlow` cmdlet exports the specified flow from the source environment.
   - The flow is saved as a .zip file at the specified path (`$exportPath`).
   - The `-ErrorAction Stop` parameter ensures that the script stops execution if an error occurs during the export process.

2. Import Flow:
   - The `Import-AdminPowerAppFlow` cmdlet imports the exported flow .zip file into the target environment.
   - The `-ErrorAction Stop` parameter ensures that the script stops execution if an error occurs during the import process.

3. Authentication:
   - The `Add-PowerAppsAccount` cmdlet is used to authenticate to Power Platform.
   - Ensure the account used has sufficient permissions to export flows from the source environment and import them into the target environment.

4. Parameters:
   - `$sourceEnvironment`: The name of the environment from which the flow will be exported.
   - `$targetEnvironment`: The name of the environment into which the flow will be imported.
   - `$flowName`: The name of the flow to be moved.
   - `$exportPath`: The file path where the exported flow will be saved.

5. Prerequisites:
   - Ensure the `Microsoft.PowerPlatform.Admin.PowerShell` module is installed.
   - The user running the script must have the necessary permissions to export and import flows in the respective environments.

6. Error Handling:
   - The `-ErrorAction Stop` parameter ensures that the script stops execution if any errors occur during the export or import process.
   - This helps prevent partial or incomplete operations.

7. Notes:
   - Ensure that the flow being moved does not have dependencies that are missing in the target environment.
   - If the flow uses connections, you may need to reconfigure them in the target environment after import.

#>