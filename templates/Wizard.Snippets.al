// Snippets for the NavigatePage assisted-setup wizard. Not a complete object.

// --- page header ---------------------------------------------------------
// page 50103 "PFX Copilot Setup Wizard"     // <= 30 chars
// {
//     PageType = NavigatePage;
//     Caption = 'PFX Copilot Setup Wizard';
//     SourceTable = "PFX Copilot Setup";
//     SourceTableTemporary = true;          // Cancel discards; Finish writes back
//     InsertAllowed = false; DeleteAllowed = false; LinksAllowed = false; ShowFilter = false;

// --- API key capture: SecretText cannot bind to a page field ----------------
field(WizardAPIKeyTxt; WizardAPIKeyTxt)
{
    ApplicationArea = All;
    Caption = 'API Key';
    ExtendedDatatype = Masked;
    ToolTip = 'Enter your Azure OpenAI API key. It is stored securely and never displayed again.';

    trigger OnValidate()
    begin
        WizardAPIKey := WizardAPIKeyTxt; // Text[250] -> SecretText
    end;
}

// --- endpoint validation ----------------------------------------------------
local procedure ValidateEndpointURL()
begin
    EndpointValidationMsg := '';
    IsEndpointValid := false;
    if WizardEndpointURL = '' then
        exit;
    if not WizardEndpointURL.StartsWith('https://') then begin
        EndpointValidationMsg := EndpointURLMustBeHTTPSErr;
        exit;
    end;
    IsEndpointValid := true;
end;

// --- Test Connection footer action (gate Next on ConnectionTestPassed) -------
action(TestConnectionAction)
{
    ApplicationArea = All;
    Caption = 'Test Connection';
    Image = TestReport;
    InFooterBar = true;
    Visible = CurrentStep = Step::APIKey;
    ToolTip = 'Test the connection to your Azure OpenAI endpoint using the credentials entered above.';

    trigger OnAction()
    var
        AIEngine: Codeunit "PFX Copilot AI Engine";
        ErrorMsg: Text[250];
    begin
        TestConnectionStatusTxt := TestingConnectionMsg;
        TestConnectionStyleExpr := 'None';
        CurrPage.Update(false);
        if AIEngine.TestPartnerConnection(WizardEndpointURL, WizardDeploymentName, WizardAPIKey, ErrorMsg) then begin
            TestConnectionStatusTxt := TestConnectionSuccessMsg;
            TestConnectionStyleExpr := 'Favorable';
            ConnectionTestPassed := true;
        end else begin
            TestConnectionStatusTxt := ErrorMsg;
            TestConnectionStyleExpr := 'Unfavorable';
            ConnectionTestPassed := false;
        end;
        UpdateNavigationButtons();
        CurrPage.Update(false);
    end;
}

// --- OnOpenPage: load real row into the temporary Rec -------------------------
trigger OnOpenPage()
var
    RealSetup: Record "PFX Copilot Setup";
begin
    Mgmt.GetOrCreateSetup(RealSetup);
    Rec := RealSetup;
    Rec.Insert();
    WizardBillingMode := Rec."Billing Mode";
    WizardEndpointURL := Mgmt.GetPartnerEndpointURL();
    WizardDeploymentName := Rec."Partner Deployment Name";
    CurrentStep := Step::Welcome;
    UpdateNavigationButtons();
end;

// --- Finish: write back, persist secrets, complete assisted setup --------------
local procedure FinishSetup()
var
    RealSetup: Record "PFX Copilot Setup";
    GuidedExperience: Codeunit "Guided Experience";
begin
    Mgmt.GetOrCreateSetup(RealSetup);
    RealSetup."Billing Mode" := WizardBillingMode;
    RealSetup."MS Model" := Rec."MS Model";
    RealSetup."High Confidence Threshold" := Rec."High Confidence Threshold";
    RealSetup."Low Confidence Threshold" := Rec."Low Confidence Threshold";
    if WizardBillingMode = Enum::"PFX Copilot Billing Mode"::PartnerBilled then begin
        RealSetup."Partner Deployment Name" := CopyStr(WizardDeploymentName, 1, MaxStrLen(RealSetup."Partner Deployment Name"));
        Mgmt.SavePartnerCredentials(WizardEndpointURL, WizardAPIKey);
    end else
        if RealSetup."Partner Endpoint Configured" then
            Mgmt.ClearPartnerCredentials();
    RealSetup."Assisted Setup Completed" := true;
    RealSetup.Modify();
    GuidedExperience.CompleteAssistedSetup(ObjectType::Page, Page::"PFX Copilot Setup Wizard");
    Message(SetupCompleteMsg);
    CurrPage.Close();
end;

// --- variables ----------------------------------------------------------------
// var
//     Mgmt: Codeunit "PFX Copilot Mgmt";
//     CurrentStep: Option Welcome,BillingMode,MSModel,PartnerEndpoint,APIKey,Thresholds,Summary;
//     Step: Option Welcome,BillingMode,MSModel,PartnerEndpoint,APIKey,Thresholds,Summary;
//     WizardBillingMode: Enum "PFX Copilot Billing Mode";
//     WizardEndpointURL: Text[250];
//     WizardDeploymentName: Text[100];
//     WizardAPIKey: SecretText;
//     WizardAPIKeyTxt: Text[250];
//     IsEndpointValid, ConnectionTestPassed: Boolean;
//     EndpointValidationMsg, TestConnectionStatusTxt: Text[250];
//     TestConnectionStyleExpr: Text;
//     EndpointURLMustBeHTTPSErr: Label 'The endpoint URL must start with https://', MaxLength = 250;
//     TestingConnectionMsg: Label 'Testing connection...', MaxLength = 250;
//     TestConnectionSuccessMsg: Label 'Connection successful. Click Next to continue.', MaxLength = 250;
//     SetupCompleteMsg: Label 'PFX Copilot has been configured successfully.', MaxLength = 250;
