#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include "shared/types.h"

static void get_screen_info(char *out_res, size_t res_len, char *out_scale, size_t scale_len,
                             char *out_brightness, size_t br_len) {
    Class uscreen = objc_getClass("UIScreen");
    if (!uscreen) {
        snprintf(out_res, res_len, "unavailable"); snprintf(out_scale, scale_len, "unavailable");
        snprintf(out_brightness, br_len, "unavailable"); return;
    }
    id mainScreen = ((id (*)(id, SEL))(void *)objc_msgSend)((id)uscreen, sel_registerName("mainScreen"));
    if (!mainScreen) {
        snprintf(out_res, res_len, "unavailable"); snprintf(out_scale, scale_len, "unavailable");
        snprintf(out_brightness, br_len, "unavailable"); return;
    }

    CGRect bounds = ((CGRect (*)(id, SEL))(void *)objc_msgSend)(mainScreen, sel_registerName("bounds"));
    CGFloat scale = ((CGFloat (*)(id, SEL))(void *)objc_msgSend)(mainScreen, sel_registerName("scale"));
    CGFloat brightness = ((CGFloat (*)(id, SEL))(void *)objc_msgSend)(mainScreen, sel_registerName("brightness"));

    snprintf(out_res, res_len, "%.0fx%.0f (native: %.0fx%.0f)",
             bounds.size.width, bounds.size.height,
             bounds.size.width * scale, bounds.size.height * scale);
    snprintf(out_scale, scale_len, "%.1f", scale);
    snprintf(out_brightness, br_len, "%.2f", brightness);
}

static void get_gpu_info(char *out, size_t len) {
    Class mtldev = objc_getClass("MTLCreateSystemDefaultDevice");
    if (mtldev) {
        id device = ((id (*)(void))(void *)mtldev)();
        if (device) {
            char *name = strdup(((const char *(*)(id, SEL))(void *)objc_msgSend)(device, sel_registerName("name")));
            uint64_t maxBufLen = ((uint64_t (*)(id, SEL))(void *)objc_msgSend)(device, sel_registerName("maxBufferLength"));
            BOOL lowPower = ((BOOL (*)(id, SEL))(void *)objc_msgSend)(device, sel_registerName("isLowPower"));
            BOOL headless = ((BOOL (*)(id, SEL))(void *)objc_msgSend)(device, sel_registerName("isHeadless"));
            BOOL removable = ((BOOL (*)(id, SEL))(void *)objc_msgSend)(device, sel_registerName("isRemovable"));
            snprintf(out, len, "%s | maxBuffer: %llu MB | lowPower:%s headless:%s removable:%s",
                     name ? name : "unknown",
                     (unsigned long long)(maxBufLen / (1024*1024)),
                     lowPower ? "Y" : "N", headless ? "Y" : "N", removable ? "Y" : "N");
            if (name) free(name);
            return;
        }
    }

    Class glkview = objc_getClass("GLKView");
    if (glkview) {
        snprintf(out, len, "OpenGL ES available (Metal fallback)");
        return;
    }
    snprintf(out, len, "unavailable");
}

static void get_opengl_info(char *out, size_t len) {
    Class eagl = objc_getClass("EAGLContext");
    if (!eagl) { snprintf(out, len, "unavailable"); return; }
    id ctx = ((id (*)(id, SEL))(void *)objc_msgSend)((id)eagl, sel_registerName("alloc"));
    ctx = ((id (*)(id, SEL, id))(void *)objc_msgSend)(ctx, sel_registerName("initWithAPI:"), (id)1);
    if (!ctx) {
        ctx = ((id (*)(id, SEL))(void *)objc_msgSend)((id)eagl, sel_registerName("alloc"));
        ctx = ((id (*)(id, SEL, id))(void *)objc_msgSend)(ctx, sel_registerName("initWithAPI:"), (id)2);
    }
    if (!ctx) { snprintf(out, len, "unavailable"); return; }

    id glkview = objc_getClass("GLKView");
    id view = ((id (*)(id, SEL))(void *)objc_msgSend)((id)glkview, sel_registerName("alloc"));
    view = ((id (*)(id, SEL))(void *)objc_msgSend)(view, sel_registerName("init"));
    if (view) {
        ((void (*)(id, SEL, id))(void *)objc_msgSend)(view, sel_registerName("setContext:"), ctx);
        id renderer = ((id (*)(id, SEL))(void *)objc_msgSend)(ctx, sel_registerName("API"));
        snprintf(out, len, "EAGL API version: %ld", (long)((NSInteger)renderer));
    } else {
        snprintf(out, len, "EAGL context created (version unknown)");
    }
}

