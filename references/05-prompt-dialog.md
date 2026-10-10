# 05 - PromptDialog page and host-page entry point

Part of the OnlyBCFans Business Central Copilot Blueprint.

## Page skeleton that compiles and behaves on BC 27.5

```al
page 78702 "PFX Copilot Dialog"
{
    PageType = PromptDialog;
    Caption = 'Suggest Balancing G/L Account';
    IsPreview = true;              // preview badge; pair with Copilot Availability::Preview
    Extensible = false;            // REQUIRED for PromptDialog (AL0223 otherwise)
    DataCaptionExpression = '';
    // No SourceTable. Context arrives via SetContext(); state lives in page variables.

    layout
    {
        area(Prompt)               // the user's free-text input
        {
            field(UserInstructionsField; UserInstructionsTxt)
            {
                ApplicationArea = All;
                MultiLine = true;
                ShowCaption = false;
                ToolTip = 'Optionally provide additional context about this transaction.';
                // Placeholder = '...'  <-- not an AL page-field property on any page type (AL0124); pre-fill in OnOpenPage instead
            }
        }
        area(Content)              // the generated output + warnings; groups toggled with Visible = <Boolean var>
        {
            group(SuggestionGrp)
            {
                ShowCaption = false;
                Visible = HasValidSuggestion;
                field(SuggestedAccountNoField; SuggestedAccountNoTxt) { ApplicationArea = All; Caption = 'Suggested Account'; Editable = false; Style = Strong; ToolTip = '...'; }
                field(ConfidenceField; ConfidenceLabelTxt) { ApplicationArea = All; Caption = 'Confidence'; Editable = false; StyleExpr = ConfidenceStyleExpr; ToolTip = '...'; }
                field(RationaleField; RationaleTxt) { ApplicationArea = All; Caption = 'Rationale'; Editable = false; MultiLine = true; ToolTip = '...'; }
            }
        }
    }

    actions
    {
        area(SystemActions)
        {
            systemaction(Generate)
            {
                Caption = 'Generate';
                ToolTip = '...';
                trigger OnAction()
                begin
                    RunGenerate();              // OnAction IS supported on Generate (and Regenerate)
                end;
            }
            systemaction(OK)
            {
                Caption = 'Keep It';
                Enabled = HasValidSuggestion;   // Enabled/Caption/ToolTip allowed; OnAction is NOT
                ToolTip = '...';
            }
            systemaction(Cancel)
            {
                Caption = 'Discard';
                ToolTip = '...';
            }
        }
        area(PromptGuide)          // canned prompt hints and secondary actions; no Image property here
        {
            action(PromptHintExpense)
            {
                ApplicationArea = All;
                Caption = 'This is an expense reimbursement';
                trigger OnAction()
                begin
                    UserInstructionsTxt := 'This is an expense reimbursement transaction.';
                    CurrPage.Update(false);
                end;
            }
            action(ManualOverrideAction)
            {
                ApplicationArea = All;
                Caption = 'Use a Different Account';
                ToolTip = '...';
                trigger OnAction()
                begin
                    RunManualOverride();        // logs, sets flag, CurrPage.Close()
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        UserInstructionsTxt := 'Describe any additional context ...';   // the "placeholder"
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if ManualOverrideSelected then
            exit(true);
        case CloseAction of
            Action::OK:                        // <-- OK, NOT LookupOK
                begin
                    if not HasValidSuggestion then
                        exit(false);           // keep dialog open: nothing to accept
                    AcceptedByUser := true;    // this project saves in the caller; saving here is equally documented
                    RunLogAccept();
                end;
            Action::Cancel:
                RunDiscard();
        end;
        exit(true);
    end;

    procedure SetContext(NewTemplate: Code[10]; NewBatch: Code[10]; NewDocNo: Code[20]) ...
    procedure WasAccepted(): Boolean ...
    procedure WasManualOverride(): Boolean ...
    procedure GetAcceptedAccountNo(): Code[20] ...
}
```

## Rules learned the hard way

