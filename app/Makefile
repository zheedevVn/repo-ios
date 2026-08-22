THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = VideoApp

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = VideoApp

VideoApp_FILES = main.m AppDelegate.m ViewController.m
VideoApp_FRAMEWORKS = UIKit WebKit CoreGraphics
VideoApp_CFLAGS = -fobjc-arc
VideoApp_CODESIGN_FLAGS = -Sentitlements.plist
VideoApp_INSTALL_PATH = /Applications

include $(THEOS_MAKE_PATH)/application.mk

after-stage::
	$(ECHO_NOTHING)cp Info.plist $(THEOS_STAGING_DIR)/Applications/VideoApp.app/Info.plist$(ECHO_END)
	$(ECHO_NOTHING)cp AppIcon60x60@2x.png $(THEOS_STAGING_DIR)/Applications/VideoApp.app/AppIcon60x60@2x.png 2>/dev/null || true$(ECHO_END)
	$(ECHO_NOTHING)cp AppIcon60x60@2x.png $(THEOS_STAGING_DIR)/Applications/VideoApp.app/icon.png 2>/dev/null || true$(ECHO_END)
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/DEBIAN$(ECHO_END)
	$(ECHO_NOTHING)cp postinst $(THEOS_STAGING_DIR)/DEBIAN/postinst$(ECHO_END)
	$(ECHO_NOTHING)chmod 0755 $(THEOS_STAGING_DIR)/DEBIAN/postinst$(ECHO_END)