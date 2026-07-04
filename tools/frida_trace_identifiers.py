"""
FingerDump Frida script for live identifier tracing.
Traces all known identifier APIs in a target app and dumps calls.

Usage:
    python frida_trace_identifiers.py com.reddit.Reddit
    python frida_trace_identifiers.py --all (trace all running apps)
"""

import frida
import sys
import json
import os
from datetime import datetime

class IdentifierTracer:
    def __init__(self, target):
        self.target = target
        self.session = None
        self.calls = []
        self.output_file = f"/tmp/fingerdump_frida_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"

    def on_message(self, message, data):
        if message['type'] == 'send':
            payload = message['payload']
            self.calls.append(payload)
            ts = datetime.now().strftime('%H:%M:%S.%f')[:-3]
            status = ""
            if payload.get('spoofed'):
                status = " [SPOOFED]"
            elif payload.get('leaking'):
                status = " [LEAKING]"
            print(f"[{ts}] {payload['api']} = {payload['value']}{status}")
        elif message['type'] == 'error':
            print(f"[ERROR] {message['description']}", file=sys.stderr)

    def save_report(self):
        report = {
            'target': self.target,
            'timestamp': datetime.now().isoformat(),
            'total_calls': len(self.calls),
            'calls': self.calls
        }
        with open(self.output_file, 'w') as f:
            json.dump(report, f, indent=2)
        print(f"\nReport saved to: {self.output_file}")

    def run(self):
        try:
            self.session = frida.attach(self.target)
        except Exception as e:
            print(f"Failed to attach to {self.target}: {e}", file=sys.stderr)
            print("Try: frida -U (list USB devices) or check app is running", file=sys.stderr)
            sys.exit(1)

        script_code = """
'use strict';

rpc.exports = {};

/* Identifier API tracer for FingerDump */

const hooks = [
    // UIDevice
    { obj: ObjC.classes.UIDevice, sel: '- name' },
    { obj: ObjC.classes.UIDevice, sel: '- systemVersion' },
    { obj: ObjC.classes.UIDevice, sel: '- systemName' },
    { obj: ObjC.classes.UIDevice, sel: '- localizedModel' },
    { obj: ObjC.classes.UIDevice, sel: '- model' },
    { obj: ObjC.classes.UIDevice, sel: '- identifierForVendor' },
    { obj: ObjC.classes.UIDevice, sel: '- userInterfaceIdiom' },
    { obj: ObjC.classes.UIDevice, sel: '- name' },

    // ASIdentifierManager
    { obj: ObjC.classes.ASIdentifierManager, sel: '- advertisingIdentifier' },
    { obj: ObjC.classes.ASIdentifierManager, sel: '- isAdvertisingTrackingEnabled' },

    // NSProcessInfo
    { obj: ObjC.classes.NSProcessInfo, sel: '- operatingSystemVersionString' },
    { obj: ObjC.classes.NSProcessInfo, sel: '- hostName' },
    { obj: ObjC.classes.NSProcessInfo, sel: '- globallyUniqueString' },
    { obj: ObjC.classes.NSProcessInfo, sel: '- processName' },
    { obj: ObjC.classes.NSProcessInfo, sel: '+ processInfo' },

    // NSLocale
    { obj: ObjC.classes.NSLocale, sel: '+ currentLocale' },
    { obj: ObjC.classes.NSLocale, sel: '+ preferredLanguages' },
    { obj: ObjC.classes.NSLocale, sel: '+ preferredLocalizations' },

    // NSTimeZone
    { obj: ObjC.classes.NSTimeZone, sel: '+ localTimeZone' },
    { obj: ObjC.classes.NSTimeZone, sel: '+ systemTimeZone' },
    { obj: ObjC.classes.NSTimeZone, sel: '+ defaultTimeZone' },

    // NSUserDefaults
    { obj: ObjC.classes.NSUserDefaults, sel: '- objectForKey:' },
    { obj: ObjC.classes.NSUserDefaults, sel: '- setObject:forKey:' },

    // UIPasteboard
    { obj: ObjC.classes.UIPasteboard, sel: '+ generalPasteboard' },
    { obj: ObjC.classes.UIPasteboard, sel: '- items' },
    { obj: ObjC.classes.UIPasteboard, sel: '- string' },

    // NSHTTPCookieStorage
    { obj: ObjC.classes.NSHTTPCookieStorage, sel: '+ sharedHTTPCookieStorage' },
    { obj: ObjC.classes.NSHTTPCookieStorage, sel: '- cookies' },

    // DCDevice
    { obj: ObjC.classes.DCDevice, sel: '+ currentDevice' },
    { obj: ObjC.classes.DCDevice, sel: '- generateTokenWithCompletionHandler:' },

    // WKWebsiteDataStore
    { obj: ObjC.classes.WKWebsiteDataStore, sel: '+ defaultDataStore' },
    { obj: ObjC.classes.WKWebsiteDataStore, sel: '- fetchDataRecordsOfTypes:completionHandler:' },

    // CTTelephonyNetworkInfo / CTCarrier
    { obj: ObjC.classes.CTTelephonyNetworkInfo, sel: '- subscriberCellularProvider' },
    { obj: ObjC.classes.CTTelephonyNetworkInfo, sel: '- serviceSubscriberCellularProvider' },
    { obj: ObjC.classes.CTCarrier, sel: '- mobileCountryCode' },
    { obj: ObjC.classes.CTCarrier, sel: '- mobileNetworkCode' },
    { obj: ObjC.classes.CTCarrier, sel: '- isoCountryCode' },
    { obj: ObjC.classes.CTCarrier, sel: '- carrierName' },

    // NSFileManager (suspect paths only)
    { obj: ObjC.classes.NSFileManager, sel: '- contentsOfDirectoryAtURL:includingPropertiesForKeys:options:error:' },
    { obj: ObjC.classes.NSFileManager, sel: '- fileExistsAtPath:' },

    // NSBundle
    { obj: ObjC.classes.NSBundle, sel: '- bundleIdentifier' },
    { obj: ObjC.classes.NSBundle, sel: '- infoDictionary' },

    // CMMotionManager
    { obj: ObjC.classes.CMMotionManager, sel: '- isAccelerometerAvailable' },
    { obj: ObjC.classes.CMMotionManager, sel: '- isGyroAvailable' },
    { obj: ObjC.classes.CMMotionManager, sel: '- isMagnetometerAvailable' },
    { obj: ObjC.classes.CMMotionManager, sel: '- isDeviceMotionAvailable' },
];

const identifierAPIs = new Set();
const apiCalls = [];

const SPOOFED_PREFIXES = [
    "00000000-0000-0000-0000-",
    "00000000-0000-0000-0001-",
    "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
    "00000000-0000-0000-0000-000000000000"
];

function isSpoofedValue(val) {
    const s = String(val);
    for (const p of SPOOFED_PREFIXES) {
        if (s.startsWith(p)) return true;
    }
    return false;
}

function getAPIKey(clsName, selName) {
    return clsName + ' ' + selName;
}

for (const h of hooks) {
    try {
        const clsName = h.obj.$className;
        let impl = null;
        try {
            impl = h.obj[h.sel];
        } catch (e) {
            continue;
        }
        if (!impl) continue;

        const selName = h.sel;
        const apiKey = getAPIKey(clsName, selName);
        identifierAPIs.add(apiKey);

        const interceptor = {
            onEnter(args) {
                this.callTime = Date.now();
            },
            onLeave(retval) {
                const elapsed = Date.now() - this.callTime;
                let val = '';

                if (selName.startsWith('+')) {
                    // class method - retval is the object
                    val = String(retval);
                } else {
                    // instance method
                    if (selName === '- identifierForVendor' || selName === '- advertisingIdentifier') {
                        val = retval ? retval.UUIDString().toString() : 'null';
                    } else {
                        val = retval ? retval.toString() : 'null';
                    }
                }

                const ln = ObjC.classes.NSThread.call('+ callStackSymbols').toString().split('\\n');
                const caller = ln.length > 2 ? ln[2].trim() : 'unknown';

                const callInfo = {
                    api: apiKey,
                    value: val.substring(0, 500),
                    spoofed: isSpoofedValue(val),
                    leaking: false,
                    caller: caller.substring(0, 200),
                    elapsed_ms: elapsed
                };

                send(callInfo);

                if (apiKey.indexOf('SecItem') >= 0) {
                    // check if keychain query has identifying info
                    try {
                        if (args[0]) {
                            const query = new ObjC.Object(args[0]);
                            // Log the query keys
                        }
                    } catch(e) {}
                }
            }
        };

        try {
            Interceptor.attach(impl, interceptor);
        } catch(e) {
            // Method might not exist at runtime
        }
    } catch (e) {
        // Class not available
    }
}

// Hook SecItem C functions
const secItemFuncs = [
    'SecItemCopyMatching',
    'SecItemAdd',
    'SecItemDelete',
    'SecItemUpdate'
];

for (const fn of secItemFuncs) {
    const ptr = Module.findExportByName(null, fn);
    if (ptr) {
        Interceptor.attach(ptr, {
            onEnter(args) {
                this.callTime = Date.now();
                const ln = ObjC.classes.NSThread.call('+ callStackSymbols').toString().split('\\n');
                const caller = ln.length > 2 ? ln[2].trim() : 'unknown';

                let details = '';
                try {
                    if (args[0]) {
                        const dict = new ObjC.Object(args[0]);
                        details = dict.toString().substring(0, 500);
                    }
                } catch(e) {}

                send({
                    api: fn,
                    value: details,
                    spoofed: false,
                    leaking: true,
                    caller: caller.substring(0, 200),
                    elapsed_ms: 0
                });
            }
        });
    }
}

// Hook sysctl C function
const sysctlPtr = Module.findExportByName(null, 'sysctl');
if (sysctlPtr) {
    Interceptor.attach(sysctlPtr, {
        onEnter(args) {
            const mib = args[0];
            if (mib) {
                try {
                    const name = Memory.readCString(mib);
                    if (name.indexOf('hw.machine') >= 0 || name.indexOf('hw.model') >= 0 ||
                        name.indexOf('kern.bootuuid') >= 0 || name.indexOf('kern.osversion') >= 0) {
                        this.isInteresting = true;
                    }
                } catch(e) {
                    this.isInteresting = false;
                }
            }
        },
        onLeave(retval) {
            if (this.isInteresting) {
                send({
                    api: 'sysctl (interesting)',
                    value: 'called',
                    spoofed: false,
                    leaking: true,
                    caller: 'unknown',
                    elapsed_ms: Date.now() - this.callTime
                });
            }
        }
    });
}

// Check if there's a FingerDump tweak loaded
const bundlePath = ObjC.classes.NSBundle ? ObjC.classes.NSBundle.mainBundle() : null;
if (bundlePath) {
    const bundleId = bundlePath.bundleIdentifier().toString();
    send({
        api: '_meta',
        value: `App: ${bundleId}`,
        spoofed: false,
        leaking: false,
        caller: '',
        elapsed_ms: 0
    });
}

// Check for FingerDump log
const fm = ObjC.classes.NSFileManager;
if (fm) {
    const logPath = '/var/mobile/Library/FingerDump/api_calls.log';
    const exists = fm.defaultManager().fileExistsAtPath_(logPath);
    send({
        api: '_meta',
        value: `FingerDump tweak log: ${exists ? 'EXISTS' : 'NOT FOUND'}`,
        spoofed: false,
        leaking: false,
        caller: '',
        elapsed_ms: 0
    });
}
""";
        script = self.session.create_script(script_code)
        script.on('message', self.on_message)
        script.load()

        print(f"[*] Tracing identifier APIs in {self.target}")
        print("[*] Press Ctrl+C to stop and save report\n")

        try:
            sys.stdin.read()
        except KeyboardInterrupt:
            pass
        finally:
            self.session.detach()
            self.save_report()

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <app_name_or_pid>")
        print(f"       {sys.argv[0]} --all")
        sys.exit(1)

    target = sys.argv[1]
    tracer = IdentifierTracer(target)
    tracer.run()

if __name__ == '__main__':
    main()
