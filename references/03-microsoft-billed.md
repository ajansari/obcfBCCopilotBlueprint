# 03 - Microsoft-billed path (Microsoft-managed Azure OpenAI)

Part of the OnlyBCFans Business Central Copilot Blueprint.

The customer needs **no Azure subscription, no endpoint, no deployment, no API key**. Usage is metered through
Business Central (Copilot credits / the tenant's AI allocation). This path is SaaS-only.

## The exact calls that work on BC 27.5

```al
local procedure SetupAuthorization(var AzureOpenAI: Codeunit "Azure OpenAI";
                                   var AOAIChatCompletionParams: Codeunit "AOAI Chat Completion Params";
                                   PFXCopilotSetup: Record "PFX Copilot Setup";
                                   var OutModelUsed: Text[100]; var OutErrorMsg: Text[250]): Boolean
var
    AOAIDeployments: Codeunit "AOAI Deployments";
    EnvironmentInformation: Codeunit "Environment Information";
    DeploymentMethod: Text;
    EmptyAPIKey: SecretText;
begin
    AzureOpenAI.SetCopilotCapability(Enum::"Copilot Capability"::SuggestGLBalancingAccount);

    if not EnvironmentInformation.IsSaaSInfrastructure() then begin
        OutErrorMsg := MSBilledRequiresSaaSErr;
        exit(false);
    end;

    case PFXCopilotSetup."MS Model" of
        Enum::"PFX Copilot MS Model"::GPT41:
            DeploymentMethod := AOAIDeployments.GetGPT41Latest();
        Enum::"PFX Copilot MS Model"::GPT41Mini:
            DeploymentMethod := AOAIDeployments.GetGPT41MiniLatest();
    end;

    AzureOpenAI.SetManagedResourceAuthorization(
        Enum::"AOAI Model Type"::"Chat Completions",
        '',             // AOAIAccountName - empty is correct for Microsoft-managed
        EmptyAPIKey,    // empty SecretText - correct
        DeploymentMethod);

    AOAIChatCompletionParams.SetMaxTokens(512);
    AOAIChatCompletionParams.SetTemperature(0.2);
    exit(true);
end;
```

Verified signature (non-obsolete):
`SetManagedResourceAuthorization(ModelType: Enum "AOAI Model Type", AOAIAccountName: Text, ApiKey: SecretText, ManagedResourceDeployment: Text)`

The older 5-parameter overload `(ModelType, Endpoint, Deployment, ApiKey, ManagedResourceDeployment)` is
**obsolete since 26.0**. source fix round 1 records the migration from 2 params the agent guessed to the real 4.

## Deployment getters in BC 27.5 (`AOAI Deployments`, codeunit 7768)

| Procedure | Status |
|---|---|
| `GetGPT41Latest()` | current - default "Quality" choice |
| `GetGPT41Preview()` | current - for testing upcoming versions |
| `GetGPT41MiniLatest()` | current - "Economy" choice |
| `GetGPT41MiniPreview()` | current |
| `GetGPT4oLatest()`, `GetGPT4oPreview()`, `GetGPT4oMiniLatest()`, `GetGPT4oMiniPreview()` | obsolete 27.0 ("no longer supported from 15 July 2025") |
| `GetGPT4Latest()`, `GetGPT4Preview()`, `GetGPT35Turbo*()`, `GetTurbo*()`, `GetGPT40613()` | obsolete 25.0 |

Give the customer a model choice as an enum in the setup table (this project: Quality GPT-4.1 recommended,
Economy GPT-4.1-mini) so you can swap deployments without a code change in the engine.

## Behaviour and billing facts observed

- Works immediately in a SaaS sandbox once the capability is registered and the admin has not disabled it.
- HTTP 402 from the service means the tenant's AI allocation is exhausted or Copilot billing is not set up; map it
  to a message that tells the user to contact their BC administrator.
- Temperature and max tokens on this path were fixed in code (0.2 / 512) and the fields hidden in the setup card
  for Microsoft billed; the customer can tune them only on Partner billed. Your call whether to expose them.
- No `Endpoint`/`Deployment` is ever stored for this mode; `IsConfigured()` returns true as soon as Billing Mode =
  Microsoft Billed.
