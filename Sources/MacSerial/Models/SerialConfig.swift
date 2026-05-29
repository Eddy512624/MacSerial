import Foundation

enum ConnectionKind: String, CaseIterable, Codable, Identifiable {
    case serial = "串口"
    case telnet = "Telnet"

    var id: String { rawValue }
}

struct SerialConfig: Codable, Equatable {
    var portPath: String?
    var baudRate: Int = 115_200
    var dataBits: Int = 8
    var parity: SerialParity = .none
    var stopBits: SerialStopBits = .one
    var flowControl: SerialFlowControl = .none
}

struct TelnetConfig: Codable, Equatable {
    var host: String = "192.168.1.10"
    var port: Int = 23
    var handlesNegotiation = true
}

enum SerialParity: String, CaseIterable, Codable, Identifiable {
    case none = "无"
    case odd = "奇校验"
    case even = "偶校验"

    var id: String { rawValue }
}

enum SerialStopBits: String, CaseIterable, Codable, Identifiable {
    case one = "1"
    case two = "2"

    var id: String { rawValue }
}

enum SerialFlowControl: String, CaseIterable, Codable, Identifiable {
    case none = "关闭"
    case rtsCts = "RTS/CTS"

    var id: String { rawValue }
}

enum DataMode: String, CaseIterable, Codable, Identifiable {
    case text = "文本"
    case hex = "HEX"

    var id: String { rawValue }
}

enum LineEnding: String, CaseIterable, Codable, Identifiable {
    case none = "无"
    case cr = "CR"
    case lf = "LF"
    case crlf = "CRLF"

    var id: String { rawValue }

    var stringValue: String {
        switch self {
        case .none: ""
        case .cr: "\r"
        case .lf: "\n"
        case .crlf: "\r\n"
        }
    }
}
