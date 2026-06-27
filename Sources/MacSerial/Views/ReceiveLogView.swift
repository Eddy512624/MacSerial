import AppKit
import SwiftUI

struct ReceiveLogView: View {
    @EnvironmentObject private var serialStore: SerialStore

    var body: some View {
        VStack(spacing: 0) {
            WrappingToolbarLayout(horizontalSpacing: 12, verticalSpacing: 8) {
                Label("接收监视", systemImage: "waveform.path.ecg")
                    .font(.headline)
                    .lineLimit(1)
                    .fixedSize()

                Picker("", selection: $serialStore.preferences.receiveMode) {
                    ForEach(DataMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 124)

                if serialStore.preferences.receiveMode == .text {
                    Picker("编码", selection: $serialStore.preferences.receiveTextEncoding) {
                        ForEach(ReceiveTextEncoding.allCases) { encoding in
                            Text(encoding.rawValue).tag(encoding)
                        }
                    }
                    .frame(width: 118)
                }

                Toggle("时间戳", isOn: $serialStore.preferences.showTimestamp)
                    .toggleStyle(.switch)
                    .fixedSize()
                Toggle("方向", isOn: $serialStore.preferences.showDirection)
                    .toggleStyle(.switch)
                    .fixedSize()
                Toggle("自动滚动", isOn: $serialStore.preferences.autoScroll)
                    .toggleStyle(.switch)
                    .fixedSize()
                Toggle("暂停", isOn: Binding(
                    get: { serialStore.preferences.pauseReceiveDisplay },
                    set: { serialStore.setPauseReceiveDisplay($0) }
                ))
                .toggleStyle(.switch)
                .fixedSize()

                Text("RX \(serialStore.rxBytes) B")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()

                Button {
                    serialStore.clearCounters()
                } label: {
                    Label("清零", systemImage: "gauge.with.dots.needle.0percent")
                }
                .help("清零收发统计")
                .fixedSize()

                Button {
                    toggleAutoSave()
                } label: {
                    Label(serialStore.isAutoSaving ? "停止保存" : "自动保存", systemImage: serialStore.isAutoSaving ? "stop.circle" : "record.circle")
                }
                .help(serialStore.isAutoSaving ? "停止自动保存接收显示" : "自动保存接收监视显示内容")
                .disabled(!serialStore.isConnected && !serialStore.isAutoSaving)
                .fixedSize()

                Button {
                    serialStore.clearMessages()
                } label: {
                    Label("清空", systemImage: "trash")
                }
                .help("清空接收区")
                .fixedSize()

                Button {
                    saveLog()
                } label: {
                    Label("保存", systemImage: "square.and.arrow.down")
                }
                .help("保存接收日志")
                .disabled(serialStore.messages.isEmpty)
                .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            ZStack {
                NativeReceiveLogTextView(
                    messages: serialStore.messages,
                    showTimestamp: serialStore.preferences.showTimestamp,
                    showDirection: serialStore.preferences.showDirection,
                    autoScroll: serialStore.preferences.autoScroll
                )

                if serialStore.messages.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 30))
                            .foregroundStyle(.secondary)
                        Text("暂无接收数据")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .allowsHitTesting(false)
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(nsColor: .textBackgroundColor).opacity(0.72),
                        Color(nsColor: .textBackgroundColor).opacity(0.5)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private func saveLog() {
        let panel = NSSavePanel()
        panel.title = "保存接收日志"
        panel.nameFieldStringValue = "MacSerial-\(logFileTimestamp()).log"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try serialStore.saveLog(to: url)
        } catch {
            serialStore.reportError("保存日志失败：\(error.localizedDescription)")
        }
    }

    private func toggleAutoSave() {
        if serialStore.isAutoSaving {
            serialStore.stopAutoSave()
            return
        }

        let panel = NSSavePanel()
        panel.title = "自动保存接收内容"
        panel.nameFieldStringValue = "MacSerial-RX-\(logFileTimestamp()).log"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try serialStore.startAutoSave(to: url)
        } catch {
            serialStore.reportError("开启自动保存失败：\(error.localizedDescription)")
        }
    }

    private func logFileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: .now)
    }
}

