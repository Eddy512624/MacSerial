import Foundation

struct SerialMessage: Identifiable, Equatable {
    enum Direction: String {
        case receive = "RX"
        case transmit = "TX"
        case system = "SYS"
        case error = "ERR"
    }

    let id = UUID()
    let date: Date
    let direction: Direction
    var text: String
}
