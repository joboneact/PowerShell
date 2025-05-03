# PP Copy Environment.ps1
# This script exports a Power Apps solution from one environment and imports it into another.

# Install the Power Platform Admin module if not already installed
# This module provides cmdlets to manage Power Platform environments and solutions.
Install-Module -Name Microsoft.PowerPlatform.Admin.PowerShell -Force -AllowClobber

# Import the Power Platform Admin module
Import-Module Microsoft.PowerPlatform.Admin.PowerShell

# Authenticate to Power Platform
# This command prompts the user to log in with their Microsoft 365 account.
# Ensure the account has sufficient permissions in both source and target environments.
Add-PowerAppsAccount

# Define source and target environments and solution details
# Replace these variables with the appropriate values for your environments and solution.
$sourceEnvironment = "SourceEnvironmentName"  # Name of the source environment
$targetEnvironment = "TargetEnvironmentName"  # Name of the target environment
$solutionName = "MySolution"                  # Name of the solution to be moved
$exportPath = "C:\Temp\MySolution.zip"        # Path to save the exported solution file

# Export the solution from the source environment
# This step exports the specified solution from the source environment and saves it as a .zip file.
Write-Host "Exporting solution '$solutionName' from environment '$sourceEnvironment'..."
Export-PowerAppSolution -EnvironmentName $sourceEnvironment -SolutionName $solutionName -SolutionFilePath $exportPath -ErrorAction Stop
Write-Host "Solution '$solutionName' exported successfully to '$exportPath'."

# Import the solution into the target environment
# This step imports the previously exported solution .zip file into the target environment.
Write-Host "Importing solution '$solutionName' into environment '$targetEnvironment'..."
Import-PowerAppSolution -EnvironmentName $targetEnvironment -SolutionFilePath $exportPath -ErrorAction Stop
Write-Host "Solution '$solutionName' imported successfully into environment '$targetEnvironment'."

<#
Explanation:

1. Export Solution:
   - The `Export-PowerAppSolution` cmdlet exports the specified solution from the source environment.
   - The solution is saved as a .zip file at the specified path (`$exportPath`).
   - The `-ErrorAction Stop` parameter ensures that the script stops execution if an error occurs during the export process.

2. Import Solution:
   - The `Import-PowerAppSolution` cmdlet imports the exported solution .zip file into the target environment.
   - The `-ErrorAction Stop` parameter ensures that the script stops execution if an error occurs during the import process.

3. Authentication:
   - The `Add-PowerAppsAccount` cmdlet is used to authenticate to Power Platform.
   - Ensure the account used has sufficient permissions to export solutions from the source environment and import them into the target environment.

4. Parameters:
   - `$sourceEnvironment`: The name of the environment from which the solution will be exported.
   - `$targetEnvironment`: The name of the environment into which the solution will be imported.
   - `$solutionName`: The name of the solution to be moved.
   - `$exportPath`: The file path where the exported solution will be saved.

5. Prerequisites:
   - Ensure the `Microsoft.PowerPlatform.Admin.PowerShell` module is installed.
   - The user running the script must have the necessary permissions to export and import solutions in the respective environments.

6. Error Handling:
   - The `-ErrorAction Stop` parameter ensures that the script stops execution if any errors occur during the export or import process.
   - This helps prevent partial or incomplete operations.

7. Notes:
   - Ensure that the solution being moved does not have dependencies that are missing in the target environment.
   - If the solution is managed, ensure that the target environment allows managed solutions to be imported.

#>