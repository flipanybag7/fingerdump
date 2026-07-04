#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>
#include "shared/types.h"

static void test_keychain(char *out_read, size_t read_len, char *out_delete, size_t del_len) {
    CFStringRef testService = CFSTR("com.fingerdump.test");
    CFStringRef testAccount = CFSTR("persistence-test-uuid");
    CFStringRef testLabel = CFSTR("FingerDump Persistence Test");

    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef uuidStr = CFUUIDCreateString(kCFAllocatorDefault, uuid);
    char uuid_c[128] = {0};
    CFStringGetCString(uuidStr, uuid_c, sizeof(uuid_c), kCFStringEncodingUTF8);
    CFDataRef value = CFDataCreate(kCFAllocatorDefault, (const UInt8 *)uuid_c, strlen(uuid_c));

    CFTypeRef keys[] = { kSecClass, kSecAttrService, kSecAttrAccount,
                         kSecAttrLabel, kSecValueData, kSecReturnData };
    CFTypeRef vals[] = { kSecClassGenericPassword, testService, testAccount,
                         testLabel, value, kCFBooleanTrue };

    CFDictionaryRef addDict = CFDictionaryCreate(kCFAllocatorDefault,
        (const void **)keys, (const void **)vals, 6,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

    CFTypeRef result = NULL;
    OSStatus status = SecItemAdd(addDict, &result);

    if (status == errSecSuccess && result) {
        char read_val[256] = {0};
        CFIndex dataLen = CFDataGetLength((CFDataRef)result);
        if (dataLen > 0 && dataLen < 256) {
            CFDataGetBytes((CFDataRef)result, CFRangeMake(0, dataLen), (UInt8 *)read_val);
            read_val[dataLen] = 0;
        }
        snprintf(out_read, read_len, "write_ok read_back=%s", read_val);
        CFRelease(result);
    } else if (status == errSecDuplicateItem) {
        snprintf(out_read, read_len, "duplicate_item (may be surviving from prior test)");
    } else {
        snprintf(out_read, read_len, "write_status=%d", (int)status);
    }

    CFTypeRef delKeys[] = { kSecClass, kSecAttrService, kSecAttrAccount };
    CFTypeRef delVals[] = { kSecClassGenericPassword, testService, testAccount };
    CFDictionaryRef delDict = CFDictionaryCreate(kCFAllocatorDefault,
        (const void **)delKeys, (const void **)delVals, 3,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

    status = SecItemDelete(delDict);
    snprintf(out_delete, del_len, "delete_status=%d", (int)status);

    CFRelease(delDict);
    CFRelease(addDict);
    CFRelease(value);
    CFRelease(uuidStr);
    CFRelease(uuid);
}

static void test_devicecheck(char *out, size_t len) {
    Class dc = objc_getClass("DCDevice");
    if (!dc) { snprintf(out, len, "unavailable (DCDevice not found)"); return; }
    id device = ((id (*)(id, SEL))(void *)objc_msgSend)((id)dc, sel_registerName("currentDevice"));
    if (!device) { snprintf(out, len, "unavailable"); return; }

    __block bool completed = false;
    id block = ^(NSData *tokenData, NSError *error) {
        completed = true;
    };

    ((void (*)(id, SEL, id))(void *)objc_msgSend)(device, sel_registerName("generateTokenWithCompletionHandler:"), block);

    int tries = 0;
    while (!completed && tries < 100) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, false);
        tries++;
    }

    if (completed) {
        snprintf(out, len, "DeviceCheck token generation completed");
    } else {
        snprintf(out, len, "DeviceCheck token generation timed out");
    }
}

