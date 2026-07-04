#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include "scanner.h"
#include "shared/types.h"
#include "shared/categories.c"

void fd_scan_all(fd_scan_result_t *result) {
    memset(result, 0, sizeof(fd_scan_result_t));
    result->category_count = CAT_COUNT;

    struct timespec tv;
    clock_gettime(CLOCK_REALTIME, &tv);
    struct tm *tm_info = localtime(&tv.tv_sec);
    strftime(result->timestamp, sizeof(result->timestamp), "%Y-%m-%dT%H:%M:%S", tm_info);

    snprintf(result->scan_id, sizeof(result->scan_id), "scan_%ld_%03ld", (long)tv.tv_sec, (long)(tv.tv_nsec / 1000000));

    snprintf(result->device_name, sizeof(result->device_name), "%s", "iOS Device");
    snprintf(result->ios_version, sizeof(result->ios_version), "%s", "iOS (unknown)");

    {
        Class uidevice = objc_getClass("UIDevice");
        if (uidevice) {
            id dev = ((id (*)(id, SEL))(void *)objc_msgSend)((id)uidevice, sel_registerName("currentDevice"));
            if (dev) {
                id name = ((id (*)(id, SEL))(void *)objc_msgSend)(dev, sel_registerName("name"));
                if (name) {
                    const char *cname = ((const char *(*)(id, SEL))(void *)objc_msgSend)(name, sel_registerName("UTF8String"));
                    if (cname) snprintf(result->device_name, sizeof(result->device_name), "%s", cname);
                }
                id ver = ((id (*)(id, SEL))(void *)objc_msgSend)(dev, sel_registerName("systemVersion"));
                if (ver) {
                    const char *cver = ((const char *(*)(id, SEL))(void *)objc_msgSend)(ver, sel_registerName("UTF8String"));
                    if (cver) snprintf(result->ios_version, sizeof(result->ios_version), "%s", cver);
                }
            }
        }
    }

    fd_scan_hardware(&result->categories[CAT_HARDWARE]);
    fd_scan_system(&result->categories[CAT_SYSTEM]);
    fd_scan_network(&result->categories[CAT_NETWORK]);
    fd_scan_graphics(&result->categories[CAT_GRAPHICS]);
    fd_scan_audio(&result->categories[CAT_AUDIO]);
    fd_scan_sensor(&result->categories[CAT_SENSOR]);
    fd_scan_fonts(&result->categories[CAT_FONT]);
    fd_scan_persistence(&result->categories[CAT_PERSISTENCE]);
    fd_scan_behavioral(&result->categories[CAT_BEHAVIORAL]);
    fd_scan_browser(&result->categories[CAT_BROWSER]);
}

void fd_scan_category(fd_scan_result_t *result, identifier_category_t cat) {
    memset(result, 0, sizeof(fd_scan_result_t));
    result->category_count = 1;

    struct timespec tv;
    clock_gettime(CLOCK_REALTIME, &tv);
    struct tm *tm_info = localtime(&tv.tv_sec);
    strftime(result->timestamp, sizeof(result->timestamp), "%Y-%m-%dT%H:%M:%S", tm_info);
    snprintf(result->scan_id, sizeof(result->scan_id), "scan_%ld", (long)tv.tv_sec);

    switch (cat) {
        case CAT_HARDWARE:    fd_scan_hardware(&result->categories[0]); break;
        case CAT_SYSTEM:      fd_scan_system(&result->categories[0]); break;
        case CAT_NETWORK:     fd_scan_network(&result->categories[0]); break;
        case CAT_GRAPHICS:    fd_scan_graphics(&result->categories[0]); break;
        case CAT_AUDIO:       fd_scan_audio(&result->categories[0]); break;
        case CAT_SENSOR:      fd_scan_sensor(&result->categories[0]); break;
        case CAT_FONT:        fd_scan_fonts(&result->categories[0]); break;
        case CAT_PERSISTENCE: fd_scan_persistence(&result->categories[0]); break;
        case CAT_BEHAVIORAL:  fd_scan_behavioral(&result->categories[0]); break;
        case CAT_BROWSER:     fd_scan_browser(&result->categories[0]); break;
        default: break;
    }
    result->categories[0].category = cat;
}

