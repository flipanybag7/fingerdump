#ifndef FINGERDUMP_SCANNER_H
#define FINGERDUMP_SCANNER_H

#include "shared/types.h"

void fd_scan_hardware(fd_category_result_t *result);
void fd_scan_system(fd_category_result_t *result);
void fd_scan_network(fd_category_result_t *result);
void fd_scan_graphics(fd_category_result_t *result);
void fd_scan_audio(fd_category_result_t *result);
void fd_scan_sensor(fd_category_result_t *result);
void fd_scan_fonts(fd_category_result_t *result);
void fd_scan_persistence(fd_category_result_t *result);
void fd_scan_behavioral(fd_category_result_t *result);
void fd_scan_browser(fd_category_result_t *result);

void fd_scan_all(fd_scan_result_t *result);
void fd_scan_category(fd_scan_result_t *result, identifier_category_t cat);
void fd_scan_result_to_json(fd_scan_result_t *result, char *out, size_t len);

#endif
