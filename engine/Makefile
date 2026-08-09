GO ?= go
GOMOBILE ?= $(shell which gomobile)
SING_BOX_TAG := v1.13.16

# The Go package is named "libbox", so gomobile produces the Swift module
# "Libbox" and the Java package "libbox" (class libbox.Libbox). The -o filename
# is just the output artifact name; keep it aligned with the module name.
LIBBOX_NAME := Libbox

.PHONY: tidy libbox-ios libbox-android test check

tidy:
	$(GO) mod tidy

# Build the Apple framework (requires macOS + Xcode CLT). Output: bin/Libbox.xcframework
libbox-ios:
	$(GO) mod tidy
	$(GOMOBILE) bind -target=ios -ldflags="-s -w" \
		-o bin/$(LIBBOX_NAME).xcframework proxyclient.dev/engine/libbox

# Build the Android AAR (requires Android NDK). Output: bin/Libbox.aar
libbox-android:
	$(GO) mod tidy
	$(GOMOBILE) bind -target=android -ldflags="-s -w" \
		-o bin/$(LIBBOX_NAME).aar proxyclient.dev/engine/libbox

test:
	$(GO) test ./libbox/...

check:
	$(GO) vet ./libbox/...
	$(GO) test ./libbox/...