| Rule | Evidence |
|---|---|
| `systemaction(OK)` closes with `CloseAction = Action::OK`. Matching `Action::LookupOK` silently does nothing. | source review, gap 13 (CRITICAL): "Keep It" did nothing at all. |
| Save in exactly one of the two documented places: inside `OnQueryClosePage` on `Action::OK` (Microsoft's sample), or in the caller when `RunModal()` returns `Action::OK` (this project). Learn: "You can use this trigger to write to the database" and an error there keeps the page open; the project's "errors are swallowed" note (source review, gap 14) was a misdiagnosis of Gap 13. | Learn OnQueryClosePage + copilot-design-content-mode (2026-10-10) |
| `systemaction(OK)` / `systemaction(Cancel)` take no `OnAction` trigger; `Generate` (and `Regenerate`) do. | source fix round 1 |
| `Placeholder` is not an AL page-field property at all (AL0124 on a Card page too). Pre-fill the variable in `OnOpenPage`. | source fix round 1; alc probe |
| `PageType = PromptDialog` requires `Extensible = false`. | alc probe: AL0223 |
| Wrap the user's free text with `AOAIChatMessages.AddXPIADetectionTags(var Text)` before adding it to the user message. | System.AI API; not done in the reference project |
| `Image` is not accepted on actions inside `area(PromptGuide)`. | source fix round 1 |
| Secondary actions such as "Use a different account" belong in `area(PromptGuide)`; Processing area is not available on PromptDialog. | source fix round 1 |
| `Regenerate` is optional. This project removed it in v1.0.0.10 because `Generate` is re-runnable; keep telemetry IDs retired, never reused. | TECHNICAL_DESIGN |
| Reset all output variables at the start of each `Generate` (`ClearSuggestionOutput`) so a failed second run does not show stale output. | code |
| Use `StyleExpr` with 'Favorable' / 'Attention' / 'Unfavorable' for confidence bands driven by setup thresholds. | code |

Other PromptDialog areas you may use (not needed here): `area(PromptOptions)` for enum/option fields that steer
generation, and `systemaction(Attach)` for file input.

## Host page entry point

Shipped version (processing + Promoted). See "About `area(Prompting)`" below for the preferred placement.

```al
pageextension 78730 "PFX Copilot Journal Ext" extends "General Journal"
{
    actions
    {
        addlast(processing)
        {
            group(CopilotActionsGrp)
            {
                Caption = 'Copilot';
                Image = SparkleFilled;
                action(SuggestBalancingAccount)
                {
                    ApplicationArea = All;
                    Caption = 'Suggest Bal. Account';
                    Image = SparkleFilled;
                    Enabled = IsActionEnabled;
                    ToolTip = 'Use Copilot to suggest ... If this button is disabled, ... run the Assisted Setup wizard ...';  // literal only
                    trigger OnAction()
                    begin
                        RunSuggestBalancingAccount();
                    end;
                }
            }
        }
        addfirst(Promoted)
        {
            actionref(SuggestBalancingAccount_Promoted; SuggestBalancingAccount) { }   // no Caption on actionref
        }
    }

    trigger OnOpenPage()            begin UpdateActionState(); end;
    trigger OnAfterGetCurrRecord()  begin UpdateActionState(); end;

    local procedure RunSuggestBalancingAccount()
    var
        PFXCopilotDialog: Page "PFX Copilot Dialog";
        ...
    begin
        // Recommended addition (not in the shipped code): platform consent/notification pre-check
        // if not AzureOpenAI.IsEnabled(Enum::"Copilot Capability"::SuggestGLBalancingAccount) then exit;
        if not PFXCopilotValidator.ValidatePreConditions(Rec."Journal Template Name", Rec."Journal Batch Name", Rec."Document No.", ErrMsg) then begin
            Message(ErrMsg);
            exit;
        end;
        PFXCopilotDialog.SetContext(Rec."Journal Template Name", Rec."Journal Batch Name", Rec."Document No.");
        PFXCopilotDialog.RunModal();
        if PFXCopilotDialog.WasAccepted() then
            if not PFXCopilotLineInserter.InsertBalancingLine(..., PFXCopilotDialog.GetAcceptedAccountNo()) then
                Message(LineInsertFailureMsg)
            else
                if not PFXCopilotLineInserter.VerifyBalanceAfterInsertion(...) then
                    Message(StillUnbalancedWarningMsg);
        if PFXCopilotDialog.WasManualOverride() then
            Message(ManualOverrideSelectedMsg);
        CurrPage.Update(false);
    end;

    local procedure UpdateActionState()
    begin
        IsActionEnabled := PFXCopilotMgmt.IsConfigured() and PFXCopilotMgmt.IsCapabilityActive();
    end;
}
```

### About `area(Prompting)`

Correction to this project's TECHNICAL_DESIGN note. Page 39 "General Journal" does not declare a Prompting area in
its own symbols (only navigation, processing, Promoted), **but a page extension may add one**. Microsoft Learn
(*Prompting using a floating action bar*) shows `addlast(Prompting)` as the way to extend a list page, lists the
supported page types (List, ListPart, StandardDialog, Worksheet from runtime 13; Card, Document, ListPlus from runtime
14), and says only `PromptDialog` pages may be run from a prompting area: 

```al
addlast(Prompting)
{
    action(SuggestBalancingAccount) { ApplicationArea = All; Caption = '...'; Image = SparkleFilled; ToolTip = '...'; trigger OnAction() begin ... end; }
}
```

compiles with 0 errors on 27.5 (verified with alc 18.0 against the repo symbols, for page 39 and for Sales Order, neither
of which declares the area). The original attempt in this project failed because it used the non-existent area name
`Prompts`. Prefer `Prompting`; that is where the client renders Copilot actions. The shipped processing + Promoted
placement is the fallback. In 27.5 Base Application only pages 5839 "Modify Marketing Text" and 388 "Bank Acc.
Reconciliation List" declare Prompting themselves. Runtime rendering of an extension-added Prompting action was not
verified in a sandbox; test it and fall back if the client does not show it. Note one Learn sentence: "Prompt actions
are displayed only if the `RunObject` property is specified", while Microsoft's own BCTech example in the same
article uses `OnAction` triggers. If you need pre-validation before opening the dialog (so `RunObject` is not an
option), that sandbox test is the thing to do. Learn's guidance for hiding the action where Copilot cannot run:
`Visible = IsCapabilityRegistered` set in `OnOpenPage`. Use `Image = Sparkle` normally and reserve `SparkleFilled`
for emphasising one of several Copilot actions; do not put "Copilot" in the caption, start with a verb.

### Tooltip on a disabled action

The tooltip must be a string literal. A variable **and a Label** both fail with AL0219 "string literal expected" on
actions in runtime 15. Write one sentence for the enabled case and one for the disabled case in the same literal
("If this button is disabled, run the Assisted Setup wizard ...").
