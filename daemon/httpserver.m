#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/stat.h>
#include <pthread.h>
#include <fcntl.h>
#include "shared/types.h"
#include "scanner.h"

#define WWW_ROOT "/var/mobile/Library/FingerDump/www"
#define HTTP_PORT 8080

static const char *mime_type(const char *ext) {
    if (!ext) return "application/octet-stream";
    if (strcasecmp(ext, "html") == 0 || strcasecmp(ext, "htm") == 0) return "text/html";
    if (strcasecmp(ext, "js") == 0) return "application/javascript";
    if (strcasecmp(ext, "css") == 0) return "text/css";
    if (strcasecmp(ext, "json") == 0) return "application/json";
    if (strcasecmp(ext, "png") == 0) return "image/png";
    if (strcasecmp(ext, "jpg") == 0 || strcasecmp(ext, "jpeg") == 0) return "image/jpeg";
    if (strcasecmp(ext, "svg") == 0) return "image/svg+xml";
    if (strcasecmp(ext, "ico") == 0) return "image/x-icon";
    return "application/octet-stream";
}

static void send_response(int fd, int code, const char *status, const char *mime, const char *body, size_t body_len) {
    char buf[4096];
    int n = snprintf(buf, sizeof(buf),
        "HTTP/1.1 %d %s\r\n"
        "Content-Type: %s\r\n"
        "Content-Length: %zu\r\n"
        "Access-Control-Allow-Origin: *\r\n"
        "Connection: close\r\n"
        "\r\n",
        code, status, mime, body_len);
    write(fd, buf, n);
    if (body && body_len > 0) write(fd, body, body_len);
}

static void send_file(int fd, const char *path) {
    struct stat st;
    if (stat(path, &st) != 0) {
        send_response(fd, 404, "Not Found", "text/plain", "File not found", 14);
        return;
    }
    FILE *f = fopen(path, "rb");
    if (!f) {
        send_response(fd, 403, "Forbidden", "text/plain", "Forbidden", 8);
        return;
    }
    const char *ext = strrchr(path, '.');
    ext = ext ? ext + 1 : "";
    const char *mime = mime_type(ext);

    char *buf = malloc(st.st_size + 1);
    size_t n = fread(buf, 1, st.st_size, f);
    fclose(f);
    send_response(fd, 200, "OK", mime, buf, n);
    free(buf);
}

static void handle_api_scan(int fd) {
    fd_scan_result_t result;
    fd_scan_all(&result);

    char json[131072];
    fd_scan_result_to_json(&result, json, sizeof(json));
    send_response(fd, 200, "OK", "application/json", json, strlen(json));
}

static void handle_api_cat(int fd, int cat) {
    if (cat < 0 || cat >= CAT_COUNT) {
        send_response(fd, 400, "Bad Request", "application/json", "{\"error\":\"invalid category\"}", 26);
        return;
    }
    fd_scan_result_t result;
    fd_scan_category(&result, (identifier_category_t)cat);
    char json[131072];
    fd_scan_result_to_json(&result, json, sizeof(json));
    send_response(fd, 200, "OK", "application/json", json, strlen(json));
}

static void handle_client(int client_fd) {
    char buf[4096] = {0};
    int n = (int)read(client_fd, buf, sizeof(buf) - 1);
    if (n <= 0) { close(client_fd); return; }
    buf[n] = 0;

    char method[16], path[1024];
    if (sscanf(buf, "%15s %1023s", method, path) < 2) {
        send_response(client_fd, 400, "Bad Request", "text/plain", "Bad Request", 10);
        close(client_fd);
        return;
    }

    if (strcmp(path, "/api/scan") == 0) {
        handle_api_scan(client_fd);
    } else if (strncmp(path, "/api/cat/", 9) == 0) {
        int cat = atoi(path + 9);
        handle_api_cat(client_fd, cat);
    } else if (strcmp(path, "/api/status") == 0) {
        send_response(client_fd, 200, "OK", "application/json", "{\"status\":\"running\",\"version\":\"1.0\"}", 42);
    } else {
        char filepath[2048];
        if (strcmp(path, "/") == 0) {
            snprintf(filepath, sizeof(filepath), "%s/index.html", WWW_ROOT);
        } else {
            snprintf(filepath, sizeof(filepath), "%s%s", WWW_ROOT, path);
        }
        send_file(client_fd, filepath);
    }
    close(client_fd);
}

static void *client_thread(void *arg) {
    int fd = *(int *)arg;
    free(arg);
    handle_client(fd);
    return NULL;
}

int http_server_start(void) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return -1;

    int opt = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(HTTP_PORT);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(fd);
        return -2;
    }
    if (listen(fd, 5) < 0) {
        close(fd);
        return -3;
    }
    return fd;
}

void http_server_run(int server_fd) {
    fprintf(stderr, "HTTP server listening on http://127.0.0.1:%d\n", HTTP_PORT);
    while (1) {
        struct sockaddr_in client;
        socklen_t client_len = sizeof(client);
        int *client_fd = malloc(sizeof(int));
        if (!client_fd) continue;
        *client_fd = accept(server_fd, (struct sockaddr *)&client, &client_len);
        if (*client_fd < 0) { free(client_fd); continue; }
        pthread_t thread;
        pthread_create(&thread, NULL, client_thread, client_fd);
        pthread_detach(thread);
    }
}
