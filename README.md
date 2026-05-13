# Internet LED Indicator for Redmi AX6 (OpenWrt)

A LuCI app that controls your router's LEDs based on internet connectivity status. Designed for OpenWrt on the Redmi AX6 but works on any OpenWrt device with appropriate LED names.

[![Publish Release](https://github.com/brayan-kelly/redmi-ax6-internet-led/actions/workflows/publish-release.yml/badge.svg)](https://github.com/brayan-kelly/redmi-ax6-internet-led/actions/workflows/publish-release.yml)
[![Latest Release](https://img.shields.io/github/v/release/brayan-kelly/redmi-ax6-internet-led)](https://github.com/brayan-kelly/redmi-ax6-internet-led/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- Monitors WAN cable connection and internet reachability
- Lights a blue LED when internet is up, a yellow LED when down, and turns both off when the cable is disconnected
- Configurable check interval, failure threshold, and diagnostic targets
- Real‑time status dashboard in LuCI
- Configuration page to select WAN interface, LED names, and other settings
- Preserves configuration as package-managed config

## Installation

### Install from OpenWrt Package

Tagged GitHub releases include an OpenWrt `.apk` package built for:

- OpenWrt 25.12.3
- `qualcommax/ipq807x`
- `aarch64_cortex-a53`

Copy the `.apk` to the router and install it:

```sh
scp luci-app-internet-led-*.apk root@router:/tmp/
ssh root@router
apk add --allow-untrusted /tmp/luci-app-internet-led-*.apk
```

## Configuration

After installation, navigate to LuCI → Status → Internet LED to view the dashboard and adjust settings.

Available options:

| Option | Description | Default |
|--------|-------------|---------|
| Enable | Turn the LED indicator on/off | Enabled |
| WAN Interface | Logical network interface to monitor | wan |
| Check Interval (seconds) | Time between connectivity checks | 5 |
| Failure Threshold | Consecutive failures before declaring internet down | 3 |
| Blue LED | Name of the LED to light when internet is up | blue:network |
| Yellow LED | Name of the LED to light when internet is down | yellow:network |
| Diagnostic Targets | Space‑separated list of IPs/hosts to ping for verification | 8.8.8.8 1.1.1.1 9.9.9.9 |

### How it works

- The script first checks if the WAN interface has a physical cable connected.
- If the cable is plugged, it pings the configured diagnostic targets (using a fallback list) to determine internet reachability.
- After `failure_threshold` consecutive failures, it declares the internet as DOWN and lights the yellow LED.
- When connectivity is restored, it lights the blue LED.
- If the cable is disconnected, both LEDs are turned off.

## Package Persistence

The package marks the UCI configuration as a managed config file:

- /etc/config/internet-led – UCI configuration

Package-owned files are restored by reinstalling the `.apk`; local configuration is preserved by the package manager.

## File Structure
```
Files/
├── etc/
│ ├── config/
│ │ └── internet-led # UCI config
│ ├── init.d/
│ │ └── internet-led # Init script
├── usr/
│ ├── bin/
│ │ └── internet-led.sh # Core monitoring daemon
│ ├── libexec/
│ │ └── rpcd/
│ │ ├── internet-led-lists # RPC to list available LEDs
│ │ └── internet-led-state # RPC to report current status
│ └── share/
│ ├── rpcd/
│ │ └── acl.d/
│ │ └── luci-app-internet-led.json
│ └── luci/
│ └── menu.d/
│ └── luci-app-internet-led.json
└── www/
└── luci-static/
└── resources/
└── view/
└── internet-led/
├── status.js
└── config.js
```

## Uninstallation

Remove the package with:

```sh
apk del luci-app-internet-led
```

This stops and disables the service through the package removal hooks.

## License

MIT License – see the LICENSE file for details.
