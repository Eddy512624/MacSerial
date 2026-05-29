import Foundation

struct SerialPortInfo: Identifiable, Hashable {
    let path: String

    var id: String { path }

    var displayName: String {
        path.replacingOccurrences(of: "/dev/", with: "")
    }
}
