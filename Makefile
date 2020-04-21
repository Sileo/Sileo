INSTALL_TARGET_PROCESSES = Sileo
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

XCODEPROJ_NAME = Sileo

Sileo_CODESIGN_FLAGS = -Sent.plist

include $(THEOS_MAKE_PATH)/xcodeproj.mk

giveMeRoot/bin/giveMeRoot: giveMeRoot/giveMeRoot.c
	$(MAKE) -C giveMeRoot

all:: giveMeRoot/bin/giveMeRoot

before-all::
ifeq ($(wildcard Pods),)
$(error Please install CocoaPods and then run 'pod install')
endif
	@git submodule update --init --recursive

internal-stage::
	mkdir -p $(THEOS_STAGING_DIR)/Applications/Sileo.app
	cp giveMeRoot/bin/giveMeRoot $(THEOS_STAGING_DIR)/Applications/Sileo.app/
	$(FAKEROOT) chmod 4755 $(THEOS_STAGING_DIR)/Applications/Sileo.app/giveMeRoot

internal-clean::
	$(MAKE) -C giveMeRoot clean

after-install::
	install.exec 'uicache -p /Applications/Sileo.app; uiopen sileo:'
