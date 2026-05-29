import Foundation

struct UserPreferences: Codable, Equatable {
    var receiveMode: DataMode = .text
    var receiveTextEncoding: ReceiveTextEncoding = .utf8
    var sendMode: DataMode = .text
    var lineEnding: LineEnding = .crlf
    var showTimestamp = true
    var showDirection = true
    var autoScroll = true
    var showQuickSend = true
    var timedSendEnabled = false
    var timedSendIntervalMS = 1_000
    var pauseReceiveDisplay = false
    var autoReconnect = true
    var hexBytesPerLine = 32

    private enum CodingKeys: String, CodingKey {
        case receiveMode
        case receiveTextEncoding
        case sendMode
        case lineEnding
        case showTimestamp
        case showDirection
        case autoScroll
        case showQuickSend
        case timedSendEnabled
        case timedSendIntervalMS
        case pauseReceiveDisplay
        case autoReconnect
        case hexBytesPerLine
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        receiveMode = try container.decodeIfPresent(DataMode.self, forKey: .receiveMode) ?? .text
        receiveTextEncoding = try container.decodeIfPresent(ReceiveTextEncoding.self, forKey: .receiveTextEncoding) ?? .utf8
        sendMode = try container.decodeIfPresent(DataMode.self, forKey: .sendMode) ?? .text
        lineEnding = try container.decodeIfPresent(LineEnding.self, forKey: .lineEnding) ?? .crlf
        showTimestamp = try container.decodeIfPresent(Bool.self, forKey: .showTimestamp) ?? true
        showDirection = try container.decodeIfPresent(Bool.self, forKey: .showDirection) ?? true
        autoScroll = try container.decodeIfPresent(Bool.self, forKey: .autoScroll) ?? true
        showQuickSend = try container.decodeIfPresent(Bool.self, forKey: .showQuickSend) ?? true
        timedSendEnabled = try container.decodeIfPresent(Bool.self, forKey: .timedSendEnabled) ?? false
        timedSendIntervalMS = try container.decodeIfPresent(Int.self, forKey: .timedSendIntervalMS) ?? 1_000
        pauseReceiveDisplay = try container.decodeIfPresent(Bool.self, forKey: .pauseReceiveDisplay) ?? false
        autoReconnect = try container.decodeIfPresent(Bool.self, forKey: .autoReconnect) ?? true
        hexBytesPerLine = try container.decodeIfPresent(Int.self, forKey: .hexBytesPerLine) ?? 32
    }
}

enum ReceiveTextEncoding: String, CaseIterable, Codable, Identifiable {
    case utf8 = "UTF-8"
    case gb18030 = "GB18030"
    case gbk = "GBK"
    case big5 = "Big5"
    case shiftJIS = "Shift-JIS"
    case latin1 = "Latin1"
    case windows1252 = "Windows-1252"
    case ascii = "ASCII"

    var id: String { rawValue }

    var stringEncoding: String.Encoding {
        switch self {
        case .utf8:
            return .utf8
        case .latin1:
            return .isoLatin1
        case .windows1252:
            return .windowsCP1252
        case .ascii:
            return .ascii
        case .gb18030:
            return encoding(named: "GB18030")
        case .gbk:
            return encoding(named: "GBK")
        case .big5:
            return encoding(named: "Big5")
        case .shiftJIS:
            return encoding(named: "Shift_JIS")
        }
    }

    private func encoding(named name: String) -> String.Encoding {
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
        guard cfEncoding != kCFStringEncodingInvalidId else {
            return .utf8
        }
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
    }
}
