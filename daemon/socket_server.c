#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <pthread.h>
#include <signal.h>
#include "shared/types.h"
#include "shared/protocol.h"
#include "scanner.h"

static int server_fd = -1;
static volatile int running = 1;

void fd_server_stop(void) {
    running = 0;
    if (server_fd >= 0) {
        close(server_fd);
        server_fd = -1;
    }
    unlink(FD_SOCK_PATH);
}

static void handle_client(int client_fd) {
    char buf[FD_BUFFER_SIZE];
    ssize_t n = read(client_fd, buf, sizeof(buf) - 1);
    if (n <= 0) { close(client_fd); return; }
    buf[n] = 0;

    fd_request_t req;
    memset(&req, 0, sizeof(req));

    if (strncmp(buf, "SCAN_ALL", 8) == 0) {
        req.type = REQ_SCAN_ALL;
    } else if (strncmp(buf, "SCAN_CAT ", 9) == 0) {
        req.type = REQ_SCAN_CATEGORY;
        snprintf(req.payload, sizeof(req.payload), "%s", buf + 9);
    } else if (strncmp(buf, "STATUS", 6) == 0) {
        req.type = REQ_STATUS;
    } else {
        fd_response_t resp;
        memset(&resp, 0, sizeof(resp));
        resp.status_code = STATUS_INVALID_REQ;
        snprintf(resp.message, sizeof(resp.message), "unknown request: %s", buf);
        write(client_fd, &resp, sizeof(resp));
        close(client_fd);
        return;
    }

    fd_response_t resp;
    memset(&resp, 0, sizeof(resp));

    switch (req.type) {
        case REQ_SCAN_ALL: {
            fd_scan_result_t result;
            fd_scan_all(&result);
            resp.status_code = STATUS_OK;
            snprintf(resp.message, sizeof(resp.message), "scan complete");
            fd_scan_result_to_json(&result, resp.json_data, sizeof(resp.json_data));
            break;
        }
        case REQ_SCAN_CATEGORY: {
            int cat = atoi(req.payload);
            if (cat < 0 || cat >= CAT_COUNT) {
                resp.status_code = STATUS_INVALID_REQ;
                snprintf(resp.message, sizeof(resp.message), "invalid category: %d", cat);
            } else {
                fd_scan_result_t result;
                fd_scan_category(&result, (identifier_category_t)cat);
                resp.status_code = STATUS_OK;
                snprintf(resp.message, sizeof(resp.message), "category scan complete");
                fd_scan_result_to_json(&result, resp.json_data, sizeof(resp.json_data));
            }
            break;
        }
        case REQ_STATUS: {
            resp.status_code = STATUS_OK;
            snprintf(resp.message, sizeof(resp.message), "FingerDump daemon v1 running");
            break;
        }
        default:
            resp.status_code = STATUS_INVALID_REQ;
            snprintf(resp.message, sizeof(resp.message), "unimplemented");
            break;
    }

    write(client_fd, &resp, sizeof(resp));
    close(client_fd);
}

static void *client_handler(void *arg) {
    int client_fd = *(int *)arg;
    free(arg);
    handle_client(client_fd);
    return NULL;
}

int fd_server_start(void) {
    struct sockaddr_un addr;
    unlink(FD_SOCK_PATH);
    mkdir("/var/run/fingerdumpd", 0755);

    server_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (server_fd < 0) return -1;

    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, FD_SOCK_PATH, sizeof(addr.sun_path) - 1);

    if (bind(server_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(server_fd);
        server_fd = -1;
        return -2;
    }

    chmod(FD_SOCK_PATH, 0777);

    if (listen(server_fd, FD_SOCK_BACKLOG) < 0) {
        close(server_fd);
        server_fd = -1;
        return -3;
    }

    return 0;
}

void fd_server_run(void) {
    struct sockaddr_un client_addr;
    socklen_t client_len = sizeof(client_addr);

    while (running) {
        fd_set read_fds;
        FD_ZERO(&read_fds);
        FD_SET(server_fd, &read_fds);

        struct timeval tv = { 1, 0 };
        int activity = select(server_fd + 1, &read_fds, NULL, NULL, &tv);

        if (activity < 0) {
            if (running) continue;
            break;
        }

        if (FD_ISSET(server_fd, &read_fds)) {
            int *client_fd = malloc(sizeof(int));
            if (!client_fd) continue;

            *client_fd = accept(server_fd, (struct sockaddr *)&client_addr, &client_len);
            if (*client_fd < 0) { free(client_fd); continue; }

            pthread_t thread;
            pthread_create(&thread, NULL, client_handler, client_fd);
            pthread_detach(thread);
        }
    }

    fd_server_stop();
}
