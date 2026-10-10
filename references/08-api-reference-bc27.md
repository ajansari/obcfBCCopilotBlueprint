# 08 - Verified System.AI API surface, BC 27.5 (System Application 27.5.46862.46929)

Part of the OnlyBCFans Business Central Copilot Blueprint.

Extracted from `SymbolReference.json` inside the symbol package. Public, non-local procedures relevant to a chat-completion
Copilot feature; a few public helpers (e.g. `AOAI Chat Messages.AddToolCalls/AssembleHistory/AssembleTools`, `AOAI Operation
Response.AddFunctionResponse/SetOperationResponse`, `Guided Experience.IsAssistedSetupComplete/ResetAssistedSetup`) are omitted.
`[OBSOLETE x]` = ObsoleteState Pending since version x; compiles with a warning, avoid.

## codeunit 7771 "Azure OpenAI" (System.AI)

```
IsEnabled(CopilotCapability): Boolean
IsEnabled(CopilotCapability, Silent: Boolean): Boolean
IsEnabled(CopilotCapability, Silent: Boolean, AppId: Guid): Boolean
IsAuthorizationConfigured(ModelType: Enum "AOAI Model Type"): Boolean
IsInitialized(CopilotCapability, ModelType): Boolean
SetManagedResourceAuthorization(ModelType, Endpoint: Text, Deployment: Text, ApiKey: SecretText, ManagedResourceDeployment: Text)   [OBSOLETE 26.0]
SetManagedResourceAuthorization(ModelType, AOAIAccountName: Text, ApiKey: SecretText, ManagedResourceDeployment: Text)              <- use this
SetAuthorization(ModelType, Endpoint: Text, Deployment: Text, ApiKey: SecretText)                                                   <- partner billed
SetAuthorization(ModelType, Deployment: Text)
GenerateTextCompletion(Prompt: SecretText, var AOAIOperationResponse): Text  (+ overloads with Metaprompt and AOAI Text Completion Params)
GenerateEmbeddings(Input: SecretText, var AOAIOperationResponse): List of [Decimal]
GenerateChatCompletion(var AOAIChatMessages, var AOAIOperationResponse)
GenerateChatCompletion(var AOAIChatMessages, AOAIChatCompletionParams, var AOAIOperationResponse)
SetCopilotCapability(CopilotCapability)                                                                                              <- mandatory
```

## codeunit 7768 "AOAI Deployments"

```
GetGPT41Latest(): Text         GetGPT41Preview(): Text
GetGPT41MiniLatest(): Text     GetGPT41MiniPreview(): Text
GetGPT4oLatest/GetGPT4oPreview/GetGPT4oMiniLatest/GetGPT4oMiniPreview   [OBSOLETE 27.0]
GetGPT4Latest/GetGPT4Preview/GetGPT35TurboLatest/GetGPT35TurboPreview/GetTurbo0301/GetTurbo0613/GetGPT40613   [OBSOLETE 25.0]
```

## codeunit 7773 "Copilot Capability"

```
RegisterCapability(CopilotCapability, LearnMoreUrl: Text[2048])
RegisterCapability(CopilotCapability, CopilotAvailability, LearnMoreUrl: Text[2048])                       [OBSOLETE 27.0]
RegisterCapability(CopilotCapability, CopilotAvailability, CopilotBillingType, LearnMoreUrl: Text[2048])   <- use this
ModifyCapability(CopilotCapability, CopilotAvailability, LearnMoreUrl)                                     [OBSOLETE 27.0]
ModifyCapability(CopilotCapability, CopilotAvailability, CopilotBillingType, LearnMoreUrl)
UnregisterCapability(CopilotCapability)
IsCapabilityRegistered(CopilotCapability[, AppId: Guid]): Boolean
IsCapabilityActive(CopilotCapability[, AppId: Guid]): Boolean
OnGetRequiredPrivacyNotices(CopilotCapability, AppId, var RequiredPrivacyNotices: List of [Code[50]])   (event)
```

## codeunit 7761 "AOAI Chat Completion Params"

```
Get/SetTemperature(Decimal)   Get/SetMaxTokens(Integer)   SetJsonMode(Boolean)   Get/SetMaxHistory(Integer)
Get/SetPresencePenalty(Decimal)   Get/SetFrequencyPenalty(Decimal)   Get/SetAOAIPolicyParams(Codeunit "AOAI Policy Params")
```

## codeunit 7763 "AOAI Chat Messages"

