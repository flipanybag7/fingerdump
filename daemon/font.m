#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <CoreFoundation/CoreFoundation.h>
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
    Class uifont = objc_getClass("UIFont");

    if (uifont) {
        id familyNames = ((id (*)(id, SEL))(void *)objc_msgSend)((id)uifont, sel_registerName("familyNames"));
        if (familyNames) {
            unsigned long count = ((unsigned long (*)(id, SEL))(void *)objc_msgSend)(familyNames, sel_registerName("count"));
            char buf[4096] = {0};
            unsigned long printed = 0;
            for (unsigned long j = 0; j < count && j < 100; j++) {
                id name = ((id (*)(id, SEL, unsigned long))(void *)objc_msgSend)(familyNames, sel_registerName("objectAtIndex:"), j);
                if (name) {
                    const char *cname = ((const char *(*)(id, SEL))(void *)objc_msgSend)(name, sel_registerName("UTF8String"));
                    if (cname) {
                        if (buf[0]) strncat(buf, ", ", sizeof(buf) - strlen(buf) - 1);
                        strncat(buf, cname, sizeof(buf) - strlen(buf) - 1);
                        printed++;
                    }
                }
            }
            snprintf(val, sizeof(val), "%s", buf);
            ADD_IDENT("font.family_names", "Font family names", "UIFont.familyNames (iOS API)", val, "", false, true, true);

            snprintf(val, sizeof(val), "%lu total families (showing %lu)", (unsigned long)count, printed);
            ADD_IDENT("font.count", "Font family count", "Total number of available font families", val, "", false, true, true);
        } else {
            ADD_IDENT("font.family_names", "Font family names", "UIFont.familyNames", "unavailable", "", false, true, true);
        }
    } else {
        ADD_IDENT("font.family_names", "Font family names", "UIFont.familyNames", "unavailable (no UIFont)", "", false, true, true);
    }

    result->count = i;
}
