namespace PFX.Copilot.Common;

using System.AI;
using PFX.Copilot.Setup;

codeunit 50102 "PFX Copilot Mgmt"
{
    Access = Internal;

    procedure IsConfigured(): Boolean
    var
        Setup: Record "PFX Copilot Setup";
    begin
        if not Setup.Get() then
            exit(false);
        case Setup."Billing Mode" of
            Enum::"PFX Copilot Billing Mode"::MicrosoftBilled:
                exit(true);
            Enum::"PFX Copilot Billing Mode"::PartnerBilled:
                exit(Setup."Partner Endpoint Configured");
            else
                exit(false);
        end;
    end;

    procedure IsCapabilityActive(): Boolean
    var
        CopilotCapability: Codeunit "Copilot Capability";
    begin
        exit(CopilotCapability.IsCapabilityActive(Enum::"Copilot Capability"::PFXSuggestSomething));
    end;

    procedure GetOrCreateSetup(var Setup: Record "PFX Copilot Setup")
    begin
        if Setup.Get() then
            exit;
        Setup.Init();
        Setup.Insert();
    end;

    // ── Partner credentials in IsolatedStorage (Company scope) ──────────────

    procedure GetPartnerEndpointURL(): Text
    var
        EndpointURL: Text;
    begin
        if IsolatedStorage.Get(PartnerEndpointURLKeyTok, DataScope::Company, EndpointURL) then
            exit(EndpointURL);
        exit('');
    end;

    procedure GetPartnerAPIKey(): SecretText
    var
        APIKey: SecretText;
    begin
        if IsolatedStorage.Get(PartnerAPIKeyTok, DataScope::Company, APIKey) then
            exit(APIKey);
        exit(APIKey); // empty SecretText
    end;

    procedure SavePartnerCredentials(EndpointURL: Text; APIKey: SecretText)
    var
        Setup: Record "PFX Copilot Setup";
    begin
        IsolatedStorage.Set(PartnerEndpointURLKeyTok, EndpointURL, DataScope::Company); // Text overload
        IsolatedStorage.Set(PartnerAPIKeyTok, APIKey, DataScope::Company);              // SecretText overload (there is no SetSecret)
        GetOrCreateSetup(Setup);
        Setup."Partner Endpoint Configured" := true;
        Setup.Modify();
    end;

    procedure ClearPartnerCredentials()
    var
        Setup: Record "PFX Copilot Setup";
    begin
        if IsolatedStorage.Contains(PartnerEndpointURLKeyTok, DataScope::Company) then
            IsolatedStorage.Delete(PartnerEndpointURLKeyTok, DataScope::Company);
        if IsolatedStorage.Contains(PartnerAPIKeyTok, DataScope::Company) then
            IsolatedStorage.Delete(PartnerAPIKeyTok, DataScope::Company);
        if Setup.Get() then begin
            Setup."Partner Endpoint Configured" := false;
            Setup.Modify();
        end;
    end;

    var
        PartnerEndpointURLKeyTok: Label 'PFXCopilot_PartnerEndpointURL', Locked = true;
        PartnerAPIKeyTok: Label 'PFXCopilot_PartnerAPIKey', Locked = true;
}