static void json_escape(const char *in, char *out, size_t len) {
    size_t j = 0;
    for (size_t i = 0; in[i] && j < len - 2; i++) {
        switch (in[i]) {
            case '"':  if (j < len - 3) { out[j++] = '\\'; out[j++] = '"'; } break;
            case '\\': if (j < len - 3) { out[j++] = '\\'; out[j++] = '\\'; } break;
            case '\n': if (j < len - 3) { out[j++] = '\\'; out[j++] = 'n'; } break;
            case '\r': if (j < len - 3) { out[j++] = '\\'; out[j++] = 'r'; } break;
            case '\t': if (j < len - 3) { out[j++] = '\\'; out[j++] = 't'; } break;
            default:   if ((unsigned char)in[i] >= 32) out[j++] = in[i]; break;
        }
    }
    out[j] = 0;
}

void fd_scan_result_to_json(fd_scan_result_t *result, char *out, size_t len) {
    char *p = out;
    size_t remaining = len;

#define APPEND(...) do { \
    int n = snprintf(p, remaining, __VA_ARGS__); \
    if (n > 0) { p += n; if ((size_t)n < remaining) remaining -= n; else remaining = 0; } \
} while(0)

    APPEND("{\n");
    char esc[2048];
    json_escape(result->scan_id, esc, sizeof(esc));
    APPEND("  \"scan_id\": \"%s\",\n", esc);
    json_escape(result->device_name, esc, sizeof(esc));
    APPEND("  \"device_name\": \"%s\",\n", esc);
    json_escape(result->ios_version, esc, sizeof(esc));
    APPEND("  \"ios_version\": \"%s\",\n", esc);
    json_escape(result->timestamp, esc, sizeof(esc));
    APPEND("  \"timestamp\": \"%s\",\n", esc);

    int total_identifiers = 0, total_leaking = 0, total_spoofed = 0;
    for (int c = 0; c < result->category_count; c++) {
        total_identifiers += result->categories[c].count;
        for (int id = 0; id < result->categories[c].count; id++) {
            if (result->categories[c].identifiers[id].is_leaking) total_leaking++;
            if (result->categories[c].identifiers[id].is_spoofed) total_spoofed++;
        }
    }

    APPEND("  \"metadata\": {\n"
           "    \"total_identifiers\": %d,\n"
           "    \"total_leaking\": %d,\n"
           "    \"total_spoofed\": %d\n"
           "  },\n", total_identifiers, total_leaking, total_spoofed);

    APPEND("  \"categories\": [\n");

    int first_cat = 1;
    for (int c = 0; c < result->category_count; c++) {
        fd_category_result_t *cat = &result->categories[c];
        if (cat->count == 0) continue;

        const char *cat_name = "unknown";
        if (cat->category >= 0 && cat->category < CAT_COUNT)
            cat_name = fd_category_names[cat->category];

        if (!first_cat) APPEND(",\n");
        first_cat = 0;

        APPEND("    {\n"
               "      \"category\": %d,\n"
               "      \"name\": \"%s\",\n"
               "      \"count\": %d,\n"
               "      \"identifiers\": [\n", cat->category, cat_name, cat->count);

        for (int id = 0; id < cat->count; id++) {
            fd_identifier_t *ident = &cat->identifiers[id];
            char ek[512], en[512], ed[512], er[2048], es[2048];
            json_escape(ident->key, ek, sizeof(ek));
            json_escape(ident->name, en, sizeof(en));
            json_escape(ident->description, ed, sizeof(ed));
            json_escape(ident->real_value, er, sizeof(er));
            json_escape(ident->spoofed_value, es, sizeof(es));

            APPEND("        {\n"
                   "          \"key\": \"%s\",\n"
                   "          \"name\": \"%s\",\n"
                   "          \"description\": \"%s\",\n"
                   "          \"real_value\": \"%s\",\n"
                   "          \"spoofed_value\": \"%s\",\n"
                   "          \"is_spoofed\": %s,\n"
                   "          \"is_leaking\": %s,\n"
                   "          \"is_available\": %s\n"
                   "        }",
                   ek, en, ed, er, es,
                   ident->is_spoofed ? "true" : "false",
                   ident->is_leaking ? "true" : "false",
                   ident->is_available ? "true" : "false");

            if (id < cat->count - 1) APPEND(",");
            APPEND("\n");
        }
        APPEND("      ]\n");
        APPEND("    }");
    }
    APPEND("\n  ]\n");
    APPEND("}\n");
#undef APPEND
}