```
SetPrimarySystemMessage(Message: SecretText)
AddSystemMessage(Text)   AddUserMessage(Text)   AddUserMessage(Text, Name: Text[2048])   AddAssistantMessage(Text)
AddToolMessage(ToolCallId, FunctionName, FunctionResult)
ModifyMessage(Id, NewMessage, NewRole: Enum "AOAI Chat Roles", NewName)   DeleteMessage(Id)
GetHistory(): List of [Text]   GetHistoryNames()   GetHistoryRoles()   GetLastMessage(): Text   GetLastRole()   GetLastName()
GetLastToolCalls(): JsonArray   SetHistoryLength(Integer)   GetHistoryTokenCount(): Integer
AddTool(Function: Interface "AOAI Function")   DeleteFunctionTool(Name): Boolean   ClearTools()
GetFunctionTool(Name, var Function): Boolean   GetFunctionTools(): List of [Text]   ToolsExists(): Boolean
SetAddToolsToPayload(Boolean)   SetToolChoice(Text)   SetFunctionAsToolChoice(Name | Interface)   GetToolChoice(): Text
Set/GetToolInvokePreference(Enum "AOAI Tool Invoke Preference")
AddXPIADetectionTags(var Input: Text)      <- wrap untrusted user text to flag prompt-injection
(AddTool(JsonObject), ModifyTool, DeleteTool(Id), GetTools()  [OBSOLETE 25.0])
```

## codeunit 7770 "AOAI Operation Response"

```
IsSuccess(): Boolean   GetStatusCode(): Integer   GetResult(): Text   GetError(): Text
IsFunctionCall(): Boolean   HasFunctionResponsesByName(Name): Boolean
TryGetFunctionReponsesByName(Name, var List of [Codeunit "AOAI Function Response"]): Boolean
GetFunctionResponses(): List of [Codeunit "AOAI Function Response"]
AppendFunctionResponsesToChatMessages(var AOAIChatMessages)
(GetFunctionResponse()  [OBSOLETE 25.0])
```

## codeunit 7759 "AOAI Token"

```
GetGPT35TokenCount(SecretText): Integer   GetGPT4TokenCount(SecretText): Integer
GetAdaTokenCount(SecretText): Integer     GetDavinciTokenCount(SecretText): Integer
GetTotalServerSessionTokensConsumed(): Integer
```

## Enums (all non-extensible, public)

```
7773 "AOAI Model Type":      Embeddings(0), "Text Completions"(1), "Chat Completions"(2)
7774 "Copilot Availability": Preview(0), "Generally Available"(1), "Early Preview"(2)
7786 "Copilot Billing Type": "Not Billed"(0), "Microsoft Billed"(1), "Custom Billed"(2), Undefined(3)
7775 "Copilot Status":       Active(0), Inactive(1)
"Copilot Capability":        extensible - add your value via enumextension
```

## Related, verified

```
codeunit 1990 "Guided Experience" (Business Foundation, System.Environment.Configuration)
  InsertAssistedSetup(Title: Text[2048], ShortTitle: Text[50], Description: Text[1024], ExpectedDuration: Integer,
                      ObjectTypeToRun: ObjectType, ObjectIDToRun: Integer, AssistedSetupGroup: Enum "Assisted Setup Group",
                      VideoUrl: Text[250], VideoCategory: Enum "Video Category", HelpUrl: Text[250][, IsPrimarySetup: Boolean])
  Exists(GuidedExperienceType, ObjectType, ObjectID)   CompleteAssistedSetup(ObjectType, ObjectID)   Remove(...)

codeunit 8703 "Feature Telemetry" (System.Telemetry)
  LogUsage(EventId: Text, FeatureName: Text, EventName: Text[, CustomDimensions: Dictionary of [Text, Text]])   (+ an overload with internal enum "AL Telemetry Scope", unusable from a PTE)
  InsertManualSetup(..., ManualSetupCategory, Keywords[, IsPrimarySetup])  <- this is where ManualSetupCategory/Keywords live, not InsertAssistedSetup
  LogError(EventId, FeatureName, EventName, ErrorText[, ErrorCallStack[, CustomDimensions]])
  LogUptake(EventId, FeatureName, FeatureUptakeStatus[, IsPerUser][, CustomDimensions])

codeunit "Environment Information" (System.Environment): IsSaaSInfrastructure(): Boolean
codeunit Language (System.Globalization): GetUserLanguageCode(): Code[10]
IsolatedStorage: Set(Key, Text|SecretText, DataScope)  Get(Key, DataScope, var Text|SecretText): Boolean  Contains(Key, DataScope)  Delete(Key, DataScope)

page 39 "General Journal" action areas declared in 27.5: navigation, processing, Promoted. A page extension can still
addlast(Prompting) - compiles (alc 18.0). Only pages 5839 and 388 declare Prompting themselves in the 27.5 Base App.
```

How to re-verify on another version: the `.app` symbol package is a ZIP with a 40-byte header. `dd bs=1 skip=40`
it to a `.zip`, extract `SymbolReference.json`, walk `Namespaces[*].Codeunits[*].Methods` (objects live under
namespaces, not at the root).
