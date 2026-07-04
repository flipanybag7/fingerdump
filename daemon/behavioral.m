#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <CoreFoundation/CoreFoundation.h>
#include <sys/sysctl.h>
#include <time.h>
#include "shared/types.h"

static void get_locale_info(char *out_lang, size_t lang_len, char *out_region, size_t reg_len,
                             char *out_prefs, size_t prefs_len) {
    Class nslocale = objc_getClass("NSLocale");
    if (!nslocale) {
        snprintf(out_lang, lang_len, "unavailable");
        snprintf(out_region, reg_len, "unavailable");
        snprintf(out_prefs, prefs_len, "unavailable");
        return;
    }
    id currentLocale = ((id (*)(id, SEL))(void *)objc_msgSend)((id)nslocale, sel_registerName("currentLocale"));
    if (!currentLocale) {
        snprintf(out_lang, lang_len, "unavailable");
        snprintf(out_region, reg_len, "unavailable");
        snprintf(out_prefs, prefs_len, "unavailable");
        return;
    }

    id langCode = ((id (*)(id, SEL))(void *)objc_msgSend)(currentLocale, sel_registerName("languageCode"));
    if (langCode) {
        char *s = strdup(((const char *(*)(id, SEL))(void *)objc_msgSend)(langCode, sel_registerName("UTF8String")));
        snprintf(out_lang, lang_len, "%s", s);
        free(s);
    } else { snprintf(out_lang, lang_len, "unavailable"); }

    id countryCode = ((id (*)(id, SEL))(void *)objc_msgSend)(currentLocale, sel_registerName("countryCode"));
    if (countryCode) {
        char *s = strdup(((const char *(*)(id, SEL))(void *)objc_msgSend)(countryCode, sel_registerName("UTF8String")));
        snprintf(out_region, reg_len, "%s", s);
        free(s);
    } else { snprintf(out_region, reg_len, "unavailable"); }

    id preferredLangs = ((id (*)(id, SEL))(void *)objc_msgSend)((id)nslocale, sel_registerName("preferredLanguages"));
    if (preferredLangs) {
        char *s = strdup(((const char *(*)(id, SEL))(void *)objc_msgSend)(preferredLangs, sel_registerName("description")));
        snprintf(out_prefs, prefs_len, "%s", s);
        free(s);
    } else { snprintf(out_prefs, prefs_len, "unavailable"); }
}

static void get_timezone(char *out, size_t len) {
    Class nstz = objc_getClass("NSTimeZone");
    if (!nstz) { snprintf(out, len, "unavailable"); return; }
    id local = ((id (*)(id, SEL))(void *)objc_msgSend)((id)nstz, sel_registerName("localTimeZone"));
    if (!local) { snprintf(out, len, "unavailable"); return; }
    id tzName = ((id (*)(id, SEL))(void *)objc_msgSend)(local, sel_registerName("name"));
    if (tzName) {
        char *s = strdup(((const char *(*)(id, SEL))(void *)objc_msgSend)(tzName, sel_registerName("UTF8String")));
        snprintf(out, len, "%s", s);
        free(s);
    } else { snprintf(out, len, "unavailable"); }
}

static void get_keyboard_info(char *out, size_t len) {
    Class tim = objc_getClass("UITextInputMode");
    if (tim) {
        id current = ((id (*)(id, SEL))(void *)objc_msgSend)((id)tim, sel_registerName("currentInputMode"));
        if (current) {
            id lang = ((id (*)(id, SEL))(void *)objc_msgSend)(current, sel_registerName("primaryLanguage"));
            if (lang) {
                char *s = strdup(((const char *(*)(id, SEL))(void *)objc_msgSend)(lang, sel_registerName("UTF8String")));
                snprintf(out, len, "%s", s);
                free(s);
                return;
            }
        }
    }
    {
        Class kb = objc_getClass("UIKeyboard");
        if (kb) {
            id active = ((id (*)(id, SEL))(void *)objc_msgSend)((id)kb, sel_registerName("activeKeyboard"));
            if (active) {
                id lang = ((id (*)(id, SEL))(void *)objc_msgSend)(active, sel_registerName("language"));
                if (lang) {
                    char *s = strdup(((const char *(*)(id, SEL))(void *)objc_msgSend)(lang, sel_registerName("UTF8String")));
                    snprintf(out, len, "%s", s);
                    free(s);
                    return;
                }
            }
        }
        snprintf(out, len, "unavailable");
    }
}

