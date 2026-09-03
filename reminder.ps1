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
