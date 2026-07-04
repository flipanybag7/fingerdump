# FingerDump

[![Build](https://github.com/flipanybag7/fingerdump/actions/workflows/build.yml/badge.svg)](https://github.com/flipanybag7/fingerdump/actions/workflows/build.yml)

Comprehensive iOS fingerprint identifier scanner and leak detector.

## Components

| Component | Path | Description |
|-----------|------|-------------|
| **Daemon** | `daemon/` | Root daemon (`fingerdumpd`) that scans all identifiers via sysctl, IOKit, Obj-C APIs |
| **Tweak** | `Tweak.xm` | MobileSubstrate tweak that hooks every identifier API and logs calls |
| **App** | `app/` | SwiftUI companion app with categorized dashboard and leak detection |
| **Web** | `web/` | JS fingerprinting tests for WebView: Canvas, WebGL, Audio, Fonts, Network |
| **Tools** | `tools/` | Frida automation script and CLI client |

## Identifiers Scanned (~60 total)

- **Hardware**: Platform, model, serial, MACs, chip IDs, boot UUID, CPU info, memory, firmware
- **System**: IDFV, IDFA, device name, OS version, build, hostname, process info
- **Network**: Local IPs (v4/v6), gateway, DNS, WiFi SSID/BSSID, proxy, interfaces
- **Graphics**: Screen resolution, scale, GPU (Metal), OpenGL ES, color depth, canvas/webgl fingerprints
- **Audio**: Device IDs, buffer size, sample rate, channels, AudioContext fingerprint
- **Sensors**: Accelerometer, gyroscope, magnetometer, barometer, proximity, device motion
- **Fonts**: Font family enumeration, cascade lists, installed font detection
- **Persistence**: Keychain write/read, DeviceCheck, UserDefaults, pasteboard, cookies, file system
- **Behavioral**: Language, region, timezone, keyboard, accessibility settings, uptime
- **Browser**: WKWebView config, cookies, URL cache, user scripts

## Architecture

```
fingerdumpd (daemon, runs as root)
  ├── Unix socket at /var/run/fingerdumpd.sock
  ├── SQLite at /var/mobile/Library/FingerDump/scans.db
  └── HTTP server for web test pages

FingerDumpTweak (MobileSubstrate)
  └── Logs all identifier API calls to /var/mobile/Library/FingerDump/api_calls.log

FingerDump.app (SwiftUI companion)
  └── Connects to daemon socket, displays scan results in categorized dashboard
```

## Build

Requires [Theos](https://theos.dev) on macOS:

```bash
export THEOS=~/theos
make package
```

Or build individual components:

```bash
# Daemon only
make fingerdumpd

# Tweak only
make FingerDumpTweak

# App (Xcode)
open app/FingerDump/FingerDump.xcodeproj
```

## Usage

```bash
# CLI scan
fingerdumpd --scan

# Start daemon
fingerdumpd --daemon

# Scan a specific category
fingerdumpd --scan-cat 1

# Open the FingerDump app
# Or load web tests in Safari: http://127.0.0.1:8080

# Watch tweak log
tail -f /var/mobile/Library/FingerDump/api_calls.log

# Frida live trace
python3 tools/frida_trace_identifiers.py com.reddit.Reddit
```

## Leak Detection

The app color-codes every identifier:
- **Red**: Real value exposed (not spoofed by tweak)
- **Green**: Successfully spoofed
- **Gray**: Not available or not hooked

The persistence category includes a reinstall test mode: write test data, delete app, reinstall, and check what survived.
