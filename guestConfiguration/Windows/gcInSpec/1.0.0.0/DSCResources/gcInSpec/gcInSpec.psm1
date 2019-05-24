
<#
    .SYNOPSIS
        Returns an object with details of InSpec installation
    .DESCRIPTION
        Queries WMI to get currently installed InSpec versions.
        Returns object with installation status and versions.    
#>
function Get-InstalledInSpecVersions {
    [cmdletbinding()]
    param(
    )

    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Checking for InSpec..."
    
    $Installed_InSpec = Get-CimInstance win32_product -Filter "Name LIKE 'InSpec%'"
    $Installed_InSpec_Version = $Installed_InSpec.Version
    $Installed_InSpec = if ($null -eq $Installed_InSpec_Version) { $false } else { $true }
    
    $returnStatus = New-Object -TypeName PSObject -ArgumentList @{
        Installed = $Installed_InSpec
        Version  = $Installed_InSpec_Version
    }

    Write-Verbose "[$((get-date).getdatetimeformats()[45])] InSpec installed: $Installed_InSpec"
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] InSpec versions: $Installed_InSpec_Version"


    return $returnStatus
}

<#
    .SYNOPSIS
        Download and install InSpec
    .DESCRIPTION
        Downloads the InSpec installation for Windows
        and installs it to the current directory.    
