TARGET := iphone:clang:latest:14.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = DeviceStats

DeviceStats_FILES = main.m AppDelegate.m ViewController.m
DeviceStats_FRAMEWORKS = UIKit WebKit CoreTelephony SystemConfiguration
DeviceStats_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
DeviceStats_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk