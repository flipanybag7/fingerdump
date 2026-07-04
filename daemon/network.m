#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <net/if.h>
#include <netinet/in.h>
#include <unistd.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CFNetwork/CFNetwork.h>
#include <net/if_dl.h>
#include "shared/types.h"

static void get_local_ips(char *out_v4, size_t v4len, char *out_v6, size_t v6len) {
    struct ifaddrs *ifap, *ifa;
    char v4[4096] = {0}, v6[4096] = {0};
    int first_v4 = 1, first_v6 = 1;

    if (getifaddrs(&ifap) != 0) {
        snprintf(out_v4, v4len, "unavailable");
        snprintf(out_v6, v6len, "unavailable");
        return;
    }

    for (ifa = ifap; ifa; ifa = ifa->ifa_next) {
        if (!ifa->ifa_addr) continue;
        if (ifa->ifa_addr->sa_family == AF_INET) {
            char addr[64];
            struct sockaddr_in *sin = (struct sockaddr_in *)ifa->ifa_addr;
            inet_ntop(AF_INET, &sin->sin_addr, addr, sizeof(addr));
            if (strcmp(ifa->ifa_name, "lo0") == 0) continue;
            char buf[128];
            snprintf(buf, sizeof(buf), "%s:%s%s", ifa->ifa_name, addr, first_v4 ? "" : ", ");
            if (first_v4) { snprintf(v4, sizeof(v4), "%s", buf); first_v4 = 0; }
            else { strncat(v4, buf, sizeof(v4) - strlen(v4) - 1); }
        } else if (ifa->ifa_addr->sa_family == AF_INET6) {
            char addr[64];
            struct sockaddr_in6 *sin6 = (struct sockaddr_in6 *)ifa->ifa_addr;
            inet_ntop(AF_INET6, &sin6->sin6_addr, addr, sizeof(addr));
            if (strcmp(ifa->ifa_name, "lo0") == 0) continue;
            if (strncmp(addr, "fe80", 4) == 0) continue;
            char buf[128];
            snprintf(buf, sizeof(buf), "%s:%s%s", ifa->ifa_name, addr, first_v6 ? "" : ", ");
            if (first_v6) { snprintf(v6, sizeof(v6), "%s", buf); first_v6 = 0; }
            else { strncat(v6, buf, sizeof(v6) - strlen(v6) - 1); }
        }
    }
    freeifaddrs(ifap);
    if (first_v4) snprintf(out_v4, v4len, "none");
    else snprintf(out_v4, v4len, "%s", v4);
    if (first_v6) snprintf(out_v6, v6len, "none");
    else snprintf(out_v6, v6len, "%s", v6);
}

static void get_default_gateway(char *out, size_t len) {
    FILE *fp;
    char buf[256];
    int found = 0;

    fp = fopen("/proc/net/route", "r");
    if (fp) {
        while (fgets(buf, sizeof(buf), fp)) {
            char iface[32] = {0};
            unsigned long dest, gw;
            if (sscanf(buf, "%s %lx %lx", iface, &dest, &gw) >= 3) {
                if (dest == 0 && gw != 0) {
                    struct in_addr in;
                    in.s_addr = gw;
                    snprintf(out, len, "%s (%s)", inet_ntoa(in), iface);
                    found = 1;
                    break;
                }
            }
        }
        fclose(fp);
    }
    if (!found) {
        struct ifaddrs *ifap, *ifa;
        if (getifaddrs(&ifap) == 0) {
            for (ifa = ifap; ifa; ifa = ifa->ifa_next) {
                if (ifa->ifa_addr && ifa->ifa_addr->sa_family == AF_INET &&
                    ifa->ifa_flags & IFF_UP && !(ifa->ifa_flags & IFF_LOOPBACK)) {
                    snprintf(out, len, "via %s", ifa->ifa_name);
                    found = 1;
                    break;
                }
            }
            freeifaddrs(ifap);
        }
    }
    if (!found) snprintf(out, len, "unavailable");
}

static void get_active_interface(char *out, size_t len) {
    struct ifaddrs *ifap, *ifa;
    if (getifaddrs(&ifap) != 0) { snprintf(out, len, "unavailable"); return; }

    for (ifa = ifap; ifa; ifa = ifa->ifa_next) {
        if (!ifa->ifa_addr || ifa->ifa_addr->sa_family != AF_INET) continue;
        if (ifa->ifa_flags & IFF_UP && !(ifa->ifa_flags & IFF_LOOPBACK)) {
            snprintf(out, len, "%s", ifa->ifa_name);
            freeifaddrs(ifap);
            return;
        }
    }
    freeifaddrs(ifap);
    snprintf(out, len, "unknown");
}

