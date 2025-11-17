#!/bin/zsh
# Zsh script optimized for macOS to open a website at a specific time
# Uses time from an NTP server (atomic clock)

# Function to retrieve accurate time from an NTP server
get_ntp_time() {
    local ntp_server="time.apple.com"
    
    # Try to get time using sntp (pre-installed on macOS)
    if command -v sntp &> /dev/null; then
        ntp_time=$(sntp -t 3 "$ntp_server" 2>/dev/null | grep -oE '\d{2}:\d{2}:\d{2}' | head -1)
        if [[ -n "$ntp_time" ]]; then
            echo "$ntp_time"
            return 0
        fi
    fi
    
    # Fallback: use system date command
    date +%H:%M:%S
}

# Function to convert HH:MM:SS to seconds since midnight
time_to_seconds() {
    local time=$1
    local hours=$(echo "$time" | cut -d: -f1)
    local minutes=$(echo "$time" | cut -d: -f2)
    local seconds=$(echo "$time" | cut -d: -f3)
    
    # Remove leading zeros
    hours=$((10#$hours))
    minutes=$((10#$minutes))
    seconds=$((10#$seconds))
    
    echo $((hours * 3600 + minutes * 60 + seconds))
}

# Main script
print -P "%F{cyan}=== Open Website at Specific Time ===%f"
print ""

# Request URL with validation
while true; do
    read "url?Please enter the URL (e.g. https://www.google.com): "
    
    if [[ -z "$url" ]]; then
        print -P "%F{red}Error: URL cannot be empty!%f"
        print ""
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
    print ""
    print "Please enter the time when the website should open"
    read "time_input?Format: HH:mm:ss (e.g. 14:30:45): "
    
    # Validate time format
    if [[ "$time_input" =~ ^([0-1][0-9]|2[0-3]):([0-5][0-9]):([0-5][0-9])$ ]]; then
        break
    else
        print -P "%F{red}Error: Invalid time format!%f"
        print -P "%F{yellow}Please use the format HH:mm:ss (e.g. 14:30:45)%f"
        print ""
    fi
done

# Get current time
print ""
print -P "%F{yellow}Retrieving accurate time...%f"
current_time=$(get_ntp_time)
current_date=$(date +%Y-%m-%d)

print -P "%F{green}Current time (atomic clock): $current_time%f"
print -P "%F{green}Target time: $time_input%f"
print -P "%F{green}URL: $url%f"
print ""

# Calculate target timestamp
current_seconds=$(time_to_seconds "$current_time")
target_seconds=$(time_to_seconds "$time_input")

# If target time is in the past, schedule for tomorrow
if (( target_seconds <= current_seconds )); then
    target_date=$(date -v+1d -j -f "%Y-%m-%d" "$current_date" +%Y-%m-%d 2>/dev/null)
    print -P "%F{yellow}The specified time is in the past for today.%f"
    print -P "%F{yellow}Website will open tomorrow at $time_input.%f"
else
    target_date=$current_date
fi

print ""
print -P "%F{cyan}Waiting until $target_date $time_input...%f"
print -P "%F{242}Press Ctrl+C to cancel%f"
print ""

# Wait until target time
while true; do
    current_time=$(get_ntp_time)
    current_seconds=$(time_to_seconds "$current_time")
    
    # Check if we've reached the target time
    current_full_date=$(date +%Y-%m-%d)
    if [[ "$current_full_date" = "$target_date" ]] && (( current_seconds >= target_seconds )); then
        break
    fi
    
    # Calculate remaining time
    if [[ "$current_full_date" = "$target_date" ]]; then
        remaining_seconds=$((target_seconds - current_seconds))
    else
        # Still waiting for target date
        remaining_seconds=$((86400 - current_seconds + target_seconds))
    fi
    
    if (( remaining_seconds < 0 )); then
        remaining_seconds=0
    fi
    
    hours=$((remaining_seconds / 3600))
    minutes=$(((remaining_seconds % 3600) / 60))
    seconds=$((remaining_seconds % 60))
    
    print -nP "\r%F{yellow}Time remaining: ${hours}h ${minutes}m ${seconds}s %f"
    
    # Short pause to save CPU
    sleep 1
done

print ""
print ""
print -P "%F{green}Time reached! Opening website...%f"

# Open website in default browser (macOS)
open "$url"

print -P "%F{green}Website has been opened!%f"
