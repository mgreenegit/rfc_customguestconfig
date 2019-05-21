
<#PSScriptInfo

.VERSION 1.0.0

.GUID 153d6ad9-90d9-4d26-b39d-799daafbe220

.AUTHOR Guest Configuration

.COMPANYNAME Microsoft Corpoation

.COPYRIGHT 2019

.TAGS GuestConfiguration Azure

.LICENSEURI https://github.com/microsoft/rfc_customguestconfig/LICENSE

.PROJECTURI https://github.commicrosoft/rfc_customguestconfig

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
https://github.com/microsoft/rfc_customguestconfig/README.md#releasenotes

.PRIVATEDATA

#>

#Requires -Module GuestConfiguration

<#

.DESCRIPTION
 Validates that the Firewalld package is installed, running, and that the default zone is public

#>
Param()

Configuration firewalldenabled {

    Import-DscResource -ModuleName 'GuestConfiguration'

    Node firewalldenabled {

        ChefInSpecResource firewalldenabled {
            Name = 'firewalldenabled'
            GithubPath = "guestConfiguration/Linux/InSpecProfiles/firewalldenabled/"
            AttributesYmlContent = "DefaultFirewalldProfile: [public]"
        }
    }
}
