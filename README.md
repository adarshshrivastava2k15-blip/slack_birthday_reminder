# Automated Birthday Notification System (Azure DevOps + Slack)

This project automates birthday celebrations by parsing a employee dataset CSV file and broadcasting daily greeting notifications to a designated Slack channel via an **Azure DevOps Pipeline**. It replaces traditional UI-based local tray balloons with an enterprise-ready cloud automation workflow.

---

## 🛠️ Implementation Steps

### Step 1: Update Your PowerShell Script (`get_birthdays.ps1`)
Cloud-hosted pipeline agents operate without a graphical user interface (GUI), meaning local Windows tray notifications will fail. Replace your local script file content with the optimized version below. This parses the local workspace dataset and securely maps outputs to a web target using environment variables.

```powershell
# Dynamically lock onto the exact folder path where this script file lives
$ScriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition
$CsvPath = Join-Path $ScriptFolder "birthdays.csv" # Ensure this matches your repository file name

# Extract the secret webhook URL passed securely from Azure DevOps
$SlackUrl = $env:SLACK_WEBHOOK_URL
if (-not $SlackUrl) {
    Write-Error "CRITICAL: Slack Webhook URL environment variable is missing."
    exit 1
}

# Verify file existence before running
if (-not (Test-Path $CsvPath)) {
    Write-Error "The file '$CsvPath' could not be found in $ScriptFolder."
    exit 1
}

# Import the dataset
$Birthdays = Import-Csv -Path $CsvPath
$Today = Get-Date

# Filter celebrants by matching numeric Month and Day against M/D/YYYY data
$Celebrants = $Birthdays | Where-Object {
    try {
        $BirthDate = [DateTime]$_.'Birth Date'
        $BirthDate.Month -eq $Today.Month -and $BirthDate.Day -eq $Today.Day
    } catch {
        $false
    }
}

# Format and send payload to Slack if matches are found
if ($Celebrants) {
    # Extract just the full name property
    $Names = $Celebrants | ForEach-Object { $_.'Full Name' }
    $NamesString = $Names -join ", "

    # Construct the JSON message structure for Slack
    $Payload = @{
        text = "🎉 *Happy Birthday* to: $NamesString! 🎂 Have a fantastic day!"
    } | ConvertTo-Json -Depth 5 -Compress

    # Send POST request payload to Slack channel
    try {
        $Response = Invoke-RestMethod -Uri $SlackUrl -Method Post -Body $Payload -ContentType "application/json; charset=utf-8"
        Write-Host "Notification successfully posted to Slack for: $NamesString" -ForegroundColor Green
    } catch {
        Write-Error "Failed to post message to Slack channel. Details: $_"
        exit 1
    }
} else {
    Write-Host "No birthdays found for today ($($Today.ToString('dd-MMM')))." -ForegroundColor Yellow
}
```

### Step 2: Establish Your Slack Webhook Integration
You must generate an API endpoint token to grant Azure DevOps pipeline permission to drop messages into your digital workspace.
1. Navigate to the [Slack API Console](https://api.slack.com/apps).
2. Select **Create New App** $
ightarrow$ Choose **From scratch**. 
3. Name the application uniquely (e.g., `Birthday Notification Bot`).
4. Locate the **Incoming Webhooks** menu block inside the left features sidebar panel.
5. Toggle **Activate Incoming Webhooks** to **On**.
6. Select **Add New Webhook to Workspace** at the bottom of the dashboard.
7. Select your target destination Slack channel and click **Allow**.
8. Copy the newly generated **Webhook URL** string metadata.

### Step 3: Safeguard the Slack URL in Azure DevOps
Mask your production webhook string endpoint inside an encrypted pipeline variable group to hide it from public repository eyes.
1. Log into your **Azure DevOps Project**, then navigate to **Pipelines** $
ightarrow$ **Library**.
2. Click **+ Variable group** and label it exactly `SlackSecrets`.
3. Create a property key row named `SLACK_WEBHOOK_URL`.
4. Paste your copied Slack Webhook URL into the **Value** entry input block.
5. Click the **Padlock icon** on the right side of the row to permanently convert it to a **Secret variable**.
6. Save your library configuration.

### Step 4: Write the Declarative Pipeline Configuration
Ensure your worker script (`get_birthdays.ps1`) and your comma-separated dataset (`birthdays.csv`) are committed to the same repository directory tree. Create a configuration file named `azure-pipelines.yml` in the root folder of your project repository:

```yaml
schedules:
- cron: "0 8 * * *" # Triggers automated run every single day at 08:00 AM UTC
  displayName: "Daily Automated Birthday Slack Sync"
  branches:
    include:
    - main
  always: true # Runs on schedule even if no manual commits are pushed to main

trigger: none # Stops pipeline from firing on regular code pushes
pr: none      # Stops pipeline from firing on pull request revisions

pool:
  vmImage: 'windows-latest' # Utilizes native Windows platform execution for optimal PowerShell integration

variables:
- group: SlackSecrets # Imports and binds the hidden variable group context established in Step 3

steps:
- task: PowerShell@2
  displayName: 'Parse CSV Records and Push Slack Notifications'
  inputs:
    targetType: 'filePath'
    filePath: '$(Build.SourcesDirectory)/get_birthdays.ps1' # Fully qualified system source path mapping
    errorActionPreference: 'stop'
  env:
    SLACK_WEBHOOK_URL: $(SLACK_WEBHOOK_URL) # Inject secret variable explicitly into environment scope
```

### Step 5: Save and Execute the Pipeline Workflow
1. Navigate to **Pipelines** $
ightarrow$ **Pipelines** $
ightarrow$ **New Pipeline** inside the Azure DevOps dashboard interface.
2. Select your version control storage option (e.g., **Azure Repos Git**) and target your codebase repository.
3. Choose **Existing Azure Pipelines YAML file** and match the path mapping to your `/azure-pipelines.yml` file.
4. Select **Run** to execute a manual initial validation run.
5. Review the execution logs. If there are names matching the current day's month and day index in the CSV, a Slack message will hit your channel instantly!

---

## 🗃️ Data Format Expectation
For the script to parse records successfully, ensure your `birthdays.csv` file uses headers matching `Full Name` and `Birth Date`. 

**Example format:**
```csv
Full Name,Birth Date
Jane Doe,11/24/1993
John Smith,09/03/1988
```