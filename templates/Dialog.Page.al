namespace PFX.Copilot.Feature;

using PFX.Copilot.Common;
using PFX.Copilot.AI;

// PromptDialog skeleton. No SourceTable; context via SetContext(); result via getters; caller performs the write.
page 50102 "PFX Copilot Dialog"
{
    PageType = PromptDialog;
    Caption = 'Suggest <Something>';
    IsPreview = true;
    Extensible = false; // required for PromptDialog (AL0223)
    DataCaptionExpression = '';

    layout
    {
        area(Prompt)
        {
            field(UserInstructionsField; UserInstructionsTxt)
            {
                ApplicationArea = All;
                MultiLine = true;
                ShowCaption = false;
                ToolTip = 'Optionally provide additional context.';
                // Placeholder is not an AL page-field property (AL0124). Pre-fill in OnOpenPage.
            }
        }
        area(Content)
        {
            group(SuggestionGrp)
            {
                ShowCaption = false;
                Visible = HasValidSuggestion;

                field(SuggestedValueField; SuggestedValueTxt) { ApplicationArea = All; Caption = 'Suggested Value'; Editable = false; Style = Strong; ToolTip = 'The value suggested by Copilot.'; }
                field(ConfidenceField; ConfidenceLabelTxt) { ApplicationArea = All; Caption = 'Confidence'; Editable = false; StyleExpr = ConfidenceStyleExpr; ToolTip = 'Green = high, amber = medium, red = low.'; }
                field(RationaleField; RationaleTxt) { ApplicationArea = All; Caption = 'Rationale'; Editable = false; MultiLine = true; ToolTip = 'Why Copilot suggested this.'; }
            }
            group(WarningGrp)
            {
                ShowCaption = false;
                Visible = WarningVisible;
                field(WarningField; WarningTxt) { ApplicationArea = All; ShowCaption = false; Editable = false; Style = Attention; MultiLine = true; ToolTip = 'Warning.'; }
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
                ToolTip = 'Ask Copilot for a suggestion.';
                trigger OnAction()
                begin
                    RunGenerate();
                end;
            }
            systemaction(OK)
            {
                Caption = 'Keep It';
                Enabled = HasValidSuggestion;
                ToolTip = 'Accept the suggestion.';
                // no OnAction here - handled in OnQueryClosePage with Action::OK
            }
            systemaction(Cancel)
            {
                Caption = 'Discard';
                ToolTip = 'Close without applying.';
            }
        }
        area(PromptGuide)
        {
            action(PromptHint1)
            {
                ApplicationArea = All;
                Caption = '<Canned hint 1>';
                trigger OnAction()
                begin
                    UserInstructionsTxt := '<Canned hint 1 text>';
                    CurrPage.Update(false);
                end;
            }
            action(ManualOverrideAction)
            {
                ApplicationArea = All;
                Caption = 'Do it manually';
                ToolTip = 'Close Copilot and continue manually.';
                trigger OnAction()
                begin
                    ManualOverrideSelected := true;
                    CurrPage.Close();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        UserInstructionsTxt := 'Describe any additional context to help Copilot.';
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if ManualOverrideSelected then
            exit(true);
        case CloseAction of
            Action::OK: // NOT LookupOK
                begin
                    if not HasValidSuggestion then
                        exit(false); // keep open
                    AcceptedByUser := true; // this template saves in the caller after RunModal(); saving here on Action::OK is equally documented
                end;
            Action::Cancel:
                ; // log "Discarded" here if you keep an audit log
        end;
        exit(true);
    end;

    procedure SetContext(NewKey1: Code[20]; NewKey2: Code[20])
    begin
        Key1 := NewKey1;
        Key2 := NewKey2;
    end;

    procedure WasAccepted(): Boolean
    begin
        exit(AcceptedByUser);
    end;

    procedure WasManualOverride(): Boolean
    begin
        exit(ManualOverrideSelected);
    end;

    procedure GetAcceptedValue(): Code[20]
    begin
        exit(SuggestedValueTxt);
    end;

    local procedure RunGenerate()
    var
        AIEngine: Codeunit "PFX Copilot AI Engine";
        ResultJson: JsonObject;
        JsonTok: JsonToken;
        ContextJson: Text;
        ReferenceJson: Text;
        ModelUsed: Text[100];
        ErrorMsg: Text[250];
    begin
        ClearSuggestionOutput();
        // ContextJson / ReferenceJson := your Context Builder codeunit
        if not AIEngine.Generate(ContextJson, ReferenceJson, UserInstructionsTxt, ResultJson, ModelUsed, ErrorMsg) then begin
            Message(ErrorMsg);
            exit;
        end;
        if ResultJson.Get('value', JsonTok) then
            SuggestedValueTxt := CopyStr(JsonTok.AsValue().AsText(), 1, MaxStrLen(SuggestedValueTxt));
        if ResultJson.Get('confidence', JsonTok) then
            ConfidenceScore := JsonTok.AsValue().AsInteger();
        if ResultJson.Get('rationale', JsonTok) then
            RationaleTxt := JsonTok.AsValue().AsText();
        // VALIDATE SuggestedValueTxt against the database here before showing it. Exit with Message on failure.
        UpdateConfidenceLabel(70, 40);
        HasValidSuggestion := SuggestedValueTxt <> '';
        CurrPage.Update(false);
    end;

    local procedure ClearSuggestionOutput()
    begin
        SuggestedValueTxt := '';
        ConfidenceScore := 0;
        ConfidenceLabelTxt := '';
        ConfidenceStyleExpr := 'None';
        RationaleTxt := '';
        HasValidSuggestion := false;
        WarningTxt := '';
        WarningVisible := false;
    end;

    local procedure UpdateConfidenceLabel(HighThreshold: Integer; LowThreshold: Integer)
    begin
        ConfidenceLabelTxt := CopyStr(Format(ConfidenceScore) + '%', 1, MaxStrLen(ConfidenceLabelTxt));
        if ConfidenceScore >= HighThreshold then
            ConfidenceStyleExpr := 'Favorable'
        else
            if ConfidenceScore < LowThreshold then
                ConfidenceStyleExpr := 'Unfavorable'
            else
                ConfidenceStyleExpr := 'Attention';
    end;

    var
        Key1: Code[20];
        Key2: Code[20];
        UserInstructionsTxt: Text[500];
        SuggestedValueTxt: Code[20];
        ConfidenceScore: Integer;
        ConfidenceLabelTxt: Text[30];
        ConfidenceStyleExpr: Text;
        RationaleTxt: Text;
        WarningTxt: Text[250];
        WarningVisible: Boolean;
        HasValidSuggestion: Boolean;
        ManualOverrideSelected: Boolean;
        AcceptedByUser: Boolean;
}
