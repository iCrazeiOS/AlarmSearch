export SDKVERSION = 14.5
export ARCHS = arm64 arm64e
export PREFIX = $(THEOS)/toolchain/Xcode16.xctoolchain/usr/bin/

INSTALL_TARGET_PROCESSES := MobileTimer

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := AlarmSearch

AlarmSearch_FILES := Tweak.xm
AlarmSearch_CFLAGS := -fobjc-arc -fvisibility=hidden

include $(THEOS_MAKE_PATH)/tweak.mk
