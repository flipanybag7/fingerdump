# FingerDump root Makefile
# Build: tweak + daemon + preference bundle

export TARGET = iphone:latest:14.0
export ARCHS = arm64
export PACKAGE_ARCH = iphoneos-arm
export PACKAGE_VERSION = 1.0.0
export TARGET_CODESIGN = true

TWEAK_NAME = FingerDumpTweak
FingerDumpTweak_FILES = Tweak.xm
FingerDumpTweak_CFLAGS = -I.
FingerDumpTweak_PRIVATE_FRAMEWORKS = CoreTelephony

TOOL_NAME = fingerdumpd
fingerdumpd_FILES = \
	daemon/fingerdumpd.m daemon/scanner.m daemon/socket_server.m daemon/httpserver.m \
	daemon/hardware.m daemon/system.m daemon/network.m daemon/graphics.m \
	daemon/audio.m daemon/sensor.m daemon/font.m daemon/persistence.m \
	daemon/behavioral.m daemon/browser.m
fingerdumpd_CFLAGS = -I.
fingerdumpd_CODESIGN_FLAGS = -Sentitlements.plist
fingerdumpd_LDFLAGS = \
	-lobjc \
	-framework CoreFoundation \
	-framework Security

BUNDLE_NAME = FingerDumpPrefs
FingerDumpPrefs_FILES = FingerDumpPrefs/FPPreferenceController.m
FingerDumpPrefs_CFLAGS = -I.
FingerDumpPrefs_LDFLAGS = -framework UIKit -framework Foundation -lobjc
FingerDumpPrefs_INSTALL_PATH = /Library/PreferenceBundles
FingerDumpPrefs_PLIST = FingerDumpPrefs/Resources/Info.plist

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/tweak.mk
include $(THEOS)/makefiles/tool.mk
include $(THEOS)/makefiles/bundle.mk

after-install::
	install.exec "mkdir -p /var/mobile/Library/FingerDump/www"
	install.exec "cp -r web/* /var/mobile/Library/FingerDump/www/"
	install.exec "chmod 755 /usr/bin/fingerdumpd"
	install.exec "chmod 644 /Library/MobileSubstrate/DynamicLibraries/FingerDumpTweak.dylib"
	install.exec "chmod 644 /Library/MobileSubstrate/DynamicLibraries/FingerDumpTweak.plist"
