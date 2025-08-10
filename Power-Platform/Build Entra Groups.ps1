# Import the required module

Import-Module Microsoft.Graph

 

# Connect

Connect-MgGraph

 

# Import the group data from a CSV file

$groups = Import-Csv -Path "C:\Path\bulk-create-groups-example.csv"

 

foreach ($group in $groups) {

    # Create the non–mail-enabled Entra security group

    $newGroup = New-MgGroup -DisplayName $group.Name `

                            -Description $group.Description `

                            -MailEnabled:$false `

                            -MailNickname $group.MailNickName `

                            -SecurityEnabled:$true `

                            -GroupTypes @()

 

    # Assign an owner if specified

    if ($group.OwnerUPN -ne "") {

        $owner = Get-MgUser -UserId $group.OwnerUPN

        Add-MgGroupOwner -GroupId $newGroup.Id -DirectoryObjectId $owner.Id

    }

}