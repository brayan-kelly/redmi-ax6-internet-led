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
- Persists across firmware upgrades (sysupgrade)

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

### Build the tarball

./create-internet-led-tarball.sh

This creates luci-app-internet-led.tar.gz in the current directory.

### Install on the router

Copy the tarball to your router and extract it:

scp luci-app-internet-led.tar.gz root@router:/tmp/
ssh root@router
cd / && tar -xzf /tmp/luci-app-internet-led.tar.gz && ./install.sh

The installer copies all files, runs the uci‑defaults script (which initialises the configuration if needed), and starts the service.

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

## Sysupgrade Persistence

The uci‑defaults script (/etc/uci-defaults/99_internet-led) adds all relevant files to /etc/sysupgrade.conf:

- /etc/config/internet-led – UCI configuration
- /etc/init.d/internet-led – Init script
- /usr/bin/internet-led.sh – Main monitoring script
- /usr/libexec/rpcd/internet-led-lists – RPC endpoint for LED listing
- /usr/libexec/rpcd/internet-led-state – RPC endpoint for status reporting
- /usr/share/rpcd/acl.d/luci-app-internet-led.json – ACL definition
- /usr/share/luci/menu.d/luci-app-internet-led.json – LuCI menu entry
- /www/luci-static/resources/view/internet-led/ – LuCI view files

This ensures your configuration and custom files survive a firmware upgrade.

## File Structure
```
Files/
├── etc/
│ ├── config/
│ │ └── internet-led # UCI config
│ ├── init.d/
│ │ └── internet-led # Init script
│ └── uci-defaults/
│ └── 99_internet-led # One‑time setup script
├── usr/
│ ├── bin/
│ │ └── internet-led.sh # Core monitoring daemon
│ ├── libexec/
│ │ └── rpcd/
│ │ └── internet-led-lists # RPC to list available LEDs
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

The tarball includes an uninstall script. To remove the package, simply run:

./uninstall.sh

This will stop the service, remove all installed files, and restart rpcd and uhttpd.

## License

MIT License – see the LICENSE file for details.
