# 04 - Partner-billed path (customer's own Azure OpenAI resource)

Part of the OnlyBCFans Business Central Copilot Blueprint.

The customer (or partner) brings an Azure OpenAI resource: endpoint URL, a chat-completions deployment name,
and an API key. Billing goes to their Azure subscription. The same `Azure OpenAI` codeunit is used; only the
authorization call differs. **`SetCopilotCapability` is still mandatory.**

Verification status: this path compiles and every signature matches the 27.5 symbols, but the repo holds no record of a
passing live Test Connection or a Partner-billed suggestion. Run it against a real deployment and record the result.

## Authorization

```al
AzureOpenAI.SetCopilotCapability(Enum::"Copilot Capability"::SuggestGLBalancingAccount);
AzureOpenAI.SetAuthorization(
    Enum::"AOAI Model Type"::"Chat Completions",
    GJCopilotMgmt.GetPartnerEndpointURL(),        // Text, from IsolatedStorage
    GJCopilotSetup."Partner Deployment Name",     // Text[100], from setup table
    GJCopilotMgmt.GetPartnerAPIKey());            // SecretText, from IsolatedStorage
AOAIChatCompletionParams.SetMaxTokens(GJCopilotSetup."Max Output Tokens");
AOAIChatCompletionParams.SetTemperature(GJCopilotSetup.Temperature);
```

Verified signature: `SetAuthorization(ModelType: Enum "AOAI Model Type", Endpoint: Text, Deployment: Text, ApiKey: SecretText)`.
A 2-param overload `SetAuthorization(ModelType, Deployment)` also exists; its semantics are not evidenced in this repo or
the symbols, so treat it as unverified.

Endpoint format: the resource root, `https://<resource>.openai.azure.com/` (enforce `https://` prefix in the wizard).
The module composes the REST path itself.

## Secret storage (what compiles and what does not)

```al
// store
IsolatedStorage.Set(PartnerEndpointURLKeyTok, EndpointURL, DataScope::Company);   // Text overload
IsolatedStorage.Set(PartnerAPIKeyTok, APIKey, DataScope::Company);                // SecretText overload

// read
if IsolatedStorage.Get(PartnerAPIKeyTok, DataScope::Company, APIKey) then ...     // APIKey: SecretText
if IsolatedStorage.Get(PartnerEndpointURLKeyTok, DataScope::Company, EndpointURL) then ...

// remove
if IsolatedStorage.Contains(Key, DataScope::Company) then IsolatedStorage.Delete(Key, DataScope::Company);
```

`IsolatedStorage.SetSecret(...)` **does not exist**; the first build used it and failed to compile (Bugfixes001).
Keep a Boolean `"Partner Endpoint Configured"` in the setup table so `IsConfigured()` can answer without touching
IsolatedStorage, and set it in the same procedure that saves the credentials.

## Capturing the key in a page (SecretText cannot bind to a field)

```al
field(WizardAPIKeyTxt; WizardAPIKeyTxt)
{
    Caption = 'API Key';
    ExtendedDatatype = Masked;
    trigger OnValidate()
    begin
        WizardAPIKey := WizardAPIKeyTxt;   // Text[250] -> SecretText (implicit conversion)
    end;
}
...
var
    WizardAPIKey: SecretText;
    WizardAPIKeyTxt: Text[250];
```

The page variable is `Text[250]`; the engine only ever receives the `SecretText`. Do not persist `WizardAPIKeyTxt`.

## Test Connection (gate "Next" on it)

```al
procedure TestPartnerConnection(EndpointURL: Text; DeploymentName: Text; APIKey: SecretText; var ErrorMsg: Text[250]): Boolean
var
    AzureOpenAI: Codeunit "Azure OpenAI";
    AOAIChatMessages: Codeunit "AOAI Chat Messages";
    AOAIChatCompletionParams: Codeunit "AOAI Chat Completion Params";
    AOAIOperationResponse: Codeunit "AOAI Operation Response";
begin
    AzureOpenAI.SetCopilotCapability(Enum::"Copilot Capability"::SuggestGLBalancingAccount);
    AzureOpenAI.SetAuthorization(Enum::"AOAI Model Type"::"Chat Completions", EndpointURL, DeploymentName, APIKey);
    AOAIChatMessages.AddUserMessage('Reply with the single word: OK');
    AOAIChatCompletionParams.SetMaxTokens(10);
    AOAIChatCompletionParams.SetTemperature(0);
    if not TryRunConnectionTest(AzureOpenAI, AOAIChatMessages, AOAIChatCompletionParams, AOAIOperationResponse) then begin
        ErrorMsg := NetworkErr;
        exit(false);
    end;
    if AOAIOperationResponse.IsSuccess() then
        exit(true);
    ErrorMsg := StrSubstNo(PartnerConnectionFailedErr, AOAIOperationResponse.GetStatusCode());
    exit(false);
end;
```

Wizard flow for Partner billed: Billing Mode → Endpoint + Deployment (Next enabled when URL is https and
deployment not blank) → API Key + Test Connection (Next enabled only after a passing test) → thresholds → ... →
Finish saves credentials via `SavePartnerCredentials(EndpointURL, APIKey)` and clears them if the user switches
back to Microsoft billed.

## Which billing type to register

Register the capability as `"Microsoft Billed"` if the app offers the Microsoft path at all (this project does, as
the recommended default). If an app ships Partner billed only, `"Custom Billed"` is the honest value.
