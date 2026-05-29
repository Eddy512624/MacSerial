import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var serialStore: SerialStore
    @State private var restoredSendPanelHeight = Self.storedSendPanelHeight()

    private static let sendPanelHeightKey = "MacSerial.sendPanelHeight"

    var body: some View {
        VStack(spacing: 0) {
            ConnectionBarView()

            Divider()

            VSplitView {
                VStack(spacing: 0) {
                    ReceiveLogView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    QuickSendStripView()
                        .frame(height: serialStore.preferences.showQuickSend ? 102 : 40)
                }
                .frame(minHeight: 220)

                SendPanelView()
                    .frame(minHeight: 96, idealHeight: restoredSendPanelHeight, maxHeight: 320)
            }
        }
        .background(Color(.windowBackgroundColor))
        .onAppear {
            serialStore.refreshPorts()
        }
        .onChange(of: serialStore.config) { oldConfig, newConfig in
            serialStore.applyConfigChange(from: oldConfig, to: newConfig)
        }
        .onChange(of: serialStore.connectionKind) {
            serialStore.saveState()
        }
        .onChange(of: serialStore.telnetConfig) {
            serialStore.saveState()
        }
        .onChange(of: serialStore.preferences) {
            serialStore.saveState()
            serialStore.updateTimedSendTimer()
        }
        .onChange(of: serialStore.preferences.receiveMode) {
            serialStore.flushReceiveBuffers()
        }
        .onChange(of: serialStore.preferences.receiveTextEncoding) {
            serialStore.flushReceiveBuffers()
        }
        .onChange(of: serialStore.quickCommands) {
            serialStore.saveState()
        }
    }

    private static func storedSendPanelHeight() -> CGFloat {
        let storedValue = UserDefaults.standard.double(forKey: sendPanelHeightKey)
        guard storedValue > 0 else { return 132 }
        return min(max(CGFloat(storedValue), 96), 320)
    }
}
