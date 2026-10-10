namespace PFX.Copilot.Setup;

enum 50100 "PFX Copilot Billing Mode"
{
    Access = Internal;
    Extensible = false;

    value(0; " ") { Caption = '(Not Configured)'; }
    value(1; MicrosoftBilled) { Caption = 'Microsoft Billed'; }
    value(2; PartnerBilled) { Caption = 'Partner Billed'; }
}

enum 50101 "PFX Copilot MS Model"
{
    Access = Internal;
    Extensible = false;

    value(0; GPT41) { Caption = 'Quality – GPT-4.1 (Recommended)'; }
    value(1; GPT41Mini) { Caption = 'Economy – GPT-4.1-mini'; }
}
