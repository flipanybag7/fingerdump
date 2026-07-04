#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreText/CoreText.h>
#include "shared/types.h"

void fd_scan_fonts(fd_category_result_t *result) {
    result->category = CAT_FONT;
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
    result->identifiers[i].category = CAT_FONT; \
    i++; \
} while(0)

    char val[4096];
    CFArrayRef fontFamilies = CTFontCopyAvailableFamilies();
    if (fontFamilies) {
        CFIndex count = CFArrayGetCount(fontFamilies);
        int printed = 0;
        char buf[4096] = {0};
        for (CFIndex j = 0; j < count && j < 100; j++) {
            CFStringRef family = CFArrayGetValueAtIndex(fontFamilies, j);
            if (family) {
                char fname[256] = {0};
                CFStringGetCString(family, fname, sizeof(fname), kCFStringEncodingUTF8);
                if (buf[0]) strncat(buf, ", ", sizeof(buf) - strlen(buf) - 1);
                strncat(buf, fname, sizeof(buf) - strlen(buf) - 1);
                printed++;
            }
        }
        snprintf(val, sizeof(val), "%s", buf);
        ADD_IDENT("font.system_families", "System font families", "CTFontCopyAvailableFamilies", val, "", false, true, true);

        snprintf(val, sizeof(val), "%ld total fonts (showing %d)", (long)count, printed);
        ADD_IDENT("font.count", "Font count", "Total number of available font families", val, "", false, true, true);

        CFRelease(fontFamilies);
    } else {
        ADD_IDENT("font.system_families", "System font families", "CTFontCopyAvailableFamilies", "unavailable", "", false, true, true);
        ADD_IDENT("font.count", "Font count", "Total number of available font families", "unavailable", "", false, true, true);
    }

    {
        CFArrayRef descriptors = CTFontCopyDefaultCascadeListForLanguages((CTFontRef)CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, 12.0, NULL), NULL);
        if (descriptors) {
            snprintf(val, sizeof(val), "%ld cascade list entries", (long)CFArrayGetCount(descriptors));
            CFRelease(descriptors);
        } else { snprintf(val, sizeof(val), "unavailable"); }
        ADD_IDENT("font.cascade_list", "Font cascade list", "Default cascade list for system font", val, "", false, true, true);
    }

    result->count = i;
}
