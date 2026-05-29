import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var serialStore: SerialStore

    var body: some View {
        Form {
            Toggle("显示时间戳", isOn: $serialStore.preferences.showTimestamp)
            Toggle("显示方向", isOn: $serialStore.preferences.showDirection)
            Toggle("自动滚动", isOn: $serialStore.preferences.autoScroll)
            Toggle("显示快捷发送", isOn: $serialStore.preferences.showQuickSend)
            Toggle("暂停接收显示", isOn: Binding(
                get: { serialStore.preferences.pauseReceiveDisplay },
                set: { serialStore.setPauseReceiveDisplay($0) }
            ))
            Toggle("自动重连", isOn: $serialStore.preferences.autoReconnect)

            Stepper(value: $serialStore.preferences.hexBytesPerLine, in: 8...128, step: 8) {
                Text("HEX 每行 \(serialStore.preferences.hexBytesPerLine) 字节")
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}
