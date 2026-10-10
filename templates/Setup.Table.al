namespace PFX.Copilot.Setup;

table 50100 "PFX Copilot Setup"
{
    Caption = 'PFX Copilot Setup';
    DataClassification = SystemMetadata;
    Access = Internal;

    fields
    {
        field(1; "Primary Key"; Code[10]) { Caption = 'Primary Key'; DataClassification = SystemMetadata; }
        field(2; "Billing Mode"; Enum "PFX Copilot Billing Mode") { Caption = 'Billing Mode'; DataClassification = SystemMetadata; }
        field(3; "MS Model"; Enum "PFX Copilot MS Model") { Caption = 'Model (Microsoft Billed)'; DataClassification = SystemMetadata; }
        field(4; "Partner Endpoint Configured"; Boolean) { Caption = 'Partner Endpoint Configured'; DataClassification = SystemMetadata; Editable = false; }
        field(5; "Partner Deployment Name"; Text[100]) { Caption = 'Partner Deployment Name'; DataClassification = OrganizationIdentifiableInformation; }
        field(6; Temperature; Decimal) { Caption = 'Temperature'; DataClassification = SystemMetadata; InitValue = 0.2; MinValue = 0; MaxValue = 2; }
        field(7; "Max Output Tokens"; Integer) { Caption = 'Max Output Tokens'; DataClassification = SystemMetadata; InitValue = 512; MinValue = 128; MaxValue = 4096; }
        field(8; "High Confidence Threshold"; Integer) { Caption = 'High Confidence Threshold (%)'; DataClassification = SystemMetadata; InitValue = 70; MinValue = 1; MaxValue = 100; }
        field(9; "Low Confidence Threshold"; Integer) { Caption = 'Low Confidence Threshold (%)'; DataClassification = SystemMetadata; InitValue = 40; MinValue = 1; MaxValue = 100; }
        field(10; "Assisted Setup Completed"; Boolean) { Caption = 'Assisted Setup Completed'; DataClassification = SystemMetadata; }
        field(11; "Learn More URL"; Text[250]) { Caption = 'Learn More URL'; DataClassification = SystemMetadata; ExtendedDatatype = URL; }
        // Endpoint URL and API key are NOT table fields. They live in IsolatedStorage (see Mgmt.Codeunit.al).
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }
}
