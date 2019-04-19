---
title: How to create Guest Configuration policies
description: Learn how to create an Azure Policy Guest Configuration policy for Windows or Linux VMs.
services: azure-policy
author: DCtheGeek
ms.author: dacoulte
ms.date: 03/27/2019
ms.topic: conceptual
ms.service: azure-policy
manager: carmonm
---
# How to create Guest Configuration policies

Guest Configuration uses a [Desired State Configuration](/powershell/dsc) (DSC) resource module to
create the configuration for auditing of the Azure virtual machines. The DSC configuration defines
the condition that the virtual machine should be in. If the evaluation of the configuration fails,
the Policy effect **audit** is triggered and the virtual machine is considered **non-compliant**.

Use the following actions to create your own configuration for validating the state of an Azure
virtual machine.

> [!IMPORTANT]
> Custom policies with Guest Configuration is a Preview feature.

## Add the GuestConfiguration resource module

To create a Guest Configuration policy, the resource module must be added. This resource module can
be used with locally installed PowerShell, with [Azure Cloud Shell](https://shell.azure.com), or
with the [Azure PowerShell Docker image](https://hub.docker.com/r/azuresdk/azure-powershell/).

### Base requirements

The Guest Configuration resource module requires the following software:

- PowerShell 5.1. If it isn't yet installed, follow [these instructions](/powershell/scripting/install/installing-windows-powershell).
- Azure PowerShell 1.5.0 or higher. If it isn't yet installed, follow [these instructions](/powershell/azure/install-az-ps).
- PowerShellGet 2.0.1 or higher. If it isn't installed or updated, follow [these instructions](/powershell/gallery/installing-psget).

### Install the module

Guest Configuration uses the **GuestConfiguration** resource module for creating DSC configurations
and publishing them to Azure Policy:

1. From an **administrative** PowerShell prompt, run the following command:

   ```azurepowershell-interactive
   # Install the Guest Configuration DSC resource module from PowerShell Gallery
   Install-Module -Name GuestConfiguration
   ```

1. Validate that the module has been imported:

   ```azurepowershell-interactive
   # Get a list of commands for the imported GuestConfiguration module
   Get-Command -Module 'GuestConfiguration'
   ```

## Create custom Guest Configuration configuration

The first step to creating a custom policy for Guest Configuration is to create the DSC
configuration.

### Custom Guest Configuration configuration on Linux

The DSC configuration for Guest Configuration on Linux uses the `ChefInSpecResource` resource to
provide the engine the name of the [Chef InSpec](https://www.chef.io/inspec/) definition. **Name**
is the only resource property and is required.

The following example creates a configuration named **baseline**, imports the **GuestConfiguration**
resource module, and uses the `ChefInSpecResource` resource set the name of the InSpec definition to
**linux-patch-baseline**:

```azurepowershell-interactive
# Define the DSC configuration and import GuestConfiguration
Configuration baseline
{
    Import-DscResource -ModuleName 'GuestConfiguration' -ModuleVersion '1.6.0.0'
    ChefInSpecResource 'audit linux packages'
    {
        Name = "linux-patch-baseline"
    }
}

# Compile the configuration to create the MOF files
baseline
```

For more information, see [Write, Compile, and Apply a Configuration](/powershell/dsc/configurations/write-compile-apply-configuration).

### Custom Guest Configuration configuration on Windows

The DSC configuration for Guest Configuration on Windows works like a standard DSC configuration and
has access to any of the available DSC resources.

The following example creates a configuration named **AuditBitLocker**, imports the
**GuestConfiguration** resource module, and uses the `Service` resource to audit for a running
service:

```azurepowershell-interactive
# Define the DSC configuration and import GuestConfiguration
Configuration AuditBitLocker
{
    Import-DscResource -ModuleName 'GuestConfiguration' -ModuleVersion '1.6.0.0'

    Service 'Ensure BitLocker service is present and running'
    {
        Name = 'BDESVC'
        Ensure = 'Absent'
        State = 'Running'
    }
}

# Compile the configuration to create the MOF files
AuditBitLocker
```

For more information, see [Write, Compile, and Apply a Configuration](/powershell/dsc/configurations/write-compile-apply-configuration).

## Create Guest Configuration custom policy package

Once the MOF is compiled, the supporting files must be packaged together. The completed package is
used by Guest Configuration to create the Azure Policy definitions. The package consists of:

- The compiled DSC configuration as a MOF
- Modules folder
  - GuestConfiguration module
  - DscNativeResources module
  - (Linux) A folder with the Chef InSpec definition and additional content
  - (Windows) DSC resource modules that aren't built in

The `New-GuestConfigurationPackage` cmdlet creates the package. The following format is used for
creating a custom package:

```azurepowershell-interactive
New-GuestConfigurationPackage -Name '{PackageName}' -Configuration '{PathToMOF}' `
    -DestinationPath '{OutputFolder}' -FilesToInclude '{PathToInSpecDefinition}' -Verbose
```

> [!NOTE]
> Only packages created for Linux that use a Chef InSpec definition should use `-FilesToInclude`.

The completed package must be uploaded to a location that is accessible by Azure, such as a public
GitHub repository, an Azure DevOps project, or Azure storage with anonymous read access.

## Convert package to Guest Configuration policy definition

Once a Guest Configuration custom policy package has been created and uploaded, it must be converted
into a Guest Configuration policy definition that can be deployed to Azure Policy. The
`New-GuestConfigurationPolicy` cmdlet takes a publicly accessible Guest Configuration custom policy
package and creates an **audit** and **deployIfNotExists** policy definition. Additionally, a policy
initiative definition that includes both policy definitions is created.

This example creates the policy and initiative definitions in a specified path from a Guest
Configuration custom policy package for Windows and provides a name, description, and version:

```azurepowershell-interactive
New-GuestConfigurationPolicy
    -ContentUri 'https://github.com/Microsoft/PowerShell-DSC-for-Linux/raw/amits/custompolicy/MyCustomPolicy4/AuditBitlocker.zip' `
    -DisplayName 'Audit BitLocker Service.' `
    -Description 'Audit if BitLocker is not enabled on Windows machine.' `
    -DestinationPath '.\policyDefinitions' `
    -Platform 'Windows' `
    -Version 1.2.3.4 `
    -Verbose
```

## Create the Azure Policy definitions and initiative

The following files are the output from `New-GuestConfigurationPolicy`:

- **Audit.json**
- **deployIfNotExists.json**
- **Initiative.json**

These files can be used individually to create their respective policy and initiative definitions.
For details on creating policies, see [programmatically create policies](./programmatically-create.md).

The **GuestConfiguration** resource module offers a way to create both policy definitions and the
initiative definition in one step through the `Publish-GuestConfigurationPolicy` cmdlet. The cmdlet
only has the **Path** parameter that points to the location of the three JSON files created by
`New-GuestConfigurationPolicy`.

```azurepowershell-interactive
Publish-GuestConfigurationPolicy -Path '.\policyDefinitions'
```

With the policy and initiative definitions created, the last step is to assign the initiative. See
how to assign the initiative with [Portal](../assign-policy-portal.md), [Azure CLI](../assign-policy-azurecli.md),
and [Azure PowerShell](../assign-policy-powershell.md).

## Next steps

- Learn about auditing VMs with [Guest Configuration](../concepts/guest-configuration.md).
- Understand how to [programmatically create policies](programmatically-create.md).
- Learn how to [get compliance data](getting-compliance-data.md).