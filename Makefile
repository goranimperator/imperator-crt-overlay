APP_NAME = CRTImperator
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

RESOURCES = $(CONTENTS)/Resources

build: $(MACOS)/$(APP_NAME) $(CONTENTS)/Info.plist $(RESOURCES)/icon.icns $(RESOURCES)/menubar-icon.png $(RESOURCES)/menubar-icon@2x.png
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

$(RESOURCES)/icon.icns: icon.icns
	@mkdir -p $(RESOURCES)
	cp icon.icns $@

$(RESOURCES)/menubar-icon.png: menubar-icon.png
	@mkdir -p $(RESOURCES)
	cp menubar-icon.png $@

$(RESOURCES)/menubar-icon@2x.png: menubar-icon@2x.png
	@mkdir -p $(RESOURCES)
	cp menubar-icon@2x.png $@

run: build
	@open $(APP_BUNDLE)

clean:
	rm -rf $(BUILD_DIR)