private struct WrappingToolbarLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let availableWidth = proposal.width ?? .greatestFiniteMagnitude
        let rows = arrangedRows(for: subviews, availableWidth: availableWidth)
        guard !rows.isEmpty else { return .zero }

        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
            height: rows.map(\.height).reduce(0, +) + verticalSpacing * CGFloat(max(rows.count - 1, 0))
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangedRows(for: subviews, availableWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                item.subview.place(
                    at: CGPoint(x: x, y: y + (row.height - item.size.height) / 2),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private func arrangedRows(for subviews: Subviews, availableWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        let maxWidth = availableWidth.isFinite ? availableWidth : .greatestFiniteMagnitude

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextWidth = current.items.isEmpty ? size.width : current.width + horizontalSpacing + size.width

            if !current.items.isEmpty, nextWidth > maxWidth {
                rows.append(current)
                current = Row()
            }

            current.append(Item(subview: subview, size: size), spacing: horizontalSpacing)
        }

        if !current.items.isEmpty {
            rows.append(current)
        }
        return rows
    }

    private struct Item {
        let subview: LayoutSubview
        let size: CGSize
    }

    private struct Row {
        var items: [Item] = []
        var width: CGFloat = 0
        var height: CGFloat = 0

        mutating func append(_ item: Item, spacing: CGFloat) {
            if !items.isEmpty {
                width += spacing
            }
            items.append(item)
            width += item.size.width
            height = max(height, item.size.height)
        }
    }
}

private struct NativeReceiveLogTextView: NSViewRepresentable {
    let messages: [SerialMessage]
    let showTimestamp: Bool
    let showDirection: Bool
    let autoScroll: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.allowsUndo = false
        textView.usesFindBar = true
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.font = Self.logFont

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
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let signature = renderSignature
        if context.coordinator.renderSignature != signature {
            let previousSelection = textView.selectedRange()
            textView.textStorage?.setAttributedString(renderedLog())
            context.coordinator.renderSignature = signature

            if previousSelection.location != NSNotFound, previousSelection.length > 0 {
                let maxLength = textView.string.count
                let location = min(previousSelection.location, maxLength)
                let length = min(previousSelection.length, maxLength - location)
                textView.setSelectedRange(NSRange(location: location, length: length))
            }
        }

        if autoScroll, textView.selectedRange().length == 0 {
            textView.scrollToEndOfDocument(nil)
        }
    }

    private var renderSignature: String {
        var signature = "\(showTimestamp)|\(showDirection)|\(messages.count)"
        if let last = messages.last {
            signature += "|\(last.id.uuidString)|\(last.text)"
        }
        return signature
    }

    private func renderedLog() -> NSAttributedString {
        let output = NSMutableAttributedString()

        for (index, message) in messages.enumerated() {
            append(message, to: output)
            if index < messages.index(before: messages.endIndex) {
                output.append(Self.segment("\n"))
            }
        }

        return output
    }

    private func append(_ message: SerialMessage, to output: NSMutableAttributedString) {
        let hasTimestamp = showTimestamp
        let hasDirection = showDirection

        if hasTimestamp {
            output.append(Self.segment("[\(TimestampFormatter.string(from: message.date))]", color: .secondaryLabelColor))
        }

        if hasDirection {
            if hasTimestamp {
                output.append(Self.segment("  "))
            }
            output.append(Self.segment(message.direction.rawValue, color: color(for: message.direction), weight: .semibold))
        }

        if hasTimestamp || hasDirection {
            output.append(Self.segment(hasTimestamp && hasDirection ? "  " : " "))
        }

        output.append(Self.segment(message.text, color: .labelColor))
    }

    private func color(for direction: SerialMessage.Direction) -> NSColor {
        switch direction {
        case .receive:
            return .systemTeal
        case .transmit:
            return .systemIndigo
        case .system:
            return .secondaryLabelColor
        case .error:
            return .systemRed
        }
    }

    private static let logFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

    private static func segment(_ text: String, color: NSColor = .labelColor, weight: NSFont.Weight = .regular) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        paragraphStyle.paragraphSpacing = 0
        paragraphStyle.lineBreakMode = .byWordWrapping

        return NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: weight),
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle
            ]
        )
    }

    final class Coordinator {
        var renderSignature = ""
    }
}

