# Changelog

OnlyBCFans Business Central Copilot Blueprint, by AJ Ansari and OnlyBCFans.

All notable changes are recorded here. Consumers pin a release tag; the tag name matches the version below.

## [1.0.0.0] - 2026-10-10

Verified against Business Central 27.5: System Application 27.5.46862.46929, Base Application 27.5.46862.49619,
AL runtime 15.0, AL compiler 18.0.2819426.

### Added
- `SKILL.md` agent entry point (Claude Code skill format): top false assumptions, 15-step procedure, rules, checklist.
- `references/01` to `09`: architecture, capability registration, Microsoft-billed path, Partner-billed path,
  PromptDialog and host-page action, AI engine and parsing, setup/wizard/telemetry/upgrade, verified System.AI API
  reference, false-assumptions table (31 rows).
- `templates/`: nine AL files (capability enum extension, billing and model enums, setup table, management codeunit with
  IsolatedStorage, install codeunit, AI engine, PromptDialog page, host page extension, wizard snippets). All compile
  with 0 errors against the 27.5 symbols.

### Corrected during independent review before release
- `addlast(Prompting)` compiles on General Journal (page 39) even though the page declares no Prompting area; the
  source project's failure was the misspelled area `Prompts`. Templates and references now prefer Prompting with
  processing + Promoted as the fallback.
- Partner-billed path downgraded from "tested live" to "compiler- and symbol-verified".
- Added `AzureOpenAI.IsEnabled` as the documented pre-check, `Extensible = false` as a compiler requirement for
  PromptDialog, `AddXPIADetectionTags` for user free text, and capability re-registration on upgrade.
- Exact compiler diagnostics recorded for Placeholder (AL0124), Label/variable tooltips (AL0219), `Timestamp` field
  (AL0757), PromptDialog without `Extensible = false` (AL0223).

### Corrected against Microsoft Learn (2026-10-10)
- "Errors inside OnQueryClosePage are swallowed" removed. Learn: the trigger may write to the database and an error
  keeps the page open; both save locations (trigger, or caller after RunModal) are documented. The source project's
  symptom was the `LookupOK` mismatch.
- Prompting area: added Learn's `addlast(Prompting)` page-extension example, the runtime 13/14 supported page-type
  matrix, the `RunObject` rendering note, `Visible = IsCapabilityRegistered` guidance, and Sparkle/caption guidance.

### Provenance
- Distilled from a shipped production extension, including its bug-fix and code-review
  records, on 2026-10-09.
