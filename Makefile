# See if we want verbose make.
V             ?= 0
# Debug build or not?
DEBUG         ?= 0
# Beta build or not?
BETA          ?= 0
# Build Nightly or not?
NIGHTLY       ?= 0

# Build for Elucubratus or not?
ELU_BUILD     ?= 0

TARGET_CODESIGN = $(shell which ldid)

# Platform to build for.
SILEO_PLATFORM ?= iphoneos-arm64
ifeq ($(SILEO_PLATFORM),iphoneos-arm64)
ARCH            = arm64
PLATFORM        = iphoneos
DEB_ARCH        = iphoneos-arm
PREFIX          =
DESTINATION     =
CONTENTS        =

ifeq ($(ELU_BUILD), 1)
DEB_DEPENDS     = firmware (>= 11.0), firmware (>= 12.2) | org.swift.libswift (>= 5.0), coreutils (>= 8.32-4), dpkg (>= 1.20.0), apt (>= 2.3.0), libzstd1
else
DEB_DEPENDS     = firmware (>= 11.0), firmware (>= 12.2) | org.swift.libswift (>= 5.0), coreutils (>= 8.31-1), dpkg (>= 1.19.7-2), apt (>= 1.8.2), libzstd1
endif

else ifeq ($(SILEO_PLATFORM),darwin-arm64)
# These trues are temporary
ARCH            = arm64
PLATFORM        = macosx
DEB_ARCH        = darwin-arm64
DEB_DEPENDS     = coreutils (>= 8.32-4), dpkg (>= 1.20.0), apt (>= 2.3.0), libzstd1
PREFIX          =
MAC             = 1
DESTINATION     = -destination "generic/platform=macOS,variant=Mac Catalyst,name=Any Mac"
CONTENTS        = Contents/
else ifeq ($(SILEO_PLATFORM),darwin-amd64)
# These trues are temporary
ARCH            = x86_64
PLATFORM        = macosx
DEB_ARCH        = darwin-amd64
DEB_DEPENDS     = coreutils (>= 8.32-4), dpkg (>= 1.20.0), apt (>= 2.3.0), libzstd1
PREFIX          =
MAC             = 1
DESTINATION     = -destination "generic/platform=macOS,variant=Mac Catalyst,name=Any Mac"
CONTENTS        = Contents/
else
$(error Unknown platform $(SILEO_PLATFORM))
endif

ifneq (,$(shell which xcpretty))
ifeq ($(V),0)
XCPRETTY := | xcpretty
endif
endif

MAKEFLAGS += --no-print-directory

export EXPANDED_CODE_SIGN_IDENTITY =
export EXPANDED_CODE_SIGN_IDENTITY_NAME =

STRIP = xcrun strip

ifneq ($(MAC), 1)
export PRODUCT_BUNDLE_IDENTIFIER = "org.coolstar.SileoStore"
SILEO_ID   = org.coolstar.sileo
else
export PRODUCT_BUNDLE_IDENTIFIER = "sileo"
SILEO_ID   = sileo
endif
export DISPLAY_NAME = "Sileo"
ICON = https:\/\/getsileo.app\/img\/icon.png
SILEO_NAME = Sileo
SILEO_APP  = Sileo.app
SILEO_VERSION = $$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" $(SILEO_STAGE_DIR)/$(PREFIX)/Applications/$(SILEO_APP)/$(CONTENTS)Info.plist)


ifeq ($(BETA), 1)
ifeq ($(MAC), 1)
export PRODUCT_BUNDLE_IDENTIFIER = "sileobeta"
SILEO_ID   = sileobeta
else
export PRODUCT_BUNDLE_IDENTIFIER = "org.coolstar.SileoBeta"
SILEO_ID   = org.coolstar.sileobeta
endif
export DISPLAY_NAME = "Sileo Beta"
ICON = https:\/\/getsileo.app\/img\/icon.png
SILEO_NAME = Sileo (Beta Channel)
SILEO_APP  = Sileo-Beta.app
SILEO_VERSION = $$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" $(SILEO_STAGE_DIR)/$(PREFIX)/Applications/$(SILEO_APP)/$(CONTENTS)Info.plist)+$$(git show -s --format=%cd --date=short HEAD | sed s/-//g).$$(git show -s --format=%cd --date=unix HEAD | sed s/-//g).$$(git rev-parse --short=7 HEAD)
endif

