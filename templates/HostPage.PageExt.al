namespace PFX.Copilot.Feature;

using Microsoft.Finance.GeneralLedger.Journal;
using System.AI;
using PFX.Copilot.Common;

// Entry point. addlast(Prompting) compiles on BC 27.5 even though page 39 declares no Prompting area itself
// (verified with alc 18.0). Prompting is where the client renders Copilot actions - verify rendering in a sandbox.
// Fallback (what the reference project shipped): addlast(processing) group + addfirst(Promoted) actionref, shown commented below.
pageextension 50130 "PFX Copilot Journal Ext" extends "General Journal"
{
    actions
    {
        addlast(Prompting)
        {
            action(PFXSuggest)
            {
                ApplicationArea = All;
                Caption = 'Suggest <Something>';
                Image = SparkleFilled;
                Enabled = IsActionEnabled;
                ToolTip = 'Use Copilot to suggest <something>. If this button is disabled, PFX Copilot is not configured - run the Assisted Setup wizard to set it up.'; // literal only (Label/variable -> AL0219)

                trigger OnAction()
                begin
                    RunSuggest();
                end;
            }
        }
        // --- Fallback placement ---------------------------------------------------
        // addlast(processing)
        // {
        //     group(PFXCopilotGrp)
        //     {
        //         Caption = 'Copilot';
        //         Image = SparkleFilled;
        //         action(PFXSuggest) { ...same as above... }
        //     }
        // }
        // addfirst(Promoted)
        // {
        //     actionref(PFXSuggest_Promoted; PFXSuggest) { } // no Caption on actionref
        // }
    }

    trigger OnOpenPage()
    begin
        UpdateActionState();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        UpdateActionState();
    end;

    local procedure RunSuggest()
    var
        AzureOpenAI: Codeunit "Azure OpenAI";
        Dialog: Page "PFX Copilot Dialog";
        AcceptedValue: Code[20];
    begin
        // 0. platform pre-check: capability active + tenant consent; non-silent form shows the standard notification
        if not AzureOpenAI.IsEnabled(Enum::"Copilot Capability"::PFXSuggestSomething) then
            exit;
        // 1. pre-conditions (your Validator codeunit) -> Message + exit on failure
        // 2. context
        Dialog.SetContext(Rec."Journal Batch Name", Rec."Document No.");
        // 3. run
        Dialog.RunModal();
        // 4. act AFTER the dialog closed - errors here surface normally
        if Dialog.WasAccepted() then begin
            AcceptedValue := Dialog.GetAcceptedValue();
            // your Inserter/Updater codeunit; Message on failure; verify the business outcome afterwards
        end;
        if Dialog.WasManualOverride() then
            Message(ManualOverrideSelectedMsg);
        CurrPage.Update(false);
    end;

    local procedure UpdateActionState()
    var
        Mgmt: Codeunit "PFX Copilot Mgmt";
    begin
        IsActionEnabled := Mgmt.IsConfigured() and Mgmt.IsCapabilityActive();
    end;

    var
        IsActionEnabled: Boolean;
        ManualOverrideSelectedMsg: Label 'Copilot suggestion discarded. Please continue manually.', MaxLength = 250;
}
