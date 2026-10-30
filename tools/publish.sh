#!/bin/zsh
# Puts a release online, in the order that keeps Check for Updates working:
#   1. the GitHub release v<version> with the zip from tools/release.sh
#   2. then site/appcast.xml, committed and pushed (GitHub Pages republishes it)
# Pushing the feed first would offer an update whose download does not exist yet.
#
# Usage: tools/publish.sh
set -euo pipefail
here=${0:A:h:h}
name=MangoStats
version=$(plutil -extract CFBundleShortVersionString raw "$here/Info.plist.in")
zip="$here/dist/$name-$version.zip"
notes="$here/docs/releases/$version.md"
[[ -f "$zip" ]] || { print "missing $zip: run tools/release.sh first"; exit 1; }
grep -q "<sparkle:shortVersionString>$version<" "$here/site/appcast.xml" \
  || { print "site/appcast.xml has no $version: run tools/release.sh first"; exit 1; }

sha=$(shasum -a 256 "$zip" | cut -d' ' -f1)
body=$(mktemp)
{
  cat "$notes"
  print "\n## Install\n"
  print "MangoStats 1.0 and later update themselves: Settings › General › Check for Updates…"
  print "Otherwise download **$name-$version.zip**, unzip it, and replace $name.app in Applications."
  print "Your settings, history, and the fan helper approval carry over. Signed with Developer ID and notarized by Apple.\n"
  print "Requires macOS 26 or later on Apple silicon.\n"
  print "SHA-256 of \`$name-$version.zip\`: \`$sha\`"
} > "$body"

if gh release view "v$version" --repo Mangocorporation/$name >/dev/null 2>&1; then
  gh release upload "v$version" "$zip" --clobber --repo Mangocorporation/$name
else
  gh release create "v$version" "$zip" --repo Mangocorporation/$name --title "$name $version" --notes-file "$body"
fi
rm -f "$body"
# The download must answer before the feed points at it.
curl -sfIL -o /dev/null "https://github.com/Mangocorporation/$name/releases/download/v$version/$name-$version.zip" \
  || { print "the zip is not downloadable yet; run tools/publish.sh again in a minute"; exit 1; }

git -C "$here" add site/appcast.xml "$notes"
git -C "$here" commit -m "Offer $name $version in Check for Updates" >/dev/null
git -C "$here" push
print "published $version: the release is on GitHub, and the feed goes live when the Pages deploy finishes"
