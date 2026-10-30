#!/bin/zsh
# Average CPU of MangoStats over 30 s with one surface open (S-023).
# Usage: tools/energy.sh closed|popover|window   (release build installed by ./build.sh)
set -u
mode=${1:-closed}
app=~/Applications/MangoStats.app/Contents/MacOS/MangoStats
pkill -x MangoStats 2>/dev/null; sleep 1
APP_STORE=/tmp/MangoStats-energy APP_PROFILE=$mode $app >/dev/null 2>&1 &
pid=$!
sleep 10
seconds() { ps -o cputime= -p $pid | awk -F'[:.]' '{ if (NF==4) print $1*3600+$2*60+$3+$4/100; else print $1*60+$2+$3/100 }'; }
a=$(seconds); sleep 30; b=$(seconds)
kill $pid 2>/dev/null
printf "%s: %.2f%% CPU (%.2f s over 30 s)\n" $mode $(( (b - a) / 30.0 * 100 )) $(( b - a ))
