#include "FingerDumpLog.h"
#import <objc/runtime.h>
#import <substrate.h>
#import <UIKit/UIKit.h>
#include <sys/stat.h>

static id (*orig_UIDevice_name)(id, SEL);
static id (*orig_UIDevice_systemVersion)(id, SEL);
static id (*orig_UIDevice_systemName)(id, SEL);
static id (*orig_UIDevice_localizedModel)(id, SEL);
static id (*orig_UIDevice_model)(id, SEL);
static id (*orig_UIDevice_identifierForVendor)(id, SEL);
static id (*orig_ASIdentifierManager_advertisingIdentifier)(id, SEL);
static BOOL (*orig_ASIdentifierManager_isAdvertisingTrackingEnabled)(id, SEL);
static id (*orig_NSLocale_currentLocale)(id, SEL);
static id (*orig_NSTimeZone_localTimeZone)(id, SEL);
static id (*orig_NSProcessInfo_operatingSystemVersionString)(id, SEL);
static id (*orig_NSUserDefaults_objectForKey)(id, SEL, id);
static id (*orig_UIPasteboard_generalPasteboard)(id, SEL);

static id new_UIDevice_name(id self, SEL _cmd) {
    id real = orig_UIDevice_name(self, _cmd);
    FDLog(@"UIDevice.name", @"%@", real);
    return real;
}

static id new_UIDevice_systemVersion(id self, SEL _cmd) {
    id real = orig_UIDevice_systemVersion(self, _cmd);
    FDLog(@"UIDevice.systemVersion", @"%@", real);
    return real;
}

static id new_UIDevice_systemName(id self, SEL _cmd) {
    id real = orig_UIDevice_systemName(self, _cmd);
    FDLog(@"UIDevice.systemName", @"%@", real);
    return real;
}

static id new_UIDevice_localizedModel(id self, SEL _cmd) {
    id real = orig_UIDevice_localizedModel(self, _cmd);
    FDLog(@"UIDevice.localizedModel", @"%@", real);
    return real;
}

static id new_UIDevice_model(id self, SEL _cmd) {
    id real = orig_UIDevice_model(self, _cmd);
    FDLog(@"UIDevice.model", @"%@", real);
    return real;
}

static id new_UIDevice_identifierForVendor(id self, SEL _cmd) {
    id real = orig_UIDevice_identifierForVendor(self, _cmd);
    FDLog(@"UIDevice.identifierForVendor", @"%@", [real UUIDString]);
    return real;
}

static id new_ASIdentifierManager_advertisingIdentifier(id self, SEL _cmd) {
    id real = orig_ASIdentifierManager_advertisingIdentifier(self, _cmd);
    FDLog(@"ASIdentifierManager.advertisingIdentifier", @"%@", [real UUIDString]);
    return real;
}

static BOOL new_ASIdentifierManager_isAdvertisingTrackingEnabled(id self, SEL _cmd) {
    BOOL real = orig_ASIdentifierManager_isAdvertisingTrackingEnabled(self, _cmd);
    FDLog(@"ASIdentifierManager.isAdvertisingTrackingEnabled", @"%s", real ? "YES" : "NO");
    return real;
}

static id new_NSLocale_currentLocale(id self, SEL _cmd) {
    id real = orig_NSLocale_currentLocale(self, _cmd);
    FDLog(@"NSLocale.currentLocale", @"%@", [real localeIdentifier]);
    return real;
}

static id new_NSTimeZone_localTimeZone(id self, SEL _cmd) {
    id real = orig_NSTimeZone_localTimeZone(self, _cmd);
    FDLog(@"NSTimeZone.localTimeZone", @"%@", [real name]);
    return real;
}

static id new_NSProcessInfo_operatingSystemVersionString(id self, SEL _cmd) {
    id real = orig_NSProcessInfo_operatingSystemVersionString(self, _cmd);
    FDLog(@"NSProcessInfo.operatingSystemVersionString", @"%@", real);
    return real;
}

