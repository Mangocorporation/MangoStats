# Fix log

## 2026-10-30 Power column read 0.0 for every process
Symptom: PWR showed 0,0 even for Chrome at 88 % CPU.
Cause: `ri_billed_energy` (rusage v4) moves in tiny, delayed steps (Chrome: 0.03 W over 2 s).
Fix: read `ri_energy_nj` from `RUSAGE_INFO_V6`, the per-process energy estimate (Chrome ≈ 1 W).
Rule: Probe a new kernel counter twice, 2 s apart, on a busy process before building on it.
