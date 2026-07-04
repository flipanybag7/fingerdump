#ifndef FINGERDUMP_PROTOCOL_H
#define FINGERDUMP_PROTOCOL_H

#include "types.h"

#define FD_PROTOCOL_VERSION 1
#define FD_SOCK_BACKLOG 5
#define FD_MAX_CLIENTS 10
#define FD_READ_TIMEOUT_SEC 30
#define FD_BUFFER_SIZE 131072

typedef enum {
    STATUS_OK = 0,
    STATUS_ERROR = -1,
    STATUS_NOT_FOUND = -2,
    STATUS_BUSY = -3,
    STATUS_INVALID_REQ = -4,
} fd_status_t;

#define FD_MSG_TERMINATOR "\n---END---\n"
#define FD_MSG_TERMINATOR_LEN 10

#endif
