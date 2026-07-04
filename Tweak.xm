#include "FingerDumpLog.h"

%hook UIDevice

- (NSString *)name {
    NSString *real = %orig;
    FDLog(@"UIDevice.name", @"%@", real);
    return real;
}

- (NSString *)systemVersion {
    NSString *real = %orig;
    FDLog(@"UIDevice.systemVersion", @"%@", real);
    return real;
}

- (NSString *)systemName {
    NSString *real = %orig;
    FDLog(@"UIDevice.systemName", @"%@", real);
    return real;
}

- (NSString *)localizedModel {
    NSString *real = %orig;
    FDLog(@"UIDevice.localizedModel", @"%@", real);
    return real;
}

- (NSString *)model {
    NSString *real = %orig;
    FDLog(@"UIDevice.model", @"%@", real);
    return real;
}

- (NSUUID *)identifierForVendor {
    NSUUID *real = %orig;
    FDLog(@"UIDevice.identifierForVendor", @"%@", real.UUIDString);
    return real;
}

- (UIUserInterfaceIdiom)userInterfaceIdiom {
    UIUserInterfaceIdiom real = %orig;
    FDLog(@"UIDevice.userInterfaceIdiom", @"%ld", (long)real);
    return real;
}

@end

%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    NSUUID *real = %orig;
    FDLog(@"ASIdentifierManager.advertisingIdentifier", @"%@", real.UUIDString);
    return real;
}

- (BOOL)isAdvertisingTrackingEnabled {
    BOOL real = %orig;
    FDLog(@"ASIdentifierManager.isAdvertisingTrackingEnabled", @"%s", real ? "YES" : "NO");
    return real;
}

- (BOOL)isAdvertisingTrackingEnabled:(BOOL)enabled {
    BOOL real = %orig;
    FDLog(@"ASIdentifierManager.isAdvertisingTrackingEnabled:", @"%s", real ? "YES" : "NO");
    return real;
}

@end

%hook NSProcessInfo

- (NSString *)operatingSystemVersionString {
    NSString *real = %orig;
    FDLog(@"NSProcessInfo.operatingSystemVersionString", @"%@", real);
    return real;
}

- (NSString *)hostName {
    NSString *real = %orig;
    FDLog(@"NSProcessInfo.hostName", @"%@", real);
    return real;
}

- (NSString *)globallyUniqueString {
    NSString *real = %orig;
    FDLog(@"NSProcessInfo.globallyUniqueString", @"%@", real);
    return real;
}

- (NSString *)processName {
    NSString *real = %orig;
    FDLog(@"NSProcessInfo.processName", @"%@", real);
    return real;
}

@end

%hook NSLocale

+ (NSLocale *)currentLocale {
    NSLocale *real = %orig;
    FDLog(@"NSLocale.currentLocale", @"%@", real.localeIdentifier);
    return real;
}

+ (NSArray *)preferredLanguages {
    NSArray *real = %orig;
    FDLog(@"NSLocale.preferredLanguages", @"%@", [real description]);
    return real;
}

+ (NSString *)preferredLocalizations {
    NSString *real = %orig;
    FDLog(@"NSLocale.preferredLocalizations", @"%@", real);
    return real;
}

@end

%hook NSTimeZone

+ (NSTimeZone *)localTimeZone {
    NSTimeZone *real = %orig;
    FDLog(@"NSTimeZone.localTimeZone", @"%@", real.name);
    return real;
}

+ (NSTimeZone *)systemTimeZone {
    NSTimeZone *real = %orig;
    FDLog(@"NSTimeZone.systemTimeZone", @"%@", real.name);
    return real;
}

+ (NSTimeZone *)defaultTimeZone {
    NSTimeZone *real = %orig;
    FDLog(@"NSTimeZone.defaultTimeZone", @"%@", real.name);
    return real;
}

@end

%hook NSUserDefaults

- (id)objectForKey:(NSString *)key {
    id obj = %orig;
    if ([key hasPrefix:@"Apple"] || [key hasPrefix:@"NS"] || [key hasSuffix:@"Identifier"] || [key hasSuffix:@"UUID"] || [key hasSuffix:@"ID"] || [key hasSuffix:@"UID"]) {
        FDLog([@"NSUserDefaults.objectForKey:" stringByAppendingString:key], @"%@", [obj description]);
    }
    return obj;
}

- (void)setObject:(id)obj forKey:(NSString *)key {
    FDLog([@"NSUserDefaults.setObject:forKey:" stringByAppendingString:key], @"%@", [obj description]);
    %orig;
}

@end

%hook NSFileManager

