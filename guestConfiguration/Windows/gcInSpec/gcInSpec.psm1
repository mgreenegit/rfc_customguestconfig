
$script:Supported_InSpec_Version = [version]'4.3.2.1'
$script:module_path = split-path -parent $MyInvocation.MyCommand.Definition
$script:module_path = $script:module_path -replace 'Program Files', 'progra~1'
$script:guest_assignment_folder = (Get-Item $script:module_path).Parent.FullName
$script:guest_assignment_folder = $script:guest_assignment_folder -replace 'Program Files', 'progra~1'

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
    $Installed_InSpec_Versions = $Installed_InSpec | ForEach-Object { $_.Version }
    $Installed_InSpec = if ($null -eq $Installed_InSpec_Versions) { $false } else { $true }
    
    $returnStatus = New-Object -TypeName PSObject -ArgumentList @{
        Installed = $Installed_InSpec
        Versions  = $Installed_InSpec_Versions
    }

    Write-Verbose "[$((get-date).getdatetimeformats()[45])] InSpec installed: $Installed_InSpec"
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] InSpec versions: $Installed_InSpec_Versions"


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
        [version]$InSpec_Version = $Script:Supported_InSpec_Version
    )
    
    $InSpec_Package_Version = "$($InSpec_Version.Major).$($InSpec_Version.Minor).$($InSpec_Version.Build)"
    $Inspec_Package_Name = "inspec-$InSpec_Package_Version-$($InSpec_Version.Revision)-x64.msi"
    $Inspec_Download_Uri = "https://packages.chef.io/files/stable/inspec/$InSpec_Package_Version/windows/2016/$Inspec_Package_Name"
        
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Downloading InSpec to $script:guest_assignment_folder\$Inspec_Package_Name"
    Invoke-WebRequest -Uri $Inspec_Download_Uri -TimeoutSec 120 -OutFile "$script:guest_assignment_folder\$Inspec_Package_Name" -RetryIntervalSec 5 -MaximumRetryCount 12 
        
    $msiArguments = @(
        '/i'
        ('"{0}"' -f "$script:guest_assignment_folder\$Inspec_Package_Name")
        '/qn'
        "/L*v `"$script:guest_assignment_folder\$Inspec_Package_Name.log`""
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

    $run_inspec_exec_arguements = @(
        "exec $policy_folder_path"
        "--reporter=json-min:$inspec_output_file_path cli:$inspec_cli_output_file_path"
        "--chef-license=accept"
    )

    # add attributes reference if input is provided
    if ('' -ne $attributes_file_path) {
        $run_inspec_exec_arguements += " --attrs $attributes_file_path"
    }

    $env:HOMEDRIVE = $env:SystemDrive

    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Starting the InSpec process with the command $InSpec_Exec_Path $run_inspec_exec_arguements" 
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
    $inspecResults = Get-Content $inspec_output_file_path | ConvertFrom-Json -Depth 10
    
    # get raw content from CLI file
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Reading cli output from $inspec_cli_output_file_path" 
    $inspecCLI = Get-Content $inspec_cli_output_file_path
    # remove color encoding from CLI output
    $inspecCLI = $inspecCLI -replace '\x1b\[[0-9;]*m', ''

    # create and set statistics object
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Setting duration statistics to: $($inspecResults.statistics.duration)"
    $statistics = New-Object -TypeName PSObject -Property @{
        Duration = $inspecResults.statistics.duration
    }
    
    # there can be multiple controls in a profile
    $controls = @()

    # store reasons code/phrase for Get
    $reasons = @()

    # results are compliant until a failed test is returned
    [bool]$is_compliant = $true

    # loop through each control and create objects for the array; set compliance
    foreach ($control in $inspecResults.controls) {

        Write-Verbose "[$((get-date).getdatetimeformats()[45])] Processing reasons data for: $($control.code_desc)"
        
        [bool]$test_compliant = $true
        [bool]$test_skipped = $false

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
            $reason_phrase = "InSpec policy test failed."
        
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
            Phrase  = $control.reason_phrase
        }
    }

    # the overall status is based on any control being failed
    $status = if ($true -eq $is_compliant) { 'Compliant' } else { 'Non-Compliant' }

    # parent object containing all info including raw output (future use)
    $inspecObject = New-Object -TypeName PSObject -Property @{
        version        = $inspecResults.version
        statistics     = $statistics
        controls       = $controls
        status         = $status
        cli            = $inspecCLI
        reasons        = $reasons
    }
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Overall status: $($inspecObject.status)"
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Reason phrase: $($inspecObject.reason_phrases)"

    return $inspecObject
}

<#
    Structures InSpec execution/output for use with
    Azure Guest COnfiguration.
#>
[DscResource()]
class gcInSpec {
    <#
       Name of the Guest Configuration assignment.
    #>
    [DscProperty(Key)]
    [string]$name

    [DscProperty()]
    [version]$version = $Script:Supported_InSpec_Version

    [DscProperty(NotConfigurable)]
    [string]$status

    [DscProperty(NotConfigurable)]
    [string]$Reasons

    <#
        This function is not implemented for Audit scenarios.
    #>
    [void] Set() {
        throw 'Set functionality is not supported in this version of the DSC resource.' 
    }

    <#
        Return compliance status from InSpec output.
    #>
    [bool] Test() {
    
        $get = $this.Get()
        
        if ("Compliant" -eq $get.status) {
            return $true
        }
        else {
            return $false
        }
    }

    <#
        Returns the Reasons information from InSpec content.
    #>
    [gcInSpec] Get() {

        Write-Verbose "[$((get-date).getdatetimeformats()[45])] required InSpec version: $($this.version)"

        $Installed_InSpec_Versions = (Get-InstalledInSpecVersions).versions
        if ($Installed_InSpec_Versions -notcontains $this.version) {
            Install-Inspec
        }

        $InSpecArgs = @{
            policy_folder_path          = "$script:guest_assignment_folder\$($this.name)\"
            inspec_output_file_path     = "$script:guest_assignment_folder\$($this.name).json"
            inspec_cli_output_file_path = "$script:guest_assignment_folder\$($this.name).cli"
        }

        Invoke-InSpec @InSpecArgs
        
        $ConvertArgs = @{
            inspec_output_file_path     = "$script:guest_assignment_folder\$($this.name).json"
            inspec_cli_output_file_path = "$script:guest_assignment_folder\$($this.name).cli"
        }
        
        $get = ConvertFrom-InSpec @ConvertArgs
        
        $this.name      = $this.name
        $this.version   = $Installed_InSpec_Versions
        $this.status    = $get.status
        $this.Reasons   = $get.reasons
        return $this
    }
}
