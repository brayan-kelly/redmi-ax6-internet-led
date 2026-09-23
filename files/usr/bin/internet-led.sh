#!/bin/sh

load_config() {
    ENABLED=$(uci -q get internet-led.main.enabled || echo "1")
    WAN_IF=$(uci -q get internet-led.main.wan_if || echo "wan")
    INTERVAL=$(uci -q get internet-led.main.interval || echo "5")
    FAIL_THRESHOLD=$(uci -q get internet-led.main.fail_threshold || echo "3")
    BLUE_LED=$(uci -q get internet-led.main.blue_led || echo "blue:network")
    YELLOW_LED=$(uci -q get internet-led.main.yellow_led || echo "yellow:network")
    TARGETS=$(uci -q get internet-led.main.diagnostic_targets || echo "8.8.8.8 1.1.1.1 9.9.9.9")

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

validate_led_names() {
    local led

    for led in "$BLUE_LED" "$YELLOW_LED"; do
        case "$led" in
            ''|.|..|*/*|*[!A-Za-z0-9_.:-]*)
                log "Ignoring invalid LED name"
                if [ "$led" = "$BLUE_LED" ]; then
                    BLUE_LED=""
                fi
                if [ "$led" = "$YELLOW_LED" ]; then
                    YELLOW_LED=""
                fi
                ;;
            *)
                if [ ! -d "/sys/class/leds/$led" ] || [ ! -e "/sys/class/leds/$led/brightness" ]; then
                    log "Ignoring unavailable LED: $led"
                    [ "$led" = "$BLUE_LED" ] && BLUE_LED=""
                    [ "$led" = "$YELLOW_LED" ] && YELLOW_LED=""
                fi
                ;;
        esac
    done
}

# ========= LED CONTROL =========
set_leds() {
    # $1 = online LED brightness (0-255), $2 = offline LED brightness
    if [ "$BLUE_LED" = "$YELLOW_LED" ]; then
        [ -e "/sys/class/leds/$BLUE_LED/brightness" ] && echo "$1" > "/sys/class/leds/$BLUE_LED/brightness"
        return
    fi

    [ -e "/sys/class/leds/$BLUE_LED/brightness" ] && echo "$1" > "/sys/class/leds/$BLUE_LED/brightness"
    [ -e "/sys/class/leds/$YELLOW_LED/brightness" ] && echo "$2" > "/sys/class/leds/$YELLOW_LED/brightness"
}

get_phy_dev() {
    local iface="$1" status dev l3_dev

    # netifd knows the active device behind logical interfaces such as WAN,
    # bridges, VLANs, and PPP. Prefer its aggregate device so bridge carrier
    # reflects the bridge rather than an arbitrary member port.
    status=$(ubus call "network.interface.$iface" status 2>/dev/null)
    dev=$(printf '%s' "$status" | jsonfilter -e '@.device' 2>/dev/null)
    l3_dev=$(printf '%s' "$status" | jsonfilter -e '@.l3_device' 2>/dev/null)
    [ -z "$dev" ] && dev="$l3_dev"

    # Fall back for inactive interfaces without a netifd status device.
    [ -z "$dev" ] && dev=$(uci -q get "network.$iface.device" 2>/dev/null)
    [ -z "$dev" ] && dev=$(uci -q get "network.$iface.ifname" 2>/dev/null)
    [ -z "$dev" ] && dev="$iface"
    echo "$dev"
}

get_l3_dev() {
    local iface="$1" status dev

    status=$(ubus call "network.interface.$iface" status 2>/dev/null)
    dev=$(printf '%s' "$status" | jsonfilter -e '@.l3_device' 2>/dev/null)
    [ -z "$dev" ] && dev=$(printf '%s' "$status" | jsonfilter -e '@.device' 2>/dev/null)
    echo "$dev"
}

is_cable_plugged() {
    local iface="$1" dev carrier state

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

take_over_led_triggers() {
    local led trigger_file
    for led in "$BLUE_LED" "$YELLOW_LED"; do
        [ -n "$led" ] || continue
        trigger_file="/sys/class/leds/$led/trigger"
        [ -w "$trigger_file" ] && echo none > "$trigger_file"
    done
}

restore_led_triggers() {
    # The stock OpenWrt LED init script reapplies the System -> LED UCI
    # configuration, including its configured trigger and device settings.
    [ -x /etc/init.d/led ] && /etc/init.d/led reload >/dev/null 2>&1
}

check_internet() {
    local dev server

    dev=$(get_l3_dev "$WAN_IF")
    [ -n "$dev" ] || return 1

    for server in $TARGETS; do
        ping -I "$dev" -c 1 -W 2 "$server" >/dev/null 2>&1 && return 0
    done
    return 1
}

STATE_FILE="/tmp/internet_led_state"
last_state=""
consecutive_failures=0

# If script is called with "stop", just turn off LEDs and exit
if [ "$1" = "stop" ]; then
    load_config
    validate_led_names
    set_leds 0 0
    restore_led_triggers
    exit 0
fi

load_config
[ "$ENABLED" = "0" ] && exit 0
validate_led_names
take_over_led_triggers

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