- (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error {
    NSDictionary *attrs = %orig;
    if ([path containsString:@"Library"] || [path containsString:@"Documents"] || [path containsString:@"tmp"]) {
        FDLog(@"NSFileManager.attributesOfItemAtPath", @"%@", path);
    }
    return attrs;
}

- (NSArray *)contentsOfDirectoryAtURL:(NSURL *)url includingPropertiesForKeys:(NSArray *)keys options:(NSDirectoryEnumerationOptions)mask error:(NSError **)error {
    FDLog(@"NSFileManager.contentsOfDirectoryAtURL", @"%@", url.absoluteString);
    return %orig;
}

@end

%hook NSBundle

- (NSString *)bundleIdentifier {
    NSString *real = %orig;
    FDLog(@"NSBundle.bundleIdentifier", @"%@", real);
    return real;
}

- (NSString *)bundlePath {
    NSString *real = %orig;
    FDLog(@"NSBundle.bundlePath", @"%@", real);
    return real;
}

- (NSDictionary *)infoDictionary {
    NSDictionary *real = %orig;
    FDLog(@"NSBundle.infoDictionary", @"%@", [real description]);
    return real;
}

@end

%hook UIPasteboard

+ (UIPasteboard *)generalPasteboard {
    UIPasteboard *pb = %orig;
    FDLog(@"UIPasteboard.generalPasteboard", @"items=%ld changeCount=%ld", (long)pb.items.count, (long)pb.changeCount);
    return pb;
}

- (NSArray *)items {
    NSArray *items = %orig;
    if (items.count > 0) {
        FDLog(@"UIPasteboard.items", @"%@", [items description]);
    }
    return items;
}

- (void)setItems:(NSArray *)items {
    FDLog(@"UIPasteboard.setItems", @"count=%ld", (long)items.count);
    %orig;
}

- (NSString *)string {
    NSString *str = %orig;
    if (str.length > 0) {
        FDLog(@"UIPasteboard.string", @"%@", str);
    }
    return str;
}

@end

%hook DCDevice

- (void)generateTokenWithCompletionHandler:(void (^)(NSData *token, NSError *error))handler {
    FDLog(@"DCDevice.generateTokenWithCompletionHandler", @"called");
    %orig;
}

@end

%hook NSHTTPCookieStorage

+ (NSHTTPCookieStorage *)sharedHTTPCookieStorage {
    NSHTTPCookieStorage *storage = %orig;
    FDLog(@"NSHTTPCookieStorage.sharedHTTPCookieStorage", @"cookies=%ld", (long)storage.cookies.count);
    return storage;
}

- (void)setCookie:(NSHTTPCookie *)cookie {
    FDLog(@"NSHTTPCookieStorage.setCookie", @"%@", cookie.name);
    %orig;
}

- (void)deleteCookie:(NSHTTPCookie *)cookie {
    FDLog(@"NSHTTPCookieStorage.deleteCookie", @"%@", cookie.name);
    %orig;
}

- (NSArray *)cookies {
    NSArray *cookies = %orig;
    if (cookies.count > 0) {
        FDLog(@"NSHTTPCookieStorage.cookies", @"count=%ld", (long)cookies.count);
    }
    return cookies;
}

@end

%hook CMMotionManager

- (BOOL)isAccelerometerAvailable {
    BOOL real = %orig;
    FDLog(@"CMMotionManager.isAccelerometerAvailable", @"%s", real ? "YES" : "NO");
    return real;
}

- (BOOL)isGyroAvailable {
    BOOL real = %orig;
    FDLog(@"CMMotionManager.isGyroAvailable", @"%s", real ? "YES" : "NO");
    return real;
}

- (BOOL)isMagnetometerAvailable {
    BOOL real = %orig;
    FDLog(@"CMMotionManager.isMagnetometerAvailable", @"%s", real ? "YES" : "NO");
    return real;
}

- (BOOL)isDeviceMotionAvailable {
    BOOL real = %orig;
    FDLog(@"CMMotionManager.isDeviceMotionAvailable", @"%s", real ? "YES" : "NO");
    return real;
}

@end

%hook WKWebsiteDataStore

+ (WKWebsiteDataStore *)defaultDataStore {
    WKWebsiteDataStore *ds = %orig;
    FDLog(@"WKWebsiteDataStore.defaultDataStore", @"called");
    return ds;
}

- (void)fetchDataRecordsOfTypes:(NSSet *)types completionHandler:(void (^)(NSArray *records))handler {
    FDLog(@"WKWebsiteDataStore.fetchDataRecordsOfTypes", @"called");
    %orig;
}

@end

%hook CTTelephonyNetworkInfo

- (NSString *)subscriberCellularProvider {
    NSString *provider = %orig;
    FDLog(@"CTTelephonyNetworkInfo.subscriberCellularProvider", @"%@", provider);
    return provider;
}

- (id /* CTCarrier */)serviceSubscriberCellularProvider {
    id carrier = %orig;
    FDLog(@"CTTelephonyNetworkInfo.serviceSubscriberCellularProvider", @"%@", [carrier description]);
    return carrier;
}

@end

%hook CTCarrier

- (NSString *)mobileCountryCode {
    NSString *real = %orig;
    FDLog(@"CTCarrier.mobileCountryCode", @"%@", real);
    return real;
}

- (NSString *)mobileNetworkCode {
    NSString *real = %orig;
    FDLog(@"CTCarrier.mobileNetworkCode", @"%@", real);
    return real;
}

- (NSString *)isoCountryCode {
    NSString *real = %orig;
    FDLog(@"CTCarrier.isoCountryCode", @"%@", real);
    return real;
}

@end

%ctor {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        FDLog(@"UIApplicationDidFinishLaunching", @"app started");
    }];

    FDLog(@"FingerDump", @"Tweak loaded into %@", [[NSBundle mainBundle] bundleIdentifier]);

    mkdir("/var/mobile/Library/FingerDump", 0755);

    FILE *log = fopen("/var/mobile/Library/FingerDump/tweak_init.log", "a");
    if (log) {
        fprintf(log, "[%ld] Tweak loaded: %s\n", time(NULL), [[[NSBundle mainBundle] bundleIdentifier] UTF8String]);
        fclose(log);
    }
}
