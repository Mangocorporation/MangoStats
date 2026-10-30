# Architecture review, 2026-10-30 (after M2)

Survey: 4,032 lines; largest StatusView.swift (266), PopoverView.swift (257). No file near 600.
Fix log: one entry (power counter), not an area that repeats.

## Sensors enter through the existing seam  [no change needed]
M3 adds GPU, temperature, power, and fan readings. They fit as one `SensorReading?` on `Reading`
(Kit) filled by new readers in `Sampling/`, and fields set in `StatusBuilder`. Tests feed made-up
sensor values, like the battery tests. No refactor first.

## One card view per stat for both surfaces  [Worth exploring]
Still true from the M1 review. S-016 adds temperature pills to CPU and GPU in both files: two small
edits, not yet painful. Revisit if M3 adds a third copy.

## Top recommendation
None Strong. The code is fine for M3.
