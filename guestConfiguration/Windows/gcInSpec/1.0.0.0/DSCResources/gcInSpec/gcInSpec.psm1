
$script:Supported_InSpec_Version = [version]'4.3.2.1'
$script:module_path = split-path -parent $MyInvocation.MyCommand.Definition
$script:module_path = $script:module_path -replace 'Program Files', 'progra~1'
$script:guest_assignment_folder = (Get-Item $script:module_path).Parent.FullName
$script:guest_assignment_folder = $script:guest_assignment_folder -replace 'Program Files', 'progra~1'

function Get-TargetResource {
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $version
    )

    Write-Verbose "[$((get-date).getdatetimeformats()[45])] required InSpec version: $version"

    $Installed_InSpec_Versions = (Get-InstalledInSpecVersions).versions
    if ($Installed_InSpec_Versions -notcontains $version) {
        Install-Inspec
    }

    $InSpecArgs = @{
        policy_folder_path          = "$script:guest_assignment_folder\$name\"
        inspec_output_file_path     = "$script:guest_assignment_folder\$name.json"
        inspec_cli_output_file_path = "$script:guest_assignment_folder\$name.cli"
    }

    Invoke-InSpec @InSpecArgs
        
    $ConvertArgs = @{
        inspec_output_file_path     = "$script:guest_assignment_folder\$name.json"
        inspec_cli_output_file_path = "$script:guest_assignment_folder\$name.cli"
    }
        
    $get = ConvertFrom-InSpec @ConvertArgs
 
    $Reasons = $get.Reasons
    return $Reasons
}

function Test-TargetResource {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $version
    )

    $reasons = @(Get-TargetResource -Name $Name).Reasons

    if ($null -ne $reasons -and $reasons.Count -gt 0) {
        return $false
    }

    return $true
}

function Set-TargetResource {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $version
    )

    throw 'Set functionality is not supported in this version of the DSC resource.'
}