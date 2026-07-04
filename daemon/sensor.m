#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreMotion/CoreMotion.h>
#include "shared/types.h"

void fd_scan_sensor(fd_category_result_t *result) {
    result->category = CAT_SENSOR;
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
    result->identifiers[i].category = CAT_SENSOR; \
    i++; \
} while(0)

    char val[512];
    Class cm = objc_getClass("CMMotionManager");

    if (cm) {
        id manager = ((id (*)(id, SEL))(void *)objc_msgSend)((id)cm, sel_registerName("alloc"));
        manager = ((id (*)(id, SEL))(void *)objc_msgSend)(manager, sel_registerName("init"));

        if (manager) {
            BOOL accel = ((BOOL (*)(id, SEL))(void *)objc_msgSend)(manager, sel_registerName("isAccelerometerAvailable"));
            BOOL gyro = ((BOOL (*)(id, SEL))(void *)objc_msgSend)(manager, sel_registerName("isGyroAvailable"));
            BOOL magnet = ((BOOL (*)(id, SEL))(void *)objc_msgSend)(manager, sel_registerName("isMagnetometerAvailable"));
            BOOL deviceMotion = ((BOOL (*)(id, SEL))(void *)objc_msgSend)(manager, sel_registerName("isDeviceMotionAvailable"));
            BOOL pedo = ((BOOL (*)(id, SEL))(void *)objc_msgSend)(manager, sel_registerName("isPedometerAvailable"));

            snprintf(val, sizeof(val), "accel:%s gyro:%s magnet:%s motion:%s pedo:%s",
                     accel ? "Y" : "N", gyro ? "Y" : "N", magnet ? "Y" : "N",
                     deviceMotion ? "Y" : "N", pedo ? "Y" : "N");
            ADD_IDENT("sensor.availability", "Sensor availability", "CMMotionManager sensor availability flags", val, "", false, true, true);

            if (accel) {
                id accelData = ((id (*)(id, SEL))(void *)objc_msgSend)(manager, sel_registerName("accelerometerData"));
                if (accelData) {
                    id accelVal = ((id (*)(id, SEL))(void *)objc_msgSend)(accelData, sel_registerName("acceleration"));
                    double x = ((double (*)(id, SEL))(void *)objc_msgSend)(accelVal, sel_registerName("x"));
                    double y = ((double (*)(id, SEL))(void *)objc_msgSend)(accelVal, sel_registerName("y"));
                    double z = ((double (*)(id, SEL))(void *)objc_msgSend)(accelVal, sel_registerName("z"));
                    snprintf(val, sizeof(val), "x=%.6f y=%.6f z=%.6f", x, y, z);
                } else { snprintf(val, sizeof(val), "not started"); }
                ADD_IDENT("sensor.accelerometer", "Accelerometer data", "Current accelerometer readings (calibration fingerprint)", val, "", false, true, true);
            }

            if (gyro) {
                id gyroData = ((id (*)(id, SEL))(void *)objc_msgSend)(manager, sel_registerName("gyroData"));
                if (gyroData) {
                    id rotVal = ((id (*)(id, SEL))(void *)objc_msgSend)(gyroData, sel_registerName("rotationRate"));
                    double x = ((double (*)(id, SEL))(void *)objc_msgSend)(rotVal, sel_registerName("x"));
                    double y = ((double (*)(id, SEL))(void *)objc_msgSend)(rotVal, sel_registerName("y"));
                    double z = ((double (*)(id, SEL))(void *)objc_msgSend)(rotVal, sel_registerName("z"));
                    snprintf(val, sizeof(val), "x=%.6f y=%.6f z=%.6f", x, y, z);
                } else { snprintf(val, sizeof(val), "not started"); }
                ADD_IDENT("sensor.gyroscope", "Gyroscope data", "Current gyroscope readings (bias fingerprint)", val, "", false, true, true);
            }

            if (magnet) {
                id magnetData = ((id (*)(id, SEL))(void *)objc_msgSend)(manager, sel_registerName("magnetometerData"));
                if (magnetData) {
                    id magVal = ((id (*)(id, SEL))(void *)objc_msgSend)(magnetData, sel_registerName("magneticField"));
                    double x = ((double (*)(id, SEL))(void *)objc_msgSend)(magVal, sel_registerName("x"));
                    double y = ((double (*)(id, SEL))(void *)objc_msgSend)(magVal, sel_registerName("y"));
                    double z = ((double (*)(id, SEL))(void *)objc_msgSend)(magVal, sel_registerName("z"));
                    NSInteger cal = ((NSInteger (*)(id, SEL))(void *)objc_msgSend)(magnetData, sel_registerName("calibrationAccuracy"));
                    snprintf(val, sizeof(val), "x=%.6f y=%.6f z=%.6f cal=%ld", x, y, z, (long)cal);
                } else { snprintf(val, sizeof(val), "not started"); }
                ADD_IDENT("sensor.magnetometer", "Magnetometer data", "Current magnetometer readings (calibration fingerprint)", val, "", false, true, true);
            }

            if (deviceMotion) {
                id motion = ((id (*)(id, SEL))(void *)objc_msgSend)(manager, sel_registerName("deviceMotion"));
                if (motion) {
                    id gravity = ((id (*)(id, SEL))(void *)objc_msgSend)(motion, sel_registerName("gravity"));
                    double gx = ((double (*)(id, SEL))(void *)objc_msgSend)(gravity, sel_registerName("x"));
                    double gy = ((double (*)(id, SEL))(void *)objc_msgSend)(gravity, sel_registerName("y"));
                    double gz = ((double (*)(id, SEL))(void *)objc_msgSend)(gravity, sel_registerName("z"));
                    snprintf(val, sizeof(val), "gravity=(%.4f,%.4f,%.4f)", gx, gy, gz);
                } else { snprintf(val, sizeof(val), "not started"); }
                ADD_IDENT("sensor.device_motion", "Device motion", "Device motion gravity vector (device orientation fingerprint)", val, "", false, true, true);
            }

            ((void (*)(id, SEL))(void *)objc_msgSend)(manager, sel_registerName("release"));
        } else {
            ADD_IDENT("sensor.availability", "Sensor availability", "CMMotionManager sensor availability", "unavailable", "", false, true, true);
        }
    } else {
        ADD_IDENT("sensor.availability", "Sensor availability", "CMMotionManager sensor availability", "unavailable (no CMMotionManager)", "", false, true, true);
    }

    {
        Class alt = objc_getClass("CMAltimeter");
        if (alt && ((BOOL (*)(id, SEL))(void *)objc_msgSend)((id)alt, sel_registerName("isRelativeAltitudeAvailable"))) {
            snprintf(val, sizeof(val), "available");
        } else { snprintf(val, sizeof(val), "unavailable"); }
        ADD_IDENT("sensor.barometer", "Barometer availability", "CMAltimeter relative altitude availability", val, "", false, true, true);
    }

    {
        Class prox = objc_getClass("UIDevice");
        if (prox) {
            id dev = ((id (*)(id, SEL))(void *)objc_msgSend)((id)prox, sel_registerName("currentDevice"));
            BOOL proxMon = ((BOOL (*)(id, SEL))(void *)objc_msgSend)(dev, sel_registerName("proximityMonitoringEnabled"));
            BOOL proxState = ((BOOL (*)(id, SEL))(void *)objc_msgSend)(dev, sel_registerName("proximityState"));
            snprintf(val, sizeof(val), "monitoring=%s state=%s", proxMon ? "Y" : "N", proxState ? "near" : "far");
            ADD_IDENT("sensor.proximity", "Proximity sensor", "UIDevice proximity sensor state", val, "", false, true, true);
        }
    }

    result->count = i;
}
