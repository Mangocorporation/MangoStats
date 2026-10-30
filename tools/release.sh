#!/bin/zsh
# Builds a MangoStats release that runs on any Mac: Developer ID signature,
# hardened runtime, notarized by Apple, ticket stapled. Writes dist/MangoStats-<version>.zip.
#
# Usage: tools/release.sh           build, sign, notarize, staple
#        tools/release.sh --check   build and verify what can be done without credentials;
#                                   list what is missing
#
# Needs, once per Mac (see docs/RELEASE.md):
#   - a "Developer ID Application" certificate for team SJR7785KA2 in the keychain
#   - notarization credentials saved with: xcrun notarytool store-credentials MangoMemory
#   - the Sparkle signing key, made once with generate_keys (docs/RELEASE.md)
# And, for each release, its notes in docs/releases/<version>.md.
set -euo pipefail
here=${0:A:h:h}
name=MangoStats
team=SJR7785KA2
# The team's notarization credentials, saved once as the "MangoMemory" keychain profile.
profile="${NOTARY_PROFILE:-MangoMemory}"
out="$HOME/Library/Developer/$name/release"
dist="$here/dist"
check=false
[[ " $* " == *" --check "* ]] && check=true

missing=()
identity=$(security find-identity -v -p codesigning 2>/dev/null | grep -o "\"Developer ID Application: [^\"]*($team)\"" | head -1 | tr -d '"' || true)
[[ -n "$identity" ]] || missing+=("Developer ID Application certificate for team $team")
xcrun notarytool history --keychain-profile "$profile" >/dev/null 2>&1 || missing+=("notarization credentials (keychain profile \"$profile\")")
scratch="$HOME/Library/Developer/$name/build"
sparkle="$scratch/artifacts/sparkle/Sparkle/bin"
[[ -x "$sparkle/sign_update" ]] || swift package resolve --package-path "$here" --scratch-path "$scratch" >/dev/null
# The key in the keychain must be the one the app trusts (SUPublicEDKey in Info.plist.in).
public_key=$("$sparkle/generate_keys" -p 2>/dev/null || true)
if [[ -z "$public_key" ]]; then
  missing+=("Sparkle signing key (run $sparkle/generate_keys)")
elif ! grep -q "<string>$public_key</string>" "$here/Info.plist.in"; then
  missing+=("SUPublicEDKey in Info.plist.in to match the Sparkle key ($public_key)")
fi
version=$(plutil -extract CFBundleShortVersionString raw "$here/Info.plist.in")
notes="$here/docs/releases/$version.md"
[[ -f "$notes" ]] || missing+=("release notes in docs/releases/$version.md")

if (( ${#missing} )) && ! $check; then
  print "Missing:"; printf '  - %s\n' "${missing[@]}"
  print "See docs/RELEASE.md, or run tools/release.sh --check."
  exit 1
fi

# Without the certificate, --check signs with the development identity to test the rest.
sign="${identity:-$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 -o '"Apple Development: [^"]*"' | tr -d '"' || true)}"
rm -rf "$out"
APP_DIR="$out" SIGN_IDENTITY="$sign" "$here/build.sh" >/dev/null
app="$out/$name.app"

codesign --verify --strict --deep "$app" && print "signature: valid ($sign)"
for bin in "$app/Contents/MacOS/$name" "$app/Contents/MacOS/${name}Helper"; do
  # Capture first: grep -q closing the pipe early fails the pipeline under pipefail.
  details=$(codesign -dv "$bin" 2>&1)
  [[ "$details" == *"(runtime)"* ]] && print "hardened runtime: ${bin:t}" || { print "no hardened runtime: ${bin:t}"; exit 1; }
done
codesign -v -R="identifier \"com.mangocorp.mangostats\" and anchor apple generic and certificate leaf[subject.OU] = \"$team\"" "$app" \
  && print "helper accepts this app: yes"

if $check; then
  if (( ${#missing} )); then print "\nMissing for a real release:"; printf '  - %s\n' "${missing[@]}"; else print "\nReady: run tools/release.sh"; fi
  exit 0
fi

mkdir -p "$dist"
zip="$dist/$name-$version.zip"
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
print "notarizing (a few minutes)…"
xcrun notarytool submit "$zip" --keychain-profile "$profile" --wait
xcrun stapler staple "$app"
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
spctl --assess --type execute -vv "$app"

# Check for Updates: sign the zip with the Sparkle key and add it to the feed.
# The feed goes online with tools/publish.sh, after the zip is on GitHub.
signature=$("$sparkle/sign_update" "$zip")   # sparkle:edSignature="…" length="…"
build=$(plutil -extract CFBundleVersion raw "$app/Contents/Info.plist")
python3 -I "$here/tools/appcast_add.py" "$here/site/appcast.xml" "$version" "$build" "$signature" "$notes"
print "added $version to site/appcast.xml"
print "released $zip. Next: tools/publish.sh"
