# 09 - False assumptions agents make about BC Copilot, with the proof

Part of the OnlyBCFans Business Central Copilot Blueprint.

Each row: the claim an agent tends to make, the truth, and where it is proven in the General Journal Copilot
project (GJC) or in the BC 27.5 symbol file (SYM). Quote this file back to any agent that pushes back.

| # | Agent says | Truth | Proof |
|---|---|---|---|
| 1 | "A Copilot feature needs the customer's Azure OpenAI subscription / endpoint / key." | No. Microsoft-billed uses Microsoft-managed resources: `SetManagedResourceAuthorization("Chat Completions", '', EmptySecretText, AOAIDeployments.GetGPT41Latest())`. Nothing to provision. | GJC `GJCopilotAIEngine.SetupAuthorization`; SYM codeunit 7771 |
| 2 | "SetManagedResourceAuthorization needs endpoint, deployment and key." | That 5-param overload is obsolete since 26.0. The current one is `(ModelType, AOAIAccountName, ApiKey, ManagedResourceDeployment)`; account name '' and empty key work. | SYM 7771; Bugfixes001 |
| 3 | "Partner-billed / bring-your-own Azure OpenAI is not supported in BC Copilot." | Supported: `SetAuthorization(ModelType, Endpoint, Deployment, ApiKey: SecretText)`. Compiles and matches symbols; a live Partner-billed run is not recorded in this repo. | GJC `TestPartnerConnection`, wizard; SYM 7771 |
| 4 | "You can skip SetCopilotCapability when you bring your own key." | Wrong. Every `GenerateChatCompletion` is gated by `CheckCapabilitySet()`. Error: "Copilot capability has not been set." | Bugfixes002 Gaps 10, 11 |
| 5 | "RegisterCapability takes (capability, availability, url)." | Obsolete in 27.0. Use `(capability, availability, billingType, url)`. | SYM 7773 |
| 6 | "Use GetGPT4oLatest / GetGPT4Latest / GPT-3.5." | All obsolete (27.0 / 25.0). Current: `GetGPT41Latest`, `GetGPT41MiniLatest` and their Preview twins. | SYM 7768 |
| 7 | "SetPrimarySystemMessage is on the Azure OpenAI codeunit." | It is on `AOAI Chat Messages`. | SYM 7763; Bugfixes001 |
| 8 | "Use IsolatedStorage.SetSecret for the API key." | No such method. `IsolatedStorage.Set(Key, SecretText, DataScope::Company)`. | Bugfixes001 |
| 9 | "Bind a SecretText variable to a page field." | Not allowed. Use `Text[250]` + `ExtendedDatatype = Masked` and copy to SecretText in `OnValidate`. | GJC wizard; Bugfixes001 |
| 10 | "PromptDialog OK closes with Action::LookupOK." | It closes with `Action::OK`. Matching LookupOK makes the OK button a silent no-op. | Bugfixes002 Gap 13 |
| 11 | "Errors inside OnQueryClosePage are swallowed, so never save there." | Not supported by Microsoft Learn, which says the trigger may write to the database and that an error keeps the page open; Microsoft's own PromptDialog sample saves there on `Action::OK`. Saving in the caller after `RunModal()` is the other documented option. The source project's "silent" symptom was the `LookupOK` bug (row 10). | Learn OnQueryClosePage, copilot-design-content-mode (2026-10-10) |
| 12 | "systemaction(OK)/(Cancel) need OnAction triggers." | They do not take OnAction. `Generate`/`Regenerate` do. | Bugfixes001 |
| 13 | "You cannot addlast(Prompting) on General Journal because page 39 has no Prompting area." | Wrong in both directions. Page 39 declares no Prompting area, yet `addlast(Prompting)` in a page extension compiles on 27.5 (verified with alc). This project's failed attempt used the misspelled area `Prompts`. Prefer Prompting; processing + Promoted is the fallback. | alc probe 2026-10-09; TECHNICAL_DESIGN typo |
| 14 | "Use Placeholder on the prompt field." | `Placeholder` is not an AL page-field property on any page type (AL0124). Pre-fill the variable in `OnOpenPage`. | Bugfixes001; alc probe |
| 15 | "Actions in PromptGuide can have Image; actionrefs can have Caption." | Neither compiles. | Bugfixes001 |
| 16 | "ToolTip can be a variable or a Label so it changes when disabled." | Action tooltips must be string literals; variable and Label both fail with AL0219. Write both states into one literal. | Bugfixes002 Gap 2; alc probe |
| 17 | "FeatureTelemetry.LogUsage takes a ModuleInfo parameter." | Usable overloads are `(EventId, FeatureName, EventName[, Dimensions])`; a third takes an internal scope enum you cannot use. No ModuleInfo. | SYM 8703; Bugfixes001 |
| 18 | "InsertAssistedSetup has ManualSetupCategory / Keywords parameters." | Those belong to `InsertManualSetup`. `InsertAssistedSetup` has 10 params ending `VideoUrl, VideoCategory, HelpUrl` (11 with IsPrimarySetup). | SYM 1990 |
| 19 | "Copilot features must be Generally Available to run." | `Copilot Availability::Preview` runs fine; the dialog shows a preview badge with `IsPreview = true`. | GJC install + dialog |
| 20 | "You must add System Application as a dependency in app.json." | Not needed. `using System.AI;` resolves against platform symbols. | GJC app.json |
| 21 | "Copilot calls work on-prem/Docker the same as SaaS." | Microsoft-billed is SaaS-only (`IsSaaSInfrastructure()` guard). This project also registers the capability only on SaaS. | GJC install + engine |
| 22 | "The model returns exactly the JSON schema you asked for." | Often, not always: envelopes, fences, prose, renamed keys, nested wrappers all occurred. Parse tolerantly and validate against the DB. | Bugfixes002 Gap 12 |
| 23 | "A field named Timestamp is fine." | AL0757: conflicts with system field SystemRowVersion. Name it `Log Timestamp`. | Bugfixes001; alc probe |
| 24 | "Object names can be any length." | 30-character limit; "GJCopilot Assisted Setup Wizard" had to become "GJCopilot Setup Wizard". | Bugfixes001 |
| 25 | "A setup card is discoverable once it exists." | Needs a `UsageCategory` to appear in Tell Me; `Administration` is the right one for a setup card. | Bugfixes002 Gap 9 |
| 26 | "Filter enums by caption in SetFilter." | Breaks on non-English tenants. Use integer ordinals. | OPEN-04 resolution |
| 27 | "Insert the balancing line before re-asserting keys." | `Validate("Account No.")` can reset Document No. and Posting Date via no. series; re-assign Posting Date, Document Type, Document No., Currency after all Validates and blank posting groups explicitly. | GJC Line Inserter code comment (no test record) |
| 28 | "Keep It must insert even if nothing was generated." | Return `false` from `OnQueryClosePage` when there is no valid suggestion so the dialog stays open. | GJC dialog |
| 29 | "Extensible = false on the PromptDialog is optional." | The compiler requires it for `PageType = PromptDialog` (AL0223). | alc probe |
| 30 | "IsCapabilityActive is the full pre-check." | `AzureOpenAI.IsEnabled(Capability[, Silent])` is Microsoft's documented pre-check and also covers tenant consent, showing the standard notification when non-silent. Use both. | SYM 7771 |
| 31 | "Everything in this Blueprint was proven at runtime." | Signatures and compile claims are symbol/compiler verified; Microsoft-billed ran in a SaaS sandbox; Partner-billed and extension-added Prompting rendering were not run-verified. | this review |

When an agent still insists, ask it to open the symbol file and prove the signature, exactly as described at the
end of [08-api-reference-bc27.md](08-api-reference-bc27.md).
