#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <CoreFoundation/CoreFoundation.h>
#include <WebKit/WebKit.h>
#include "shared/types.h"

void fd_scan_browser(fd_category_result_t *result) {
    result->category = CAT_BROWSER;
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
    result->identifiers[i].category = CAT_BROWSER; \
    i++; \
} while(0)

    char val[512];

    {
        Class wkv = objc_getClass("WKWebView");
        if (wkv) {
            id config = ((id (*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("WKWebViewConfiguration"), sel_registerName("new"));
            if (config) {
                id prefs = ((id (*)(id, SEL))(void *)objc_msgSend)(config, sel_registerName("preferences"));
                if (prefs) {
                    BOOL java = ((BOOL (*)(id, SEL))(void *)objc_msgSend)(prefs, sel_registerName("javaScriptEnabled"));
                    BOOL javaCanOpen = ((BOOL (*)(id, SEL))(void *)objc_msgSend)(prefs, sel_registerName("javaScriptCanOpenWindowsAutomatically"));
                    snprintf(val, sizeof(val), "js:%s canOpenWindows:%s", java ? "Y" : "N", javaCanOpen ? "Y" : "N");
                } else { snprintf(val, sizeof(val), "unavailable"); }
                CFRelease(config);
            } else { snprintf(val, sizeof(val), "unavailable"); }
        } else { snprintf(val, sizeof(val), "unavailable (no WKWebView)"); }
        ADD_IDENT("browser.webview_config", "WKWebView config", "WKWebView default configuration preferences", val, "", false, true, true);
    }

    {
        Class wku = objc_getClass("WKUserContentController");
        if (wku) {
            id controller = ((id (*)(id, SEL))(void *)objc_msgSend)((id)wku, sel_registerName("new"));
            if (controller) {
                id scripts = ((id (*)(id, SEL))(void *)objc_msgSend)(controller, sel_registerName("userScripts"));
                if (scripts) {
                    char *s = strdup(((const char *(*)(id, SEL))(void *)objc_msgSend)(scripts, sel_registerName("description")));
                    snprintf(val, sizeof(val), "%ld scripts", (long)((id (*)(id, SEL))(void *)objc_msgSend)(scripts, sel_registerName("count")));
                    free(s);
                } else { snprintf(val, sizeof(val), "none"); }
                CFRelease(controller);
            } else { snprintf(val, sizeof(val), "unavailable"); }
        } else { snprintf(val, sizeof(val), "unavailable"); }
        ADD_IDENT("browser.user_scripts", "WKUserScripts", "WKUserContentController injected scripts", val, "", false, true, true);
    }

    {
        Class nshttp = objc_getClass("NSHTTPCookieStorage");
        if (nshttp) {
            id storage = ((id (*)(id, SEL))(void *)objc_msgSend)((id)nshttp, sel_registerName("sharedHTTPCookieStorage"));
            if (storage) {
                id cookies = ((id (*)(id, SEL))(void *)objc_msgSend)(storage, sel_registerName("cookies"));
                if (cookies) {
                    snprintf(val, sizeof(val), "%ld cookies", (long)((id (*)(id, SEL))(void *)objc_msgSend)(cookies, sel_registerName("count")));
                } else { snprintf(val, sizeof(val), "none"); }
            } else { snprintf(val, sizeof(val), "unavailable"); }
        } else { snprintf(val, sizeof(val), "unavailable"); }
        ADD_IDENT("browser.http_cookies", "HTTP cookies", "NSHTTPCookieStorage shared cookies count", val, "", false, true, true);
    }

    {
        Class nsurlcache = objc_getClass("NSURLCache");
        if (nsurlcache) {
            id cache = ((id (*)(id, SEL))(void *)objc_msgSend)((id)nsurlcache, sel_registerName("sharedURLCache"));
            if (cache) {
                NSUInteger mem = ((NSUInteger (*)(id, SEL))(void *)objc_msgSend)(cache, sel_registerName("memoryCapacity"));
                NSUInteger disk = ((NSUInteger (*)(id, SEL))(void *)objc_msgSend)(cache, sel_registerName("diskCapacity"));
                snprintf(val, sizeof(val), "memory=%lluMB disk=%lluMB",
                         (unsigned long long)(mem / (1024*1024)),
                         (unsigned long long)(disk / (1024*1024)));
            } else { snprintf(val, sizeof(val), "unavailable"); }
        } else { snprintf(val, sizeof(val), "unavailable"); }
        ADD_IDENT("browser.url_cache", "URLCache capacity", "NSURLCache shared cache capacity", val, "", false, true, true);
    }

    {
        snprintf(val, sizeof(val), "(run web test - canvas_fingerprint.js)");
        ADD_IDENT("browser.canvas_fp", "Canvas fingerprint", "JS Canvas 2D fingerprint from WKWebView", val, "", false, true, false);

        snprintf(val, sizeof(val), "(run web test - webgl_fingerprint.js)");
        ADD_IDENT("browser.webgl_fp", "WebGL fingerprint", "JS WebGL renderer/vendor from WKWebView", val, "", false, true, false);

        snprintf(val, sizeof(val), "(run web test - audio_fingerprint.js)");
        ADD_IDENT("browser.audio_fp", "AudioContext fingerprint", "JS AudioContext fingerprint from WKWebView", val, "", false, true, false);

        snprintf(val, sizeof(val), "(run web test - font_enumeration.js)");
        ADD_IDENT("browser.font_fp", "Font enumeration", "JS font enumeration from WKWebView", val, "", false, true, false);

        snprintf(val, sizeof(val), "(run web test - network_leaks.js)");
        ADD_IDENT("browser.network_fp", "Network leaks", "JS WebRTC / network leak detection from WKWebView", val, "", false, true, false);

        snprintf(val, sizeof(val), "(run fingerprint.com/demo)");
        ADD_IDENT("browser.fingerprintjs", "FingerprintJS ID", "FingerprintJS visitorId from WKWebView", val, "", false, true, false);
    }

    result->count = i;
}
