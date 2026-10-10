# 06 - AI engine: messages, call, errors, context, parsing

Part of the OnlyBCFans Business Central Copilot Blueprint.

## Call sequence

```al
procedure GenerateSuggestion(JournalContextJson: Text; COAContextJson: Text; UserInstructions: Text;
                             var OutAccountNo: Code[20]; var OutAccountName: Text[100]; var OutConfidence: Integer;
                             var OutRationale: Text; var OutModelUsed: Text[100]; var OutErrorMsg: Text[250]): Boolean
var
    AzureOpenAI: Codeunit "Azure OpenAI";
    AOAIChatCompletionParams: Codeunit "AOAI Chat Completion Params";
    AOAIOperationResponse: Codeunit "AOAI Operation Response";
    ChatMessages: Codeunit "AOAI Chat Messages";
begin
    GJCopilotMgmt.GetOrCreateSetup(GJCopilotSetup);
    if not SetupAuthorization(AzureOpenAI, AOAIChatCompletionParams, GJCopilotSetup, OutModelUsed, OutErrorMsg) then
        exit(false);                                            // sets capability + billing-mode auth (03/04)

    ChatMessages.SetPrimarySystemMessage(BuildSystemPrompt(COAContextJson));   // on ChatMessages, NOT on AzureOpenAI
    ChatMessages.AddUserMessage(BuildUserMessage(JournalContextJson, UserInstructions));

    if not TryGenerateChatCompletion(AzureOpenAI, ChatMessages, AOAIChatCompletionParams, AOAIOperationResponse) then begin
        OutErrorMsg := NetworkErr;                              // exception thrown by the module
        exit(false);
    end;
    if not AOAIOperationResponse.IsSuccess() then
        exit(HandleOperationError(AOAIOperationResponse, OutErrorMsg));   // 402 / 429 / 503 / other

    exit(ParseAIResponse(AOAIOperationResponse.GetResult(), OutAccountNo, OutAccountName, OutConfidence, OutRationale, OutErrorMsg));
end;

[TryFunction]
local procedure TryGenerateChatCompletion(var AzureOpenAI: Codeunit "Azure OpenAI"; var ChatMessages: Codeunit "AOAI Chat Messages";
                                          var AOAIChatCompletionParams: Codeunit "AOAI Chat Completion Params";
                                          var AOAIOperationResponse: Codeunit "AOAI Operation Response")
begin
    AzureOpenAI.GenerateChatCompletion(ChatMessages, AOAIChatCompletionParams, AOAIOperationResponse);
end;
```

Signatures (27.5): `GenerateChatCompletion(var AOAIChatMessages, var AOAIOperationResponse)` and
`GenerateChatCompletion(var AOAIChatMessages, AOAIChatCompletionParams, var AOAIOperationResponse)`.
`SetPrimarySystemMessage(Message: SecretText)` accepts Text by implicit conversion.
Params: `SetTemperature(Decimal)`, `SetMaxTokens(Integer)`, `SetJsonMode(Boolean)`, `SetMaxHistory`,
`SetPresencePenalty`, `SetFrequencyPenalty`. `SetJsonMode(true)` is a good addition when the deployment supports it;
this project relied on prompt instructions plus a tolerant parser and did not need it.

## HTTP status mapping that users understood

| Status | Message to user | Telemetry category |
|---|---|---|
| 402 | "Your organisation's Copilot AI allocation is exhausted or billing is not configured. Contact your BC administrator." | 402-AllocationExhausted |
| 429 | "Copilot is receiving too many requests. Try again in a few seconds." | 429-RateLimit |
| 503 | "The Copilot AI service is temporarily unavailable. Try again." | 503-ServiceUnavailable |
| other | "Copilot could not reach the AI service. Try again." | Unknown-<code> |

Never surface raw diagnostics (`GetLastErrorText`, raw response) to end users in production. The project shipped
DIAG-* strings once by accident; review caught it (Bugfixes002 Gap 15).

## System prompt pattern that produced parseable output

```
You are an expert Microsoft Dynamics 365 Business Central accountant.
Your ONLY task: suggest the correct balancing G/L account for the journal entry provided.

STRICT RULES:
1. Suggest ONLY accounts from the Chart of Accounts context provided below.
2. Return ONLY valid JSON matching the schema below - no markdown fences, no extra text.
3. Never suggest blocked accounts or non-Posting type accounts.
4. Confidence must be an integer 1-100.
5. Rationale must be plain text, maximum 250 words.
6. Refuse any request not related to G/L account balancing.
7. Respond in language code: <Language.GetUserLanguageCode()>

RESPONSE SCHEMA (return ONLY this JSON):
{ "account_no": "string", "account_name": "string", "confidence": integer, "rationale": "string" }

CHART OF ACCOUNTS:
<json array>
```

User message: `Journal Entry Context:\n<json>\n\nAdditional context from user: <text>\n\nSuggest the balancing G/L account.`

Prompt injection: the reference project concatenates the user's free text straight into the message. Do better: call
`ChatMessages.AddXPIADetectionTags(UserInstructions)` (var Text) first so the platform's cross-prompt-injection detection
can flag it.

Build the system prompt fresh on every call (idempotent guard rails). Newlines: build CR+LF from a `Text[2]` with
`nl[1] := 13; nl[2] := 10;`. A literal escape sequence in the string tripped the preprocessor in this project.

## Context JSON and token budget

- Serialize with `JsonObject`/`JsonArray` and `WriteTo(Text)`; never hand-concatenate JSON.
- Dates as `Format(Date, 0, '<Year4>-<Month,2>-<Day,2>')`.
- Reference data (here the Chart of Accounts): include only rows the model is allowed to pick (not blocked,
  Posting type, Direct Posting) to keep tokens down.
- Token estimate: `StrLen(Text) div 4`. Budget used: 50,000 tokens for the reference list. When over budget,
  rebuild with a narrower filter (here: only the Account Categories present on the source lines) and tell the user
  the list was reduced (`COAFilteredWarningVisible`). `AOAI Token.GetGPT4TokenCount(SecretText)` exists if you want
  a real count.
- Filter enums by integer ordinal, not caption: `Format(GLAccount."Account Category".AsInteger())` joined with `|`
  into `SetFilter`. Caption filters break on non-English tenants (OPEN-04, resolved v1.0.0.12).
- Cap the number of source rows you send (open item OPEN-07 suggests 100) and warn when truncated.

## Tolerant response parsing

`GetResult()` returned, in practice, either the bare assistant content or a `{"role":"assistant","content":"..."}`
envelope, sometimes wrapped in ``` fences or surrounded by prose, and the model occasionally renamed keys. The
parser that stopped the "unexpected response" failures (Bugfixes002 Gap 12):

1. `Trim()`; if it parses as JSON and has `content`, take `content` and trim again.
2. If it starts with ```, cut from first `{` to last `}`.
3. Otherwise still cut from first `{` to last `}` (prose wrappers).
4. `ReadFrom`; if a `suggestion` object exists, descend into it.
5. Accept key variants: `account_no | accountNo | account_number | accountNumber | account`;
   `account_name | accountName | name`.
6. Confidence outside 1..100 becomes 0 (shown as low).
7. Any failure returns a generic "Copilot returned an unexpected response" message.

Then **validate the result against the database** (exists, not blocked, posting type, direct posting, posting-date
range warning) before it is displayed. The model is a suggester, not an authority.

## Language

`Language.GetUserLanguageCode()` (codeunit Language, System.Globalization) gives the user's language code to put
in the prompt so the rationale is localized.
