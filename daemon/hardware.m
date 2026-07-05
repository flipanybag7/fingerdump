#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/utsname.h>
#include <sys/sysctl.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <ifaddrs.h>
#include <unistd.h>
#include <CoreFoundation/CoreFoundation.h>
#include "shared/types.h"

#ifndef HW_CPU_SUBTYPE
#define HW_CPU_SUBTYPE 8
#endif

#ifndef KERN_BOOTUUID
#define KERN_BOOTUUID 15
#endif

static void get_platform(char *out, size_t len) {
    size_t n = len;
    int mib[2] = { CTL_HW, HW_MACHINE };
    sysctl(mib, 2, out, &n, NULL, 0);
}

static void get_model(char *out, size_t len) {
    size_t n = len;
    int mib[2] = { CTL_HW, HW_MODEL };
    sysctl(mib, 2, out, &n, NULL, 0);
}

static void get_cpu_subtype(char *out, size_t len) {
    cpu_subtype_t subtype;
    size_t n = sizeof(subtype);
    int mib[2] = { CTL_HW, HW_CPU_SUBTYPE };
    if (sysctl(mib, 2, &subtype, &n, NULL, 0) == 0) {
        snprintf(out, len, "%d", subtype);
    } else {
        snprintf(out, len, "unavailable");
    }
}

static void get_physmem(char *out, size_t len) {
    uint64_t mem;
    size_t n = sizeof(mem);
    int mib[2] = { CTL_HW, HW_MEMSIZE };
    if (sysctl(mib, 2, &mem, &n, NULL, 0) == 0) {
        double mb = mem / (1024.0 * 1024.0);
        snprintf(out, len, "%.0f MB", mb);
    } else {
        snprintf(out, len, "unavailable");
    }
}

static void get_cpu_freq(char *out, size_t len) {
    uint64_t freq;
    size_t n = sizeof(freq);
    int mib[2] = { CTL_HW, HW_CPU_FREQ };
    if (sysctl(mib, 2, &freq, &n, NULL, 0) == 0) {
        double mhz = freq / 1000000.0;
        snprintf(out, len, "%.0f MHz", mhz);
    } else {
        snprintf(out, len, "unavailable");
    }
}

static void get_boot_uuid(char *out, size_t len) {
    char buf[256] = {0};
    size_t n = sizeof(buf) - 1;
    int mib[2] = { CTL_KERN, KERN_BOOTUUID };
    if (sysctl(mib, 2, buf, &n, NULL, 0) == 0) {
        snprintf(out, len, "%s", buf);
    } else {
        snprintf(out, len, "unavailable");
    }
}

