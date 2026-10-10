namespace PFX.Copilot.AI;

using System.AI;
using System.Environment;
using System.Globalization;
using PFX.Copilot.Common;
using PFX.Copilot.Setup;

// Generic engine: both billing paths, TryFunction-wrapped call, status mapping, tolerant JSON parsing.
// Replace BuildSystemPrompt / BuildUserMessage / ParseAIResponse with your feature's schema.
codeunit 50103 "PFX Copilot AI Engine"
{
    Access = Internal;

    procedure Generate(ContextJson: Text; ReferenceJson: Text; UserInstructions: Text;
                       var OutResultJson: JsonObject; var OutModelUsed: Text[100]; var OutErrorMsg: Text[250]): Boolean
    var
        AzureOpenAI: Codeunit "Azure OpenAI";
        AOAIChatCompletionParams: Codeunit "AOAI Chat Completion Params";
        AOAIOperationResponse: Codeunit "AOAI Operation Response";
        ChatMessages: Codeunit "AOAI Chat Messages";
        Setup: Record "PFX Copilot Setup";
        Mgmt: Codeunit "PFX Copilot Mgmt";
    begin
        Mgmt.GetOrCreateSetup(Setup);
        if not SetupAuthorization(AzureOpenAI, AOAIChatCompletionParams, Setup, OutModelUsed, OutErrorMsg) then
            exit(false);

        ChatMessages.SetPrimarySystemMessage(BuildSystemPrompt(ReferenceJson)); // on ChatMessages, not on AzureOpenAI
        ChatMessages.AddXPIADetectionTags(UserInstructions);                      // flag untrusted free text for prompt-injection detection
        ChatMessages.AddUserMessage(BuildUserMessage(ContextJson, UserInstructions));

        if not TryGenerateChatCompletion(AzureOpenAI, ChatMessages, AOAIChatCompletionParams, AOAIOperationResponse) then begin
            OutErrorMsg := CopyStr(NetworkErr, 1, MaxStrLen(OutErrorMsg));
            exit(false);
        end;
        if not AOAIOperationResponse.IsSuccess() then
            exit(HandleOperationError(AOAIOperationResponse, OutErrorMsg));

        exit(ParseAIResponse(AOAIOperationResponse.GetResult(), OutResultJson, OutErrorMsg));
    end;

    procedure TestPartnerConnection(EndpointURL: Text; DeploymentName: Text; APIKey: SecretText; var ErrorMsg: Text[250]): Boolean
    var
        AzureOpenAI: Codeunit "Azure OpenAI";
        ChatMessages: Codeunit "AOAI Chat Messages";
        AOAIChatCompletionParams: Codeunit "AOAI Chat Completion Params";
        AOAIOperationResponse: Codeunit "AOAI Operation Response";
    begin
        AzureOpenAI.SetCopilotCapability(Enum::"Copilot Capability"::PFXSuggestSomething); // mandatory here too
        AzureOpenAI.SetAuthorization(Enum::"AOAI Model Type"::"Chat Completions", EndpointURL, DeploymentName, APIKey);
        ChatMessages.AddUserMessage(ConnectionTestPromptTok);
        AOAIChatCompletionParams.SetMaxTokens(10);
        AOAIChatCompletionParams.SetTemperature(0);
        if not TryGenerateChatCompletion(AzureOpenAI, ChatMessages, AOAIChatCompletionParams, AOAIOperationResponse) then begin
            ErrorMsg := CopyStr(NetworkErr, 1, MaxStrLen(ErrorMsg));
            exit(false);
        end;
        if AOAIOperationResponse.IsSuccess() then
            exit(true);
        ErrorMsg := CopyStr(StrSubstNo(PartnerConnectionFailedErr, AOAIOperationResponse.GetStatusCode()), 1, MaxStrLen(ErrorMsg));
        exit(false);
    end;

    [TryFunction]
    local procedure TryGenerateChatCompletion(var AzureOpenAI: Codeunit "Azure OpenAI"; var ChatMessages: Codeunit "AOAI Chat Messages";
                                              var AOAIChatCompletionParams: Codeunit "AOAI Chat Completion Params";
                                              var AOAIOperationResponse: Codeunit "AOAI Operation Response")
    begin
        AzureOpenAI.GenerateChatCompletion(ChatMessages, AOAIChatCompletionParams, AOAIOperationResponse);
    end;

    local procedure SetupAuthorization(var AzureOpenAI: Codeunit "Azure OpenAI"; var AOAIChatCompletionParams: Codeunit "AOAI Chat Completion Params";
                                       Setup: Record "PFX Copilot Setup"; var OutModelUsed: Text[100]; var OutErrorMsg: Text[250]): Boolean
    var
        AOAIDeployments: Codeunit "AOAI Deployments";
        Mgmt: Codeunit "PFX Copilot Mgmt";
        EnvironmentInformation: Codeunit "Environment Information";
        DeploymentMethod: Text;
        EmptyAPIKey: SecretText;
    begin
        AzureOpenAI.SetCopilotCapability(Enum::"Copilot Capability"::PFXSuggestSomething); // FIRST, always

        case Setup."Billing Mode" of
            Enum::"PFX Copilot Billing Mode"::MicrosoftBilled:
                begin
                    if not EnvironmentInformation.IsSaaSInfrastructure() then begin
                        OutErrorMsg := CopyStr(MSBilledRequiresSaaSErr, 1, MaxStrLen(OutErrorMsg));
                        exit(false);
                    end;
                    case Setup."MS Model" of
                        Enum::"PFX Copilot MS Model"::GPT41:
                            begin
                                DeploymentMethod := AOAIDeployments.GetGPT41Latest();
                                OutModelUsed := CopyStr(MSBilledGPT41ModelNameTok, 1, MaxStrLen(OutModelUsed));
                            end;
                        Enum::"PFX Copilot MS Model"::GPT41Mini:
                            begin
                                DeploymentMethod := AOAIDeployments.GetGPT41MiniLatest();
                                OutModelUsed := CopyStr(MSBilledGPT41MiniModelNameTok, 1, MaxStrLen(OutModelUsed));
                            end;
                    end;
                    // 4-parameter overload: (ModelType, AOAIAccountName, ApiKey, ManagedResourceDeployment). Empty account + empty key is correct.
                    AzureOpenAI.SetManagedResourceAuthorization(Enum::"AOAI Model Type"::"Chat Completions", '', EmptyAPIKey, DeploymentMethod);
                    AOAIChatCompletionParams.SetMaxTokens(512);
                    AOAIChatCompletionParams.SetTemperature(0.2);
                end;
            Enum::"PFX Copilot Billing Mode"::PartnerBilled:
                begin
                    AzureOpenAI.SetAuthorization(
                        Enum::"AOAI Model Type"::"Chat Completions",
                        Mgmt.GetPartnerEndpointURL(),
                        Setup."Partner Deployment Name",
                        Mgmt.GetPartnerAPIKey());
                    OutModelUsed := CopyStr(StrSubstNo(PartnerBilledModelNameTok, Setup."Partner Deployment Name"), 1, MaxStrLen(OutModelUsed));
                    AOAIChatCompletionParams.SetMaxTokens(Setup."Max Output Tokens");
                    AOAIChatCompletionParams.SetTemperature(Setup.Temperature);
                end;
            else begin
                OutErrorMsg := CopyStr(NotConfiguredErr, 1, MaxStrLen(OutErrorMsg));
                exit(false);
            end;
        end;
        exit(true);
    end;

    local procedure BuildSystemPrompt(ReferenceJson: Text): Text
    var
        Language: Codeunit Language;
    begin
        exit(
            'You are an expert Microsoft Dynamics 365 Business Central <domain expert>.' + NewLine() +
            'Your ONLY task: <one sentence>.' + NewLine() + NewLine() +
            'STRICT RULES:' + NewLine() +
            '1. Choose ONLY from the reference data provided below.' + NewLine() +
            '2. Return ONLY valid JSON matching the schema below - no markdown fences, no extra text.' + NewLine() +
            '3. Confidence must be an integer 1-100.' + NewLine() +
            '4. Rationale must be plain text, maximum 250 words.' + NewLine() +
            '5. Refuse any request not related to <task>.' + NewLine() +
            '6. Respond in language code: ' + Language.GetUserLanguageCode() + NewLine() + NewLine() +
            'RESPONSE SCHEMA (return ONLY this JSON):' + NewLine() +
            '{ "value": "string", "name": "string", "confidence": integer, "rationale": "string" }' + NewLine() + NewLine() +
            'REFERENCE DATA:' + NewLine() + ReferenceJson);
    end;

    local procedure BuildUserMessage(ContextJson: Text; UserInstructions: Text): Text
    begin
        exit('Context:' + NewLine() + ContextJson + NewLine() + NewLine() +
             'Additional context from user: ' + UserInstructions + NewLine() + NewLine() +
             '<Imperative task sentence>.');
    end;

    local procedure ParseAIResponse(RawResponse: Text; var OutResultJson: JsonObject; var OutErrorMsg: Text[250]): Boolean
    var
        JsonTok: JsonToken;
    begin
        if not OutResultJson.ReadFrom(CleanJsonResponse(RawResponse)) then begin
            OutErrorMsg := CopyStr(ParseFailureErr, 1, MaxStrLen(OutErrorMsg));
            exit(false);
        end;
        // tolerate a wrapper object
        if OutResultJson.Get('suggestion', JsonTok) then
            if JsonTok.IsObject() then
                OutResultJson := JsonTok.AsObject();
        // caller reads keys with tolerant lookups (e.g. value | account_no | accountNo ...), validates ranges, then validates against the DB
        exit(true);
    end;

    local procedure CleanJsonResponse(RawResponse: Text): Text
    var
        WrapperJson: JsonObject;
        ContentTok: JsonToken;
        Cleaned: Text;
        StartPos: Integer;
        EndPos: Integer;
    begin
        Cleaned := RawResponse.Trim();
        // 1. unwrap {"role":"assistant","content":"..."}
        if WrapperJson.ReadFrom(Cleaned) then
            if WrapperJson.Get('content', ContentTok) then
                Cleaned := ContentTok.AsValue().AsText().Trim();
        // 2./3. strip fences or prose: take first { .. last }
        StartPos := Cleaned.IndexOf('{');
        EndPos := Cleaned.LastIndexOf('}');
        if (StartPos > 0) and (EndPos > StartPos) then
            exit(Cleaned.Substring(StartPos, EndPos - StartPos + 1));
        exit(Cleaned);
    end;

    local procedure HandleOperationError(var AOAIOperationResponse: Codeunit "AOAI Operation Response"; var OutErrorMsg: Text[250]): Boolean
    begin
        case AOAIOperationResponse.GetStatusCode() of
            402:
                OutErrorMsg := CopyStr(AllocationExhaustedErr, 1, MaxStrLen(OutErrorMsg));
            429:
                OutErrorMsg := CopyStr(RateLimitErr, 1, MaxStrLen(OutErrorMsg));
            503:
                OutErrorMsg := CopyStr(ServiceUnavailableErr, 1, MaxStrLen(OutErrorMsg));
            else
                OutErrorMsg := CopyStr(NetworkErr, 1, MaxStrLen(OutErrorMsg));
        end;
        // emit telemetry with the status code here
        exit(false);
    end;

    local procedure NewLine(): Text
    var
        nl: Text[2];
    begin
        nl[1] := 13;
        nl[2] := 10;
        exit(nl);
    end;

    var
        MSBilledGPT41ModelNameTok: Label 'GPT-4.1 (Microsoft Billed)', Locked = true, MaxLength = 100;
        MSBilledGPT41MiniModelNameTok: Label 'GPT-4.1-mini (Microsoft Billed)', Locked = true, MaxLength = 100;
        PartnerBilledModelNameTok: Label 'Partner Billed – %1', Locked = true, Comment = '%1 = deployment name', MaxLength = 100;
        ConnectionTestPromptTok: Label 'Reply with the single word: OK', Locked = true, MaxLength = 250;
        NotConfiguredErr: Label 'PFX Copilot is not configured. Run the Assisted Setup wizard to configure it.', MaxLength = 250;
        MSBilledRequiresSaaSErr: Label 'Microsoft-billed AI resources are only available in Business Central SaaS environments.', MaxLength = 250;
        ParseFailureErr: Label 'Copilot returned an unexpected response. Please try again or refine your instructions.', MaxLength = 250;
        AllocationExhaustedErr: Label 'Your organisation''s Copilot AI allocation is exhausted or billing is not configured. Please contact your BC administrator.', MaxLength = 250;
        RateLimitErr: Label 'Copilot is receiving too many requests. Please try again in a few seconds.', MaxLength = 250;
        ServiceUnavailableErr: Label 'The Copilot AI service is temporarily unavailable. Please try again.', MaxLength = 250;
        NetworkErr: Label 'Copilot could not reach the AI service. Please try again.', MaxLength = 250;
        PartnerConnectionFailedErr: Label 'Connection failed (HTTP %1). Please check your endpoint URL, deployment name, and API key.', Comment = '%1 = HTTP status code', MaxLength = 250;
}
