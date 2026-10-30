# Fix log

## 2026-10-30 Power column read 0.0 for every process
Symptom: PWR showed 0,0 even for Chrome at 88 % CPU.
Cause: `ri_billed_energy` (rusage v4) moves in tiny, delayed steps (Chrome: 0.03 W over 2 s).
Fix: read `ri_energy_nj` from `RUSAGE_INFO_V6`, the per-process energy estimate (Chrome ≈ 1 W).
Rule: Probe a new kernel counter twice, 2 s apart, on a busy process before building on it.

## 2026-10-30 Energy numbers jumped between identical runs
Symptom: tools/energy.sh read 0.6 % and 12 % CPU for the same build, closed.
Cause: each run swaps the test instance into the menu bar; clicking it during a run opens the
real popover (process reading + rendering), and battery power slows the clocks.
Fix: compare builds back to back, several runs each; read a heavy run's `sample` top of stack.
Rule: Never trust one energy run; A/B the old and new build in the same session before acting.

## 2026-10-30 Popover CPU doubled by value animations
Symptom: popover open cost 2.77 % CPU vs 1.3–1.6 % without animations (same session, A/B).
Cause: `.contentTransition(.numericText())` and `.animation(…, value:)` re-render the whole
popover for ~0.35 s after every 2 s sample.
Fix: no animations on live values; FanControl writes observed state only when it changes.
Rule: Don't animate values that update on a timer.

## 2026-10-30 Downloaded 1.0 rejected by Gatekeeper
Symptom: "MangoStats.app Not Opened" after unzipping the release zip; spctl: "unsealed contents
present in the root directory of an embedded framework". The same zip extracted with ditto passed.
Cause: `ditto -c -k` stored extended attributes as `._` files next to Sparkle.framework's symlinks
(xattr -cr skips symlinks); extractors other than ditto leave them as real files.
Fix: `xattr -crs` in build.sh, `ditto --norsrc --noextattr` in release.sh, and release.sh now
extracts the zip with plain `unzip` and requires Gatekeeper to accept it.
Rule: Test a release the way people open it (plain unzip, quarantined), not only with the tools that built it.

## 2026-10-30 Every site showed the router's latency
Symptom: router, Cloudflare, Google, and Apple all read 9.2 ms with the same jitter.
Cause: on macOS every ICMP datagram socket can receive every echo reply; with pings running in
parallel, each socket took the first reply (the router's) as its own.
Fix: accept a reply only from the target's address with our echo identifier (recvfrom + id check).
Rule: When probes run in parallel, match each answer to its question (source and id), never "first reply wins".

## 2026-10-30 build.sh said "binary is older" for code that had compiled
Symptom: after a history rewrite or a comment-only edit, build.sh failed with "binary is older than
<file>", and the release script stopped, while `swift build` said "Build complete".
Cause: the guard compared file dates, but SwiftPM's build system tracks contents: a touched file
with no new work leaves the binary's date alone. Touching and rebuilding didn't help.
Fix: judge the build by swift build's exit status (the guard's real purpose); `status` is read-only in
zsh, so the variable is build_status.
Rule: Check a build tool's exit status, not file dates; never pipe the command you need the status of.