#>
function Install-Inspec {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true)]
        [version]$InSpec_Version
    )
    
    $InSpec_Package_Version = "$($InSpec_Version.Major).$($InSpec_Version.Minor).$($InSpec_Version.Build)"
    $Inspec_Package_Name = "inspec-$InSpec_Package_Version-$($InSpec_Version.Revision)-x64.msi"
    $Inspec_Download_Uri = "https://packages.chef.io/files/stable/inspec/$InSpec_Package_Version/windows/2016/$Inspec_Package_Name"
        
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Downloading InSpec to $gcinspec_module_folder_path\$Inspec_Package_Name"
    Invoke-WebRequest -Uri $Inspec_Download_Uri -TimeoutSec 120 -OutFile "$env:windir\temp\$Inspec_Package_Name"
        
    $msiArguments = @(
        '/i'
        ('"{0}"' -f "$env:windir\temp\$Inspec_Package_Name")
        '/qn'
        "/L*v `"$env:windir\temp\$Inspec_Package_Name.log`""
    )
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Installing InSpec with arguments: $msiArguments"
    Start-Process "C:\Windows\System32\msiexec.exe" -ArgumentList $msiArguments -Wait -NoNewWindow
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] InSpec installation process ended"
}

<#
    .SYNOPSIS
        Runs InSpec with parameters
    .DESCRIPTION
        This function executes the .bat file provided with
        InSpec, using parameter input for the path to
        profiles and desitnation for json/cli output.
    
#>
function Invoke-InSpec {
    param(
        [Parameter(Mandatory = $true)]
        [string]$policy_folder_path,
        [Parameter(Mandatory = $true)]
        [string]$inspec_output_file_path,
        [Parameter(Mandatory = $true)]
        [string]$inspec_cli_output_file_path,
        [string]$attributes_file_path
    )
    
    # path to the inspec bat file
    $InSpec_Exec_Path = "$env:SystemDrive\opscode\inspec\bin\inspec.bat"
@"
@ECHO OFF
SET HOMEDRIVE=%SystemDrive%
"%~dp0..\embedded\bin\ruby.exe" "%~dpn0" %*
"@ | Set-Content $InSpec_Exec_Path

    # TEMP this can be an issue when testing in Windows PowerShell, InSpec does not like spaces in paths
    foreach ($path in ($policy_folder_path,$inspec_output_file_path,$inspec_cli_output_file_path,$attributes_file_path)) {
        $path = $path -replace 'Program Files', 'progra~1'
    }
    
    $run_inspec_exec_arguements = @(
        "exec $policy_folder_path"
        "--reporter=json-min:$inspec_output_file_path cli:$inspec_cli_output_file_path"
        "--chef-license=accept"
    )

    # add attributes reference if input is provided
    if ('' -ne $attributes_file_path) {
        $run_inspec_exec_arguements += " --attrs $attributes_file_path"
    }

    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Starting the InSpec process with the command $InSpec_Exec_Path $run_inspec_exec_arguements" 
    
    # temp log file for debugging
    "$InSpec_Exec_Path $run_inspec_exec_arguements" | Set-Content "$env:windir\temp\inspecexec.txt"
    Start-Process $InSpec_Exec_Path -ArgumentList $run_inspec_exec_arguements -Wait -NoNewWindow
}

<#
    .SYNOPSIS
        Creates a PowerShell object based on InSpec output.
    .DESCRIPTION
        Takes location of json-min and cli output files
        and converts the information to a PowerShell object
        with properties for use in the DSC resource.
    
#>
function ConvertFrom-InSpec {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$inspec_output_file_path,
        [Parameter(Mandatory = $true)]
        [string]$inspec_cli_output_file_path
    )
    
    # get JSON file containing InSpec output
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Reading json output from $inspec_output_file_path" 
    $inspecResults = Get-Content $inspec_output_file_path | ConvertFrom-Json

    # get raw content from CLI file
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Reading cli output from $inspec_cli_output_file_path" 
    $inspecCLI = Get-Content $inspec_cli_output_file_path
    # remove color encoding from CLI output
    $inspecCLI = $inspecCLI -replace '\x1b\[[0-9;]*m', ''

    # create and set statistics object
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Setting duration statistics to: $($inspecResults.statistics.duration)"
    $statistics = $inspecResults.statistics.duration
    
    # there can be multiple controls in a profile
    $controls = @()

    # store reasons code/phrase for Get
    $reasons = @()

    # results are compliant until a failed test is returned
    [bool]$is_compliant = $true

    # loop through each control and create objects for the array; set compliance
    foreach ($control in $inspecResults.controls) {

        Write-Verbose "[$((get-date).getdatetimeformats()[45])] Processing reasons data for: $($control.code_desc)"
        
        [bool]$test_compliant   = $true
        [bool]$test_skipped     = $false
        $reason_phrase          = $null

        Write-Verbose "[$((get-date).getdatetimeformats()[45])] Control status: $($control.status)"
        
        if ('failed' -eq $control.status) {
            $is_compliant = $false
            $test_compliant = $false
        }

        if ('skipped' -eq $control.status) {
            $test_skipped = $true
        }

        # any non-compliant tests should start with this text
        if ($false -eq $test_compliant -and $false -eq $test_skipped) {
            $reason_phrase = 'InSpec policy test failed. '
        
            if ($null -ne $control.code_desc) {
                Write-Verbose "[$((get-date).getdatetimeformats()[45])] Control description: $($control.status)"
                $reason_phase += " Test description: $($control.code_desc)"
            } else {
                Write-Verbose "Policy test failed, but no code description found for the reason phrase."
            }
            
            if ($null -ne $control.message) {
                Write-Verbose "[$((get-date).getdatetimeformats()[45])] Control message: $($control.status)"
                $reason_phrase += "Test message: $($control.message)"
            } else {
                Write-Verbose "Policy test failed, but no message found for the reason phrase."
            }
        }

        Write-Verbose "[$((get-date).getdatetimeformats()[45])] Control reason phrases: $reason_phrase)"

        # each control object (future use)
        $controls += New-Object -TypeName PSObject -Property @{
            id             = $control.id
            profile_id     = $control.profile_id
            profile_sha256 = $control.profile_sha256
            status         = $control.status
            code_desc      = $control.code_desc
            message        = $control.message
            reason_phrase  = $reason_phrase
        }
        
        $reasons += @{
            Code    = "gcInSpec:gcInSpec:InSpecPolicyNotCompliant"
            Phrase  = $reason_phrase
        }
    }

    # parent object containing all info including raw output (future use)
    $inspecObject = New-Object -TypeName PSObject -Property @{
        version        = $inspecResults.version
        statistics     = $statistics
        controls       = $controls
        status         = $is_compliant
        cli            = $inspecCLI
        reasons        = $reasons
    }
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Overall status: $($inspecObject.status)"
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Reason phrase: $($inspecObject.reasons)"

    return $inspecObject
}

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

    $Installed_InSpec_Version = (Get-InstalledInSpecVersions).version
    if ($Installed_InSpec_Version -ne $version) {
        Install-Inspec $version
        
        $Installed_InSpec_Version = (Get-InstalledInSpecVersions).version
        if ($Installed_InSpec_Version -ne $version) {
            throw 'InSpec installation was not successful'
        }
    }

    $configuration_folder = "C:\ProgramData\GuestConfig\Configuration\$name\Modules\$name"
    $args = @{
        policy_folder_path          = "$configuration_folder\"
        inspec_output_file_path     = "$configuration_folder\$name.json"
        inspec_cli_output_file_path = "$configuration_folder\$name.cli"
    }

    Invoke-InSpec @args
    $args.remove('policy_folder_path')
    $inspec = ConvertFrom-InSpec @args

    $Reasons = @{
        Code    = 'gcInSpec:gcInSpec:InSpecPolicyNotCompliant'
        Phrase  = $inspec.cli
    }

    $return = @{
        name    = $name
        version = $Installed_InSpec_Version
        status  = $inspec.status
        Reasons = $Reasons
    }
    return $return
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

    $status = (Get-TargetResource -name $name -version $version).status
    return $status
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