static void get_display_info(char *out, size_t len) {
    Class uscreen = objc_getClass("UIScreen");
    if (!uscreen) { snprintf(out, len, "unavailable"); return; }

    id mainScreen = ((id (*)(id, SEL))(void *)objc_msgSend)((id)uscreen, sel_registerName("mainScreen"));
    if (!mainScreen) { snprintf(out, len, "unavailable"); return; }

    CGRect bounds = ((CGRect (*)(id, SEL))(void *)objc_msgSend)(mainScreen, sel_registerName("bounds"));
    CGFloat scale = ((CGFloat (*)(id, SEL))(void *)objc_msgSend)(mainScreen, sel_registerName("scale"));
    CGFloat brightness = ((CGFloat (*)(id, SEL))(void *)objc_msgSend)(mainScreen, sel_registerName("brightness"));
    id traitCollection = ((id (*)(id, SEL))(void *)objc_msgSend)(mainScreen, sel_registerName("traitCollection"));
    NSInteger displayGamut = traitCollection ? ((NSInteger (*)(id, SEL))(void *)objc_msgSend)(traitCollection, sel_registerName("displayGamut")) : 0;

    snprintf(out, len, "UIScreen: %.0fx%.0f scale=%.1f brightness=%.2f gamut=%ld",
             bounds.size.width, bounds.size.height,
             (double)scale, (double)brightness, (long)displayGamut);
}

void fd_scan_graphics(fd_category_result_t *result) {
    result->category = CAT_GRAPHICS;
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
    result->identifiers[i].category = CAT_GRAPHICS; \
    i++; \
} while(0)

    char val[512], val2[512], val3[512];

    get_screen_info(val, sizeof(val), val2, sizeof(val2), val3, sizeof(val3));
    ADD_IDENT("gfx.screen_bounds", "Screen resolution", "UIScreen bounds (points and native pixels)", val, "", false, true, true);
    ADD_IDENT("gfx.screen_scale", "Screen scale", "UIScreen scale factor", val2, "", false, true, true);
    ADD_IDENT("gfx.screen_brightness", "Screen brightness", "UIScreen brightness level", val3, "", false, true, true);

    get_gpu_info(val, sizeof(val));
    ADD_IDENT("gfx.gpu", "GPU info", "Metal GPU device name and properties", val, "", false, true, true);

    get_opengl_info(val, sizeof(val));
    ADD_IDENT("gfx.opengl", "OpenGL ES", "OpenGL ES API version / capabilities", val, "", false, true, true);

    get_display_info(val, sizeof(val));
    ADD_IDENT("gfx.display", "Display hardware", "CoreGraphics display IDs, sizes, refresh rates", val, "", false, true, true);

    {
        Class uscreen = objc_getClass("UIScreen");
        if (uscreen) {
            id ms = ((id (*)(id, SEL))(void *)objc_msgSend)((id)uscreen, sel_registerName("mainScreen"));
            CGFloat sc = ms ? ((CGFloat (*)(id, SEL))(void *)objc_msgSend)(ms, sel_registerName("scale")) : 1.0;
            snprintf(val, sizeof(val), "32-bit (scale=%.1f)", (double)sc);
        } else { snprintf(val, sizeof(val), "unknown (no UIScreen)"); }
        ADD_IDENT("gfx.color_depth", "Color depth", "Display color depth (iOS: 32-bit assumed)", val, "", false, true, true);
    }

    ADD_IDENT("gfx.canvas_fp", "Canvas fingerprint (WebView)", "Canvas 2D fingerprint via JS (load web test page)", "(run web test)", "", false, true, false);
    ADD_IDENT("gfx.webgl_fp", "WebGL fingerprint (WebView)", "WebGL renderer/vendor fingerprint via JS", "(run web test)", "", false, true, false);

    result->count = i;
}
