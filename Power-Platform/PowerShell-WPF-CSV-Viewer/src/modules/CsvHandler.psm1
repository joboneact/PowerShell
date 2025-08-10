# CsvHandler.psm1

function Import-CsvData {
    param (
        [string]$FilePath
    )
    if (-Not (Test-Path -Path $FilePath)) {
        throw "The specified CSV file does not exist."
    }
    return Import-Csv -Path $FilePath
}

function Filter-CsvData {
    param (
        [array]$Data,
        [string]$SearchTerm
    )
    if (-not $SearchTerm) {
        return $Data
    }
    $SearchTerm = $SearchTerm.ToLower()
    return $Data | Where-Object {
        $_.Name.ToLower().Contains($SearchTerm) -or
        $_.Description.ToLower().Contains($SearchTerm) -or
        $_.NickName.ToLower().Contains($SearchTerm) -or
        $_.OwnerUPN.ToLower().Contains($SearchTerm)
    }
}

function Convert-ToNestedCsv {
    param (
        [array]$SelectedRows
    )
    $csvOutput = @()
    foreach ($row in $SelectedRows) {
        $csvOutput += "$($row.Name),$($row.Description),$($row.NickName),$($row.OwnerUPN)"
    }
    return $csvOutput -join "`n"
}

function Convert-ToJson {
    param (
        [array]$SelectedRows
    )
    return $SelectedRows | ConvertTo-Json -Depth 3
}

Export-ModuleMember -Function Import-CsvData, Filter-CsvData, Convert-ToNestedCsv, Convert-ToJson