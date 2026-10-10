# 07 - Setup card, assisted setup wizard, telemetry, install/upgrade

Part of the OnlyBCFans Business Central Copilot Blueprint.

## Setup card

- `PageType = Card; SourceTable = <Setup>; InsertAllowed = false; DeleteAllowed = false; UsageCategory = Administration; ApplicationArea = All;`
- **A `UsageCategory` is required** or the page is invisible to Tell Me search (Bugfixes002 Gap 9); `Administration` is the right value for a setup card.
- `OnOpenPage` calls `GetOrCreateSetup(Rec)` so the single row always exists.
- Groups toggled by billing mode: `Visible = IsMSBilled` / `Visible = IsPartnerBilled`, recomputed in
  `OnAfterGetRecord` and in the Billing Mode field's `OnValidate`.
- Partner credentials are never shown; a drill-down text field points the admin to the wizard.
- Promoted actions: open the log list, re-run the wizard (`Page.Run(Page::"<Wizard>")`).

## Assisted setup registration (install, per company)

```al
local procedure RegisterAssistedSetup()
var
    GuidedExperience: Codeunit "Guided Experience";
begin
    if GuidedExperience.Exists(Enum::"Guided Experience Type"::"Assisted Setup", ObjectType::Page, Page::"GJCopilot Setup Wizard") then
        exit;
    GuidedExperience.InsertAssistedSetup(
        AssistedSetupTitleTok,          // Text[2048]
        AssistedSetupShortTitleTok,     // Text[50]
        AssistedSetupDescriptionTok,    // Text[1024]
        5,                              // expected minutes
        ObjectType::Page,
        Page::"GJCopilot Setup Wizard",
        Enum::"Assisted Setup Group"::Extensions,
        '',                             // VideoUrl Text[250]
        Enum::"Video Category"::Uncategorized,
        DefaultLearnMoreUrlTok);        // HelpUrl Text[250]
end;
```

Verified 27.5 signatures (Business Foundation, codeunit 1990 "Guided Experience"):
- `InsertAssistedSetup(Title, ShortTitle, Description, ExpectedDuration, ObjectTypeToRun, ObjectIDToRun, AssistedSetupGroup, VideoUrl, VideoCategory, HelpUrl)` - 10 params
- `InsertAssistedSetup(... , HelpUrl, IsPrimarySetup: Boolean)` - 11 params
- `Exists(GuidedExperienceType, ObjectType, ObjectID)`
- `CompleteAssistedSetup(ObjectType, ObjectID)`
- `Remove(GuidedExperienceType, ObjectType, ObjectID)`

`ManualSetupCategory` and `Keywords` are parameters of `InsertManualSetup(...)`, a different procedure; the TDD confused the two.
Namespaces: `System.Environment.Configuration` for Guided Experience and the Assisted Setup Group enum,
`System.Media` for Video Category.

`InsertAssistedSetup` is an upsert that keeps the Completed flag, so the Upgrade codeunit calls it again (without
the `Exists` guard) to refresh title/description on existing tenants (OPEN-09).

## Wizard page pattern

- `PageType = NavigatePage; SourceTable = <Setup>; SourceTableTemporary = true;` so Cancel discards.
- `OnOpenPage`: load the real setup into `Rec`, `Rec.Insert()`, seed wizard variables, `CurrentStep := Step::Welcome`.
- Steps are groups with `Visible = CurrentStep = Step::X` (two Option variables `CurrentStep`/`Step` with identical members).
- Footer actions `Back`, `Next`, `Finish`, `Test Connection` with `InFooterBar = true`; enable/visible booleans
  recomputed in `UpdateNavigationButtons()`; always `CurrPage.Update(false)` after changing step.
- Branch after Billing Mode: MS → Model step; Partner → Endpoint step → API Key step (Next gated on a passing test).
- `FinishSetup()`: copy values from `Rec` to the real record, save/clear partner credentials, set
  `"Assisted Setup Completed" := true`, `Modify()`, `GuidedExperience.CompleteAssistedSetup(ObjectType::Page, Page::"<Wizard>")`, Message, Close.
- Page object names max 30 characters ("GJCopilot Assisted Setup Wizard" was too long and had to be renamed).
- A privacy notice on the Welcome step: what data goes to the model, and that Microsoft-billed is covered by the
  BC SaaS Data Protection Addendum.

## Feature Telemetry

```al
local procedure EmitEvent(EventId: Text[8]; EventName: Text[128]; Dimensions: Dictionary of [Text, Text])
var
    FeatureTelemetry: Codeunit "Feature Telemetry";   // System.Telemetry
begin
    FeatureTelemetry.LogUsage(EventId, TelemetryFeatureNameTok, EventName, Dimensions);
end;
```

Verified overloads usable from a PTE: `LogUsage(EventId, FeatureName, EventName)` and `LogUsage(EventId, FeatureName, EventName, CustomDimensions)`.
A third overload with an `AL Telemetry Scope` enum exists but that enum is internal to the System Application. There is
**no** overload taking a `ModuleInfo` (the first build assumed one). `LogError(...)` and `LogUptake(...)`
exist too. Event IDs are 8-char locked labels (`0GLSUG01`...). Retired IDs are never reused. Dimensions used:
BillingMode, ConfidenceBand, ModelUsed, ErrorCategory, ModelName.

## Install / Upgrade

- `OnInstallAppPerDatabase`: capability registration (SaaS guard). Repeat the guarded registration in `OnUpgradePerDatabase` so capabilities added in later versions reach existing tenants (the reference project does not, which is a gap).
- `OnInstallAppPerCompany`: assisted setup + ensure the setup row with defaults (Temperature 0.2, MaxTokens 512,
  thresholds 70/40, Learn More URL).
- `OnUpgradePerCompany`: backfill new fields, re-upsert assisted setup.
- Keep `DefaultLearnMoreUrlTok` and `app.json.help` identical (OPEN-08).

## Audit log

Table with AutoIncrement `Entry No.`, `Log Timestamp` (do not name a field `Timestamp`: AL0757 "metadata name of Field
'Timestamp' conflicts with Field 'SystemRowVersion'"), User ID, Company, business keys, Suggested value, Confidence, Outcome enum, Billing Mode enum, Model Used,
rows analysed, Error Message Text[250]. Keys on timestamp and (User ID, Outcome). List page with a user-chosen
cutoff date for "Delete entries before".
