#!/bin/zsh
# Runs the in-app self-test with throwaway settings. Exit code 0 when every check passed.
set -u
rm -rf ~/Library/Saved\ Application\ State/com.mangocorp.mangostats.savedState
store=/tmp/MangoStats-self
APP_STORE=$store ~/Applications/MangoStats.app/Contents/MacOS/MangoStats --selftest
