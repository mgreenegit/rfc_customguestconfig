# Azure Policy Custom Guest Configuration - Request for Comments
![Azure Policy Guest Configuration](https://contosodev.blob.core.windows.net/img/GuestConfigurationIcon.jpg)

The release is currently broken (on purpose).
See the details below to understand the reasoning behind this approach.

[![Build Status](https://dev.azure.com/azvmguestpolicy/CustomGuestConfiguration/_apis/build/status/Microsoft.rfc_customguestconfig?branchName=master)](https://dev.azure.com/azvmguestpolicy/CustomGuestConfiguration/_build/latest?definitionId=3?branchName=master)

![Deployment Gate Status](https://vsrm.dev.azure.com/azvmguestpolicy/_apis/public/Release/badge/8cf7364a-2490-4dd7-8353-5c7e17e8728d/1/2)

This repository is the home for a *theoretical* design for Azure Policy Guest Configuration
to support customer-provided content.
As part of an open collaboration with the community
we welcome you to review the information on this page,
the project examples,
and **please provide feedback** using the survey in the
[Issues](https://github.com/Microsoft/rfc_customguestconfig/issues)
list.

## What is the scenario we would like to support?

In Spring 2019,
we would like to offer support for customers to use their own content
in Azure Policy Guest Configuration scenarios.
Azure already offers built-in Policy content to audit settings
inside virtual machines such as which application are installed and/or not installed.
This change would empower customers to author
and use custom configurations.

Examples include:

- Security configuration baselines (many settings)
- Key security checks such as which accounts have administrative privileges inside VMs
- Application settings

To validate this scenario,
we will work through iterations of what we will ask to be validated.

An early iteration of this capability in preview would support
configurations for Windows authored in Desired State Configuration
and profiles for Linux authored in Chef Inspec.
Only resources provided in the Guest Configuration module
would be recommended.

In future iterations,
custom DSC resources would also be recommended for testing.

## User story

Dana is responsible for virtual machines running in the Azure cloud.
She needs to be certain that for all machines,
an anti-virus solution is installed and configured correctly.
She creates a configuration with details about the solution
and publishes it to Azure blob storage.
Next, She creates new definitions in Azure Policy
to assign the content to all VMs and audit the compliance status.
Finally, She reviews the results in Azure Policy and sets up an alert
to be notified if any servers do not meet requirements.

## What we are proposing to support this scenario

For built-in policies,
the
[Guest Configuration API](https://docs.microsoft.com/en-us/rest/api/guestconfiguration/guestconfigurationassignments/get#guestconfigurationnavigation)
accepts a GET operation that returns properties
including a contentURI path to the configuration package
and contentHash value so the content can be verified.
A potential solution to support custom content
would be to allow a PUT operation to also set the properties
for the location and hash value.
This would mean the content package could be hosted in locations
such GitHub repo's, GitHub releases, blob storage,
or static links to NuGet feeds (pending validation).

We also believe there is a need for additional tooling
to simplify the process of authoring configuration content.
New cmdlets would be available to provide assistance for authors
creating custom content.
This would include validation, packaging, and publishing.

Many organizations need to audit servers against configuration baselines
published by third party organizations.
A community module,
[Baseline Management](https://github.com/microsoft/baselinemanagement)
provides a solution to convert from Group Policy templates
to DSC configurations,
which would be perfect content to use in Policy as custom content.

## Theoretical example repo

This repo demonstrates how a project
to centrally manage a custom policy
might be organized.

The folder
[customPolicyFiles](https://github.com/Microsoft/rfc_customguestconfig/tree/master/customPolicyFiles)
contains the Azure Policy definitions
and a theoretical Password Policy
authored in Desired State Configuration.
The configuration content is located
within the guestConfiguration subfolder,
including a custom DSC resource based on the community maintained resource
[SecurityPolicyDSC](https://github.com/PowerShell/SecurityPolicyDsc).

The variables **contentUri** and **contentHash**
in the file
[deployIfNotExists.rules.json](https://github.com/Microsoft/rfc_customguestconfig/blob/master/customPolicyFiles/deployIfNotExists.rules.json#L85)
are automatically populated during the Build phase.
The package will be automatically created using the cmdlets
available in the
[Guest Configuration module](https://www.powershellgallery.com/packages/GuestConfiguration/).

## Give us feedback!

We are very interested in understanding how you would leverage
Azure Guest Configuration to audit settings
inside your virtual machines.
Please contribute to the Issues list with ideas for content
that could be validated in this RFC repo,
and any requirements you have for tools that improve your authoring experience.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
