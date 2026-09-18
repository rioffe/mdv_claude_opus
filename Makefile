# mdv6 — §5.3 build and release targets (R-34, K-11).
SHELL := /bin/bash
.DEFAULT_GOAL := build

APP        := build/mdv6.app
DIST       := dist
# Release inputs (§5.3). The checked-in identity defaults name the repository owner's identity and MUST be
# overridden by any other release engineer; VERSION is derived only from the exact tag (D-32).
# TEAM_ID is the repository owner's Apple Team ID (placeholder until set)
TEAM_ID        ?= XXXXXXXXXX
CERT_NAME      ?= Developer ID Application: Robert Ioffe ($(TEAM_ID))
NOTARY_PROFILE ?= mdv6-notary
NOTES_FILE     ?=

# The exact tag on HEAD, or empty. Not overridable: a command-line VERSION is rejected by check-version.
GIT_EXACT_TAG := $(shell git describe --tags --exact-match 2>/dev/null)
ifeq ($(origin VERSION), command line)
  VERSION_OVERRIDDEN := 1
endif
VERSION := $(GIT_EXACT_TAG)
RELEASE_VERSION := $(patsubst v%,%,$(VERSION))
ZIP := $(DIST)/mdv6-$(RELEASE_VERSION)-macos.zip

.PHONY: build release run install install-cli uninstall register clean dist check-version sign zip-notary notarize staple zip-release checksum verify-release github-release icon deps test

deps:
	@command -v swift >/dev/null || { echo "swift toolchain required"; exit 1; }
	@swift --version 2>/dev/null | grep -qE 'Swift version ([5]\.(9|[1-9][0-9])|[6-9]\.)' || { echo "Swift >= 5.9 required"; exit 1; }
	@[ "$$(sw_vers -productVersion | cut -d. -f1)" -ge 13 ] || { echo "macOS >= 13 required"; exit 1; }
	@[ -x ./build.sh ] || { echo "build.sh must be executable"; exit 1; }

build: deps
	./build.sh debug

release: deps
	./build.sh release

run: build
	open $(APP)

test:
	swift test

install: release
	rm -rf /Applications/mdv6.app
	cp -R $(APP) /Applications/mdv6.app
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/mdv6.app
	$(MAKE) install-cli

install-cli:
	sudo ln -sf "$(CURDIR)/bin/mdv6" /usr/local/bin/mdv6

uninstall:
	sudo rm -f /usr/local/bin/mdv6
	rm -rf /Applications/mdv6.app

register: build
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f $(APP)

clean:
	rm -rf build .build build_icon

icon:
	./tools/build-icon.sh

# --- dist chain (R-34): check-version MUST run and fail before clean or any build step ---
check-version:
	@if [ -n "$(VERSION_OVERRIDDEN)" ]; then echo "check-version: VERSION cannot be given on the command line; releases are named from the exact vX.Y.Z tag on HEAD (R-34)"; exit 1; fi
	@if [ -z "$(GIT_EXACT_TAG)" ]; then echo "check-version: HEAD carries no exact tag; tag it vX.Y.Z first (R-34)"; exit 1; fi
	@if ! echo "$(GIT_EXACT_TAG)" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$$'; then echo "check-version: tag '$(GIT_EXACT_TAG)' is not vX.Y.Z (R-34)"; exit 1; fi
	@echo "check-version: releasing $(GIT_EXACT_TAG)"

dist: check-version
	$(MAKE) clean
	$(MAKE) release
	$(MAKE) sign
	$(MAKE) zip-notary
	$(MAKE) notarize
	$(MAKE) staple
	$(MAKE) zip-release
	$(MAKE) checksum
	$(MAKE) verify-release

sign:
	@[ -n "$(CERT_NAME)" ] || { echo "sign: CERT_NAME is empty"; exit 1; }
	codesign --force --deep --options runtime --timestamp --sign "$(CERT_NAME)" --entitlements mdv6/mdv6.entitlements $(APP)
	codesign --verify --deep --strict $(APP)

zip-notary:
	mkdir -p $(DIST)
	ditto -c -k --keepParent $(APP) $(DIST)/mdv6-notary.zip

notarize:
	@[ -n "$(NOTARY_PROFILE)" ] || { echo "notarize: NOTARY_PROFILE is empty"; exit 1; }
	xcrun notarytool submit $(DIST)/mdv6-notary.zip --keychain-profile "$(NOTARY_PROFILE)" --wait

staple:
	xcrun stapler staple $(APP)
	xcrun stapler validate $(APP)

zip-release:
	rm -f $(ZIP)
	ditto -c -k --keepParent $(APP) $(ZIP)

checksum:
	cd $(DIST) && shasum -a 256 $(notdir $(ZIP)) > $(notdir $(ZIP)).sha256

verify-release:
	rm -rf $(DIST)/verify && mkdir -p $(DIST)/verify
	ditto -x -k $(ZIP) $(DIST)/verify
	codesign --verify --deep --strict $(DIST)/verify/mdv6.app
	spctl --assess --type execute --verbose=4 $(DIST)/verify/mdv6.app
	xcrun stapler validate $(DIST)/verify/mdv6.app

github-release: check-version
	gh release create $(VERSION) $(ZIP) $(ZIP).sha256 --title "mdv6 $(VERSION)" $(if $(NOTES_FILE),--notes-file $(NOTES_FILE),--generate-notes)
