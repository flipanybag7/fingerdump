#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <CoreFoundation/CoreFoundation.h>
#include <UIKit/UIDevice.h>
#include <sys/sysctl.h>
#include "shared/types.h"

static char *copy_objc_string(id obj, SEL sel) {
    if (!obj || !sel) return strdup("unavailable");
    id val = ((id (*)(id, SEL))(void *)objc_msgSend)(obj, sel);
    if (!val) return strdup("null");
    const char *cstr = ((const char *(*)(id, SEL))(void *)objc_msgSend)(val, sel_registerName("UTF8String"));
    if (!cstr) return strdup("null");
    return strdup(cstr);
}

static void get_idfv(char *out, size_t len) {
    Class uidevice = objc_getClass("UIDevice");
    if (!uidevice) { snprintf(out, len, "unavailable"); return; }
    id device = ((id (*)(id, SEL))(void *)objc_msgSend)((id)uidevice, sel_registerName("currentDevice"));
    if (!device) { snprintf(out, len, "unavailable"); return; }
    id uuid = ((id (*)(id, SEL))(void *)objc_msgSend)(device, sel_registerName("identifierForVendor"));
    if (!uuid) { snprintf(out, len, "unavailable"); return; }
    char *s = copy_objc_string(uuid, sel_registerName("UUIDString"));
    snprintf(out, len, "%s", s);
    free(s);
}

static void get_idfa(char *out, size_t len) {
    Class asmanager = objc_getClass("ASIdentifierManager");
    if (!asmanager) { snprintf(out, len, "unavailable (ASIdentifierManager not found)"); return; }
    id manager = ((id (*)(id, SEL))(void *)objc_msgSend)((id)asmanager, sel_registerName("sharedManager"));
    if (!manager) { snprintf(out, len, "unavailable"); return; }
    id idfa = ((id (*)(id, SEL))(void *)objc_msgSend)(manager, sel_registerName("advertisingIdentifier"));
    if (!idfa) { snprintf(out, len, "unavailable"); return; }
    BOOL tracked = ((BOOL (*)(id, SEL))(void *)objc_msgSend)(manager, sel_registerName("isAdvertisingTrackingEnabled"));
    char *s = copy_objc_string(idfa, sel_registerName("UUIDString"));
    snprintf(out, len, "%s (tracking: %s)", s, tracked ? "yes" : "no");
    free(s);
}

static void get_device_name(char *out, size_t len) {
    Class uidevice = objc_getClass("UIDevice");
    if (!uidevice) { snprintf(out, len, "unavailable"); return; }
    id device = ((id (*)(id, SEL))(void *)objc_msgSend)((id)uidevice, sel_registerName("currentDevice"));
    char *s = copy_objc_string(device, sel_registerName("name"));
    snprintf(out, len, "%s", s);
    free(s);
}

static void get_system_version(char *out, size_t len) {
    Class uidevice = objc_getClass("UIDevice");
    if (!uidevice) { snprintf(out, len, "unavailable"); return; }
    id device = ((id (*)(id, SEL))(void *)objc_msgSend)((id)uidevice, sel_registerName("currentDevice"));
    char *sv = copy_objc_string(device, sel_registerName("systemVersion"));
    char *sn = copy_objc_string(device, sel_registerName("systemName"));
    snprintf(out, len, "%s %s", sn, sv);
    free(sv); free(sn);
}

static void get_localized_model(char *out, size_t len) {
    Class uidevice = objc_getClass("UIDevice");
    if (!uidevice) { snprintf(out, len, "unavailable"); return; }
    id device = ((id (*)(id, SEL))(void *)objc_msgSend)((id)uidevice, sel_registerName("currentDevice"));
    char *s = copy_objc_string(device, sel_registerName("localizedModel"));
    snprintf(out, len, "%s", s);
    free(s);
}

static void get_user_interface_idiom(char *out, size_t len) {
    Class uidevice = objc_getClass("UIDevice");
    if (!uidevice) { snprintf(out, len, "unavailable"); return; }
    id device = ((id (*)(id, SEL))(void *)objc_msgSend)((id)uidevice, sel_registerName("currentDevice"));
    NSInteger idiom = ((NSInteger (*)(id, SEL))(void *)objc_msgSend)(device, sel_registerName("userInterfaceIdiom"));
    const char *names[] = {"unspecified", "phone", "pad", "tv", "carplay", "mac", "vision"};
    if (idiom >= 0 && idiom < 7) snprintf(out, len, "%s (%ld)", names[idiom], (long)idiom);
    else snprintf(out, len, "unknown (%ld)", (long)idiom);
}

static void get_build_version(char *out, size_t len) {
    char buf[256] = {0};
    size_t n = sizeof(buf) - 1;
    int mib[2] = { CTL_KERN, KERN_OSVERSION };
    if (sysctl(mib, 2, buf, &n, NULL, 0) == 0) {
        snprintf(out, len, "%s", buf);
    } else {
        snprintf(out, len, "unavailable");
    }
}

