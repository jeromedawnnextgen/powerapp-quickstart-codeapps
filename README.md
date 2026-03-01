# powerapp-quickstart

One-command wizard to scaffold, configure, and deploy a new Power Apps Code App.

## Usage

Open PowerShell in this folder and run:

```powershell
.\new-codeapp.ps1
```

The script will walk you through:

1. **Prerequisite check** — Node.js and PAC CLI
2. **App config** — folder name, display name, environment ID
3. **Scaffold** — pulls the official Microsoft Vite template
4. **npm install** — installs all dependencies
5. **Auth** — checks for an existing PAC auth profile, runs device code flow if needed
6. **Environment select** — targets your Power Platform environment
7. **pac code init** — registers the app (creates `power.config.json`)
8. **Data source** *(optional)* — adds Dataverse connector + auto-patches the generated TypeScript bug
9. **Done** — opens VS Code and/or starts the dev server

## Requirements

- Windows (PowerShell 5.1+)
- [Node.js LTS](https://nodejs.org)
- PAC CLI — via the [VS Code Power Platform Tools extension](https://marketplace.visualstudio.com/items?itemName=microsoft-IsvExpTools.powerplatform-vscode) or `winget install Microsoft.PowerPlatformCLI`
- Power Platform environment with Code Apps enabled
- Power Apps Premium license

## Notes

- Default environment ID is pre-set to Jerome Dawn's Environment. Override it at the prompt.
- The script auto-fixes the `MSCRM.IncludeMipSensitivityLabel` bug in the generated Dataverse service file (known Microsoft issue that breaks TypeScript builds).
- Run the script from whichever directory you want the new app folder created in.
