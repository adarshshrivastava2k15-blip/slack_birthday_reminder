# Dynamically lock onto the exact folder path where this script file lives
$ScriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition
$CsvPath = Join-Path $ScriptFolder "birthdays_with_years.csv"

# Verify file existence before running
if (-not (Test-Path $CsvPath)) {
    Write-Error "The file '$CsvPath' could not be found in $ScriptFolder."
    exit
}

# Load the required Windows notification assembly
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

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

# Trigger system tray banner alerts if matches are found
if ($Celebrants) {
    $Notification = New-Object System.Windows.Forms.NotifyIcon
    $Notification.Icon = [System.Drawing.SystemIcons]::Information
    $Notification.Visible = $true

    foreach ($Person in $Celebrants) {
        $Title = "🎉 Birthday Alert Today!"
        $Message = "Don't forget to wish Happy Birthday to $($Person.'Full Name')!"
        
        # Display the alert banner for 10 seconds
        $Notification.ShowBalloonTip(10000, $Title, $Message, [System.Windows.Forms.ToolTipIcon]::Info)
        Write-Host $Message -ForegroundColor Green
        
        # Small delay to prevent overlapping banners if multiple matches exist
        Start-Sleep -Seconds 4
    }
    $Notification.Dispose()
} else {
    Write-Host "No birthdays found for today ($($Today.ToString('MM-dd')))." -ForegroundColor Yellow
}
