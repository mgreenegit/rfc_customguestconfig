
<#PSScriptInfo

.VERSION 2.0.0

.GUID d9e8074b-af23-478c-b6a5-bdffd18cdf36

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
 Validates that the Windows host firewall is enabled and that the active profile is public

#>
Param()

Configuration windowsfirewallenabled {

    Import-DscResource -ModuleName 'gcInSpec'

    Node windowsfirewallenabled {

        gcInSpec windowsfirewallenabled {
            name    = 'windowsfirewallenabled'
            version = '4.3.2.1'
            #AttributesYmlContent = "DefaultFirewalldProfile: [public]"
        }
    }
}
