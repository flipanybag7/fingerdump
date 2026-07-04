#ifndef FINGERDUMP_LOG_H
#define FINGERDUMP_LOG_H

#include <stdio.h>
#include <time.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>

static inline void FDLog(NSString *api, NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);

    NSString *pid = [[NSProcessInfo processInfo] processName] ?: @"?";
    NSString *logLine = [NSString stringWithFormat:@"[FD] [%@] [%@] %@\n",
                         pid, api, msg];

    const char *cstr = [logLine UTF8String];
    if (cstr) {
        FILE *f = fopen("/var/mobile/Library/FingerDump/api_calls.log", "a");
        if (f) {
            fprintf(f, "%s", cstr);
            fclose(f);
        }
        fprintf(stderr, "%s", cstr);
    }
}

#endif
