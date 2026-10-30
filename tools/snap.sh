#!/bin/zsh
# Snapshots of every page in light and dark, with live data and throwaway settings.
# Usage: tools/snap.sh            all pages
#        APP_SNAPSHOT_PAGES=popover,settings tools/snap.sh
set -u
app=~/Applications/MangoStats.app/Contents/MacOS/MangoStats
store=/tmp/MangoStats-test
shots=/tmp/MangoStats-shots
# A crashed run leaves saved window state, and the next launch would wait on a "reopen windows?" alert.
rm -rf ~/Library/Saved\ Application\ State/com.mangocorp.mangostats.savedState
rm -rf $shots
APP_STORE=$store APP_SNAPSHOT=$shots $app
