# Azure VM Patch Orchestration Policies

A set of Azure Policy definitions that govern the **patch orchestration** (`patchMode`) setting on Azure virtual machines. These policies enforce and remediate the patch orchestration option for both Windows and Linux VMs.

## Overview

Azure VMs expose a `patchMode` property that controls how guest OS updates are orchestrated. These policies standardize that setting across your environment:

| OS      | Enforced `patchMode` | Meaning |
| ------- | -------------------- | ------- |
| Windows | `Manual`             | Manual updates — the platform does not automatically apply patches. |
| Linux   | `ImageDefault`       | Image default — patching follows the default behavior of the OS image. |

Each OS has two complementary policies:

- **Deny** — prevents *new* (or updated) VMs from being created with a non-compliant `patchMode`.
- **Modify** — remediates *existing* VMs by setting `patchMode` to the desired value via a remediation task.

## Policy Definitions

| File | Display name | Effect(s) | Purpose |
| ---- | ------------ | --------- | ------- |
| [Deny-WindowsVMPatchOrchestration.json](Deny-WindowsVMPatchOrchestration.json) | Windows virtual machines must use the 'Manual updates' patch orchestration option | `Audit`, `Deny`, `Disabled` (default `Deny`) | Blocks/audits Windows VMs not set to `Manual`. |
| [Deny-LinuxVMPatchOrchestration.json](Deny-LinuxVMPatchOrchestration.json) | Linux virtual machines must use the 'Image default' patch orchestration option | `Audit`, `Deny`, `Disabled` (default `Deny`) | Blocks/audits Linux VMs not set to `ImageDefault`. |
| [Modify-WindowsVMPatchOrchestration.json](Modify-WindowsVMPatchOrchestration.json) | Configure Windows virtual machines to use the 'Manual updates' patch orchestration option | `Modify`, `Disabled` (default `Modify`) | Remediates existing Windows VMs to `Manual`. |
| [Modify-LinuxVMPatchOrchestration.json](Modify-LinuxVMPatchOrchestration.json) | Configure Linux virtual machines to use the 'Image default' patch orchestration option | `Modify`, `Disabled` (default `Modify`) | Remediates existing Linux VMs to `ImageDefault`. |

## Policy Initiative

All four policies are bundled into a single initiative (policy set definition) for easier assignment:

| File | Display name | Purpose |
| ---- | ------------ | ------- |
| [Initiative-VMPatchOrchestration.json](Initiative-VMPatchOrchestration.json) | Enforce and configure VM patch orchestration options | Groups the Deny and Modify policies for both Windows and Linux VMs. |

The initiative exposes one effect parameter per member policy, so you can tune each policy's behavior at assignment time:

| Initiative parameter | Member policy | Allowed values (default) |
| -------------------- | ------------- | ------------------------ |
| `denyWindowsEffect` | Deny-WindowsVMPatchOrchestration | `Audit`, `Deny`, `Disabled` (`Deny`) |
| `denyLinuxEffect` | Deny-LinuxVMPatchOrchestration | `Audit`, `Deny`, `Disabled` (`Deny`) |
| `modifyWindowsEffect` | Modify-WindowsVMPatchOrchestration | `Modify`, `Disabled` (`Modify`) |
| `modifyLinuxEffect` | Modify-LinuxVMPatchOrchestration | `Modify`, `Disabled` (`Modify`) |

> **Note:** The initiative references each member policy by its subscription-scoped definition ID. Create the four policy definitions **before** creating the initiative, and use the same `--name` values shown in this README so the references resolve.

### Common properties

- **Resource type targeted:** `Microsoft.Compute/virtualMachines`
- **Mode:** `All`
- **Category:** `Compute`
- **Version:** `1.0.0`
- **Effect parameter:** Each policy exposes an `effect` parameter so you can change the behavior (e.g., switch `Deny` to `Audit`, or disable a policy) per assignment.

### Modify policy details

The Modify policies require a managed identity to perform remediation. They use the built-in role:

- **Virtual Machine Contributor** — `9980e02c-c2be-4d73-94e8-173b1dc7cf3c`

They define a `conflictEffect` of `audit`, and perform an `addOrReplace` operation on the `patchMode` field.

## Getting the files

Download all of the policy JSON files **and** the [Deploy-Policies.ps1](Deploy-Policies.ps1) script into the same local folder before deploying. The script reads the JSON files from its own directory.

### Option A — Clone the repository (recommended)

```bash
git clone https://github.com/abrarhuss/AzPatchOrchestrationPolicies.git
cd AzPatchOrchestrationPolicies
```

### Option B — Download individual files

Use the **Raw → Save As** option in GitHub, or download each file with PowerShell into the current folder:

```powershell
$base  = "https://raw.githubusercontent.com/abrarhuss/AzPatchOrchestrationPolicies/main"
$files = @(
    "Deny-WindowsVMPatchOrchestration.json",
    "Deny-LinuxVMPatchOrchestration.json",
    "Modify-WindowsVMPatchOrchestration.json",
    "Modify-LinuxVMPatchOrchestration.json",
    "Initiative-VMPatchOrchestration.json",
    "Deploy-Policies.ps1"
)
foreach ($f in $files) {
    Invoke-WebRequest -Uri "$base/$f" -OutFile $f
}
```

