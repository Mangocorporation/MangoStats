#!/bin/zsh
# Builds MangoStats and installs it to ~/Applications/MangoStats.app.
# Build products live in ~/Library/Developer/MangoStats, outside the repo
# (and outside Dropbox or iCloud, which would try to sync them).
#
# Usage: ./build.sh            release build, install
#        ./build.sh --debug    debug build, install
#        ./build.sh --open     install, then quit the running copy and open the new one
#        APP_DIR=<dir> SIGN_IDENTITY="Developer ID Application: …" ./build.sh
#                              build into <dir> with Developer ID (tools/release.sh does this)
set -euo pipefail
here=${0:A:h}
name="MangoStats"
scratch="$HOME/Library/Developer/$name/build"
config=release
[[ " $* " == *" --debug "* ]] && config=debug

# Sign with your Apple Development certificate when you have one (Xcode >
# Settings > Accounts). Otherwise sign ad hoc, which is fine for your own Mac.
identity="${SIGN_IDENTITY:-}"
if [[ -z "$identity" ]]; then
  identity=$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 -o '"Apple Development: [^"]*"' | tr -d '"' || true)
fi
[[ -n "$identity" ]] || identity=-

swift build -c $config --package-path "$here" --scratch-path "$scratch" 2>&1 | grep -E "error|warning|Build complete" | grep -v "^\[" || true
bin="$scratch/$config/$name"
[[ -x "$bin" ]] || { echo "build failed"; exit 1; }
# swift build can report success while an edited file failed to compile. Catch that.
stale=$(find "$here/Sources" -name '*.swift' -newer "$bin" | head -1)
if [[ -n "$stale" ]]; then
  echo "build failed: binary is older than $stale"
  swift build -c $config --package-path "$here" --scratch-path "$scratch" 2>&1 | grep -E "error" | head -20
  exit 1
fi

app="${APP_DIR:-$HOME/Applications}/$name.app"
mkdir -p "${app:h}"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/$name"
# The fan helper (S-024): a launch daemon that runs from inside the bundle.
cp "$scratch/$config/${name}Helper" "$app/Contents/MacOS/${name}Helper"
mkdir -p "$app/Contents/Library/LaunchDaemons"
cp "$here/LaunchDaemons/"*.plist "$app/Contents/Library/LaunchDaemons/"
# Sparkle, for Check for Updates. -R keeps the framework's symlinks.
mkdir -p "$app/Contents/Frameworks"
cp -R "$scratch/$config/Sparkle.framework" "$app/Contents/Frameworks/"
sed -e "s/__BUILD__/$(date +%Y%m%d%H%M)/" "$here/Info.plist.in" > "$app/Contents/Info.plist"
# The icon: Icon/AppIcon.icon -> Resources/Assets.car + AppIcon.icns, rebuilt when it changed.
if [[ -d "$here/Icon/AppIcon.icon" ]]; then
  car="$here/Resources/Assets.car"
  if [[ ! -f "$car" || -n "$(find "$here/Icon/AppIcon.icon" -newer "$car" | head -1)" ]]; then
    "$here/tools/make_icon.sh"
  fi
  cp -X "$car" "$here/Resources/AppIcon.icns" "$app/Contents/Resources/"
fi
# -s also clears the framework symlinks: an attribute left on one becomes a ._ file in the
# release zip, and Gatekeeper rejects ._ files in a framework's root after some unzips.
xattr -crs "$app"
# Sign from the inside out, all with the hardened runtime (launchd daemons and
# notarization need it). Developer ID adds a secure timestamp.
flags=(--force --options runtime)
[[ "$identity" == "Developer ID"* ]] && flags+=(--timestamp)
codesign $flags --identifier com.mangocorp.mangostats.helper --sign "$identity" \
  "$app/Contents/MacOS/${name}Helper" 2>&1 | grep -v "replacing existing signature" || true
# Sparkle as its documentation says: the XPC services, the installer tools, then
# the framework. The Downloader keeps its entitlements.
sparkle="$app/Contents/Frameworks/Sparkle.framework/Versions/B"
for part in XPCServices/Installer.xpc XPCServices/Downloader.xpc Autoupdate Updater.app; do
  codesign $flags --preserve-metadata=entitlements --sign "$identity" "$sparkle/$part" 2>&1 | grep -v "replacing existing signature" || true
done
codesign $flags --sign "$identity" "$app/Contents/Frameworks/Sparkle.framework" 2>&1 | grep -v "replacing existing signature" || true
codesign $flags --sign "$identity" "$app" 2>&1 | grep -v "replacing existing signature" || true
echo "installed $app (signed: ${identity})"

if [[ " $* " == *" --open "* ]]; then
  osascript -e "quit app \"$name\"" 2>/dev/null || true
  sleep 0.5
  open "$app"
fi
