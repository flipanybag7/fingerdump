#include "types.h"

const char *fd_category_names[CAT_COUNT] = {
    [CAT_HARDWARE]    = "Hardware",
    [CAT_SYSTEM]      = "System Identifiers",
    [CAT_NETWORK]     = "Network",
    [CAT_GRAPHICS]    = "Graphics / GPU",
    [CAT_AUDIO]       = "Audio",
    [CAT_SENSOR]      = "Sensors",
    [CAT_FONT]        = "Fonts",
    [CAT_PERSISTENCE] = "Persistence",
    [CAT_BEHAVIORAL]  = "Behavioral",
    [CAT_BROWSER]     = "Browser / WebView",
    [CAT_KEYCHAIN]    = "Keychain",
};

const char *fd_category_descriptions[CAT_COUNT] = {
    [CAT_HARDWARE]    = "Device model, serials, MAC addresses, chip identifiers from IOKit and sysctl",
    [CAT_SYSTEM]      = "IDFV, IDFA, device name, OS version, boot session UUID",
    [CAT_NETWORK]     = "IP addresses, WiFi info, cell tower data, DNS, WebRTC leaks",
    [CAT_GRAPHICS]    = "Canvas fingerprint, WebGL vendor/renderer, Metal GPU, OpenGL ES, display info",
    [CAT_AUDIO]       = "AudioContext fingerprint, AudioUnit characteristics, mic frequency response",
    [CAT_SENSOR]      = "Accelerometer, gyroscope, magnetometer calibration, barometer, proximity",
    [CAT_FONT]        = "System font list, installed font enumeration, font metric anomalies",
    [CAT_PERSISTENCE] = "UserDefaults survival, pasteboard inspection, DeviceCheck, App Attest",
    [CAT_BEHAVIORAL]  = "Language, locale, timezone, keyboard layout, accessibility settings",
    [CAT_BROWSER]     = "Navigator properties, plugin list, mime types, concurrency, platform info",
    [CAT_KEYCHAIN]    = "Keychain read/write test, access group survival, SecItem hook validation",
};
