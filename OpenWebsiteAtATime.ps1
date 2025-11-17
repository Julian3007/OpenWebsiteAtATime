# PowerShell Script to open a website at a specific time
# Uses time from an NTP server (atomic clock)

# UTF-8 Encoding for special characters
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Function to retrieve accurate time from an NTP server
# Function to retrieve accurate time from an NTP server
function Get-NTPTime {
    param (
        [string]$Server = "ptbtime1.ptb.de"  # PTB Braunschweig (Atomuhr Deutschland)
    )
    
    try {
        # Prepare NTP request
        $NTPData = New-Object byte[] 48
        $NTPData[0] = 0x1B  # NTP Request Header
        
        # Create socket and send request
        $Socket = New-Object System.Net.Sockets.Socket([System.Net.Sockets.AddressFamily]::InterNetwork, 
                                                        [System.Net.Sockets.SocketType]::Dgram, 
                                                        [System.Net.Sockets.ProtocolType]::Udp)
        $Socket.Connect($Server, 123)
        $Socket.ReceiveTimeout = 3000
        $Socket.Send($NTPData) | Out-Null
        $Socket.Receive($NTPData) | Out-Null
        $Socket.Close()
        
        # Extract NTP time (bytes 40-43)
        [byte[]]$IntPart = $NTPData[40..43]
        [Array]::Reverse($IntPart)
        $IntPartValue = [BitConverter]::ToUInt32($IntPart, 0)
        
        # Convert NTP time to DateTime
        $NTPEpoch = New-Object DateTime(1900, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
        $NTPTime = $NTPEpoch.AddSeconds($IntPartValue)
        
        # Convert to local time
        return $NTPTime.ToLocalTime()
    }
    catch {
        Write-Warning "Error retrieving NTP time: $_"
        Write-Warning "Using local system time as fallback."
        return Get-Date
    }
}

# User input
Write-Host "=== Open Website at Specific Time ===" -ForegroundColor Cyan
Write-Host ""

# Request URL with retry on error
do {
    $urlValid = $true
    $url = Read-Host "Please enter the URL (e.g. https://www.google.com)"
    
    if ([string]::IsNullOrWhiteSpace($url)) {
        Write-Host "Error: URL cannot be empty!" -ForegroundColor Red
        Write-Host ""
        $urlValid = $false
    }
    else {
        if (-not $url.StartsWith("http")) {
            $url = "https://$url"
        }
    }
} while (-not $urlValid)

# Request target time with retry on error
do {
    $timeValid = $true
    Write-Host ""
    Write-Host "Please enter the time when the website should open"
    $timeInput = Read-Host "Format: HH:mm:ss (e.g. 14:30:45)"

    try {
        # Parse time
        $targetTime = [DateTime]::ParseExact($timeInput, "HH:mm:ss", $null)
    }
    catch {
        Write-Host "Error: Invalid time format!" -ForegroundColor Red
        Write-Host "Please use the format HH:mm:ss (e.g. 14:30:45)" -ForegroundColor Yellow
        Write-Host ""
        $timeValid = $false
    }
} while (-not $timeValid)

# Get current time from atomic clock
Write-Host ""
Write-Host "Retrieving accurate time from NTP server..." -ForegroundColor Yellow
$currentTime = Get-NTPTime

Write-Host "Current time (atomic clock): $($currentTime.ToString('HH:mm:ss'))" -ForegroundColor Green
Write-Host "Target time: $($timeInput)" -ForegroundColor Green
Write-Host "URL: $url" -ForegroundColor Green
Write-Host ""

# Set target time for today
$targetDateTime = Get-Date -Year $currentTime.Year -Month $currentTime.Month -Day $currentTime.Day `
                           -Hour $targetTime.Hour -Minute $targetTime.Minute -Second $targetTime.Second

# If target time is already past, schedule for tomorrow
if ($targetDateTime -le $currentTime) {
    $targetDateTime = $targetDateTime.AddDays(1)
    Write-Host "The specified time is in the past for today." -ForegroundColor Yellow
    Write-Host "Website will open tomorrow at $timeInput." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Waiting until $($targetDateTime.ToString('dd.MM.yyyy HH:mm:ss'))..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to cancel" -ForegroundColor Gray
Write-Host ""

# Wait until target time
while ($true) {
    $currentTime = Get-NTPTime
    $timeRemaining = $targetDateTime - $currentTime
    
    if ($timeRemaining.TotalSeconds -le 0) {
        break
    }
    
    # Display remaining time
    $hours = [math]::Floor($timeRemaining.TotalHours)
    $minutes = $timeRemaining.Minutes
    $seconds = $timeRemaining.Seconds
    
    Write-Host "`rTime remaining: ${hours}h ${minutes}m ${seconds}s " -NoNewline -ForegroundColor Yellow
    
    # Short pause to save CPU
    Start-Sleep -Seconds 1
}

Write-Host ""
Write-Host ""
Write-Host "Time reached! Opening website..." -ForegroundColor Green

# Open website in default browser (new tab)
Start-Process $url

Write-Host "Website has been opened!" -ForegroundColor Green