static void get_accessibility_info(char *out, size_t len) {
    Class uia = objc_getClass("UIAccessibility");
    if (!uia) { snprintf(out, len, "unavailable"); return; }

    BOOL bold = ((BOOL (*)(id, SEL))(void *)objc_msgSend)((id)uia, sel_registerName("isBoldTextEnabled"));
    BOOL buttonShapes = ((BOOL (*)(id, SEL))(void *)objc_msgSend)((id)uia, sel_registerName("isButtonShapesEnabled"));
    BOOL reduceMotion = ((BOOL (*)(id, SEL))(void *)objc_msgSend)((id)uia, sel_registerName("isReduceMotionEnabled"));
    BOOL reduceTransparency = ((BOOL (*)(id, SEL))(void *)objc_msgSend)((id)uia, sel_registerName("isReduceTransparencyEnabled"));
    BOOL increaseContrast = ((BOOL (*)(id, SEL))(void *)objc_msgSend)((id)uia, sel_registerName("isDarkerSystemColorsEnabled"));
    BOOL grayscale = ((BOOL (*)(id, SEL))(void *)objc_msgSend)((id)uia, sel_registerName("isGrayscaleEnabled"));
    BOOL speakSelection = ((BOOL (*)(id, SEL))(void *)objc_msgSend)((id)uia, sel_registerName("isSpeakSelectionEnabled"));
    BOOL onOffLabels = ((BOOL (*)(id, SEL))(void *)objc_msgSend)((id)uia, sel_registerName("isOnOffSwitchLabelsEnabled"));

    snprintf(out, len, "bold:%s buttonShapes:%s reduceMotion:%s reduceTransparency:%s "
             "increaseContrast:%s grayscale:%s speakSelection:%s onOffLabels:%s",
             bold ? "Y" : "N", buttonShapes ? "Y" : "N",
             reduceMotion ? "Y" : "N", reduceTransparency ? "Y" : "N",
             increaseContrast ? "Y" : "N", grayscale ? "Y" : "N",
             speakSelection ? "Y" : "N", onOffLabels ? "Y" : "N");
}

void fd_scan_behavioral(fd_category_result_t *result) {
    result->category = CAT_BEHAVIORAL;
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
    result->identifiers[i].category = CAT_BEHAVIORAL; \
    i++; \
} while(0)

    char lang[512], region[512], prefs[512], val[512];

    get_locale_info(lang, sizeof(lang), region, sizeof(region), prefs, sizeof(prefs));
    ADD_IDENT("behave.language", "Language code", "NSLocale.currentLocale.languageCode", lang, "", false, true, true);
    ADD_IDENT("behave.region", "Region code", "NSLocale.currentLocale.countryCode", region, "", false, true, true);
    ADD_IDENT("behave.preferred_langs", "Preferred languages", "NSLocale preferredLanguages array", prefs, "", false, true, true);

    get_timezone(val, sizeof(val));
    ADD_IDENT("behave.timezone", "Time zone", "NSTimeZone.localTimeZone.name", val, "", false, true, true);

    {
        BOOL is24 = ((BOOL (*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("UIDatePicker"), sel_registerName("datePickerMode"));
        (void)is24;
        snprintf(val, sizeof(val), "check locale/capability");
        ADD_IDENT("behave.time_format", "Time format", "System time format setting (12h vs 24h)", val, "", false, true, true);
    }

    get_keyboard_info(val, sizeof(val));
    ADD_IDENT("behave.keyboard", "Active keyboard", "Current input method / keyboard language", val, "", false, true, true);

    get_accessibility_info(val, sizeof(val));
    ADD_IDENT("behave.accessibility", "Accessibility settings", "UIAccessibility flags (bold, reduce motion, contrast, etc.)", val, "", false, true, true);

    {
        Class nsud = objc_getClass("NSUserDefaults");
        if (nsud) {
            id ud = ((id (*)(id, SEL))(void *)objc_msgSend)((id)nsud, sel_registerName("standardUserDefaults"));
            if (ud) {
                id appleLocale = ((id (*)(id, SEL, id))(void *)objc_msgSend)(ud, sel_registerName("objectForKey:"), (id)CFSTR("AppleLocale"));
                if (appleLocale) {
                    char *s = strdup(((const char *(*)(id, SEL))(void *)objc_msgSend)(appleLocale, sel_registerName("UTF8String")));
                    snprintf(val, sizeof(val), "%s", s);
                    free(s);
                } else { snprintf(val, sizeof(val), "unavailable"); }
            } else { snprintf(val, sizeof(val), "unavailable"); }
        } else { snprintf(val, sizeof(val), "unavailable"); }
        ADD_IDENT("behave.apple_locale", "AppleLocale", "NSUserDefaults AppleLocale override", val, "", false, true, true);
    }

    {
        Class nsud = objc_getClass("NSUserDefaults");
        if (nsud) {
            id ud = ((id (*)(id, SEL))(void *)objc_msgSend)((id)nsud, sel_registerName("standardUserDefaults"));
            if (ud) {
                id metric = ((id (*)(id, SEL, id))(void *)objc_msgSend)(ud, sel_registerName("objectForKey:"), (id)CFSTR("AppleMetricUnits"));
                if (metric) {
                    BOOL metricVal = ((BOOL (*)(id, SEL))(void *)objc_msgSend)(metric, sel_registerName("boolValue"));
                    snprintf(val, sizeof(val), "%s", metricVal ? "metric" : "imperial");
                } else { snprintf(val, sizeof(val), "unavailable"); }
            } else { snprintf(val, sizeof(val), "unavailable"); }
        } else { snprintf(val, sizeof(val), "unavailable"); }
        ADD_IDENT("behave.metric_units", "Metric units", "AppleMetricUnits preference", val, "", false, true, true);
    }

    {
        int64_t boottime_sec = 0;
        struct timeval boottime;
        size_t size = sizeof(boottime);
        int mib[2] = { CTL_KERN, KERN_BOOTTIME };
        if (sysctl(mib, 2, &boottime, &size, NULL, 0) == 0) {
            boottime_sec = boottime.tv_sec;
        }
        struct timespec ts;
        clock_gettime(CLOCK_UPTIME_RAW, &ts);
        snprintf(val, sizeof(val), "boot=%.0f uptime=%.0fs", (double)boottime_sec, (double)ts.tv_sec);
        ADD_IDENT("behave.uptime", "System uptime", "System boot time and raw uptime", val, "", false, true, true);
    }

    result->count = i;
}
