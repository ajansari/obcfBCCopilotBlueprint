# 01 - Architecture of a BC Copilot feature

Part of the OnlyBCFans Business Central Copilot Blueprint.

Source of truth: General Journal Copilot v1.0.0.13 (BC 27.5, runtime 15.0, target Cloud).

## app.json that worked

```json
{
  "platform": "27.0.0.0",
  "application": "27.0.0.0",
  "runtime": "15.0",
  "target": "Cloud",
  "features": ["NoImplicitWith", "TranslationFile", "GenerateCaptions"],
  "idRanges": [{ "from": 78700, "to": 78799 }],
  "resourceExposurePolicy": { "allowDebugging": true, "allowDownloadingSource": false, "includeSourceInSymbolFile": false }
}
```

No `dependencies` entry is required for the AI module. `using System.AI;` resolves against the System Application
that ships with the platform. Symbols needed in `.alpackages`: System, System Application, Business Foundation,
Base Application, Application (all 27.x).

## Namespaces and objects

```
src/
├── Common/       Mgmt (setup access, secrets, activation check), Logger, Telemetry, Copilot Capability enum ext
├── Setup/        Setup table, Setup card page, Billing Mode enum, MS Model enum
├── Log/          Log table, Log list page, Log Outcome enum
├── AI/           AI Engine (Azure OpenAI calls), Context Builder (JSON), Validator (pre/post checks)
├── Journal/      Host page extension, PromptDialog page, Line Inserter (the only object that writes business data)
├── Wizard/       Assisted Setup wizard (NavigatePage)
├── Install/      Install codeunit, Upgrade codeunit
└── Permissions/  <PFX>-USER, <PFX>-ADMIN
```

| ID | Object | Type | Role |
|---|---|---|---|
| 78700 | GJCopilot Setup | Table | single-row config per company |
| 78701 | GJCopilot Log | Table | audit, AutoIncrement PK |
| 78700 | GJCopilot Billing Mode | Enum | " " / MicrosoftBilled / PartnerBilled |
| 78701 | GJCopilot MS Model | Enum | GPT41 / GPT41Mini |
| 78702 | GJCopilot Log Outcome | Enum | Accepted / Discarded / ManualOverride / Error / Generated |
| 78700 | GJCopilot Capability | EnumExt of "Copilot Capability" | SuggestGLBalancingAccount |
| 78700 | GJCopilot Setup Card | Page Card | UsageCategory = Administration |
| 78701 | GJCopilot Log List | Page List | admin housekeeping |
| 78702 | GJCopilot Dialog | Page PromptDialog | the Copilot UI |
| 78703 | GJCopilot Setup Wizard | Page NavigatePage | assisted setup |
| 78730 | GJCopilot Journal Ext | PageExt of page 39 | entry point action |
| 78700 | GJCopilot Install | Codeunit Install | capability + assisted setup registration |
| 78701 | GJCopilot Upgrade | Codeunit Upgrade | upserts, backfills |
| 78702 | GJCopilot Mgmt | Codeunit | IsConfigured, IsCapabilityActive, secrets |
| 78703 | GJCopilot AI Engine | Codeunit | Azure OpenAI |
| 78704 | GJCopilot Context Builder | Codeunit | JSON context, token budget |
| 78705 | GJCopilot Line Inserter | Codeunit | writes the journal line |
| 78706 | GJCopilot Validator | Codeunit | pre-conditions and output validation |
| 78707 | GJCopilot Logger | Codeunit | audit rows |
| 78708 | GJCopilot Telemetry | Codeunit SingleInstance | Feature Telemetry events |

All codeunits are `Access = Internal`. The dialog is `Extensible = false`, which the compiler requires for `PageType = PromptDialog` (AL0223).

## Pipeline

```
Host page action (OnAction)
  ├─ Validator.ValidatePreConditions          (lines exist? already done? capability active?)
  ├─ Dialog.SetContext(keys)                  (no SourceTable; context in page variables)
  ├─ Dialog.RunModal()
  │     └─ systemaction(Generate) → RunGenerate:
  │           ContextBuilder.BuildPromptContext → AIEngine.GenerateSuggestion
  │           → Validator.ValidateSuggestedAccount → populate fields → Logger + Telemetry
  │     └─ OnQueryClosePage(Action::OK)   → AcceptedByUser := true; log Accepted
  │     └─ OnQueryClosePage(Action::Cancel) → log Discarded
  ├─ if Dialog.WasAccepted() then LineInserter.InsertBalancingLine(...)   ← insert happens HERE, not in the dialog
  ├─ LineInserter.VerifyBalanceAfterInsertion → Message if still unbalanced
  └─ CurrPage.Update(false)
```

Why the insert is outside the dialog: the journal page owns the record set, needs to verify the balance afterwards
and refresh itself, so the caller performs the write. This is one of the two save locations Microsoft documents (the
other is inside `OnQueryClosePage`, as in Microsoft's own sample). The project's earlier note that errors inside
`OnQueryClosePage` are "silently swallowed" is not corroborated by Microsoft Learn, which says the trigger may write
to the database and that an error there keeps the page open. Public getters (`WasAccepted`, `GetAcceptedAccountNo`)
work because the caller still holds the page variable instance after `RunModal()` returns; `RunModal()` itself
returns the close `Action`, so `if Dialog.RunModal() = Action::OK` is an equivalent test.

## Permission sets

USER: setup table R, log table RI, all feature codeunits X, dialog + wizard pages X, host tables (Gen. Journal
Line, G/L Account) RIMD/R as required.
ADMIN: `IncludedPermissionSets = <PFX>-USER`, setup table RIMD, log table RD (insert comes from USER), setup card + log list X, install
codeunit X. Both need `using` for the base namespaces of the tables they grant (Microsoft.Finance.GeneralLedger.Journal etc.).

## Data classification

Setup fields: SystemMetadata, except customer-visible text (deployment name, line description) which is
OrganizationIdentifiableInformation. Log table: EndUserPseudonymousIdentifiers at table level; Document No.,
Batch Name, Suggested Account are CustomerContent.
