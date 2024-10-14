export PACKAGE_VERSION := 0.6

ifeq ($(THEOS_DEVICE_SIMULATOR),1)
TARGET := simulator:clang:latest:14.0
ARCHS := arm64 x86_64
INSTALL_TARGET_PROCESSES := SpringBoard
else
TARGET := iphone:clang:latest:14.0
ARCHS := arm64 arm64e
INSTALL_TARGET_PROCESSES := SpringBoard
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := DictationInKeyboard

DictationInKeyboard_FILES += DictationInKeyboard.xm
DictationInKeyboard_CFLAGS += -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

export THEOS_OBJ_DIR
after-all::
	@devkit/sim-install.sh
