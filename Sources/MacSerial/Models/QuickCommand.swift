import Foundation

struct QuickCommand: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var payload: String
    var group: String
    var mode: DataMode
    var lineEnding: LineEnding

    init(
        id: UUID = UUID(),
        title: String,
        payload: String,
        group: String = "项圈",
        mode: DataMode = .text,
        lineEnding: LineEnding = .crlf
    ) {
        self.id = id
        self.title = title
        self.payload = payload
        self.group = group
        self.mode = mode
        self.lineEnding = lineEnding
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case payload
        case group
        case mode
        case lineEnding
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        payload = try container.decode(String.self, forKey: .payload)
        group = QuickCommand.normalizedGroup(try container.decodeIfPresent(String.self, forKey: .group) ?? "项圈")
        mode = try container.decode(DataMode.self, forKey: .mode)
        lineEnding = try container.decode(LineEnding.self, forKey: .lineEnding)
    }

    static func normalizedGroup(_ group: String) -> String {
        switch group {
        case "基站", "Modbus":
            "基站"
        default:
            "项圈"
        }
    }
}
