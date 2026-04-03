#!/bin/sh

load_config() {
    ENABLED=$(uci -q get internet_led.main.enabled || echo "1")
    [ "$ENABLED" = "0" ] && return 1

    WAN_IF=$(uci -q get internet_led.main.wan_if || echo "wan")
    INTERVAL=$(uci -q get internet_led.main.interval || echo "5")
    FAIL_THRESHOLD=$(uci -q get internet_led.main.fail_threshold || echo "3")
    BLUE_LED=$(uci -q get internet_led.main.blue_led || echo "blue:network")
    YELLOW_LED=$(uci -q get internet_led.main.yellow_led || echo "yellow:network")
    TARGETS=$(uci -q get internet_led.main.diagnostic_targets || echo "8.8.8.8 1.1.1.1 9.9.9.9")

    # Ensure numeric values are valid
    case "$INTERVAL" in ''|*[!0-9]*) INTERVAL=5 ;; esac
    case "$FAIL_THRESHOLD" in ''|*[!0-9]*) FAIL_THRESHOLD=3 ;; esac
    [ "$INTERVAL" -lt 1 ] && INTERVAL=1
    [ "$FAIL_THRESHOLD" -lt 1 ] && FAIL_THRESHOLD=1

    # Targets may be space or comma separated
    TARGETS=$(echo "$TARGETS" | tr ',' ' ')
}

LOG_TAG="internet-led"
log() {
    logger -t "$LOG_TAG" "$*"
}

# ========= LED CONTROL =========
set_leds() {
    # $1 = blue brightness (0-255), $2 = yellow brightness
    [ -e "/sys/class/leds/$BLUE_LED/brightness" ] && echo "$1" > "/sys/class/leds/$BLUE_LED/brightness"
    [ -e "/sys/class/leds/$YELLOW_LED/brightness" ] && echo "$2" > "/sys/class/leds/$YELLOW_LED/brightness"
}

get_phy_dev() {
    local iface="$1" dev
    dev=$(uci -q get network."$iface".device 2>/dev/null)
    [ -z "$dev" ] && dev=$(uci -q get network."$iface".ifname 2>/dev/null)
    [ -z "$dev" ] && dev="$iface"

    # For bridges, get first member
    if [ -d "/sys/class/net/$dev/brif" ]; then
        dev=$(ls /sys/class/net/"$dev"/brif 2>/dev/null | head -n1)
    fi

    # Strip VLAN tag (e.g., eth0.1 -> eth0). This gives the parent physical interface.
    dev="${dev%%.*}"
    echo "$dev"
}

is_cable_plugged() {
    local iface="$1" dev

    dev=$(get_phy_dev "$iface")
    if [ -z "$dev" ]; then
        # Fallback: if we can't determine, assume plugged (avoid false negatives)
        return 0
    fi

    if [ -f "/sys/class/net/$dev/carrier" ]; then
        carrier=$(cat "/sys/class/net/$dev/carrier" 2>/dev/null)
        [ "$carrier" = "1" ] && return 0
        [ "$carrier" = "0" ] && return 1
    fi

    if [ -f "/sys/class/net/$dev/operstate" ]; then
        state=$(cat "/sys/class/net/$dev/operstate" 2>/dev/null)
        case "$state" in
            up|unknown) return 0 ;;
            down|dormant|lowerlayerdown) return 1 ;;
        esac
    fi

    [ -d "/sys/class/net/$dev" ] && return 0
    return 1
}

check_internet() {
    for server in $TARGETS; do
        ping -c 1 -W 2 "$server" >/dev/null 2>&1 && return 0
    done
    return 1
}

STATE_FILE="/tmp/internet_led_state"
last_state=""
consecutive_failures=0

# If script is called with "stop", just turn off LEDs and exit
if [ "$1" = "stop" ]; then
    load_config
    set_leds 0 0
    exit 0
fi

load_config || exit 0

while :; do
    if is_cable_plugged "$WAN_IF"; then
        if check_internet; then
            if [ "$last_state" != "ONLINE" ]; then
                log "Internet is UP"
                last_state="ONLINE"
            fi
            set_leds 255 0
            echo "ONLINE" > "$STATE_FILE"
            consecutive_failures=0
        else
            # Offline – use failure debounce
            consecutive_failures=$((consecutive_failures + 1))

            if [ "$consecutive_failures" -ge "$FAIL_THRESHOLD" ]; then
                if [ "$last_state" != "OFFLINE" ]; then
                    log "Internet is DOWN (after $consecutive_failures failures)"
                    last_state="OFFLINE"
                fi
                set_leds 0 255
                echo "OFFLINE" > "$STATE_FILE"
            else
                # Not yet enough failures – keep previous state (likely still online)
                # If we were already offline, we stay offline (just don't log)
                if [ "$last_state" = "OFFLINE" ]; then
                    set_leds 0 255
                    echo "OFFLINE" > "$STATE_FILE"
                else
                    set_leds 255 0
                    echo "ONLINE" > "$STATE_FILE"
                fi
            fi
        fi
    else
        if [ "$last_state" != "DISCONNECTED" ]; then
            log "Cable disconnected"
            last_state="DISCONNECTED"
        fi
        set_leds 0 0
        echo "DISCONNECTED" > "$STATE_FILE"
        consecutive_failures=0
    fi

    sleep "$INTERVAL"
done
