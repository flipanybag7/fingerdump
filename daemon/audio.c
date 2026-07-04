#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <CoreFoundation/CoreFoundation.h>
#include <AudioToolbox/AudioToolbox.h>
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

    {
        AudioDeviceID defaultInput = 0, defaultOutput = 0;
        uint32_t size = sizeof(AudioDeviceID);
        AudioObjectPropertyAddress addr = {
            kAudioHardwarePropertyDefaultInputDevice,
            kAudioObjectPropertyScopeGlobal,
            kAudioObjectPropertyElementMain
        };
        OSStatus st = AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, &defaultInput);
        if (st == noErr) {
            snprintf(val, sizeof(val), "input: %u", (unsigned int)defaultInput);
        } else {
            snprintf(val, sizeof(val), "unavailable");
        }
        size = sizeof(AudioDeviceID);
        addr.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
        st = AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, &defaultOutput);
        if (st == noErr) {
            char buf[128];
            snprintf(buf, sizeof(buf), " | output: %u", (unsigned int)defaultOutput);
            strncat(val, buf, sizeof(val) - strlen(val) - 1);
        }
        ADD_IDENT("audio.devices", "Audio device IDs", "Default audio input/output device IDs", val, "", false, true, true);
    }

    {
        UInt32 bufferSize = 0;
        uint32_t size = sizeof(bufferSize);
        AudioObjectPropertyAddress addr = {
            kAudioDevicePropertyBufferFrameSize,
            kAudioObjectPropertyScopeGlobal,
            kAudioObjectPropertyElementMain
        };
        AudioDeviceID output = 0;
        uint32_t sz = sizeof(output);
        addr.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
        if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &sz, &output) == noErr) {
            addr.mSelector = kAudioDevicePropertyBufferFrameSize;
            if (AudioObjectGetPropertyData(output, &addr, 0, NULL, &size, &bufferSize) == noErr) {
                snprintf(val, sizeof(val), "%u frames", (unsigned int)bufferSize);
            } else { snprintf(val, sizeof(val), "unavailable"); }
        } else { snprintf(val, sizeof(val), "unavailable"); }
        ADD_IDENT("audio.buffer_size", "Audio buffer size", "Default output audio buffer frame size", val, "", false, true, true);
    }

    {
        Float64 sampleRate = 0;
        uint32_t size = sizeof(sampleRate);
        AudioObjectPropertyAddress addr = {
            kAudioDevicePropertyNominalSampleRate,
            kAudioObjectPropertyScopeGlobal,
            kAudioObjectPropertyElementMain
        };
        AudioDeviceID output = 0;
        uint32_t sz = sizeof(output);
        addr.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
        if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &sz, &output) == noErr) {
            addr.mSelector = kAudioDevicePropertyNominalSampleRate;
            if (AudioObjectGetPropertyData(output, &addr, 0, NULL, &size, &sampleRate) == noErr) {
                snprintf(val, sizeof(val), "%.0f Hz", (double)sampleRate);
            } else { snprintf(val, sizeof(val), "unavailable"); }
        } else { snprintf(val, sizeof(val), "unavailable"); }
        ADD_IDENT("audio.sample_rate", "Sample rate", "Default output audio sample rate", val, "", false, true, true);
    }

    {
        UInt32 channels = 0;
        uint32_t size = sizeof(channels);
        AudioObjectPropertyAddress addr = {
            kAudioDevicePropertyStreamConfiguration,
            kAudioObjectPropertyScopeOutput,
            kAudioObjectPropertyElementMain
        };
        AudioDeviceID output = 0;
        uint32_t sz = sizeof(output);
        addr.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
        if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &sz, &output) == noErr) {
            addr.mSelector = kAudioDevicePropertyStreamConfiguration;
            AudioBufferList *buflist = malloc(sizeof(AudioBufferList));
            if (buflist) {
                if (AudioObjectGetPropertyData(output, &addr, 0, NULL, &size, buflist) == noErr) {
                    channels = buflist->mNumberBuffers;
                }
                free(buflist);
            }
        }
        snprintf(val, sizeof(val), "%u", (unsigned int)channels);
        ADD_IDENT("audio.channels", "Audio channels", "Number of audio output channels", val, "", false, true, true);
    }

    ADD_IDENT("audio.audio_context_fp", "AudioContext fingerprint (WebView)", "Audio oscillator fingerprint via JS (load web test page)", "(run web test)", "", false, true, false);

    result->count = i;
}
