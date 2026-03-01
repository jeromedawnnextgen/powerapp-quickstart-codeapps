# powerapp-quickstart

A fully automated, one-command PowerShell wizard that scaffolds, configures, authenticates, deploys, and publishes a new **Power Apps Code App** to your Power Platform environment — and automatically pushes it to GitHub.

## What It Does

This script completely automates the Power Apps Code App setup process:

1. **Prerequisite validation** — checks for Node.js and PAC CLI
2. **Project scaffolding** — pulls the official Microsoft Vite template
3. **Dependency installation** — runs `npm install` 
4. **Power Platform authentication** — verifies or establishes PAC auth
5. **Environment selection** — targets your specified Power Platform environment
6. **App registration** — registers the new app with `pac code init`
7. **Cloud deployment** — pushes the app to Power Platform with `pac code push`
8. **Solution management** — adds the app to an existing or new solution (optional)
9. **Dataverse integration** — optionally adds a Dataverse data source connector
10. **GitHub integration** — automatically creates a GitHub repo and pushes all code
11. **Development setup** — opens VS Code and starts the local dev server

When complete, your new Power Apps Code App will be **live in Power Platform**, **published to GitHub**, and **ready to develop locally**.

## Requirements

### System & Tools
- **Windows** (PowerShell 5.1 or later)
- **[Node.js LTS](https://nodejs.org)** — download and install
- **PAC CLI** (Power Platform CLI) — install via one of:
  - `winget install Microsoft.PowerPlatformCLI`
  - [VS Code Power Platform Tools extension](https://marketplace.visualstudio.com/items?itemName=microsoft-IsvExpTools.powerplatform-vscode)
  - Manual installation if you have the path (set `pacCliPath` in config.json)
- **[Git](https://git-scm.com)** — for local version control
- **[GitHub CLI](https://cli.github.com)** — for automatic GitHub repo creation

### Power Platform
- A **Power Platform environment** with Code Apps enabled
- A **Power Apps Premium license** (required for Code Apps)
- A **GitHub account** (for automatic repository creation)

## Initial Setup

### 1. Prepare Your Configuration
The script reads defaults from `config.json`. Copy the example to get started:

```powershell
Copy-Item config.example.json config.json
```

### 2. Edit `config.json`
Open `config.json` and customize these values:

```json
{
  "_readme": "Your personal config — gitignored, never committed.",

  "outputDirectory": "C:\\path\\where\\apps\\created",  // Where new app folders go
  "environmentId": "YOUR-ENVIRONMENT-ID",              // Your Power Platform environment ID
  "connectionId": "YOUR-CONNECTION-ID",                // (Optional) Pre-filled Dataverse connection
  "pacCliPath": "",                                    // Leave empty if PAC is in PATH
  "autoAddDataSource": false,                          // Auto-add Dataverse (requires connectionId)
  "autoOpenVSCode": true,                              // Auto-open VS Code after completion
  "autoStartDev": false,                               // Auto-start npm dev server
  "githubUsername": "your-github-username"             // For automatic GitHub repo creation
}
```

#### Finding Your Environment ID
In the **Power Platform admin center** ([admin.powerplatform.com](https://admin.powerplatform.com)):
1. Go to **Environments**
2. Select your environment
3. Copy the **Environment ID** from the URL or details panel

#### Finding Your Connection ID (Optional)
Run this in PowerShell:
```powershell
pac connection list
```
Look for your Dataverse connection and copy its **Connection Reference ID**.

#### GitHub Setup
Run this once to authenticate with GitHub:
```powershell
gh auth login
```
Then add your GitHub username to `config.json`.

### 3. Authenticate with Power Platform
First-time setup:
```powershell
gh auth login
pac auth create --deviceCode
```

## Running the Script

Open PowerShell in this directory and run:

```powershell
.\new-codeapp.ps1
```

### Interactive Prompts
The script will ask you:
- **App name** — becomes the folder name (e.g., "HR Resource Management")
- **Display name** — shown in Power Apps (defaults to app name)
- **Environment ID** — defaults to value in config.json
- **Add to solution?** — (y/N) yes to add to existing or new solution
- **Solution name** — if yes, provide the solution name

### What Happens Automatically
Once you provide these values, the script:
1. Creates the project folder and scaffolds from the Microsoft template
2. Installs all npm dependencies
3. Authenticates with Power Platform (if needed)
4. Registers the app and creates `power.config.json`
5. **Deploys** the app to your environment (it now shows up in Power Apps!)
6. Adds it to your specified solution (creating the solution if it doesn't exist)
7. Initializes a local Git repository
8. **Creates a GitHub repository** and pushes all code
9. Opens the project in VS Code
10. Starts the local development server on `localhost:5173` (or next available port)

## Development Workflow

After the script completes, you have three ways to work:

### Local Development
Your app runs locally at `http://localhost:5173`:
```powershell
npm run dev
```

### Build for Production
```powershell
npm run build
```
Creates optimized production files in the `dist/` folder.

### Deploy to Power Platform
Push your latest changes to Power Platform:
```powershell
pac code push
```

## Troubleshooting

### "PAC CLI not found"
Install one of:
- `winget install Microsoft.PowerPlatformCLI`
- VS Code Power Platform Tools extension
- Or set the full path in `config.json` under `pacCliPath`

### "PAC code push failed"
- Ensure you're authenticated: `pac auth status`
- Verify your environment ID is correct in `config.json`
- Try manually: `cd your-app-folder && pac code push`

### "GitHub repo creation failed"
- Ensure GitHub CLI is authenticated: `gh auth status`
- Your GitHub username must be in `config.json`
- The repo name may already exist on your account

### "Service file not found" (Dataverse)
If you see the MSCRM TypeScript bug warning:
1. Go to `src/generated/services/MicrosoftDataverseService.ts`
2. Find all instances of `MSCRM.IncludeMipSensitivityLabel`
3. Replace with `MSCRM_IncludeMipSensitivityLabel`
4. Save and run `npm run build` again

### Port Already in Use (dev server)
The dev server automatically tries the next available port if 5173 is taken. Check the terminal output for the actual URL.

## File Structure

After running the script, you'll have:

```
your-app-name/
├── src/
│   ├── App.tsx              // Main app component
│   ├── index.css            // Styling
│   └── generated/           // Auto-generated Dataverse service (if added)
├── power.config.json        // Power Platform configuration
├── vite.config.ts           // Vite build config
├── package.json             // npm dependencies
├── tsconfig.json            // TypeScript config
├── .git/                    // Local git repository
└── README.md                // Your new app's documentation
```

## Notes & Known Issues

- **Default Environment ID**: The example config.json has Jerome Dawn's environment ID — you must change this to your own
- **MSCRM Bug**: The script auto-fixes the `MSCRM.IncludeMipSensitivityLabel` bug in Dataverse service files when adding a data source
- **Script Location**: The script creates apps in a directory based on `outputDirectory` in config.json, or the parent of the script's directory if not set
- **GitHub Repository**: Created as a **public repository** — change visibility in GitHub if needed
- **Git Configuration**: The script uses your global Git user name and email — set these with:
  ```powershell
  git config --global user.name "Your Name"
  git config --global user.email "your.email@example.com"
  ```

## Advanced Config Options

All options in `config.json` are optional and have sensible defaults:

| Option | Type | Default | Purpose |
|--------|------|---------|---------|
| `outputDirectory` | string | Parent of script | Where to create new app folders |
| `environmentId` | string | Required | Your Power Platform environment ID |
| `connectionId` | string | Empty | Pre-filled Dataverse connection ID |
| `pacCliPath` | string | Auto-detect | Full path to pac.exe if not in PATH |
| `autoAddDataSource` | boolean | false | Skip Dataverse prompt if true (requires `connectionId`) |
| `autoOpenVSCode` | boolean | true | Automatically open the app in VS Code |
| `autoStartDev` | boolean | false | Automatically start dev server after completion |
| `githubUsername` | string | Required for GitHub | Your GitHub username for repo creation |

## Support & Customization

This script is a foundation — feel free to customize it for your team's needs. Common modifications:

- Add custom npm scripts to `package.json`
- Extend the scaffolding with additional templates
- Add post-deployment hooks (e.g., Teams channel notifications)
- Integrate with your CI/CD pipeline

---

**Happy building! 🚀**
