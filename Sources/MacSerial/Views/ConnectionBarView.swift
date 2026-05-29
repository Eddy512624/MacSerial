import SwiftUI

struct ConnectionBarView: View {
    @EnvironmentObject private var serialStore: SerialStore

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Text("MacSerial")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize()

                ConnectionStatusView(
                    isConnected: serialStore.isConnected,
                    reconnectMessage: serialStore.reconnectMessage
                )

                Spacer()

                if serialStore.connectionKind == .serial {
                    Button {
                        serialStore.refreshPorts()
                    } label: {
                        Label("刷新串口", systemImage: "arrow.clockwise")
                    }
                    .help("刷新串口列表")
                    .fixedSize()
                }

                Button(connectionButtonTitle) {
                    serialStore.toggleConnection()
                }
                .buttonStyle(.borderedProminent)
                .tint(serialStore.isConnected ? .red : .accentColor)
                .fixedSize()
            }

            HStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Picker("连接类型", selection: $serialStore.connectionKind) {
                            ForEach(ConnectionKind.allCases) { kind in
                                Text(kind.rawValue).tag(kind)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 86)
                        .disabled(serialStore.isConnected || serialStore.reconnectMessage != nil)

                        if serialStore.connectionKind == .serial {
                            Picker("串口", selection: $serialStore.config.portPath) {
                                    Text("请选择串口").tag(String?.none)
                                    ForEach(serialStore.ports) { port in
                                        Text(port.displayName).tag(Optional(port.path))
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 238)

                            LabeledPicker(title: "波特率", width: 126) {
                                Picker("波特率", selection: $serialStore.config.baudRate) {
                                    ForEach([9_600, 19_200, 38_400, 57_600, 115_200, 230_400, 460_800, 921_600], id: \.self) { baudRate in
                                        Text("\(baudRate)").tag(baudRate)
                                    }
                                }
                            }

                            LabeledPicker(title: "数据位", width: 82) {
                                Picker("数据位", selection: $serialStore.config.dataBits) {
                                    ForEach([7, 8], id: \.self) { value in
                                        Text("\(value)").tag(value)
                                    }
                                }
                            }

                            LabeledPicker(title: "校验位", width: 112) {
                                Picker("校验位", selection: $serialStore.config.parity) {
                                    ForEach(SerialParity.allCases) { parity in
                                        Text(parity.rawValue).tag(parity)
                                    }
                                }
                            }

                            LabeledPicker(title: "停止位", width: 82) {
                                Picker("停止位", selection: $serialStore.config.stopBits) {
                                    ForEach(SerialStopBits.allCases) { stopBits in
                                        Text(stopBits.rawValue).tag(stopBits)
                                    }
                                }
                            }

                            LabeledPicker(title: "流控", width: 132) {
                                Picker("流控", selection: $serialStore.config.flowControl) {
                                    ForEach(SerialFlowControl.allCases) { flowControl in
                                        Text(flowControl.rawValue).tag(flowControl)
                                    }
                                }
                            }
                        } else {
                            HStack(spacing: 6) {
                                LabeledTextField(title: "主机", width: 220) {
                                    TextField("192.168.1.10", text: $serialStore.telnetConfig.host)
                                        .textFieldStyle(.plain)
                                        .padding(.horizontal, 10)
                                        .frame(height: 28)
                                        .background(TelnetInputBackground())
                                }

                                Menu {
                                    if serialStore.telnetHistory.isEmpty {
                                        Text("暂无历史")
                                    } else {
                                        ForEach(serialStore.telnetHistory, id: \.historyID) { item in
                                            Button(item.historyTitle) {
                                                serialStore.useTelnetHistory(item)
                                            }
                                        }
                                    }
                                } label: {
                                    Image(systemName: "clock.arrow.circlepath")
                                }
                                .menuStyle(.borderlessButton)
                                .help("Telnet 历史")
                                .disabled(serialStore.telnetHistory.isEmpty)
                            }
                            .disabled(serialStore.isConnected || serialStore.reconnectMessage != nil)

                            LabeledTextField(title: "端口", width: 88) {
                                TextField("23", value: $serialStore.telnetConfig.port, format: .number)
                                    .textFieldStyle(.plain)
                                    .padding(.horizontal, 10)
                                    .frame(height: 28)
                                    .background(TelnetInputBackground())
                            }
                            .disabled(serialStore.isConnected || serialStore.reconnectMessage != nil)

                            Toggle("协商", isOn: $serialStore.telnetConfig.handlesNegotiation)
                                .toggleStyle(.switch)
                                .fixedSize()
                                .disabled(serialStore.isConnected || serialStore.reconnectMessage != nil)
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .frame(minWidth: 0, maxWidth: .infinity)

                Text(endpointText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(minWidth: 72, idealWidth: 180, maxWidth: 220, alignment: .trailing)
                    .layoutPriority(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.bar)
    }

    private var connectionButtonTitle: String {
        switch serialStore.connectionKind {
        case .serial:
            return serialStore.isConnected ? "关闭串口" : "打开串口"
        case .telnet:
            if isConnecting {
                return "取消连接"
            }
            return serialStore.isConnected ? "断开 Telnet" : "连接 Telnet"
        }
    }

    private var isConnecting: Bool {
        serialStore.connectionKind == .telnet && !serialStore.isConnected && serialStore.reconnectMessage != nil
    }

    private var endpointText: String {
        switch serialStore.connectionKind {
        case .serial:
            return serialStore.config.portPath ?? "未选择设备"
        case .telnet:
            let host = serialStore.telnetConfig.host.trimmingCharacters(in: .whitespacesAndNewlines)
            return host.isEmpty ? "telnet://未设置:23" : "telnet://\(host):\(serialStore.telnetConfig.port)"
        }
    }
}

private struct LabeledPicker<Content: View>: View {
    let title: String
    let width: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
            content
                .labelsHidden()
                .frame(width: width)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private extension TelnetConfig {
    var historyID: String {
        "\(host.lowercased()):\(port)"
    }

    var historyTitle: String {
        "\(host):\(port)"
    }
}

private struct TelnetInputBackground: View {
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor).opacity(isEnabled ? 0.54 : 0.28))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.secondary.opacity(isEnabled ? 0.34 : 0.18), lineWidth: 1)
            }
    }
}

private struct LabeledTextField<Content: View>: View {
    let title: String
    let width: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
            content
                .frame(width: width)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct ConnectionStatusView: View {
    let isConnected: Bool
    let reconnectMessage: String?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.1))
        .clipShape(Capsule())
        .fixedSize()
    }

    private var statusColor: Color {
        if isConnected { return .green }
        if reconnectMessage != nil { return .orange }
        return Color.secondary.opacity(0.6)
    }

    private var statusText: String {
        if isConnected { return "已连接" }
        if let reconnectMessage { return reconnectMessage }
        return "未连接"
    }
}
