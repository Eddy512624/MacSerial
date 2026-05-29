@preconcurrency import AppKit
import SwiftUI

struct SplitViewHeightPersistenceView: NSViewRepresentable {
    let storageKey: String
    let defaultHeight: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.attach(to: nsView)
    }

    @MainActor
    final class Coordinator {
        var parent: SplitViewHeightPersistenceView
        private weak var view: NSView?
        private weak var splitView: NSSplitView?
        private var observer: NSObjectProtocol?
        private var didApplyInitialHeight = false
        private var lastSavedHeight: CGFloat = 0
        private var isRestoring = false

        init(_ parent: SplitViewHeightPersistenceView) {
            self.parent = parent
        }

        func attach(to view: NSView) {
            self.view = view
            Task { @MainActor [weak self, weak view] in
                guard let self, let view else { return }
                self.configureSplitView(from: view)
                await Task.yield()
                self.configureSplitView(from: view)
            }
        }

        private func configureSplitView(from view: NSView) {
            guard let splitView = view.enclosingSplitView else { return }

            if self.splitView !== splitView {
                if let observer {
                    NotificationCenter.default.removeObserver(observer)
                }

                self.splitView = splitView
                observer = NotificationCenter.default.addObserver(
                    forName: NSSplitView.didResizeSubviewsNotification,
                    object: splitView,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in
                        self?.saveCurrentHeight()
                    }
                }
            }

            applySavedHeightIfReady(to: splitView)
        }

        private func applySavedHeightIfReady(to splitView: NSSplitView) {
            guard !didApplyInitialHeight else { return }
            guard splitView.subviews.count >= 2 else { return }
            guard splitView.bounds.height >= parent.minHeight + 220 else { return }

            let savedHeight = UserDefaults.standard.object(forKey: parent.storageKey) as? Double
            let targetHeight = CGFloat(savedHeight ?? parent.defaultHeight)
            let clampedHeight = clamp(targetHeight)

            didApplyInitialHeight = true
            isRestoring = true
            restoreBottomPaneHeight(clampedHeight, in: splitView)
            isRestoring = false
            lastSavedHeight = clampedHeight
        }

        private func restoreBottomPaneHeight(_ height: CGFloat, in splitView: NSSplitView) {
            let dividerThickness = splitView.dividerThickness
            let maxBottomHeight = max(parent.minHeight, splitView.bounds.height - 220 - dividerThickness)
            let targetHeight = min(height, maxBottomHeight)
            let positions = [
                splitView.bounds.height - targetHeight - dividerThickness,
                targetHeight
            ]

            var bestPosition = positions[0]
            var bestDelta = CGFloat.greatestFiniteMagnitude

            for position in positions {
                splitView.setPosition(position, ofDividerAt: 0)
                splitView.layoutSubtreeIfNeeded()

                let delta = abs(bottomPaneHeight(in: splitView) - targetHeight)
                if delta < bestDelta {
                    bestDelta = delta
                    bestPosition = position
                }
            }

            splitView.setPosition(bestPosition, ofDividerAt: 0)
            splitView.layoutSubtreeIfNeeded()
        }

        private func saveCurrentHeight() {
            guard !isRestoring else { return }
            guard let view else { return }
            let height = view.bounds.height > 0 ? view.bounds.height : splitView.map(bottomPaneHeight(in:)) ?? 0
            guard height >= parent.minHeight - 1 else { return }
            let clampedHeight = clamp(height)
            guard abs(clampedHeight - lastSavedHeight) >= 1 else { return }

            lastSavedHeight = clampedHeight
            UserDefaults.standard.set(Double(clampedHeight), forKey: parent.storageKey)
            UserDefaults.standard.synchronize()
        }

        private func bottomPaneHeight(in splitView: NSSplitView) -> CGFloat {
            guard let bottomPane = splitView.subviews.last else { return 0 }
            return bottomPane.bounds.height > 0 ? bottomPane.bounds.height : bottomPane.frame.height
        }

        private func clamp(_ value: CGFloat) -> CGFloat {
            min(max(value, parent.minHeight), parent.maxHeight)
        }
    }
}

private extension NSView {
    var enclosingSplitView: NSSplitView? {
        var current = superview
        while let view = current {
            if let splitView = view as? NSSplitView {
                return splitView
            }
            current = view.superview
        }
        return nil
    }
}