static void get_wifi_mac(char *out, size_t len) {
    struct ifaddrs *ifap, *ifa;
    struct sockaddr_dl *sdl;
    unsigned char mac[6];

    if (getifaddrs(&ifap) != 0) {
        snprintf(out, len, "unavailable");
        return;
    }

    for (ifa = ifap; ifa; ifa = ifa->ifa_next) {
        if (ifa->ifa_addr && ifa->ifa_addr->sa_family == AF_LINK) {
            char *name = ifa->ifa_name;
            if (strcmp(name, "en0") == 0) {
                sdl = (struct sockaddr_dl *)ifa->ifa_addr;
                if (sdl->sdl_alen == 6) {
                    memcpy(mac, LLADDR(sdl), 6);
                    snprintf(out, len, "%02x:%02x:%02x:%02x:%02x:%02x",
                             mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
                    freeifaddrs(ifap);
                    return;
                }
            }
        }
    }
    freeifaddrs(ifap);
    snprintf(out, len, "unavailable");
}

static void get_bluetooth_mac(char *out, size_t len) {
    struct ifaddrs *ifap, *ifa;
    struct sockaddr_dl *sdl;
    unsigned char mac[6];

    if (getifaddrs(&ifap) != 0) {
        snprintf(out, len, "unavailable");
        return;
    }
    for (ifa = ifap; ifa; ifa = ifa->ifa_next) {
        if (ifa->ifa_addr && ifa->ifa_addr->sa_family == AF_LINK) {
            char *name = ifa->ifa_name;
            if (strstr(name, "bt") || strstr(name, "lo0")) continue;
            if (strncmp(name, "en", 2) != 0 && strncmp(name, "awdl", 4) != 0) {
                sdl = (struct sockaddr_dl *)ifa->ifa_addr;
                if (sdl->sdl_alen == 6) {
                    memcpy(mac, LLADDR(sdl), 6);
                    snprintf(out, len, "%02x:%02x:%02x:%02x:%02x:%02x",
                             mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
                    freeifaddrs(ifap);
                    return;
                }
            }
        }
    }
    freeifaddrs(ifap);
    snprintf(out, len, "unavailable");
}

static void get_chip_id(char *out, size_t len) {
    char buf[256] = {0};
    size_t n = sizeof(buf) - 1;
    int mib[2] = { CTL_HW, HW_MACHINE };
    sysctl(mib, 2, buf, &n, NULL, 0);
    snprintf(out, len, "%s", buf);
}

void fd_scan_hardware(fd_category_result_t *result) {
    result->category = CAT_HARDWARE;
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
    result->identifiers[i].category = CAT_HARDWARE; \
    i++; \
} while(0)

    char val[512];

    get_platform(val, sizeof(val));
    ADD_IDENT("hw.platform", "Platform (hw.machine)", "Device platform identifier (e.g. iPhone12,5)", val, "", false, true, true);

    get_model(val, sizeof(val));
    ADD_IDENT("hw.model", "Model (hw.model)", "Device model identifier", val, "", false, true, true);

    struct utsname un;
    uname(&un);
    ADD_IDENT("uname.machine", "Uname machine", "uname() machine field", un.machine, "", false, true, true);
    ADD_IDENT("uname.nodename", "Uname nodename", "uname() nodename (hostname)", un.nodename, "", false, true, true);
    ADD_IDENT("uname.release", "Uname release", "uname() kernel release", un.release, "", false, true, true);
    ADD_IDENT("uname.version", "Uname version", "uname() kernel version", un.version, "", false, true, true);

    get_cpu_subtype(val, sizeof(val));
    ADD_IDENT("hw.cpu_subtype", "CPU subtype", "CPU subtype identifier", val, "", false, true, true);

    get_physmem(val, sizeof(val));
    ADD_IDENT("hw.memsize", "Physical memory", "Total physical RAM", val, "", false, true, true);

    get_cpu_freq(val, sizeof(val));
    ADD_IDENT("hw.cpufreq", "CPU frequency", "CPU clock frequency", val, "", false, true, true);

    get_boot_uuid(val, sizeof(val));
    ADD_IDENT("kern.bootuuid", "Boot UUID", "Kernel boot session UUID", val, "", false, true, true);

    get_wifi_mac(val, sizeof(val));
    ADD_IDENT("mac.wifi", "WiFi MAC address", "WiFi interface (en0) MAC address", val, "", false, true, true);

    get_bluetooth_mac(val, sizeof(val));
    ADD_IDENT("mac.bluetooth", "Bluetooth MAC", "Bluetooth interface MAC address", val, "", false, true, true);

    get_chip_id(val, sizeof(val));
    ADD_IDENT("chip.id", "Chip identifier", "SoC chip identifier", val, "", false, true, true);

    int ncpu;
    size_t nlen = sizeof(ncpu);
    int mib[2] = { CTL_HW, HW_NCPU };
    if (sysctl(mib, 2, &ncpu, &nlen, NULL, 0) == 0) {
        snprintf(val, sizeof(val), "%d", ncpu);
    } else { snprintf(val, sizeof(val), "unavailable"); }
    ADD_IDENT("hw.ncpu", "CPU count", "Number of CPUs", val, "", false, true, true);

    result->count = i;
}
