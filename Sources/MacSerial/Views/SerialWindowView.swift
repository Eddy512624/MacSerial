import SwiftUI

struct SerialWindowView: View {
    @StateObject private var serialStore = SerialStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ContentView()
            .environmentObject(serialStore)
            .focusedSceneValue(\.serialStore, serialStore)
            .frame(minWidth: 760, minHeight: 500)
            .background(WindowMinimumSizeView(minSize: CGSize(width: 760, height: 500)))
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    serialStore.shutdown()
                }
            }
    }
}
