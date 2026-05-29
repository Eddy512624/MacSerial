import AppKit
import SwiftUI

struct WindowMinimumSizeView: NSViewRepresentable {
    let minSize: CGSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            applyMinimumSize(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            applyMinimumSize(to: nsView.window)
        }
    }

    private func applyMinimumSize(to window: NSWindow?) {
        guard let window else { return }

        window.contentMinSize = minSize
        window.minSize = NSSize(width: minSize.width, height: minSize.height + 28)

        let contentSize = window.contentView?.bounds.size ?? window.frame.size
        guard contentSize.width < minSize.width || contentSize.height < minSize.height else { return }

        let targetContentSize = NSSize(
            width: max(contentSize.width, minSize.width),
            height: max(contentSize.height, minSize.height)
        )
        let targetFrame = window.frameRect(forContentRect: NSRect(origin: .zero, size: targetContentSize))
        var frame = window.frame
        frame.origin.y += frame.height - targetFrame.height
        frame.size = targetFrame.size
        window.setFrame(frame, display: true, animate: false)
    }
}
