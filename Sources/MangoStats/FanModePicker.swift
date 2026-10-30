import SwiftUI
import MangoStatsKit

/// Auto, Cool, and Max on the Fan cards (S-025). Without the helper, Cool
/// and Max are off and say where to turn fan control on.
struct FanModePicker: View {
    var compact = false
    private var fan = FanControl.shared

    init(compact: Bool = false) {
        self.compact = compact
    }

    var body: some View {
        HStack(spacing: compact ? Metric.compactSegmentGap : Metric.segmentGap) {
            ForEach(FanMode.allCases) { mode in
                let available = mode == .auto || fan.state == .on
                Button(mode.title) { fan.pick(mode) }
                    .buttonStyle(SegmentButtonStyle(selected: fan.wanted == mode, compact: compact))
                    .disabled(!available)
                    .help(available ? mode.help : "Allow fan control in Settings > General")
                    .accessibilityLabel("Fan mode \(mode.title)")
                    .accessibilityAddTraits(fan.wanted == mode ? .isSelected : [])
            }
        }
    }
}