ifeq ($(NIGHTLY), 1)
ifeq ($(MAC), 1)
export PRODUCT_BUNDLE_IDENTIFIER = "sileonightly"
SILEO_ID   = sileonightly
else
export PRODUCT_BUNDLE_IDENTIFIER = "org.coolstar.SileoNightly"
SILEO_ID   = org.coolstar.sileonightly
endif
export DISPLAY_NAME = "Sileo Nightly"
ICON = https:\/\/beta.anamy.gay\/static\/SileoNightly.png
SILEO_NAME = Sileo (Nightly Channel)
SILEO_APP  = Sileo-Nightly.app
SILEO_VERSION = $$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" $(SILEO_STAGE_DIR)/$(PREFIX)/Applications/$(SILEO_APP)/$(CONTENTS)Info.plist)+$$(git show -s --format=%cd --date=short HEAD | sed s/-//g).$$(git show -s --format=%cd --date=unix HEAD | sed s/-//g).$$(git rev-parse --short=7 HEAD)
endif


SILEOTMP = $(TMPDIR)/sileo
SILEO_STAGE_DIR = $(SILEOTMP)/stage
SILEO_APP_DIR = $(SILEOTMP)/install/$(PREFIX)/Applications/Sileo.app

ifneq ($(DEBUG),0)
BUILD_CONFIG  := Debug
else
BUILD_CONFIG  := Release
endif

ifeq ($(ELU_BUILD), 1)
DPKG_TYPE ?= xz
else ifeq ($(shell dpkg-deb --help | grep -qi "zstd" && echo 1),1)
DPKG_TYPE ?= zstd
else
DPKG_TYPE ?= xz
endif

giveMeRoot/bin/giveMeRoot: giveMeRoot/giveMeRoot.c
	$(MAKE) -C giveMeRoot \
		CC="xcrun -sdk $(PLATFORM) cc -arch $(ARCH)"

ifeq ($(MAC), 1)
$(SILEO_APP_DIR):
	@set -o pipefail; \
		xcodebuild -jobs $(shell sysctl -n hw.ncpu) -project 'Sileo.xcodeproj' -scheme 'Sileo' $(DESTINATION) -configuration $(BUILD_CONFIG) ARCHS=$(ARCH) -derivedDataPath $(SILEOTMP) \
		archive -archivePath="$(SILEOTMP)/Sileo.xcarchive" \
		CODE_SIGNING_ALLOWED=NO PRODUCT_BUNDLE_IDENTIFIER=$(PRODUCT_BUNDLE_IDENTIFIER) DISPLAY_NAME=$(DISPLAY_NAME) \
		DSTROOT=$(SILEOTMP)/install $(XCPRETTY) ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES=NO
else
$(SILEO_APP_DIR):
	@set -o pipefail; \
		xcodebuild -jobs $(shell sysctl -n hw.ncpu) -project 'Sileo.xcodeproj' -scheme 'Sileo' -configuration $(BUILD_CONFIG) -arch $(ARCH) -sdk $(PLATFORM) -derivedDataPath $(SILEOTMP) \
		archive -archivePath="$(SILEOTMP)/Sileo.xcarchive" \
		CODE_SIGNING_ALLOWED=NO PRODUCT_BUNDLE_IDENTIFIER=$(PRODUCT_BUNDLE_IDENTIFIER) DISPLAY_NAME=$(DISPLAY_NAME) \
		DSTROOT=$(SILEOTMP)/install $(XCPRETTY) ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES=NO
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
endif

all:: $(SILEO_APP_DIR) giveMeRoot/bin/giveMeRoot