static void get_os_release(char *out, size_t len) {
    char buf[256] = {0};
    size_t n = sizeof(buf) - 1;
    int mib[2] = { CTL_KERN, KERN_OSRELEASE };
    if (sysctl(mib, 2, buf, &n, NULL, 0) == 0) {
        snprintf(out, len, "%s", buf);
    } else {
        snprintf(out, len, "unavailable");
    }
}

static void get_hostname(char *out, size_t len) {
    char buf[256] = {0};
    if (gethostname(buf, sizeof(buf)) == 0) {
        snprintf(out, len, "%s", buf);
    } else {
        snprintf(out, len, "unavailable");
    }
}

static void get_process_info(void) {
}

void fd_scan_system(fd_category_result_t *result) {
    result->category = CAT_SYSTEM;
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
    result->identifiers[i].category = CAT_SYSTEM; \
    i++; \
} while(0)

    char val[512];

    get_idfv(val, sizeof(val));
    ADD_IDENT("system.idfv", "Identifier for Vendor (IDFV)", "UIDevice.currentDevice.identifierForVendor", val, "", false, true, true);

    get_idfa(val, sizeof(val));
    ADD_IDENT("system.idfa", "Advertising Identifier (IDFA)", "ASIdentifierManager.sharedManager.advertisingIdentifier", val, "", false, true, true);

    get_device_name(val, sizeof(val));
    ADD_IDENT("system.device_name", "Device name", "UIDevice.currentDevice.name", val, "", false, true, true);

    get_system_version(val, sizeof(val));
    ADD_IDENT("system.version", "System version", "UIDevice.currentDevice.systemVersion + systemName", val, "", false, true, true);

    get_localized_model(val, sizeof(val));
    ADD_IDENT("system.localized_model", "Localized model", "UIDevice.currentDevice.localizedModel", val, "", false, true, true);

    get_user_interface_idiom(val, sizeof(val));
    ADD_IDENT("system.idiom", "User interface idiom", "UIDevice.currentDevice.userInterfaceIdiom", val, "", false, true, true);

    get_build_version(val, sizeof(val));
    ADD_IDENT("system.build", "Build version", "Kern.osversion (build number)", val, "", false, true, true);

    get_os_release(val, sizeof(val));
    ADD_IDENT("system.osrelease", "OS release", "Kern.osrelease (XNU version)", val, "", false, true, true);

    get_hostname(val, sizeof(val));
    ADD_IDENT("system.hostname", "Hostname", "gethostname() result", val, "", false, true, true);

    {
        Class npp = objc_getClass("NSProcessInfo");
        if (npp) {
            id pi = ((id (*)(id, SEL))(void *)objc_msgSend)((id)npp, sel_registerName("processInfo"));
            if (pi) {
                char *hn = copy_objc_string(pi, sel_registerName("hostName"));
                snprintf(val, sizeof(val), "%s", hn);
                free(hn);
            } else { snprintf(val, sizeof(val), "unavailable"); }
        } else { snprintf(val, sizeof(val), "unavailable"); }
        ADD_IDENT("system.process_hostname", "NSProcessInfo hostname", "NSProcessInfo.processInfo.hostName", val, "", false, true, true);
    }

    {
        Class npp = objc_getClass("NSProcessInfo");
        if (npp) {
            id pi = ((id (*)(id, SEL))(void *)objc_msgSend)((id)npp, sel_registerName("processInfo"));
            if (pi) {
                char *an = copy_objc_string(pi, sel_registerName("operatingSystemVersionString"));
                snprintf(val, sizeof(val), "%s", an);
                free(an);
            } else { snprintf(val, sizeof(val), "unavailable"); }
        } else { snprintf(val, sizeof(val), "unavailable"); }
        ADD_IDENT("system.os_version_string", "OS version string", "NSProcessInfo operatingSystemVersionString", val, "", false, true, true);
    }

    {
        Class npp = objc_getClass("NSProcessInfo");
        if (npp) {
            id pi = ((id (*)(id, SEL))(void *)objc_msgSend)((id)npp, sel_registerName("processInfo"));
            if (pi) {
                char *pn = copy_objc_string(pi, sel_registerName("processName"));
                snprintf(val, sizeof(val), "%s", pn);
                free(pn);
            } else { snprintf(val, sizeof(val), "unavailable"); }
        } else { snprintf(val, sizeof(val), "unavailable"); }
        ADD_IDENT("system.process_name", "Process name", "NSProcessInfo.processInfo.processName", val, "", false, true, true);
    }

    {
        char buf[64] = {0};
        size_t n = sizeof(buf) - 1;
        int mib[2] = { CTL_KERN, KERN_PID };
        int pid = getpid();
        mib[1] = KERN_PROC;
        struct kinfo_proc kp;
        n = sizeof(kp);
        int mib3[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, pid };
        if (sysctl(mib3, 4, &kp, &n, NULL, 0) == 0) {
            snprintf(val, sizeof(val), "%s", kp.kp_proc.p_comm);
        } else { snprintf(val, sizeof(val), "unavailable"); }
        ADD_IDENT("system.proc_comm", "Process comm", "Process command name from kinfo_proc", val, "", false, true, true);
    }

    result->count = i;
}
