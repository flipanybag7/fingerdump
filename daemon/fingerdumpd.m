#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <CoreFoundation/CoreFoundation.h>
#include "shared/types.h"
#include "shared/protocol.h"
#include "scanner.h"

extern int fd_server_start(void);
extern void fd_server_run(void);
extern void fd_server_stop(void);
extern int http_server_start(void);
extern void http_server_run(int);

static const char *pid_path = "/var/run/fingerdumpd.pid";

static void daemonize(void) {
    pid_t pid = fork();
    if (pid < 0) exit(1);
    if (pid > 0) exit(0);
    setsid();

    signal(SIGHUP, SIG_IGN);
    pid = fork();
    if (pid < 0) exit(1);
    if (pid > 0) exit(0);

    chdir("/");
    umask(0);

    int fd = open("/dev/null", O_RDWR);
    if (fd >= 0) {
        dup2(fd, STDIN_FILENO);
        dup2(fd, STDOUT_FILENO);
        dup2(fd, STDERR_FILENO);
        if (fd > 2) close(fd);
    }

    FILE *pf = fopen(pid_path, "w");
    if (pf) {
        fprintf(pf, "%d\n", getpid());
        fclose(pf);
    }
}

static void cleanup(int sig) {
    fd_server_stop();
    unlink(pid_path);
    _exit(128 + sig);
}

static void sigsegv_handler(int sig) {
    write(STDOUT_FILENO, "{\"error\": \"scanner crashed (SIGSEGV)\", \"hint\": \"IOKit not available on this device\"}\n", 88);
    _exit(1);
}

static void run_cli_scan(void) {
    fd_scan_result_t result;
    fd_scan_all(&result);

    char json_buf[65536];
    fd_scan_result_to_json(&result, json_buf, sizeof(json_buf));
    printf("%s\n", json_buf);
}

int main(int argc, char **argv) {
    signal(SIGINT, cleanup);
    signal(SIGTERM, cleanup);
    signal(SIGSEGV, sigsegv_handler);
    signal(SIGBUS, sigsegv_handler);
    signal(SIGABRT, sigsegv_handler);
    signal(SIGILL, sigsegv_handler);

    if (argc > 1) {
        if (strcmp(argv[1], "--version") == 0 || strcmp(argv[1], "-v") == 0) {
            printf("FingerDump v1.0.0 | built for arm64\n");
            return 0;
        }
        if (strcmp(argv[1], "--scan") == 0) {
            run_cli_scan();
            return 0;
        }
        if (strcmp(argv[1], "--scan-cat") == 0 && argc > 2) {
            int cat = atoi(argv[2]);
            if (cat < 0 || cat >= CAT_COUNT) {
                fprintf(stderr, "invalid category %d (0-%d)\n", cat, CAT_COUNT - 1);
                return 1;
            }
            fd_scan_result_t result;
            fd_scan_category(&result, (identifier_category_t)cat);
            char json_buf[65536];
            fd_scan_result_to_json(&result, json_buf, sizeof(json_buf));
            printf("%s\n", json_buf);
            return 0;
        }
        if (strcmp(argv[1], "--daemon") == 0) {
            daemonize();
        }
        if (strcmp(argv[1], "--serve") == 0) {
            int srv = http_server_start();
            if (srv < 0) {
                fprintf(stderr, "failed to start HTTP server\n");
                return 1;
            }
            http_server_run(srv);
            return 0;
        }
        if (strcmp(argv[1], "--foreground") == 0) {
            FILE *pf = fopen(pid_path, "w");
            if (pf) { fprintf(pf, "%d\n", getpid()); fclose(pf); }
        }
        if (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0) {
            printf("FingerDump Scanner Daemon\n");
            printf("Usage:\n");
            printf("  fingerdumpd --daemon        Run as daemon (background)\n");
            printf("  fingerdumpd --foreground    Run in foreground\n");
            printf("  fingerdumpd --serve         Start HTTP dashboard on http://localhost:8080\n");
            printf("  fingerdumpd --scan          Run a single full scan, output JSON, exit\n");
            printf("  fingerdumpd --scan-cat N    Scan single category N, output JSON\n");
            printf("  fingerdumpd --help          Display this help\n");
            printf("\nCategories:\n");
            for (int i = 0; i < CAT_COUNT; i++) {
                printf("  %2d: %s\n", i, fd_category_names[i]);
            }
            return 0;
        }
    }

    if (fd_server_start() != 0) {
        fprintf(stderr, "failed to start socket server\n");
        return 1;
    }

    fprintf(stdout, "FingerDump daemon listening on %s\n", FD_SOCK_PATH);
    fd_server_run();
    return 0;
}