ifneq ($(MAC),1)
stage: all
	@mkdir -p $(SILEO_STAGE_DIR)/$(PREFIX)/Applications/
	@rm -rf $(SILEO_STAGE_DIR)/$(PREFIX)/Applications/$(SILEO_APP)
	@mv $(SILEO_APP_DIR) $(SILEO_STAGE_DIR)/$(PREFIX)/Applications/$(SILEO_APP)
	@rm -rf $(SILEO_STAGE_DIR)/$(PREFIX)/Applications/$(SILEO_APP)/_CodeSignature
	@rm -rf $(SILEO_STAGE_DIR)/$(PREFIX)/Applications/$(SILEO_APP)/Frameworks
	@cp giveMeRoot/bin/giveMeRoot $(SILEO_STAGE_DIR)/$(PREFIX)/Applications/$(SILEO_APP)/
	@$(TARGET_CODESIGN) -SSileo/Entitlements.entitlements $(SILEO_STAGE_DIR)/$(PREFIX)/Applications/$(SILEO_APP)/
	@$(TARGET_CODESIGN) -SgiveMeRoot/Entitlements.plist $(SILEO_STAGE_DIR)/$(PREFIX)/Applications/$(SILEO_APP)/giveMeRoot
	@chmod 4755 $(SILEO_STAGE_DIR)/$(PREFIX)/Applications/$(SILEO_APP)/giveMeRoot
else
stage: all
	@mkdir -p $(SILEO_STAGE_DIR)/$(PREFIX)/Applications/
	@rm -rf $(SILEO_STAGE_DIR)/$(PREFIX)/Applications/$(SILEO_APP)
	@mv $(SILEO_APP_DIR) $(SILEO_STAGE_DIR)/$(PREFIX)/Applications/$(SILEO_APP)
	@rm -rf $(SILEO_STAGE_DIR)/$(PREFIX)/Applications/$(SILEO_APP)/_CodeSignature
	@rm -rf $(SILEO_STAGE_DIR)/$(PREFIX)/Applications/$(SILEO_APP)/Frameworks
	@cp giveMeRoot/bin/giveMeRoot $(SILEO_STAGE_DIR)/$(PREFIX)/Applications/$(SILEO_APP)/Contents/Plugins/SileoRootWrapper.bundle/Contents/Resources/
	@$(TARGET_CODESIGN) -SSileo/Sileo.entitlements $(SILEO_STAGE_DIR)/$(PREFIX)/Applications/$(SILEO_APP)/Contents/MacOS/Sileo
	@$(TARGET_CODESIGN) -SSileo/Sileo.entitlements $(SILEO_STAGE_DIR)/$(PREFIX)/Applications/$(SILEO_APP)/Contents/Plugins/SileoRootWrapper.bundle/Contents/MacOS/SileoRootWrapper
	@$(TARGET_CODESIGN) -SSileo/Sileo.entitlements $(SILEO_STAGE_DIR)/$(PREFIX)/Applications/$(SILEO_APP)/Contents/Plugins/SileoRootWrapper.bundle/Contents/Resources/giveMeRoot
endif

ifeq ($(MAC), 1)
package: stage
	@cp -a ./layout/DEBIAN $(SILEO_STAGE_DIR)
	@sed -e s/@@MARKETING_VERSION@@/$(SILEO_VERSION)/ \
		-e 's/@@PACKAGE_ID@@/$(SILEO_ID)/' \
		-e 's/@@PACKAGE_NAME@@/$(SILEO_NAME)/' \
		-e 's/@@DEB_ARCH@@/$(DEB_ARCH)/' \
		-e 's/@@ICON@@/$(ICON)/' \
		-e 's/@@DEB_DEPENDS@@/$(DEB_DEPENDS)/' $(SILEO_STAGE_DIR)/DEBIAN/control.in > $(SILEO_STAGE_DIR)/DEBIAN/control
	@rm -f $(SILEO_STAGE_DIR)/DEBIAN/control.in
	@mkdir -p ./packages
	@dpkg-deb -Z$(DPKG_TYPE) --root-owner-group -b $(SILEO_STAGE_DIR) ./packages/$(SILEO_ID)_$(SILEO_VERSION)_$(DEB_ARCH).deb
