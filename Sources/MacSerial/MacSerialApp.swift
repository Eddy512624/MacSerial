import SwiftUI

@main
struct MacSerialApp: App {
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.serialStore) private var focusedSerialStore

    var body: some Scene {
        WindowGroup("MacSerial", id: "main") {
            SerialWindowView()
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建窗口") {
                    openWindow(id: "main")
                }
                .keyboardShortcut("n", modifiers: [.command])
            }

            CommandMenu("连接") {
                Button("刷新串口") {
                    focusedSerialStore?.refreshPorts()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(focusedSerialStore == nil)

                Button(focusedSerialStore?.isConnected == true ? "关闭串口" : "打开串口") {
                    focusedSerialStore?.toggleConnection()
                }
                .keyboardShortcut("o", modifiers: [.command])
                .disabled(focusedSerialStore == nil)
            }

            CommandMenu("视图") {
                Toggle("显示时间戳", isOn: focusedBinding(
                    get: { $0.preferences.showTimestamp },
                    set: { $0.preferences.showTimestamp = $1 }
                ))
                .disabled(focusedSerialStore == nil)

                Toggle("显示方向", isOn: focusedBinding(
                    get: { $0.preferences.showDirection },
                    set: { $0.preferences.showDirection = $1 }
                ))
                .disabled(focusedSerialStore == nil)

                Toggle("自动滚动", isOn: focusedBinding(
                    get: { $0.preferences.autoScroll },
                    set: { $0.preferences.autoScroll = $1 }
                ))
                .disabled(focusedSerialStore == nil)

                Toggle("暂停接收显示", isOn: Binding(
                    get: { focusedSerialStore?.preferences.pauseReceiveDisplay ?? false },
                    set: { focusedSerialStore?.setPauseReceiveDisplay($0) }
                ))
                .disabled(focusedSerialStore == nil)

                Toggle("自动重连", isOn: focusedBinding(
                    get: { $0.preferences.autoReconnect },
                    set: { $0.preferences.autoReconnect = $1 }
                ))
                .disabled(focusedSerialStore == nil)

                Button("文本/HEX 显示切换") {
                    focusedSerialStore?.toggleReceiveMode()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                .disabled(focusedSerialStore == nil)

                Button("清空接收区") {
                    focusedSerialStore?.clearMessages()
                }
                .keyboardShortcut("k", modifiers: [.command])
                .disabled(focusedSerialStore == nil)

                Button("清零收发统计") {
                    focusedSerialStore?.clearCounters()
                }
                .disabled(focusedSerialStore == nil)
            }
        }

        Settings {
            Text("每个窗口都有独立串口会话。请在对应窗口中调整串口和显示设置。")
                .padding(24)
                .frame(width: 420)
        }
    }

    private func focusedBinding(
        get: @escaping (SerialStore) -> Bool,
        set: @escaping (SerialStore, Bool) -> Void
    ) -> Binding<Bool> {
        Binding(
            get: {
                guard let focusedSerialStore else { return false }
                return get(focusedSerialStore)
            },
            set: { newValue in
                guard let focusedSerialStore else { return }
                set(focusedSerialStore, newValue)
            }
        )
    }
}
