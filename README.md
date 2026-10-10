# OnlyBCFans Business Central Copilot Blueprint

**Created by:** AJ Ansari, OnlyBCFans  
**Last Updated:** October 10, 2026  
**Verified against:** Business Central 27.5 (System Application 27.5.46862.46929, Base Application 27.5.46862.49619), AL runtime 15.0, AL compiler 18.0  
**License:** MIT

A verified, end-to-end reference for building a Microsoft Dynamics 365 Business Central **Copilot feature in AL**, covering
both ways the AI can be paid for: **Microsoft billed** (Microsoft-managed Azure OpenAI, no Azure subscription needed) and
**Partner billed** (the customer's own Azure OpenAI endpoint, deployment and key). It is written so that an AI coding agent,
or a human, can follow it without guessing and without re-discovering the pitfalls.

> **One line that says what this is for**
>
> The Standards Guide answers *"what are the rules?"* and the Patterns library answers *"how do I fix this class of bug?"*
> The Blueprint answers *"how do I build a whole Copilot feature, correctly, on this version of Business Central?"*

Short names: *OnlyBCFans BC Copilot Blueprint* or *OBCF BC Copilot Blueprint*.

---

## Contents

- [What this is](#what-this-is)
- [What this is not](#what-this-is-not)
- [Where it comes from](#where-it-comes-from)
- [What is inside](#what-is-inside)
- [How to use it as a human](#how-to-use-it-as-a-human)
- [How to use it with an agent](#how-to-use-it-with-an-agent)
- [What is verified and how](#what-is-verified-and-how)
- [Related projects](#related-projects)
- [Versioning](#versioning)
- [License](#license)

---

## What this is

One reference design, documented thoroughly:

- **Capability registration** - the `Copilot Capability` enum extension, the 4-parameter `RegisterCapability` with billing
  type, activation checks, and the `SetCopilotCapability` call every request needs.
- **Microsoft-billed path** - `SetManagedResourceAuthorization` with an empty account name and empty key, the current
  `AOAI Deployments` getters, the SaaS guard, and what HTTP 402 means.
- **Partner-billed path** - `SetAuthorization` with endpoint, deployment and `SecretText` key; IsolatedStorage for
  secrets; capturing a key in a page; a Test Connection gate.
- **PromptDialog page** - areas, system actions, the `Action::OK` close action, the two documented places to save,
  and the `Prompting` area on the host page.
- **AI engine** - message assembly, the `[TryFunction]` wrapper, status-code mapping, a system prompt that yields JSON,
  tolerant parsing, token budget, and validation of the model's answer against the database.
- **Setup, wizard, telemetry, install and upgrade** - assisted setup registration, a NavigatePage wizard bound to a
  temporary setup record, Feature Telemetry, audit logging.
- **A verified API reference** for the System.AI module on BC 27.5, with obsolete markers.
- **A false-assumptions table** - the claims agents keep making about BC Copilot that are wrong, each with evidence.
- **Copy-ready AL templates** that compile against the 27.5 symbols.

## What this is not

- **Not a rulebook.** Rules live in the [OnlyCopilotFans BC AL Development Standards](https://github.com/ajansari/ocpfBCALStandards).
  The Blueprint cites a handful of hard rules because a feature cannot work without them, but it does not number or
  govern them.
- **Not a pattern library.** Bug-shaped lessons that generalise beyond Copilot belong in
  [OCPF BC AL Patterns](https://github.com/ajansari/ocpfBCALPatterns).
- **Not a build process.** Intake, review gates and sign-offs belong to whatever process you run, for example the
  OnlyCopilotFans BC Agentic Dev Framework. The Blueprint is what that process builds from.
- **Not a catalog.** It holds one design. A second Copilot shape (agents with tools, embeddings, chat) would be a
  separate Blueprint.
- **Not version-agnostic.** Every claim is pinned to BC 27.5. Re-verify before trusting it on another version
  (see [What is verified and how](#what-is-verified-and-how)).

## Where it comes from

The Blueprint is distilled from **General Journal Copilot** (publisher OnlyCopilotFans, v1.0.0.13), a per-tenant
extension that suggests the balancing G/L account for a General Journal document from a PromptDialog, with confidence
score, rationale, audit log and telemetry. The extension was built, reviewed, fixed and tested on a BC 27.5 SaaS
sandbox. Its bug-fix and review records are the evidence behind most entries in the false-assumptions table.

## What is inside

| Path | For whom | What |
|---|---|---|
| [`SKILL.md`](SKILL.md) | agents (also a good 10-minute read for humans) | The entry point: the seven claims agents get wrong, a 15-step procedure, non-negotiable rules, a done checklist. Formatted as a Claude Code skill. |
| [`references/01-architecture.md`](references/01-architecture.md) | both | Object inventory, namespaces, pipeline, permission sets, app.json. |
| [`references/02-capability-registration.md`](references/02-capability-registration.md) | both | Declare, register, re-register on upgrade, check at runtime, bind to each request. |
| [`references/03-microsoft-billed.md`](references/03-microsoft-billed.md) | both | Managed-resource authorization, deployment getters, SaaS-only behaviour, billing facts. |
| [`references/04-partner-billed.md`](references/04-partner-billed.md) | both | Own-key authorization, secret storage, key capture in a page, Test Connection. |
| [`references/05-prompt-dialog.md`](references/05-prompt-dialog.md) | both | PromptDialog page rules and the host-page action, including the Prompting-area correction. |
| [`references/06-ai-engine-context-parsing.md`](references/06-ai-engine-context-parsing.md) | both | Call sequence, error mapping, prompt, context JSON, token budget, tolerant parsing. |
| [`references/07-setup-wizard-telemetry-upgrade.md`](references/07-setup-wizard-telemetry-upgrade.md) | both | Setup card, assisted setup, wizard pattern, Feature Telemetry, install and upgrade, audit log. |
| [`references/08-api-reference-bc27.md`](references/08-api-reference-bc27.md) | both | System.AI signatures extracted from the 27.5 symbols, with obsolete markers, and how to re-extract them. |
| [`references/09-false-assumptions.md`](references/09-false-assumptions.md) | both | 31 wrong claims, the truth, and the evidence for each. |
| [`templates/`](templates/) | agents, then humans reviewing | Nine AL files with prefix `PFX` and IDs 50100-50199. Rename, renumber, fill the `<placeholders>`, compile. |
| [`CHANGELOG.md`](CHANGELOG.md) | both | What was verified when, and against which BC build. |

## How to use it as a human

1. Read [`SKILL.md`](SKILL.md) section 0 and [`references/09-false-assumptions.md`](references/09-false-assumptions.md)
   first. They are the shortest route to the things that cost the original project the most time.
2. Read [`references/01-architecture.md`](references/01-architecture.md) to see the shape of the solution, then the
   billing path you need (03 or 04) and the PromptDialog rules (05).
3. Use [`references/08-api-reference-bc27.md`](references/08-api-reference-bc27.md) as the lookup when the compiler and
   your memory disagree.
4. Start from [`templates/`](templates/) rather than from a blank file. Every template compiled with 0 errors against the
   27.5 symbols on the date in the header.
5. Before you ship, walk the done checklist in [`SKILL.md`](SKILL.md) section 3.

## How to use it with an agent

**Claude Code, project skill.** Copy this folder into the target project at `.claude/skills/obcf-bc-copilot-blueprint/`
(the file `SKILL.md` must be at that folder's root). The skill triggers on Copilot, Azure OpenAI, AOAI, PromptDialog,
Copilot Capability, Microsoft-billed, Partner-billed, and on an agent about to say that a BC Copilot capability is not
possible. For a user-wide install use `~/.claude/skills/obcf-bc-copilot-blueprint/`.

**Claude Code, one-off.** Paste `SKILL.md` and `references/09-false-assumptions.md` into the prompt, and tell the agent
where the folder is so it can open the rest on demand.

**GitHub Copilot and other agents.** Fetch this repository into the project (gitignored, with a `SNAPSHOT.json` recording
the commit, the same way the Patterns library is fetched) and add one line to `.github/copilot-instructions.md` or the
agent's system instructions:

> For any Business Central Copilot or Azure OpenAI work, read `<path>/obcfBCCopilotBlueprint/SKILL.md` and follow it. Do
> not claim a BC Copilot capability is impossible without checking `<path>/obcfBCCopilotBlueprint/references/09-false-assumptions.md`.

**With the OnlyCopilotFans BC Agentic Dev Framework.** Treat the Blueprint as a fetched input alongside the Standards
Guide and Patterns. The framework's FRD and TDD steps should cite it when the project includes a Copilot feature.

## What is verified and how

Three levels of evidence are used, and each claim says which one backs it:

| Level | Meaning | Examples |
|---|---|---|
| **Symbol-verified** | Extracted from `SymbolReference.json` inside the Microsoft symbol packages for BC 27.5. | Every procedure signature, parameter list, enum value and obsolete marker in `references/08`. |
| **Compiler-verified** | Probe objects or the templates themselves compiled with AL compiler 18.0 against those symbols. | "`addlast(Prompting)` compiles on page 39", "`Extensible = false` is required for PromptDialog (AL0223)", every template. |
| **Run-verified** | Observed in a BC 27.5 SaaS sandbox. | The Microsoft-billed path end to end; the "Copilot capability has not been set" error; the `Action::OK` close action; the `LookupOK` no-op bug; `OnQueryClosePage`. |

Not run-verified and marked as such in the text: a live Partner-billed call against a customer Azure OpenAI deployment,
and the client rendering of a `Prompting` action added by a page extension.

To re-verify on a newer BC: the `.app` symbol package is a ZIP with a 40-byte header. Strip it (`dd bs=1 skip=40`),
extract `SymbolReference.json`, and walk `Namespaces[*].Codeunits[*].Methods` recursively; objects live under namespaces,
not at the JSON root. The procedure is written out at the end of
[`references/08-api-reference-bc27.md`](references/08-api-reference-bc27.md).

## Related projects

- **[OnlyCopilotFans BC AL Development Standards](https://github.com/ajansari/ocpfBCALStandards)** - the governance
  rulebook. The Blueprint obeys it; where the two seem to disagree, the Standards win and the Blueprint has a bug.
- **[OCPF BC AL Patterns](https://github.com/ajansari/ocpfBCALPatterns)** - reusable, bug-derived AL patterns. Three
  lessons first recorded here (PromptDialog close action and post-close insert, SecretText capture and IsolatedStorage,
  the `Prompting` area typo) are candidates for that library.
- **OnlyCopilotFans BC Agentic Dev Framework** - the end-to-end agentic build process. It can consume the Blueprint as a
  fetched input; the Blueprint does not depend on it.
- **General Journal Copilot** (OnlyCopilotFans) - the extension this Blueprint was distilled from.

## Versioning

The Blueprint is pinned to a BC version. The header of this file and [`CHANGELOG.md`](CHANGELOG.md) say which build the
claims were verified against and when. Consumers should pin a release tag rather than track `main`.

Version numbers follow `major.minor.patch.build`:

- **major** - re-verified against a new BC major version, or a change to the reference design itself.
- **minor** - a new reference document, template, or false-assumption row.
- **patch** - a corrected claim, signature, or evidence citation.
- **build** - typos and formatting.

## License

MIT, copyright AJ Ansari and OnlyBCFans. See [LICENSE](LICENSE).