static id new_NSUserDefaults_objectForKey(id self, SEL _cmd, id key) {
    id obj = orig_NSUserDefaults_objectForKey(self, _cmd, key);
    NSString *k = key;
    if ([k hasPrefix:@"Apple"] || [k hasPrefix:@"NS"] || [k hasSuffix:@"Identifier"] || [k hasSuffix:@"UUID"] || [k hasSuffix:@"ID"]) {
        FDLog([@"NSUserDefaults.objectForKey:" stringByAppendingString:k], @"%@", [obj description]);
    }
    return obj;
}

static id new_UIPasteboard_generalPasteboard(id self, SEL _cmd) {
    id pb = orig_UIPasteboard_generalPasteboard(self, _cmd);
    FDLog(@"UIPasteboard.generalPasteboard", @"called");
    return pb;
}

__attribute__((constructor)) static void init() {
    @autoreleasepool {
        NSString *procName = [[NSProcessInfo processInfo] processName];
        if ([procName isEqualToString:@"fingerdumpd"]) {
            return;
        }

        mkdir("/var/mobile/Library/FingerDump", 0755);
        FDLog(@"FingerDump", @"Tweak loaded into %@", procName);

        MSHookMessageEx(objc_getClass("UIDevice"), @selector(name), (IMP)new_UIDevice_name, (IMP *)&orig_UIDevice_name);
        MSHookMessageEx(objc_getClass("UIDevice"), @selector(systemVersion), (IMP)new_UIDevice_systemVersion, (IMP *)&orig_UIDevice_systemVersion);
        MSHookMessageEx(objc_getClass("UIDevice"), @selector(systemName), (IMP)new_UIDevice_systemName, (IMP *)&orig_UIDevice_systemName);
        MSHookMessageEx(objc_getClass("UIDevice"), @selector(localizedModel), (IMP)new_UIDevice_localizedModel, (IMP *)&orig_UIDevice_localizedModel);
        MSHookMessageEx(objc_getClass("UIDevice"), @selector(model), (IMP)new_UIDevice_model, (IMP *)&orig_UIDevice_model);
        MSHookMessageEx(objc_getClass("UIDevice"), @selector(identifierForVendor), (IMP)new_UIDevice_identifierForVendor, (IMP *)&orig_UIDevice_identifierForVendor);
        MSHookMessageEx(objc_getClass("ASIdentifierManager"), @selector(advertisingIdentifier), (IMP)new_ASIdentifierManager_advertisingIdentifier, (IMP *)&orig_ASIdentifierManager_advertisingIdentifier);
        MSHookMessageEx(objc_getClass("ASIdentifierManager"), @selector(isAdvertisingTrackingEnabled), (IMP)new_ASIdentifierManager_isAdvertisingTrackingEnabled, (IMP *)&orig_ASIdentifierManager_isAdvertisingTrackingEnabled);
        MSHookMessageEx(objc_getClass("NSLocale"), @selector(currentLocale), (IMP)new_NSLocale_currentLocale, (IMP *)&orig_NSLocale_currentLocale);
        MSHookMessageEx(objc_getClass("NSTimeZone"), @selector(localTimeZone), (IMP)new_NSTimeZone_localTimeZone, (IMP *)&orig_NSTimeZone_localTimeZone);
        MSHookMessageEx(objc_getClass("NSProcessInfo"), @selector(operatingSystemVersionString), (IMP)new_NSProcessInfo_operatingSystemVersionString, (IMP *)&orig_NSProcessInfo_operatingSystemVersionString);
        MSHookMessageEx(objc_getClass("NSUserDefaults"), @selector(objectForKey:), (IMP)new_NSUserDefaults_objectForKey, (IMP *)&orig_NSUserDefaults_objectForKey);
        MSHookMessageEx(objc_getClass("UIPasteboard"), @selector(generalPasteboard), (IMP)new_UIPasteboard_generalPasteboard, (IMP *)&orig_UIPasteboard_generalPasteboard);
    }
}
