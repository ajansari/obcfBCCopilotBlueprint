// Template: rename PFX, renumber 50100, pick your own value id (unique within the Copilot Capability enum across apps).
namespace PFX.Copilot.Common;

using System.AI;

enumextension 50100 "PFX Copilot Capability" extends "Copilot Capability"
{
    value(50100; PFXSuggestSomething)
    {
        Caption = 'PFX Suggest Something'; // shown in "Copilot & agent capabilities"
    }
}
