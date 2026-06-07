EXE_NAME = CRTImperator
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/Imperator CRT Overlay.app
CONTENTS = $(APP_BUNDLE)/Contents
MACOS = $(CONTENTS)/MacOS
RESOURCES = $(CONTENTS)/Resources

SWIFT_FILES = Sources/main.swift \
              Sources/AppDelegate.swift \
              Sources/OverlayWindow.swift \
              Sources/CRTMetalView.swift \
              Sources/CRTSettings.swift \
              Sources/StatusBarController.swift

.PHONY: build run clean

build: $(SWIFT_FILES) Info.plist icon.icns menubar-icon.png menubar-icon@2x.png
	@mkdir -p "$(MACOS)" "$(RESOURCES)"
	swiftc $(SWIFT_FILES) \
		-o "$(MACOS)/$(EXE_NAME)" \
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
	@xcrun actool Assets.xcassets --compile "$(RESOURCES)" --platform macosx --minimum-deployment-target 13.0 --output-partial-info-plist /dev/null 2>/dev/null || true
	@codesign --force --deep --sign - "$(APP_BUNDLE)"
	@echo "Build complete: $(APP_BUNDLE)"

run: build
	@open "$(APP_BUNDLE)"

clean:
	rm -rf $(BUILD_DIR)