## Deploying the policies

### PowerShell deployment script (recommended)

[Deploy-Policies.ps1](Deploy-Policies.ps1) is a wrapper that creates (or updates) all four policy definitions **and** the initiative in one step. It automatically resolves the initiative's `[concat(subscription().id, ...)]` references to your subscription-scoped definition IDs, so you don't have to create the definitions before the initiative manually.

**Prerequisites**

- [Azure PowerShell (`Az`) module](https://learn.microsoft.com/powershell/azure/install-azure-powershell) installed.
- Signed in with `Connect-AzAccount`.
- Permission to create policy definitions and set definitions at the subscription scope (e.g., **Resource Policy Contributor** or **Owner**).

**Run it**

From the folder that contains the JSON files and the script:

```powershell
# Deploy to the current Az context subscription
.\Deploy-Policies.ps1

# Or target a specific subscription
.\Deploy-Policies.ps1 -SubscriptionId "00000000-0000-0000-0000-000000000000"
```

The script will:

1. Create the four policy definitions (`Deny-*` and `Modify-*`).
2. Create the `VMPatchOrchestration-Initiative` policy set definition referencing those definitions.

On success it prints `Done. 4 policy definitions + 1 initiative deployed.` After deploying, continue with [Assigning the initiative](#assigning-the-initiative).

> **Tip:** If you previously hit the error `The value '[parameters('denyWindowsEffect'` is not allowed for policy parameter 'effect'`, make sure you are using the current version of the script — older versions corrupted the initiative's parameter references during ID resolution.

### Azure CLI

Create each policy definition:

```bash
# Windows - Deny
az policy definition create \
  --name "Deny-WindowsVMPatchOrchestration" \
  --rules @Deny-WindowsVMPatchOrchestration.json

# Linux - Deny
az policy definition create \
  --name "Deny-LinuxVMPatchOrchestration" \
  --rules @Deny-LinuxVMPatchOrchestration.json

# Windows - Modify
az policy definition create \
  --name "Modify-WindowsVMPatchOrchestration" \
  --rules @Modify-WindowsVMPatchOrchestration.json

# Linux - Modify
az policy definition create \
  --name "Modify-LinuxVMPatchOrchestration" \
  --rules @Modify-LinuxVMPatchOrchestration.json
```

Then create the initiative that references the four definitions:

```bash
az policy set-definition create \
  --name "VMPatchOrchestration-Initiative" \
  --definitions @<(jq '.properties.policyDefinitions' Initiative-VMPatchOrchestration.json) \
  --params @<(jq '.properties.parameters' Initiative-VMPatchOrchestration.json)
```

> **Note:** The JSON files contain the full definition (`name`, `type`, `properties`). When using `az policy definition create` / `az policy set-definition create`, you may prefer to pass the rule, definitions, and parameters separately, or use a deployment template (ARM/Bicep) that references the `properties` block. The initiative references each member policy by its subscription-scoped definition ID, so create the policy definitions first.

### Azure PowerShell

```powershell
New-AzPolicyDefinition `
  -Name "Deny-WindowsVMPatchOrchestration" `
  -Policy ".\Deny-WindowsVMPatchOrchestration.json"
```

## Assigning the initiative

Assign the initiative to a scope (management group, subscription, or resource group). Because it contains **Modify** policies, the assignment needs a managed identity and a location:

```bash
az policy assignment create \
  --name "VMPatchOrchestration" \
  --policy-set-definition "VMPatchOrchestration-Initiative" \
  --scope "/subscriptions/<subscriptionId>" \
  --mi-system-assigned \
  --location "<region>"
```

Then trigger remediation for each Modify policy in the initiative (use the `policyDefinitionReferenceId` from the initiative):

```bash
az policy remediation create \
  --name "remediate-windows-patchmode" \
  --policy-assignment "VMPatchOrchestration" \
  --definition-reference-id "Modify-WindowsVMPatchOrchestration" \
  --scope "/subscriptions/<subscriptionId>"

az policy remediation create \
  --name "remediate-linux-patchmode" \
  --policy-assignment "VMPatchOrchestration" \
  --definition-reference-id "Modify-LinuxVMPatchOrchestration" \
  --scope "/subscriptions/<subscriptionId>"
```

You can still assign the individual policies directly if you prefer not to use the initiative.

## Customizing behavior

- To audit instead of block new VMs, set the `denyWindowsEffect` / `denyLinuxEffect` initiative parameter to `Audit` at assignment time.
- To temporarily turn off a member policy, set its effect parameter to `Disabled`.
- Adjust the assignment scope to roll out gradually (e.g., start at a single resource group).

## References

- [Azure Policy effects](https://learn.microsoft.com/azure/governance/policy/concepts/effects)
- [Automatic VM guest patching / patch orchestration modes](https://learn.microsoft.com/azure/virtual-machines/automatic-vm-guest-patching)
- [Remediate non-compliant resources](https://learn.microsoft.com/azure/governance/policy/how-to/remediate-resources)
