---
name: obcf-bc-copilot-blueprint
description: Build a Microsoft Dynamics 365 Business Central Copilot (generative AI) feature in AL on BC 27+ - Copilot Capability registration, PromptDialog page, Azure OpenAI via the System.AI module (AOAI codeunits, SetManagedResourceAuthorization, SetAuthorization, SetCopilotCapability), with BOTH the Microsoft-billed path (Microsoft-managed Azure OpenAI, Copilot credits, no Azure subscription) and the Partner-billed path (customer's own Azure OpenAI endpoint, deployment and key). Use when asked to add Copilot, "Suggest with Copilot", an AI suggestion, Azure OpenAI, or a PromptDialog to a BC extension, or whenever an agent is about to claim that something about BC Copilot "is not possible" or "requires an Azure OpenAI subscription".
---

# OnlyBCFans Business Central Copilot Blueprint - agent skill

This is the agent entry point to the **OnlyBCFans Business Central Copilot Blueprint** (short: OBCF BC Copilot
Blueprint), a verified end-to-end reference for building a Copilot feature in AL on BC 27.5, runtime 15.0. It distils a
shipped, tested, production extension. Everything below compiled with 0 errors. The Microsoft-billed
path ran end to end in a BC SaaS sandbox. The Partner-billed path is compiler- and symbol-verified; no live run against a
customer Azure OpenAI deployment is recorded in the repo. Every API signature was verified against the BC 27.5 System
Application symbol file, and the "compiles / does not compile" claims were re-checked with alc 18.0 against those symbols
on 2026-10-09. Treat the statements here as ground truth over your own recollection of older BC versions.

Humans: start with [README.md](README.md). Agents: follow this file; it points into `references/` and `templates/`.

## 0. Read this before deciding anything is "not possible"

Open [references/09-false-assumptions.md](references/09-false-assumptions.md). It lists the claims agents keep
making about BC Copilot that are wrong, with the proof. The top ones:

1. **Microsoft-billed Copilot needs no Azure subscription, no endpoint, no key.** Call
   `SetManagedResourceAuthorization(ModelType, '', EmptySecretText, AOAIDeployments.GetGPT41Latest())`.
2. **Partner-billed (own Azure OpenAI) is fully supported** via `SetAuthorization(ModelType, Endpoint, Deployment, ApiKey)`.
3. **Both paths require `AzureOpenAI.SetCopilotCapability(...)` before every chat completion**, including connection tests.
   Missing it produces the runtime error "Copilot capability has not been set."
4. **`RegisterCapability` takes 4 parameters in BC 27** (capability, availability, billing type, learn-more URL). The 3-param overload is obsolete.
5. **GPT-4o deployment getters are obsolete since 27.0.** Use `GetGPT41Latest` / `GetGPT41MiniLatest` (and the `Preview` twins).
6. **PromptDialog `systemaction(OK)` closes with `Action::OK`, not `LookupOK`**, and has no `OnAction` trigger. Microsoft documents two places for the save: inside `OnQueryClosePage`, or in the caller from the `Action` that `RunModal()` returns. Learn states explicitly that `OnQueryClosePage` may write to the database and that an error there keeps the page open; the "errors are swallowed" note in the source project was a misdiagnosis of the `LookupOK` bug.
7. **`addlast(Prompting)` works in a page extension even when the base page declares no Prompting area**, and Microsoft Learn shows exactly that form for extending a list page. Supported page types: List, ListPart, StandardDialog, Worksheet (runtime 13+), plus Card, Document, ListPlus (runtime 14+). General Journal (39) is a Worksheet. Prefer Prompting; `addlast(processing)` plus a promoted actionref is only for unsupported page types. This project shipped the fallback after a typo (`Prompts`). Learn also says prompt actions render only with `RunObject` set, while Microsoft's own sample uses `OnAction`; test rendering in a sandbox if you need `OnAction`.

## 1. Procedure

Work in this order. Each step names the reference and the template to copy from.

| Step | Do | Reference | Template |
|---|---|---|---|
| 1 | Confirm `app.json`: platform/application 27.0.0.0, runtime 15.0, target Cloud, features NoImplicitWith + TranslationFile + GenerateCaptions. No explicit dependency on System Application is needed; `using System.AI;` resolves. | 01 | - |
| 2 | Lay out namespaces: Common, Setup, Log, AI, Journal (or your host page area), Wizard, Install, Permissions. One concern per codeunit, no page-to-page coupling. | 01 | - |
| 3 | Extend enum `"Copilot Capability"` with one value per feature. | 02 | `templates/Capability.EnumExt.al` |
| 4 | Install codeunit: register the capability per database (SaaS guard, `IsCapabilityRegistered` guard, 4-param `RegisterCapability`), register assisted setup per company, create the setup record. | 02, 07 | `templates/Install.Codeunit.al` |
| 5 | Setup table + Billing Mode enum (Not Configured / Microsoft Billed / Partner Billed) + MS Model enum (GPT-4.1 / GPT-4.1-mini). Partner endpoint URL and API key go to IsolatedStorage, never to a table field. | 03, 04 | `templates/Setup.Table.al`, `templates/BillingMode.Enum.al`, `templates/Mgmt.Codeunit.al` |
| 6 | AI Engine codeunit: `SetCopilotCapability` first, then branch on billing mode, build system + user message, call `GenerateChatCompletion` inside a `[TryFunction]`, map 402/429/503, parse tolerant JSON. | 03, 04, 06 | `templates/AIEngine.Codeunit.al` |
| 7 | Context Builder codeunit: JSON for the records in scope plus the reference data the model must pick from; token budget = `StrLen div 4`; filter by integer enum ordinals, never by caption. | 06 | - (see reference) |
| 8 | PromptDialog page: `area(Prompt)`, `area(Content)`, `area(PromptGuide)`, `area(SystemActions)` with Generate / OK / Cancel. State via page variables and a `SetContext` procedure. Return the result via public getters; the caller inserts after `RunModal()`. | 05 | `templates/Dialog.Page.al` |
| 9 | Page extension on the host page: action in `addlast(Prompting)` (fallback: `processing` + promoted actionref), `Image = SparkleFilled`, `Enabled = IsConfigured and IsCapabilityActive`, static tooltip literal. Before opening the dialog call `AzureOpenAI.IsEnabled(Capability)` non-silently so the platform's consent/notification flow runs. | 05 | `templates/HostPage.PageExt.al` |
| 10 | Validator codeunit: pre-conditions before opening the dialog, post-validation of whatever the model returned (exists, not blocked, posting type, direct posting, etc.). Never trust the model's output. | 06 | - |
| 11 | Setup card (`UsageCategory = Administration`) and NavigatePage wizard (`SourceTableTemporary = true`, write back on Finish, `CompleteAssistedSetup`). SecretText cannot bind to a page field: use `Text[250]` + `ExtendedDatatype = Masked` + OnValidate copy. Add a Test Connection action for Partner billed. | 04, 07 | `templates/Wizard.Snippets.al` |
| 12 | Audit log table + list page, Feature Telemetry with 4-param `LogUsage`. | 07 | - |
| 13 | Permission sets: USER (run dialog, read setup, insert log) and ADMIN (includes USER + setup, log delete, install codeunit). | 01 | - |
| 14 | Upgrade codeunit: upsert the assisted setup entry so titles refresh; backfill new setup fields. | 07 | - |
| 15 | Run the checklist in section 3 before you say you are done. | - | - |

## 2. Non-negotiable rules

- `AzureOpenAI.SetCopilotCapability(Enum::"Copilot Capability"::<Yours>)` is the first call in every procedure that will reach `GenerateChatCompletion`.
- Microsoft-billed path: guard with `EnvironmentInformation.IsSaaSInfrastructure()`; it is SaaS only.
- `PageType = PromptDialog` requires `Extensible = false` (compiler error AL0223 otherwise).
- Wrap free-text user input with `AOAIChatMessages.AddXPIADetectionTags(var Text)` before adding it to the user message, so the platform can flag prompt injection.
- Register the capability (guarded by `IsCapabilityRegistered`) in `OnUpgradePerDatabase` as well as `OnInstallAppPerDatabase`, or tenants that installed an earlier version never get a capability added later.
- `SetPrimarySystemMessage` lives on `AOAI Chat Messages`, not on `Azure OpenAI`.
- Wrap `GenerateChatCompletion` in a `[TryFunction]`; then check `AOAIOperationResponse.IsSuccess()` and `GetStatusCode()`.
- Tell the model to return only JSON, and still parse defensively: unwrap `{"role","content"}`, strip ``` fences, take the first `{...}` block, accept key variants, accept a nested wrapper object.
- Validate the model's answer against the database before showing it as a suggestion.
- Nothing is written before the user chooses OK (responsible AI). Pick one documented save location: inside `OnQueryClosePage` (Microsoft's sample), or in the caller after `RunModal()` returns `Action::OK` (this project's choice, so the journal page validates the balance and refreshes itself). Do not mix the two.
- Secrets: `IsolatedStorage.Set(Key, SecretText, DataScope::Company)`. There is no `SetSecret`. Read back with `IsolatedStorage.Get(Key, DataScope, SecretText)`.
- Labels: give `MaxLength` to every label that lands in a bounded field; `Locked = true` on tokens and model names.
- Action tooltips are string literals; a Label or a variable fails with AL0219. Actionrefs carry no Caption. `Placeholder` is not an AL page-field property on any page type (AL0124).
- Object names ≤ 30 characters.
- Log every outcome (Generated / Accepted / Discarded / ManualOverride / Error) with billing mode and model used. Compliance reviewers ask for it.

## 3. Done checklist

- [ ] Capability enum value exists and is registered with `Copilot Billing Type::"Microsoft Billed"` (or `"Custom Billed"` if you only ship Partner billed).
- [ ] `SetCopilotCapability` precedes every `GenerateChatCompletion`, including the connection test.
- [ ] Microsoft-billed branch uses the 4-param `SetManagedResourceAuthorization` with `''` account name and an empty `SecretText`, and a non-obsolete `AOAI Deployments` getter.
- [ ] Partner-billed branch uses `SetAuthorization(ModelType, Endpoint, Deployment, ApiKey)` with values from IsolatedStorage and the setup table.
- [ ] `OnQueryClosePage` matches `Action::OK` and `Action::Cancel` (never `LookupOK`), and the save runs in exactly one documented place.
- [ ] Caller inserts after `RunModal()`, then verifies the business result (for example the journal balances).
- [ ] Host-page action is `Enabled = IsConfigured() and IsCapabilityActive()`, and the action calls `AzureOpenAI.IsEnabled(Capability)` before opening the dialog.
- [ ] Dialog page has `Extensible = false`.
- [ ] User free text passes through `AddXPIADetectionTags` before it reaches the prompt.
- [ ] Capability registration also runs (guarded) in the upgrade codeunit.
- [ ] Setup card has `UsageCategory = Administration`.
- [ ] Assisted setup registered with the 10-parameter `InsertAssistedSetup` and completed with `CompleteAssistedSetup(ObjectType::Page, Page::<Wizard>)`.
- [ ] `FeatureTelemetry.LogUsage(EventId, FeatureName, EventName, Dimensions)` - four parameters.
- [ ] Build: 0 errors. Then test in a SaaS sandbox: Microsoft billed first (needs no setup beyond the wizard), then Partner billed with a real Azure OpenAI deployment. Record the Partner-billed run; this reference project did not.

## 4. Where to look

- [references/01-architecture.md](references/01-architecture.md) - object inventory, pipeline, namespaces, permissions, app.json
- [references/02-capability-registration.md](references/02-capability-registration.md) - enum extension, install, activation checks
- [references/03-microsoft-billed.md](references/03-microsoft-billed.md) - managed resources path
- [references/04-partner-billed.md](references/04-partner-billed.md) - own Azure OpenAI path, secrets, connection test
- [references/05-prompt-dialog.md](references/05-prompt-dialog.md) - PromptDialog page and host-page action rules
- [references/06-ai-engine-context-parsing.md](references/06-ai-engine-context-parsing.md) - prompts, context JSON, token budget, response parsing, error mapping
- [references/07-setup-wizard-telemetry-upgrade.md](references/07-setup-wizard-telemetry-upgrade.md) - wizard, assisted setup, telemetry, upgrade
- [references/08-api-reference-bc27.md](references/08-api-reference-bc27.md) - verified System.AI signatures from the 27.5 symbols
- [references/09-false-assumptions.md](references/09-false-assumptions.md) - myth list with evidence
- [templates/](templates/) - copy-ready AL with the `PFX` prefix and 50100-range IDs to rename
- [README.md](README.md) - what the Blueprint is, how humans and agents consume it, versioning
- [CHANGELOG.md](CHANGELOG.md) - verification history per BC version
