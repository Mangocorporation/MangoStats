import Foundation
import Testing
@testable import MangoStatsKit

@Test("Default layout shows CPU and Memory")
func defaultLayout() {
    let layout = MenuBarLayout(encodedOrder: nil, encodedEnabled: nil)
    #expect(layout.visible == [.cpu, .memory])
    #expect(layout.order == MenuBarStat.allCases)
}

@Test("Layout survives a save and load")
func roundTrip() {
    var layout = MenuBarLayout.default
    layout.enabled = [.network, .cpu, .battery]
    layout.move(fromOffsets: IndexSet(integer: 4), toOffset: 0)
    let loaded = MenuBarLayout(encodedOrder: layout.encodedOrder, encodedEnabled: layout.encodedEnabled)
    #expect(loaded == layout)
    #expect(loaded.visible == [.network, .cpu, .battery])
}

@Test("Unknown and repeated keys are ignored, missing stats are added")
func ignoresJunk() {
    let layout = MenuBarLayout(encodedOrder: "fan,bogus,fan,cpu", encodedEnabled: "cpu,warp")
    #expect(layout.order.prefix(2) == [.fan, .cpu])
    #expect(layout.order.count == MenuBarStat.allCases.count)
    #expect(layout.visible == [.cpu])
}

@Test("Everything off is allowed")
func allOff() {
    let layout = MenuBarLayout(encodedOrder: "cpu", encodedEnabled: "")
    #expect(layout.visible.isEmpty)
}
