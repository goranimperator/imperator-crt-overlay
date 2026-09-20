EXE_NAME = CRTImperator
APP_NAME = Imperator CRT Overlay
BUILD_DIR = build
DIST = dist
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS = $(APP_BUNDLE)/Contents
MACOS = $(CONTENTS)/MacOS
RESOURCES = $(CONTENTS)/Resources
ZIP = $(DIST)/Imperator-CRT-Overlay-$(VERSION).zip

# Lowest macOS the app runs on. Kept at 13.0 so the app is not restricted to
# macOS 27 machines.
DEPLOYMENT_TARGET = 13.0

# AppKit picks the generation of every control it draws from the sdk field in
# LC_BUILD_VERSION, not from the macOS it is running on. swiftc stamps that
# field from -target, so a binary targeting 13.0 would draw macOS 13 era
# controls forever. Passing -platform_version explicitly stamps the real SDK
# while leaving the minimum where it is: minos 13.0, sdk 27.0.
SDK_VERSION = $(shell xcrun --sdk macosx --show-sdk-version)

BUILD_NUMBER = $(shell git rev-list --count HEAD)
# The release target commits before it tags, but make expands its variables
# first, so the tagged build needs that pending commit counted.
RELEASE_BUILD_NUMBER = $(shell expr $$(git rev-list --count HEAD) + 1)

SWIFT_FILES = Sources/main.swift \
              Sources/AppDelegate.swift \
              Sources/OverlayWindow.swift \
              Sources/CRTMetalView.swift \
              Sources/CRTSettings.swift \
              Sources/StatusBarController.swift \
              Sources/MenuBarPanel.swift

.PHONY: build run clean check-version dist release

build: $(SWIFT_FILES) Info.plist icon.icns menubar-icon.png menubar-icon@2x.png
	@mkdir -p "$(MACOS)" "$(RESOURCES)"
	swiftc $(SWIFT_FILES) \
		-o "$(MACOS)/$(EXE_NAME)" \
		-target arm64-apple-macos$(DEPLOYMENT_TARGET) \
		-Xlinker -platform_version -Xlinker macos \
		-Xlinker $(DEPLOYMENT_TARGET) -Xlinker $(SDK_VERSION) \
		-framework AppKit \
		-framework Metal \
		-framework MetalKit \
		-framework QuartzCore \
		-suppress-warnings \
		-O
	cp Info.plist "$(CONTENTS)/Info.plist"
	cp icon.icns "$(RESOURCES)/icon.icns"
	cp menubar-icon.png "$(RESOURCES)/menubar-icon.png"
	cp "menubar-icon@2x.png" "$(RESOURCES)/menubar-icon@2x.png"
	@xcrun actool Assets.xcassets --compile "$(RESOURCES)" --platform macosx --minimum-deployment-target $(DEPLOYMENT_TARGET) --output-partial-info-plist /dev/null 2>/dev/null || true
	@codesign --force --deep --sign - "$(APP_BUNDLE)"
	@echo "Build complete: $(APP_BUNDLE)"

run: build
	@open "$(APP_BUNDLE)"

clean:
	rm -rf $(BUILD_DIR) $(DIST)

check-version:
	@test -n "$(VERSION)" || { echo "Usage: make $(MAKECMDGOALS) VERSION=x.y.z"; exit 1; }

# Distributable zip. Touches nothing in git and nothing on the remote.
dist: check-version
	@mkdir -p $(DIST)
	rm -f "$(ZIP)"
	$(MAKE) build
	@# Stamp the version into the built bundle rather than the source, so a test
	@# zip reports what it would ship as without dirtying the working tree.
	@# Editing Info.plist breaks the signature, so re-sign afterwards.
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" "$(CONTENTS)/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILD_NUMBER)" "$(CONTENTS)/Info.plist"
	codesign --force --deep --sign - "$(APP_BUNDLE)"
	ditto -c -k --sequesterRsrc --keepParent "$(APP_BUNDLE)" "$(ZIP)"
	@echo "Wrote $(ZIP)"

# Bump the version, commit, tag, push, publish the GitHub release with the zip.
release: check-version
	@git diff --quiet && git diff --cached --quiet || { echo "Working tree dirty -- commit first."; exit 1; }
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(RELEASE_BUILD_NUMBER)" Info.plist
	$(MAKE) dist VERSION=$(VERSION) BUILD_NUMBER=$(RELEASE_BUILD_NUMBER)
	git add Info.plist
	git commit -m "Release v$(VERSION)"
	git tag -a v$(VERSION) -m "$(APP_NAME) $(VERSION)"
	git push origin HEAD
	git push origin v$(VERSION)
	gh release create v$(VERSION) \
		--title "$(APP_NAME) $(VERSION)" \
		--notes-file release-notes.md \
		"$(ZIP)#$(APP_NAME) $(VERSION) (macOS)"
