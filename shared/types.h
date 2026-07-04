#ifndef FINGERDUMP_TYPES_H
#define FINGERDUMP_TYPES_H

#include <stdbool.h>
#include <stdint.h>

#define FD_MAX_KEY_LEN 128
#define FD_MAX_VALUE_LEN 1024
#define FD_MAX_NAME_LEN 256
#define FD_MAX_DESC_LEN 512
#define FD_MAX_CATEGORIES 16
#define FD_MAX_IDENTIFIERS_PER_CATEGORY 64
#define FD_SOCK_PATH "/var/run/fingerdumpd.sock"
#define FD_DB_PATH "/var/mobile/Library/FingerDump/scans.db"
#define FD_WEB_ROOT "/var/mobile/Library/FingerDump/www"

typedef enum {
    CAT_HARDWARE      = 0,
    CAT_SYSTEM        = 1,
    CAT_NETWORK       = 2,
    CAT_GRAPHICS      = 3,
    CAT_AUDIO         = 4,
    CAT_SENSOR        = 5,
    CAT_FONT          = 6,
    CAT_PERSISTENCE   = 7,
    CAT_BEHAVIORAL    = 8,
    CAT_BROWSER       = 9,
    CAT_KEYCHAIN      = 10,
    CAT_COUNT,
} identifier_category_t;

extern const char *fd_category_names[CAT_COUNT];
extern const char *fd_category_descriptions[CAT_COUNT];

typedef struct {
    char key[FD_MAX_KEY_LEN];
    char name[FD_MAX_NAME_LEN];
    char description[FD_MAX_DESC_LEN];
    char real_value[FD_MAX_VALUE_LEN];
    char spoofed_value[FD_MAX_VALUE_LEN];
    identifier_category_t category;
    bool is_spoofed;
    bool is_leaking;
    bool is_available;
} fd_identifier_t;

typedef struct {
    identifier_category_t category;
    fd_identifier_t identifiers[FD_MAX_IDENTIFIERS_PER_CATEGORY];
    int count;
} fd_category_result_t;

typedef struct {
    fd_category_result_t categories[CAT_COUNT];
    int category_count;
    char device_name[256];
    char ios_version[64];
    char timestamp[64];
    char scan_id[64];
} fd_scan_result_t;

typedef struct {
    double duration_ms;
    int total_identifiers;
    int total_leaking;
    int total_spoofed;
} fd_scan_metadata_t;

typedef enum {
    REQ_SCAN_ALL = 0,
    REQ_SCAN_CATEGORY = 1,
    REQ_SCAN_ONE = 2,
    REQ_GET_HISTORY = 3,
    REQ_STATUS = 4,
} fd_request_type_t;

typedef struct {
    fd_request_type_t type;
    char payload[1024];
} fd_request_t;

typedef struct {
    int status_code;
    char message[512];
    char json_data[65536];
} fd_response_t;

#endif
