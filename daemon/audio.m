#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <CoreFoundation/CoreFoundation.h>
#include "shared/types.h"

void fd_scan_audio(fd_category_result_t *result) {
    result->category = CAT_AUDIO;
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
    result->identifiers[i].category = CAT_AUDIO; \
    i++; \
} while(0)

    char val[512];
    Class asClass = objc_getClass("AVAudioSession");

    if (asClass) {
        id shared = ((id (*)(id, SEL))(void *)objc_msgSend)((id)asClass, sel_registerName("sharedInstance"));
        if (shared) {
            double sampleRate = ((double (*)(id, SEL))(void *)objc_msgSend)(shared, sel_registerName("sampleRate"));
            double inputLat = ((double (*)(id, SEL))(void *)objc_msgSend)(shared, sel_registerName("inputLatency"));
            double outputLat = ((double (*)(id, SEL))(void *)objc_msgSend)(shared, sel_registerName("outputLatency"));
            double ioDur = ((double (*)(id, SEL))(void *)objc_msgSend)(shared, sel_registerName("ioBufferDuration"));
            double hwSampleRate = ((double (*)(id, SEL))(void *)objc_msgSend)(shared, sel_registerName("preferredSampleRate"));
            NSInteger inputCh = ((NSInteger (*)(id, SEL))(void *)objc_msgSend)(shared, sel_registerName("inputNumberOfChannels"));
            NSInteger outputCh = ((NSInteger (*)(id, SEL))(void *)objc_msgSend)(shared, sel_registerName("outputNumberOfChannels"));

            snprintf(val, sizeof(val), "%.0f Hz", sampleRate);
            ADD_IDENT("audio.sample_rate", "Sample rate", "AVAudioSession current sample rate", val, "", false, true, true);

            snprintf(val, sizeof(val), "%.4f sec", inputLat);
            ADD_IDENT("audio.input_latency", "Input latency", "AVAudioSession input latency", val, "", false, true, true);

            snprintf(val, sizeof(val), "%.4f sec", outputLat);
            ADD_IDENT("audio.output_latency", "Output latency", "AVAudioSession output latency", val, "", false, true, true);

            snprintf(val, sizeof(val), "%.4f sec", ioDur);
            ADD_IDENT("audio.io_buffer", "IO buffer duration", "AVAudioSession IO buffer duration", val, "", false, true, true);

            snprintf(val, sizeof(val), "%.0f Hz", hwSampleRate);
            ADD_IDENT("audio.preferred_sample_rate", "Preferred sample rate", "AVAudioSession preferred sample rate", val, "", false, true, true);

            snprintf(val, sizeof(val), "%ld", (long)inputCh);
            ADD_IDENT("audio.input_channels", "Input channels", "AVAudioSession input channel count", val, "", false, true, true);

            snprintf(val, sizeof(val), "%ld", (long)outputCh);
            ADD_IDENT("audio.output_channels", "Output channels", "AVAudioSession output channel count", val, "", false, true, true);

            id route = ((id (*)(id, SEL))(void *)objc_msgSend)(shared, sel_registerName("currentRoute"));
            if (route) {
                id inputs = ((id (*)(id, SEL))(void *)objc_msgSend)(route, sel_registerName("inputs"));
                id outputs = ((id (*)(id, SEL))(void *)objc_msgSend)(route, sel_registerName("outputs"));

                if (inputs) {
                    char *s = strdup(((const char *(*)(id, SEL))(void *)objc_msgSend)(inputs, sel_registerName("description")));
                    snprintf(val, sizeof(val), "%s", s);
                    free(s);
                } else { snprintf(val, sizeof(val), "none"); }
                ADD_IDENT("audio.route_inputs", "Audio route inputs", "AVAudioSession current route inputs", val, "", false, true, true);

                if (outputs) {
                    id firstOutput = ((id (*)(id, SEL, unsigned long))(void *)objc_msgSend)(outputs, sel_registerName("objectAtIndex:"), (unsigned long)0);
                    if (firstOutput) {
                        id portType = ((id (*)(id, SEL))(void *)objc_msgSend)(firstOutput, sel_registerName("portType"));
                        if (portType) {
                            char *s = strdup(((const char *(*)(id, SEL))(void *)objc_msgSend)(portType, sel_registerName("UTF8String")));
                            snprintf(val, sizeof(val), "%s", s);
                            free(s);
                        } else { snprintf(val, sizeof(val), "unknown"); }
                        ADD_IDENT("audio.output_port", "Output port type", "AVAudioSession current output port type", val, "", false, true, true);

                        id portName = ((id (*)(id, SEL))(void *)objc_msgSend)(firstOutput, sel_registerName("portName"));
                        if (portName) {
                            char *s = strdup(((const char *(*)(id, SEL))(void *)objc_msgSend)(portName, sel_registerName("UTF8String")));
                            snprintf(val, sizeof(val), "%s", s);
                            free(s);
                        } else { snprintf(val, sizeof(val), "unknown"); }
                        ADD_IDENT("audio.output_port_name", "Output port name", "AVAudioSession current output port name", val, "", false, true, true);
                    }

                    char *s = strdup(((const char *(*)(id, SEL))(void *)objc_msgSend)(outputs, sel_registerName("description")));
                    snprintf(val, sizeof(val), "%s", s);
                    free(s);
                } else { snprintf(val, sizeof(val), "none"); }
                ADD_IDENT("audio.route_outputs", "Audio route outputs", "AVAudioSession current route outputs", val, "", false, true, true);
            }

            BOOL inputAvail = ((BOOL (*)(id, SEL))(void *)objc_msgSend)(shared, sel_registerName("isInputAvailable"));
            snprintf(val, sizeof(val), "%s", inputAvail ? "yes" : "no");
            ADD_IDENT("audio.input_available", "Input available", "AVAudioSession input availability", val, "", false, true, true);

            id category = ((id (*)(id, SEL))(void *)objc_msgSend)(shared, sel_registerName("category"));
            if (category) {
                char *s = strdup(((const char *(*)(id, SEL))(void *)objc_msgSend)(category, sel_registerName("UTF8String")));
                snprintf(val, sizeof(val), "%s", s);
                free(s);
            } else { snprintf(val, sizeof(val), "unknown"); }
            ADD_IDENT("audio.category", "Audio session category", "AVAudioSession category", val, "", false, true, true);

            id recordPermission = ((id (*)(id, SEL))(void *)objc_msgSend)(shared, sel_registerName("recordPermission"));
            snprintf(val, sizeof(val), "%ld", (long)((NSInteger)recordPermission));
            ADD_IDENT("audio.record_permission", "Record permission", "AVAudioSession record permission status", val, "", false, true, true);
        } else {
            ADD_IDENT("audio.sample_rate", "Sample rate", "AVAudioSession sample rate", "unavailable", "", false, true, true);
        }
    } else {
        ADD_IDENT("audio.sample_rate", "Sample rate", "AVAudioSession sample rate", "unavailable (no AVAudioSession)", "", false, true, true);
    }

    ADD_IDENT("audio.audio_context_fp", "AudioContext fingerprint (WebView)", "Audio oscillator fingerprint via JS (load web test page)", "(run web test)", "", false, true, false);

    result->count = i;
}
