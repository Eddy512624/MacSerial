import AppKit
import SwiftUI

struct SendPanelView: View {
    @EnvironmentObject private var serialStore: SerialStore

    var body: some View {
        VStack(spacing: 8) {
            SplitHandleIndicator()
                .padding(.top, -8)
                .padding(.bottom, -4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    Picker("", selection: $serialStore.preferences.sendMode) {
                        ForEach(DataMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 124)

                    Picker("结尾", selection: $serialStore.preferences.lineEnding) {
                        ForEach(LineEnding.allCases) { ending in
                            Text(ending.rawValue).tag(ending)
                        }
                    }
                    .frame(width: 132)

                    Toggle("定时发送", isOn: $serialStore.preferences.timedSendEnabled)
                        .toggleStyle(.switch)
                        .fixedSize()

                    Stepper(value: $serialStore.preferences.timedSendIntervalMS, in: 50...60_000, step: 50) {
                        Text("\(serialStore.preferences.timedSendIntervalMS) ms")
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 80, alignment: .leading)
                    }
                    .disabled(!serialStore.preferences.timedSendEnabled)
                    .fixedSize()

                    Divider()
                        .frame(height: 18)

                    Menu {
                        Button("无") { serialStore.preferences.lineEnding = .none }
                        Button("CR") { serialStore.preferences.lineEnding = .cr }
                        Button("LF") { serialStore.preferences.lineEnding = .lf }
                        Button("CRLF") { serialStore.preferences.lineEnding = .crlf }
                        Divider()
                        if serialStore.sendHistory.isEmpty {
                            Text("暂无发送历史")
                        } else {
                            ForEach(serialStore.sendHistory, id: \.self) { item in
                                Button(item) {
                                    serialStore.draftText = item
                                }
                            }
                        }
                    } label: {
                        Label("发送选项", systemImage: "slider.horizontal.3")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Text("TX \(serialStore.txBytes) B / RX \(serialStore.rxBytes) B")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            HStack(spacing: 10) {
                SendEditorView(
                    text: $serialStore.draftText,
                    mode: serialStore.preferences.sendMode,
                    onSend: {
                        serialStore.sendDraft()
                    },
                    onHistory: { up in
                        serialStore.recallSendHistory(up: up)
                    }
                )

                Button {
                    serialStore.sendDraft()
                } label: {
                    Label("发送", systemImage: "paperplane.fill")
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .help("发送当前输入")
                .disabled(!serialStore.isConnected)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
        .background {
            SplitViewHeightPersistenceView(
                storageKey: "MacSerial.sendPanelHeight",
                defaultHeight: 132,
                minHeight: 96,
                maxHeight: 320
            )
        }
        .onChange(of: serialStore.preferences.timedSendEnabled) {
            serialStore.updateTimedSendTimer()
        }
        .onChange(of: serialStore.preferences.timedSendIntervalMS) {
            serialStore.updateTimedSendTimer()
        }
    }
}

private struct SplitHandleIndicator: View {
    var body: some View {
        ZStack {
            SplitHandleDragView()
                .frame(width: 96, height: 18)

            Capsule()
                .fill(Color.secondary.opacity(0.45))
                .frame(width: 54, height: 5)
                .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                .allowsHitTesting(false)
        }
        .help("拖动调整发送区高度")
    }
}

private struct SplitHandleDragView: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView {
        DragView()
    }

    func updateNSView(_ nsView: DragView, context: Context) {}

    final class DragView: NSView {
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .resizeUpDown)
        }

        override func mouseDown(with event: NSEvent) {
            moveDivider(with: event)
        }

        override func mouseDragged(with event: NSEvent) {
            moveDivider(with: event)
        }

        private func moveDivider(with event: NSEvent) {
            guard let splitView = enclosingSplitView(), splitView.subviews.count >= 2 else { return }

            let point = splitView.convert(event.locationInWindow, from: nil)
            if splitView.isVertical {
                splitView.setPosition(point.x, ofDividerAt: 0)
            } else {
                splitView.setPosition(point.y, ofDividerAt: 0)
            }
        }

        private func enclosingSplitView() -> NSSplitView? {
            var view = superview
            while let currentView = view {
                if let splitView = currentView as? NSSplitView {
                    return splitView
                }
                view = currentView.superview
            }
            return nil
        }
    }
}

private struct SendEditorView: View {
    @Binding var text: String
    let mode: DataMode
    let onSend: () -> Void
    let onHistory: (Bool) -> Bool
    @State private var isFocused = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.35))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isFocused ? Color.accentColor : Color.secondary.opacity(0.22), lineWidth: isFocused ? 2 : 1)
                }

            NativeSendTextView(
                text: $text,
                mode: mode,
                isFocused: $isFocused,
                onSend: onSend,
                onHistory: onHistory
            )

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NativeSendTextView: NSViewRepresentable {
    @Binding var text: String
    let mode: DataMode
    @Binding var isFocused: Bool
    let onSend: () -> Void
    let onHistory: (Bool) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = PlaceholderTextView()
        textView.delegate = context.coordinator
        textView.onSend = onSend
        textView.onHistory = onHistory
        textView.string = text
        textView.placeholder = "输入要发送的数据"
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 13, height: 9)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.font = font(for: mode)

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? PlaceholderTextView else { return }

        context.coordinator.parent = self
        textView.onSend = onSend
        textView.onHistory = onHistory
        if textView.string != text {
            textView.string = text
            textView.needsDisplay = true
        }

        let nextFont = font(for: mode)
        if textView.font != nextFont {
            textView.font = nextFont
            textView.needsDisplay = true
        }
        textView.placeholder = "输入要发送的数据"
    }

    private func font(for mode: DataMode) -> NSFont {
        switch mode {
        case .text:
            NSFont.systemFont(ofSize: 13)
        case .hex:
            NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeSendTextView

        init(_ parent: NativeSendTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            textView.needsDisplay = true
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.isFocused = true
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.isFocused = false
        }
    }
}

private final class PlaceholderTextView: NSTextView {
    var placeholder = "" {
        didSet { needsDisplay = true }
    }
    var onSend: (() -> Void)?
    var onHistory: ((Bool) -> Bool)?

    override func keyDown(with event: NSEvent) {
        let isReturn = event.keyCode == 36 || event.keyCode == 76
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if isReturn, !modifiers.contains(.shift) {
            onSend?()
            return
        }

        if event.keyCode == 126, onHistory?(true) == true {
            return
        }

        if event.keyCode == 125, onHistory?(false) == true {
            return
        }

        super.keyDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard string.isEmpty, !placeholder.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.placeholderTextColor
        ]

        let origin = textContainerOrigin
        let padding = textContainer?.lineFragmentPadding ?? 0
        let point = NSPoint(x: origin.x + padding, y: origin.y)
        placeholder.draw(at: point, withAttributes: attributes)
    }
}
