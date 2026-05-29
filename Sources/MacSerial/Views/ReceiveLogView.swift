import AppKit
import SwiftUI

struct ReceiveLogView: View {
    @EnvironmentObject private var serialStore: SerialStore

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
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
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
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
                    } else {
                        LazyVStack(alignment: .leading, spacing: 5) {
                            ForEach(serialStore.messages) { message in
                                MessageRowView(
                                    message: message,
                                    showTimestamp: serialStore.preferences.showTimestamp,
                                    showDirection: serialStore.preferences.showDirection
                                )
                                    .id(message.id)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                .onChange(of: serialStore.messages) { _, messages in
                    guard serialStore.preferences.autoScroll,
                          let last = messages.last else { return }
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
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

private struct MessageRowView: View {
    let message: SerialMessage
    let showTimestamp: Bool
    let showDirection: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if showTimestamp {
                Text("[\(TimestampFormatter.string(from: message.date))]")
                    .foregroundStyle(.secondary)
            }

            if showDirection {
                Text(message.direction.rawValue)
                    .fontWeight(.semibold)
                    .foregroundStyle(directionColor)
                    .frame(width: 34, alignment: .leading)
            }

            Text(message.text)
                .textSelection(.enabled)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.system(size: 12, design: .monospaced))
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }

    private var directionColor: Color {
        switch message.direction {
        case .receive: .teal
        case .transmit: .indigo
        case .system: .secondary
        case .error: .red
        }
    }

}
