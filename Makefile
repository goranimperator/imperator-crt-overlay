APP_NAME = CRTOverlay
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS = $(APP_BUNDLE)/Contents
MACOS = $(CONTENTS)/MacOS

SWIFT_FILES = Sources/main.swift \
              Sources/AppDelegate.swift \
              Sources/OverlayWindow.swift \
              Sources/CRTMetalView.swift \
              Sources/CRTSettings.swift \
              Sources/StatusBarController.swift

.PHONY: build run clean

build: $(MACOS)/$(APP_NAME) $(CONTENTS)/Info.plist
	@codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "Build complete: $(APP_BUNDLE)"

$(MACOS)/$(APP_NAME): $(SWIFT_FILES)
	@mkdir -p $(MACOS)
	swiftc $(SWIFT_FILES) \
		-o $@ \
		-framework AppKit \
		-framework Metal \
		-framework MetalKit \
		-framework QuartzCore \
		-suppress-warnings \
		-O

$(CONTENTS)/Info.plist: Info.plist
	@mkdir -p $(CONTENTS)
	cp Info.plist $@

run: build
	@open $(APP_BUNDLE)

clean:
	rm -rf $(BUILD_DIR)
