TARGET := iphone:clang:latest:14.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := AlarmSearch

AlarmSearch_FILES := Tweak.xm
AlarmSearch_CFLAGS := -fobjc-arc
AlarmSearch_FRAMEWORKS := UIKit
AlarmSearch_LIBRARIES := substrate

INSTALL_TARGET_PROCESSES := MobileTimer

include $(THEOS_MAKE_PATH)/tweak.mk