static void get_dns_servers(char *out, size_t len) {
    Class resolver = objc_getClass("NSResolver");
    if (resolver) {
        id shared = ((id (*)(id, SEL))(void *)objc_msgSend)((id)resolver, sel_registerName("sharedResolver"));
        if (shared) {
            id servers = ((id (*)(id, SEL))(void *)objc_msgSend)(shared, sel_registerName("nameServers"));
            if (servers) {
                id desc = ((id (*)(id, SEL))(void *)objc_msgSend)(servers, sel_registerName("description"));
                if (desc) {
                    char *s = strdup(((const char *(*)(id, SEL))(void *)objc_msgSend)(desc, sel_registerName("UTF8String")));
                    snprintf(out, len, "%s", s);
                    free(s);
                    return;
                }
            }
        }
    }
    FILE *fp = fopen("/etc/resolv.conf", "r");
    if (fp) {
        char line[256], dns[1024] = {0};
        while (fgets(line, sizeof(line), fp)) {
            char addr[64];
            if (sscanf(line, "nameserver %63s", addr) == 1) {
                if (dns[0]) strncat(dns, ", ", sizeof(dns) - strlen(dns) - 1);
                strncat(dns, addr, sizeof(dns) - strlen(dns) - 1);
            }
        }
        fclose(fp);
        if (dns[0]) { snprintf(out, len, "%s", dns); return; }
    }
    snprintf(out, len, "unavailable");
}

static void get_http_proxy(char *out, size_t len) {
    CFDictionaryRef proxySettings = CFNetworkCopySystemProxySettings();
    if (!proxySettings) { snprintf(out, len, "unavailable"); return; }

    CFNumberRef httpEnable = CFDictionaryGetValue(proxySettings, kCFNetworkProxiesHTTPEnable);
    CFStringRef httpHost = CFDictionaryGetValue(proxySettings, kCFNetworkProxiesHTTPProxy);
    CFNumberRef httpPort = CFDictionaryGetValue(proxySettings, kCFNetworkProxiesHTTPPort);

    if (httpEnable && CFBooleanGetValue((CFBooleanRef)httpEnable) && httpHost) {
        char host[256] = {0};
        CFStringGetCString(httpHost, host, sizeof(host), kCFStringEncodingUTF8);
        int port = 0;
        if (httpPort) CFNumberGetValue(httpPort, kCFNumberIntType, &port);
        snprintf(out, len, "http://%s:%d", host, port);
    } else {
        snprintf(out, len, "none");
    }
    CFRelease(proxySettings);
}

void fd_scan_network(fd_category_result_t *result) {
    result->category = CAT_NETWORK;
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
    result->identifiers[i].category = CAT_NETWORK; \
    i++; \
} while(0)

    char v4[4096], v6[4096], val[512];

    get_local_ips(v4, sizeof(v4), v6, sizeof(v6));
    ADD_IDENT("net.ipv4", "Local IPv4 addresses", "Local IPv4 per interface (excluding loopback)", v4, "", false, true, true);
    ADD_IDENT("net.ipv6", "Local IPv6 addresses", "Local IPv6 per interface (excluding loopback/link-local)", v6, "", false, true, true);

    get_default_gateway(val, sizeof(val));
    ADD_IDENT("net.gateway", "Default gateway", "Default route gateway address", val, "", false, true, true);

    get_active_interface(val, sizeof(val));
    ADD_IDENT("net.active_iface", "Active interface", "Currently active network interface", val, "", false, true, true);

    get_dns_servers(val, sizeof(val));
    ADD_IDENT("net.dns", "DNS servers", "DNS resolver addresses", val, "", false, true, true);

    get_http_proxy(val, sizeof(val));
    ADD_IDENT("net.proxy", "HTTP proxy", "System HTTP proxy settings", val, "", false, true, true);

    {
        struct ifaddrs *ifap, *ifa;
        struct sockaddr_dl *sdl;
        unsigned char mac[6];
        int found = 0;
        if (getifaddrs(&ifap) == 0) {
            for (ifa = ifap; ifa; ifa = ifa->ifa_next) {
                if (ifa->ifa_addr && ifa->ifa_addr->sa_family == AF_LINK) {
                    if (strcmp(ifa->ifa_name, "en0") == 0) {
                        sdl = (struct sockaddr_dl *)ifa->ifa_addr;
                        if (sdl->sdl_alen == 6) {
                            memcpy(mac, LLADDR(sdl), 6);
                            snprintf(val, sizeof(val), "%02x:%02x:%02x:%02x:%02x:%02x",
                                     mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
                            found = 1;
                        }
                        break;
                    }
                }
            }
            freeifaddrs(ifap);
        }
        if (!found) snprintf(val, sizeof(val), "unavailable");
        ADD_IDENT("net.mac_en0", "en0 MAC address", "Network interface en0 MAC (WiFi)", val, "", false, true, true);
    }

    {
        char iface_list[4096] = {0};
        struct if_nameindex *ni = if_nameindex();
        if (ni) {
            for (int idx = 0; ni[idx].if_index != 0; idx++) {
                if (iface_list[0]) strncat(iface_list, ", ", sizeof(iface_list) - strlen(iface_list) - 1);
                strncat(iface_list, ni[idx].if_name, sizeof(iface_list) - strlen(iface_list) - 1);
            }
            if_freenameindex(ni);
        }
        if (iface_list[0]) snprintf(val, sizeof(val), "%s", iface_list);
        else snprintf(val, sizeof(val), "unavailable");
        ADD_IDENT("net.interfaces", "Network interfaces", "All available network interface names", val, "", false, true, true);
    }

    result->count = i;
}
