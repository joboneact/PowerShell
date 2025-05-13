# WinForms-Parameters-Sample.ps1
# This script creates a Windows Forms application in PowerShell to collect user input for various parameters.       
# Import the required .NET assemblies for Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Parameter Input Form"
$form.Size = New-Object System.Drawing.Size(400, 300)
$form.StartPosition = "CenterScreen"

# Create a label and textbox for a string parameter
$labelString = New-Object System.Windows.Forms.Label
$labelString.Text = "Enter a string:"
$labelString.Location = New-Object System.Drawing.Point(10, 20)
$labelString.Size = New-Object System.Drawing.Size(100, 20)
$form.Controls.Add($labelString)

$textBoxString = New-Object System.Windows.Forms.TextBox
$textBoxString.Location = New-Object System.Drawing.Point(120, 20)
$textBoxString.Size = New-Object System.Drawing.Size(200, 20)
$form.Controls.Add($textBoxString)

# Create a label and numeric up-down control for a number parameter
$labelNumber = New-Object System.Windows.Forms.Label
$labelNumber.Text = "Enter a number:"
$labelNumber.Location = New-Object System.Drawing.Point(10, 60)
$labelNumber.Size = New-Object System.Drawing.Size(100, 20)
$form.Controls.Add($labelNumber)

$numericUpDown = New-Object System.Windows.Forms.NumericUpDown
$numericUpDown.Location = New-Object System.Drawing.Point(120, 60)
$numericUpDown.Size = New-Object System.Drawing.Size(200, 20)
$numericUpDown.Minimum = 0
$numericUpDown.Maximum = 100
$form.Controls.Add($numericUpDown)

# Create a label and dropdown (combobox) for a selection parameter
$labelDropdown = New-Object System.Windows.Forms.Label
$labelDropdown.Text = "Select an option:"
$labelDropdown.Location = New-Object System.Drawing.Point(10, 100)
$labelDropdown.Size = New-Object System.Drawing.Size(100, 20)
$form.Controls.Add($labelDropdown)

$comboBox = New-Object System.Windows.Forms.ComboBox
$comboBox.Location = New-Object System.Drawing.Point(120, 100)
$comboBox.Size = New-Object System.Drawing.Size(200, 20)
$comboBox.Items.AddRange(@("Option 1", "Option 2", "Option 3"))
$comboBox.SelectedIndex = 0
$form.Controls.Add($comboBox)

# Create a checkbox for a boolean parameter
$checkBox = New-Object System.Windows.Forms.CheckBox
$checkBox.Text = "Enable feature"
$checkBox.Location = New-Object System.Drawing.Point(10, 140)
$checkBox.Size = New-Object System.Drawing.Size(200, 20)
$form.Controls.Add($checkBox)

# Create an OK button
$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "OK"
$okButton.Location = New-Object System.Drawing.Point(120, 200)
$okButton.Size = New-Object System.Drawing.Size(75, 30)
$okButton.Add_Click({
    # Collect the input values
    $stringValue = $textBoxString.Text
    $numberValue = $numericUpDown.Value
    $dropdownValue = $comboBox.SelectedItem
    $checkboxValue = $checkBox.Checked

    # Display the collected values (or process them as needed)
    [System.Windows.Forms.MessageBox]::Show("String: $stringValue`nNumber: $numberValue`nDropdown: $dropdownValue`nCheckbox: $checkboxValue")

    # Close the form
    $form.Close()
})
$form.Controls.Add($okButton)

# Create a Cancel button
$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = "Cancel"
$cancelButton.Location = New-Object System.Drawing.Point(210, 200)
$cancelButton.Size = New-Object System.Drawing.Size(75, 30)
$cancelButton.Add_Click({
    $form.Close()
})
$form.Controls.Add($cancelButton)

# Show the form
$form.ShowDialog()