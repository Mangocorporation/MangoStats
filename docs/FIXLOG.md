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
