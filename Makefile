# FingerDump root Makefile
# Build: tweak + daemon
# App is built separately via Xcode project

export TARGET = iphone:latest:14.0
export ARCHS = arm64 arm64e
export PACKAGE_VERSION = 1.0.0

TWEAK_NAME = FingerDumpTweak
FingerDumpTweak_FILES = Tweak.xm
FingerDumpTweak_CFLAGS = -I.
FingerDumpTweak_PRIVATE_FRAMEWORKS = CoreTelephony

TOOL_NAME = fingerdumpd
fingerdumpd_FILES = \
	daemon/fingerdumpd.c daemon/scanner.c daemon/socket_server.c \
	daemon/hardware.c daemon/system.c daemon/network.c daemon/graphics.c \
	daemon/audio.c daemon/sensor.c daemon/font.c daemon/persistence.c \
	daemon/behavioral.c daemon/browser.c
fingerdumpd_CFLAGS = \
	-I. \
	-framework CoreFoundation -framework CoreGraphics \
	-framework IOKit -framework Security -framework CoreMotion \
	-framework AudioToolbox -framework CoreText -framework WebKit \
	-framework UIKit
fingerdumpd_LDFLAGS = \
	-lobjc \
	-F/System/Library/PrivateFrameworks \
	-framework CoreTelephony

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/tweak.mk
include $(THEOS)/makefiles/tool.mk

after-install::
	install.exec "killall -9 fingerdumpd 2>/dev/null || true"
	install.exec "mkdir -p /var/mobile/Library/FingerDump/www"
	install.exec "cp -r web/* /var/mobile/Library/FingerDump/www/"
	install.exec "chmod 755 /usr/libexec/fingerdumpd"
	install.exec "chmod 644 /Library/MobileSubstrate/DynamicLibraries/FingerDumpTweak.dylib"
	install.exec "chmod 644 /Library/MobileSubstrate/DynamicLibraries/FingerDumpTweak.plist"
	install.exec "/usr/libexec/fingerdumpd --daemon"
	install.exec "uicache -p /Applications/FingerDump.app 2>/dev/null || true"