else ifeq ($(ELU_BUILD), 1)
package: stage
	@cp -a ./layout/DEBIAN $(SILEO_STAGE_DIR)
	@mv $(SILEO_STAGE_DIR)/DEBIAN/postinst.elu.in $(SILEO_STAGE_DIR)/DEBIAN/postinst.in
	@mv $(SILEO_STAGE_DIR)/DEBIAN/triggers.elu $(SILEO_STAGE_DIR)/DEBIAN/triggers
	@sed -e s/@@MARKETING_VERSION@@/$(SILEO_VERSION)/ \
		-e 's/@@PACKAGE_ID@@/$(SILEO_ID)/' \
		-e 's/@@PACKAGE_NAME@@/$(SILEO_NAME)/' \
		-e 's/@@DEB_ARCH@@/$(DEB_ARCH)/' \
		-e 's/@@ICON@@/$(ICON)/' \
		-e 's/@@DEB_DEPENDS@@/$(DEB_DEPENDS)/' $(SILEO_STAGE_DIR)/DEBIAN/control.in > $(SILEO_STAGE_DIR)/DEBIAN/control
	@rm -f $(SILEO_STAGE_DIR)/DEBIAN/control.in
	@sed -e s/@@SILEO_APP@@/$(SILEO_APP)/ \
		$(SILEO_STAGE_DIR)/DEBIAN/postinst.in > $(SILEO_STAGE_DIR)/DEBIAN/postinst
	@chmod 0755 $(SILEO_STAGE_DIR)/DEBIAN/postinst
	@rm -f $(SILEO_STAGE_DIR)/DEBIAN/postinst.in
	@mkdir -p ./packages
	@dpkg-deb -Z$(DPKG_TYPE) --root-owner-group -b $(SILEO_STAGE_DIR) ./packages/$(SILEO_ID)_$(SILEO_VERSION)_$(DEB_ARCH).deb
else
package: stage
	@cp -a ./layout/DEBIAN $(SILEO_STAGE_DIR)
	@rm -rf $(SILEO_STAGE_DIR)/DEBIAN/postinst.elu.in
	@rm -rf $(SILEO_STAGE_DIR)/DEBIAN/triggers.elu
	@sed -e s/@@MARKETING_VERSION@@/$(SILEO_VERSION)/ \
		-e 's/@@PACKAGE_ID@@/$(SILEO_ID)/' \
		-e 's/@@PACKAGE_NAME@@/$(SILEO_NAME)/' \
		-e 's/@@DEB_ARCH@@/$(DEB_ARCH)/' \
		-e 's/@@ICON@@/$(ICON)/' \
		-e 's/@@DEB_DEPENDS@@/$(DEB_DEPENDS)/' $(SILEO_STAGE_DIR)/DEBIAN/control.in > $(SILEO_STAGE_DIR)/DEBIAN/control
	@rm -f $(SILEO_STAGE_DIR)/DEBIAN/control.in
	@sed -e s/@@SILEO_APP@@/$(SILEO_APP)/ \
		$(SILEO_STAGE_DIR)/DEBIAN/postinst.in > $(SILEO_STAGE_DIR)/DEBIAN/postinst
	@chmod 0755 $(SILEO_STAGE_DIR)/DEBIAN/postinst
	@rm -f $(SILEO_STAGE_DIR)/DEBIAN/postinst.in
	@mkdir -p ./packages
	@dpkg-deb -Z$(DPKG_TYPE) --root-owner-group -b $(SILEO_STAGE_DIR) ./packages/$(SILEO_ID)_$(SILEO_VERSION)_$(DEB_ARCH).deb
endif

clean::
	@$(MAKE) -C giveMeRoot clean
	@rm -rf $(SILEOTMP)
