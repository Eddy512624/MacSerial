import Foundation

enum SerialPortManager {
    static func availablePorts() -> [SerialPortInfo] {
        let devURL = URL(fileURLWithPath: "/dev", isDirectory: true)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: devURL.path())) ?? []

        return names
            .filter { $0.hasPrefix("cu.") }
            .sorted { lhs, rhs in
                lhs.localizedStandardCompare(rhs) == .orderedAscending
            }
            .map { SerialPortInfo(path: "/dev/\($0)") }
    }
}
