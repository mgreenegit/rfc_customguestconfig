
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
    
    <#
        $get = $this.Get()
        
        if ("Compliant" -eq $get.status) {
            return $true
        }
        else {
            return $false
        }
    #>
    return $false

    }

    <#
        Returns the Reasons information from InSpec content.
    #>
    [gcInSpec] Get() {

        <#

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
        #>

        $this.Reasons   = @(@{Code="gcInSpec:gcInSpec:InSpecPolicyNotCompliant";Phrase='foo'})
        return $this
    }
}
