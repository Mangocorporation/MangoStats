import AppKit
import SwiftUI

/// Hides the title bar and its text but keeps the traffic lights, so the
/// kit's gradient runs to the top edge (design/KIT.md, Window).
struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = ChromeView()
        view.configure = { window in
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ChromeView: NSView {
        var configure: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            DispatchQueue.main.async { [weak self] in self?.configure?(window) }
        }
    }
}
