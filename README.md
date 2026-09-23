# Internet LED Indicator for OpenWrt

A LuCI app that controls router LEDs based on internet connectivity. It targets OpenWrt 25.12.x and is validated on the Redmi AX6 (`qualcommax/ipq807x`). Other devices may work when they expose writable LED brightness and trigger controls and a netifd WAN interface.

[![Publish Release](https://github.com/brayan-kelly/redmi-ax6-internet-led/actions/workflows/publish-release.yml/badge.svg)](https://github.com/brayan-kelly/redmi-ax6-internet-led/actions/workflows/publish-release.yml)
[![Latest Release](https://img.shields.io/github/v/release/brayan-kelly/redmi-ax6-internet-led)](https://github.com/brayan-kelly/redmi-ax6-internet-led/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- Monitors WAN cable connection and internet reachability
- Uses the selected LED trigger while the service runs and reapplies the router's System → LED configuration when stopped
- Lights the online LED when internet is up, the offline LED when down, and turns LEDs off when disconnected
- Configurable check interval, failure threshold, and diagnostic targets
- Real‑time status dashboard in LuCI
- Configuration page to select WAN interface, LED names, and other settings
- Preserves configuration as package-managed config

## Installation

### Install from OpenWrt Package

Tagged GitHub releases include an OpenWrt `.apk` package built with the OpenWrt 25.12.5 SDK for:

- `qualcommax/ipq807x`
- `aarch64_cortex-a53`

The repository feed is signed and hosted on GitHub Pages. Bootstrap the public key once, then add the feed and install without `--allow-untrusted`:

```sh
FEED_BASE="https://brayan-kelly.github.io/redmi-ax6-internet-led/feed"
wget "$FEED_BASE/internet-led.pub" -O /tmp/internet-led.pub
echo 'e5f197a71d2255e5e06e4ad08ed522822cd32b52f012b7e33e9751735de495a5  /tmp/internet-led.pub' | sha256sum -c -
install -m 0644 /tmp/internet-led.pub /etc/apk/keys/internet-led.pub
echo "$FEED_BASE/aarch64_cortex-a53" >> /etc/apk/repositories.d/internet-led.list
apk update
apk add luci-app-internet-led
```

The feed URL is enabled after the first signed release is deployed.

## Configuration

After installation, navigate to LuCI → Status → Internet LED to view the dashboard and adjust settings.

Available options:

| Option | Description | Default |
|--------|-------------|---------|
| Enable | Turn the LED indicator on/off | Enabled |
| WAN Interface | Logical network interface to monitor | wan |
| Check Interval (seconds) | Time between connectivity checks | 5 |
| Failure Threshold | Consecutive failures before declaring internet down | 3 |
| Online LED | Name of the LED to light when internet is up | blue:network |
| Offline LED | Name of the LED to light when internet is down | yellow:network |
| Diagnostic Targets | Space‑separated list of IPs/hosts to ping for verification | 8.8.8.8 1.1.1.1 9.9.9.9 |

### How it works

- The script first checks if the WAN interface has a physical cable connected.
- If the selected WAN device has link, it pings the configured diagnostic targets through that interface to determine internet reachability.
- After `failure_threshold` consecutive failures, it declares the internet as DOWN and lights the yellow LED.
- When connectivity is restored, it lights the blue LED.
- If the selected WAN device has no link, both LEDs are turned off.
- If the same LED is selected for both states, it is on when online and off when offline or disconnected.

## Package Persistence

The package preserves its UCI configuration as a managed config file:

- /etc/config/internet-led – UCI configuration

Package-owned files are restored by reinstalling the `.apk`; local configuration is preserved by the package manager. System → LED rules remain in `/etc/config/system` and are reapplied when this service stops.

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

This stops and disables the service. Its stop path restores the LED triggers from System → LED. Package installation and removal reload rpcd so it picks up the package ACL; uhttpd is not restarted.

## License

MIT License – see the LICENSE file for details.
