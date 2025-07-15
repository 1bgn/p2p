# Makefile for injectable build_runner tasks

.PHONY: build watch clean rebuild

## Run code generation once
build:
	flutter pub run build_runner build --delete-conflicting-outputs

## Continuously watch for code changes and regenerate
watch:
	flutter pub run build_runner watch --delete-conflicting-outputs

## Clean generated files
clean:
	flutter clean
	rm -rf lib/**.g.dart lib/**.config.dart
	rm -rf .dart_tool build

## Clean and rebuild all generated files
rebuild: clean build

buildicons:
	flutter pub run flutter_launcher_icons
rmdmg:
	mv build/macos/Build/Products/Release/beam_drop.app build/macos/Build/Products/Release/BeamDrop.app
builddmg:
	create-dmg \
	--volname "BeamDrop" \
	--window-pos 200 120 \
	--window-size 800 400 \
	--icon-size 100 \
	--icon "BeamDrop.app" 200 190 \
	--hide-extension "BeamDrop.app" \
	--app-drop-link 600 185 \
	/Users/semenhrispens/projects/beam_drop/BeamDrop.dmg \
	/Users/semenhrispens/projects/beam_drop/build/macos/Build/Products/Release/BeamDrop.app



