# See if we want verbose make.
V     ?= 0
# Debug build or not?
DEBUG ?= 0
# Beta build or not?
BETA  ?= 0

ifneq (,$(shell which xcpretty))
ifeq ($(V),0)
XCPRETTY := | xcpretty
endif
endif

MAKEFLAGS += --no-print-directory

export EXPANDED_CODE_SIGN_IDENTITY =
export EXPANDED_CODE_SIGN_IDENTITY_NAME =

LDID = $(shell which ldid)
STRIP = xcrun strip

ifneq ($(BETA),0)
export PRODUCT_BUNDLE_IDENTIFIER = "org.coolstar.SileoBeta"
SILEO_ID   = org.coolstar.sileobeta
SILEO_NAME = Sileo (Beta Channel)
SILEO_APP  = Sileo-Beta.app
else
export PRODUCT_BUNDLE_IDENTIFIER = "org.coolstar.SileoStore"
SILEO_ID   = org.coolstar.sileo
SILEO_NAME = Sileo
SILEO_APP  = Sileo.app
endif

SILEOTMP = $(TMPDIR)/sileo
SILEO_STAGE_DIR = $(SILEOTMP)/stage
SILEO_APP_DIR = $(SILEOTMP)/install/Applications/Sileo.app

ifneq ($(DEBUG),0)
BUILD_CONFIG  := Debug
SILEO_VERSION = $$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" $(SILEO_STAGE_DIR)/Applications/$(SILEO_APP)/Info.plist)+debug
else
BUILD_CONFIG  := Release
SILEO_VERSION = $$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" $(SILEO_STAGE_DIR)/Applications/$(SILEO_APP)/Info.plist)
endif

ifeq ($(shell dpkg-deb --help | grep "zstd" && echo 1),1)
DPKG_TYPE ?= zstd
else
DPKG_TYPE ?= xz
endif

giveMeRoot/bin/giveMeRoot: giveMeRoot/giveMeRoot.c
	$(MAKE) -C giveMeRoot

$(SILEO_APP_DIR):
	@set -o pipefail; \
		xcodebuild -jobs $(shell sysctl -n hw.ncpu) -workspace 'Sileo.xcworkspace' -scheme 'Sileo' -configuration $(BUILD_CONFIG) -arch arm64 -sdk iphoneos -derivedDataPath $(SILEOTMP) \
		archive -archivePath="$(SILEOTMP)/Sileo.xcarchive" \
		CODE_SIGNING_ALLOWED=NO PRODUCT_BUNDLE_IDENTIFIER=$(PRODUCT_BUNDLE_IDENTIFIER) \
		DSTROOT=$(SILEOTMP)/install $(XCPRETTY)
	@rm -f $(SILEO_APP_DIR)/Frameworks/libswift*.dylib
	@function process_exec { \
		$(STRIP) $$1; \
	}; \
	function process_bundle { \
		process_exec $$1/$$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" $$1/Info.plist); \
	}; \
	export -f process_exec process_bundle; \
	find $(SILEO_APP_DIR) -name '*.dylib' -print0 | xargs -I{} -0 bash -c 'process_exec "$$@"' _ {}; \
	find $(SILEO_APP_DIR) \( -name '*.framework' -or -name '*.appex' \) -print0 | xargs -I{} -0 bash -c 'process_bundle "$$@"' _ {}; \
	process_bundle $(SILEO_APP_DIR)

all:: $(SILEO_APP_DIR) giveMeRoot/bin/giveMeRoot

stage: all
	@mkdir -p $(SILEO_STAGE_DIR)/Applications/
	@cp -a ./layout/DEBIAN $(SILEO_STAGE_DIR)
	@cp -a $(SILEO_APP_DIR) $(SILEO_STAGE_DIR)/Applications/$(SILEO_APP)
	@cp giveMeRoot/bin/giveMeRoot $(SILEO_STAGE_DIR)/Applications/$(SILEO_APP)/
	@$(LDID) -SSileo/Entitlements.plist $(SILEO_STAGE_DIR)/Applications/$(SILEO_APP)/
	@$(LDID) -SgiveMeRoot/Entitlements.plist $(SILEO_STAGE_DIR)/Applications/$(SILEO_APP)/giveMeRoot
	@chmod 4755 $(SILEO_STAGE_DIR)/Applications/$(SILEO_APP)/giveMeRoot
	@sed -e s/@@MARKETING_VERSION@@/$(SILEO_VERSION)/ \
		-e 's/@@PACKAGE_ID@@/$(SILEO_ID)/' \
		-e 's/@@PACKAGE_NAME@@/$(SILEO_NAME)/' $(SILEO_STAGE_DIR)/DEBIAN/control.in > $(SILEO_STAGE_DIR)/DEBIAN/control
	@rm -f $(SILEO_STAGE_DIR)/DEBIAN/control.in

package: stage
	@mkdir -p ./packages
	@dpkg-deb -Z$(DPKG_TYPE) --root-owner-group -b $(SILEO_STAGE_DIR) ./packages/$(SILEO_ID)_$(SILEO_VERSION)_iphoneos-arm.deb

clean::
	@$(MAKE) -C giveMeRoot clean
	@rm -rf $(SILEOTMP)
