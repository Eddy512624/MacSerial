import Foundation

struct UserPreferences: Codable, Equatable {
    var receiveMode: DataMode = .text
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