void fd_scan_persistence(fd_category_result_t *result) {
    result->category = CAT_PERSISTENCE;
    int i = 0;

#define ADD_IDENT(k, n, d, real, spoofed, spoofed_flag, leak_flag, avail) do { \
    snprintf(result->identifiers[i].key, FD_MAX_KEY_LEN, "%s", k); \
    snprintf(result->identifiers[i].name, FD_MAX_NAME_LEN, "%s", n); \
    snprintf(result->identifiers[i].description, FD_MAX_DESC_LEN, "%s", d); \
    snprintf(result->identifiers[i].real_value, FD_MAX_VALUE_LEN, "%s", real); \
    snprintf(result->identifiers[i].spoofed_value, FD_MAX_VALUE_LEN, "%s", spoofed); \
    result->identifiers[i].is_spoofed = spoofed_flag; \
    result->identifiers[i].is_leaking = leak_flag; \
    result->identifiers[i].is_available = avail; \
    result->identifiers[i].category = CAT_PERSISTENCE; \
    i++; \
} while(0)

    char val[512], val2[512];

    test_keychain(val, sizeof(val), val2, sizeof(val2));
    ADD_IDENT("persistence.keychain_write", "Keychain write/read test", "Write a UUID to keychain and read it back", val, "", false, true, true);
    ADD_IDENT("persistence.keychain_delete", "Keychain delete test", "Delete the test keychain item", val2, "", false, true, true);

    test_devicecheck(val, sizeof(val));
    ADD_IDENT("persistence.devicecheck", "DeviceCheck token", "DCDevice.generateTokenWithCompletionHandler", val, "", false, true, true);

    {
        Class ud = objc_getClass("NSUserDefaults");
        if (ud) {
            id defaults = ((id (*)(id, SEL))(void *)objc_msgSend)((id)ud, sel_registerName("standardUserDefaults"));
            if (defaults) {
                id testVal = ((id (*)(id, SEL, id))(void *)objc_msgSend)(defaults, sel_registerName("objectForKey:"), (id)CFSTR("FingerDumpPersistenceTest"));
                if (testVal) {
                    char *s = strdup(((const char *(*)(id, SEL))(void *)objc_msgSend)(testVal, sel_registerName("UTF8String")));
                    snprintf(val, sizeof(val), "found: %s", s);
                    free(s);
                } else {
                    ((void (*)(id, SEL, id, id))(void *)objc_msgSend)(defaults, sel_registerName("setObject:forKey:"), (id)CFSTR("FingerDumpTest"), (id)CFSTR("FingerDumpPersistenceTest"));
                    ((void (*)(id, SEL))(void *)objc_msgSend)(defaults, sel_registerName("synchronize"));
                    snprintf(val, sizeof(val), "written (check after reinstall)");
                }
            } else { snprintf(val, sizeof(val), "unavailable"); }
        } else { snprintf(val, sizeof(val), "unavailable"); }
        ADD_IDENT("persistence.userdefaults", "UserDefaults persistence", "NSUserDefaults write/read test (survives reinstall?)", val, "", false, true, true);
    }

    {
        Class pb = objc_getClass("UIPasteboard");
        if (pb) {
            id gp = ((id (*)(id, SEL))(void *)objc_msgSend)((id)pb, sel_registerName("generalPasteboard"));
            if (gp) {
                id items = ((id (*)(id, SEL))(void *)objc_msgSend)(gp, sel_registerName("items"));
                if (items) {
                    char *s = strdup(((const char *(*)(id, SEL))(void *)objc_msgSend)(items, sel_registerName("description")));
                    snprintf(val, sizeof(val), "%s", s);
                    free(s);
                } else { snprintf(val, sizeof(val), "empty"); }
            } else { snprintf(val, sizeof(val), "unavailable"); }
        } else { snprintf(val, sizeof(val), "unavailable"); }
        ADD_IDENT("persistence.pasteboard", "Pasteboard contents", "UIPasteboard.general items (potential tracking IDs)", val, "", false, true, true);
    }

    {
        Class wkp = objc_getClass("WKWebsiteDataStore");
        if (wkp) {
            id ds = ((id (*)(id, SEL))(void *)objc_msgSend)((id)wkp, sel_registerName("defaultDataStore"));
            if (ds) {
                ((void (*)(id, SEL, id, id))(void *)objc_msgSend)(ds, sel_registerName("fetchDataRecordsOfTypes:completionHandler:"), nil, ^(id records) { });
                if (cookies) {
                    char *s = strdup(((const char *(*)(id, SEL))(void *)objc_msgSend)(cookies, sel_registerName("description")));
                    snprintf(val, sizeof(val), "%s", s);
                    free(s);
                } else { snprintf(val, sizeof(val), "none"); }
            } else { snprintf(val, sizeof(val), "unavailable"); }
        } else { snprintf(val, sizeof(val), "unavailable"); }
        ADD_IDENT("persistence.webview_cookies", "WKWebView cookies", "WkWebsiteDataStore cookies/storage (cross-app tracking via WebView)", val, "", false, true, true);
    }

    {
        Class fm = objc_getClass("NSFileManager");
        if (fm) {
            id fmgr = ((id (*)(id, SEL))(void *)objc_msgSend)((id)fm, sel_registerName("defaultManager"));
            if (fmgr) {
                id appSupport = ((id (*)(id, SEL, unsigned long, unsigned long, id, BOOL, id *))(void *)objc_msgSend)(fmgr, sel_registerName("URLForDirectory:inDomain:appropriateForURL:create:error:"), (unsigned long)14, (unsigned long)1, nil, false, nil);
                if (appSupport) {
                    id contents = ((id (*)(id, SEL, id, id, unsigned long, id *))(void *)objc_msgSend)(fmgr, sel_registerName("contentsOfDirectoryAtURL:includingPropertiesForKeys:options:error:"), appSupport, nil, (unsigned long)0, nil);
                    if (contents) {
                        char *s = strdup(((const char *(*)(id, SEL))(void *)objc_msgSend)(contents, sel_registerName("description")));
                        snprintf(val, sizeof(val), "%s", s);
                        free(s);
                    } else { snprintf(val, sizeof(val), "empty"); }
                } else { snprintf(val, sizeof(val), "unavailable"); }
            } else { snprintf(val, sizeof(val), "unavailable"); }
        } else { snprintf(val, sizeof(val), "unavailable"); }
        ADD_IDENT("persistence.app_support", "App support directory", "NSApplicationSupportDirectory contents (shared file persistence)", val, "", false, true, true);
    }

    result->count = i;
}
