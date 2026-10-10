# 02 - Copilot capability: declare, register, check

Part of the OnlyBCFans Business Central Copilot Blueprint.

## Declare (enum extension)

```al
namespace GeneralJournalCopilot.Common;
using System.AI;

enumextension 78700 "GJCopilot Capability" extends "Copilot Capability"
{
    value(78700; SuggestGLBalancingAccount)
    {
        Caption = 'Suggest G/L Balancing Account';
    }
}
```

The caption is what appears in **Copilot & agent capabilities** in the BC admin UI, where the tenant admin can
switch the feature on and off.

## Register (install codeunit, per database)

```al
trigger OnInstallAppPerDatabase()
var
    EnvironmentInformation: Codeunit "Environment Information";
begin
    if not EnvironmentInformation.IsSaaSInfrastructure() then
        exit;
    RegisterCopilotCapability();
end;

local procedure RegisterCopilotCapability()
var
    CopilotCapability: Codeunit "Copilot Capability";
begin
    if CopilotCapability.IsCapabilityRegistered(Enum::"Copilot Capability"::SuggestGLBalancingAccount) then
        exit;
    CopilotCapability.RegisterCapability(
        Enum::"Copilot Capability"::SuggestGLBalancingAccount,
        Enum::"Copilot Availability"::Preview,
        Enum::"Copilot Billing Type"::"Microsoft Billed",
        DefaultLearnMoreUrlTok);   // Label, Locked = true, Text[2048] max
end;
```

Verified BC 27.5 signature:
`RegisterCapability(CopilotCapability, CopilotAvailability, CopilotBillingType, LearnMoreUrl: Text[2048])`.
The 3-parameter overload exists but is **obsolete since 27.0** and will warn.

Enum values available:
- `Copilot Availability`: Preview, "Generally Available", "Early Preview". Preview works fine for a PTE; the
  dialog shows a preview badge when `IsPreview = true`.
- `Copilot Billing Type`: "Not Billed", "Microsoft Billed", "Custom Billed", Undefined. Use "Microsoft Billed"
  when the feature can run on Microsoft-managed resources. The first build of this project registered "Not Billed"
  by mistake and it was flagged in review (Bugfixes002 Gap 1).

Also available: `ModifyCapability(cap, availability, billingType, url)`, `UnregisterCapability(cap)`,
`IsCapabilityRegistered(cap[, AppId])`, `IsCapabilityActive(cap[, AppId])`.

### Design note on the SaaS guard

This project skips registration outside SaaS, which means on-prem/Docker the action stays disabled because
`IsCapabilityActive` returns false. That was acceptable for a Cloud-target app. If you need Partner billed to run in
a Docker sandbox, try registering without the guard and test; do not assume either way.

## Register again on upgrade

`RegisterCapability` in this project runs only in `OnInstallAppPerDatabase`. If a later version adds a second capability
value, tenants that installed earlier never get it. Call the same guarded `RegisterCopilotCapability()` from
`OnUpgradePerDatabase` too.

## Check at runtime

Three different questions:

```al
// Is the tenant admin allowing this capability right now?  (Copilot & agent capabilities page) - cheap, use for Enabled =
CopilotCapability.IsCapabilityActive(Enum::"Copilot Capability"::SuggestGLBalancingAccount)

// Microsoft's documented pre-check: capability active AND tenant-level Copilot/data-movement consent given.
// Non-silent form shows the platform's own notification when something is missing. Call it in the action before opening the dialog.
AzureOpenAI.IsEnabled(Enum::"Copilot Capability"::SuggestGLBalancingAccount)          // or IsEnabled(cap, Silent)

// Has our app configured a billing mode (and, for Partner, stored credentials)?
GJCopilotMgmt.IsConfigured()
```

The reference project only used `IsCapabilityActive`; adding `IsEnabled` is the stronger pattern (consent behaviour not
runtime-tested here).

The host-page action is `Enabled = IsConfigured() and IsCapabilityActive()`, recomputed in `OnOpenPage` and
`OnAfterGetCurrRecord`. The pre-condition validator returns a friendly error when the capability was disabled by
the admin.

## Bind the capability to each request

Every `Azure OpenAI` codeunit instance must be told which capability it serves **before** `GenerateChatCompletion`:

```al
AzureOpenAI.SetCopilotCapability(Enum::"Copilot Capability"::SuggestGLBalancingAccount);
```

Forgetting this is the most common runtime failure. Symptom text: `Copilot capability has not been set.`
It applies to the Partner-billed path and to connection tests too (Bugfixes002 Gaps 10 and 11).
