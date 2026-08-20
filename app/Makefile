TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = VideoApp

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = VideoApp

VideoApp_FILES = main.m AppDelegate.m ViewController.m
VideoApp_FRAMEWORKS = UIKit WebKit CoreGraphics
VideoApp_CFLAGS = -fobjc-arc
VideoApp_CODESIGN_FLAGS = -S

include $(THEOS_MAKE_PATH)/application.mk