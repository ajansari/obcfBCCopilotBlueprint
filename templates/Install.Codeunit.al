namespace PFX.Copilot.Install;

using System.AI;
using System.Environment;
using System.Environment.Configuration;
using System.Media;
using PFX.Copilot.Setup;
using PFX.Copilot.Wizard;

codeunit 50100 "PFX Copilot Install"
{
    Subtype = Install;
    Access = Internal;

    trigger OnInstallAppPerDatabase()
    var
        EnvironmentInformation: Codeunit "Environment Information";
    begin
        // Microsoft-managed AI is SaaS-only. This project registers the capability only on SaaS.
        if not EnvironmentInformation.IsSaaSInfrastructure() then
            exit;
        RegisterCopilotCapability();
    end;

    trigger OnInstallAppPerCompany()
    begin
        RegisterAssistedSetup();
        EnsureSetupRecord();
    end;

    // Also call RegisterCopilotCapability() (same SaaS guard) from the Upgrade codeunit's OnUpgradePerDatabase,
    // otherwise capabilities added in a later version never reach tenants that installed an earlier one.
    // Make it 'internal procedure' instead of local if you share it with the upgrade codeunit.

    local procedure RegisterCopilotCapability()
    var
        CopilotCapability: Codeunit "Copilot Capability";
    begin
        if CopilotCapability.IsCapabilityRegistered(Enum::"Copilot Capability"::PFXSuggestSomething) then
            exit;
        // BC 27: 4-parameter overload. The 3-parameter one is obsolete.
        CopilotCapability.RegisterCapability(
            Enum::"Copilot Capability"::PFXSuggestSomething,
            Enum::"Copilot Availability"::Preview,
            Enum::"Copilot Billing Type"::"Microsoft Billed",
            DefaultLearnMoreUrlTok);
    end;

    local procedure RegisterAssistedSetup()
    var
        GuidedExperience: Codeunit "Guided Experience";
    begin
        if GuidedExperience.Exists(Enum::"Guided Experience Type"::"Assisted Setup", ObjectType::Page, Page::"PFX Copilot Setup Wizard") then
            exit;
        GuidedExperience.InsertAssistedSetup(
            AssistedSetupTitleTok,
            AssistedSetupShortTitleTok,
            AssistedSetupDescriptionTok,
            5,
            ObjectType::Page,
            Page::"PFX Copilot Setup Wizard",
            Enum::"Assisted Setup Group"::Extensions,
            '',
            Enum::"Video Category"::Uncategorized,
            DefaultLearnMoreUrlTok);
    end;

    local procedure EnsureSetupRecord()
    var
        Setup: Record "PFX Copilot Setup";
    begin
        if Setup.Get() then
            exit;
        Setup.Init();
        Setup.Temperature := 0.2;
        Setup."Max Output Tokens" := 512;
        Setup."High Confidence Threshold" := 70;
        Setup."Low Confidence Threshold" := 40;
        Setup."Learn More URL" := CopyStr(DefaultLearnMoreUrlTok, 1, MaxStrLen(Setup."Learn More URL"));
        Setup.Insert();
    end;

    var
        DefaultLearnMoreUrlTok: Label 'https://example.com/pfx-copilot', Locked = true; // keep identical to app.json "help"
        AssistedSetupTitleTok: Label 'Configure PFX Copilot', MaxLength = 2048;
        AssistedSetupShortTitleTok: Label 'PFX Copilot', MaxLength = 50;
        AssistedSetupDescriptionTok: Label 'Configure the billing mode, AI model, and confidence thresholds for PFX Copilot.', MaxLength = 1024;
}
