#!/bin/bash
# Shell script to open a website at a specific time
# Uses time from an NTP server (atomic clock)
# Compatible with Linux and macOS

# Function to retrieve accurate time from an NTP server
get_ntp_time() {
    local ntp_server="ptbtime1.ptb.de"
    
    # Try to get time from NTP server
    if command -v ntpdate &> /dev/null; then
        # Use ntpdate if available
        ntp_time=$(ntpdate -q "$ntp_server" 2>/dev/null | grep -oP '\d{2}:\d{2}:\d{2}' | head -1)
        if [ -n "$ntp_time" ]; then
            echo "$ntp_time"
            return 0
        fi
    fi
    
    # Fallback: use system date command
    date +%H:%M:%S
}

# Function to get current timestamp in seconds
get_timestamp() {
    date +%s
}

# Function to convert HH:MM:SS to seconds since midnight
time_to_seconds() {
    local time=$1
    local hours=$(echo "$time" | cut -d: -f1)
    local minutes=$(echo "$time" | cut -d: -f2)
    local seconds=$(echo "$time" | cut -d: -f3)
    
    # Remove leading zeros to avoid octal interpretation
    hours=$((10#$hours))
    minutes=$((10#$minutes))
    seconds=$((10#$seconds))
    
    echo $((hours * 3600 + minutes * 60 + seconds))
}

# Function to open URL in default browser
open_url() {
    local url=$1
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        open "$url"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command -v xdg-open &> /dev/null; then
            xdg-open "$url"
        elif command -v gnome-open &> /dev/null; then
            gnome-open "$url"
        elif command -v firefox &> /dev/null; then
            firefox "$url" &
        elif command -v google-chrome &> /dev/null; then
            google-chrome "$url" &
        else
            echo "Error: No browser found!"
            exit 1
        fi
    else
        echo "Error: Unsupported operating system!"
        exit 1
    fi
}

# Main script
echo "=== Open Website at Specific Time ==="
echo ""

# Request URL with validation
while true; do
    read -p "Please enter the URL (e.g. https://www.google.com): " url
    
    if [ -z "$url" ]; then
        echo "Error: URL cannot be empty!"
        echo ""
    else
        # Add https:// if not present
        if [[ ! "$url" =~ ^https?:// ]]; then
            url="https://$url"
        fi
        break
    fi
done

# Request target time with validation
while true; do
    echo ""
    echo "Please enter the time when the website should open"
    read -p "Format: HH:mm:ss (e.g. 14:30:45): " time_input
    
    # Validate time format
    if [[ "$time_input" =~ ^([0-1][0-9]|2[0-3]):([0-5][0-9]):([0-5][0-9])$ ]]; then
        break
    else
        echo "Error: Invalid time format!"
        echo "Please use the format HH:mm:ss (e.g. 14:30:45)"
        echo ""
    fi
done

# Get current time
echo ""
echo "Retrieving accurate time..."
current_time=$(get_ntp_time)
current_date=$(date +%Y-%m-%d)

echo "Current time (atomic clock): $current_time"
echo "Target time: $time_input"
echo "URL: $url"
echo ""

# Calculate target timestamp
current_seconds=$(time_to_seconds "$current_time")
target_seconds=$(time_to_seconds "$time_input")

# If target time is in the past, schedule for tomorrow
if [ $target_seconds -le $current_seconds ]; then
    target_date=$(date -d "$current_date + 1 day" +%Y-%m-%d 2>/dev/null || date -v+1d -j -f "%Y-%m-%d" "$current_date" +%Y-%m-%d 2>/dev/null)
    echo "The specified time is in the past for today."
    echo "Website will open tomorrow at $time_input."
else
    target_date=$current_date
fi

echo ""
echo "Waiting until $target_date $time_input..."
echo "Press Ctrl+C to cancel"
echo ""

# Wait until target time
while true; do
    current_time=$(get_ntp_time)
    current_seconds=$(time_to_seconds "$current_time")
    
    # Check if we've reached the target time
    current_full_date=$(date +%Y-%m-%d)
    if [ "$current_full_date" = "$target_date" ] && [ $current_seconds -ge $target_seconds ]; then
        break
    fi
    
    # Calculate remaining time
    if [ "$current_full_date" = "$target_date" ]; then
        remaining_seconds=$((target_seconds - current_seconds))
    else
        # Still waiting for target date
        remaining_seconds=$((86400 - current_seconds + target_seconds))
    fi
    
    if [ $remaining_seconds -lt 0 ]; then
        remaining_seconds=0
    fi
    
    hours=$((remaining_seconds / 3600))
    minutes=$(((remaining_seconds % 3600) / 60))
    seconds=$((remaining_seconds % 60))
    
    printf "\rTime remaining: %dh %dm %ds " $hours $minutes $seconds
    
    # Short pause to save CPU
    sleep 1
done

echo ""
echo ""
echo "Time reached! Opening website..."

# Open website in default browser
open_url "$url"

echo "Website has been opened!"
