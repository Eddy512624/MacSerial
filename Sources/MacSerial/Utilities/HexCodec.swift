import Foundation

enum HexCodecError: LocalizedError {
    case empty
    case invalidToken(String)
    case invalidLength(String)

    var errorDescription: String? {
        switch self {
        case .empty:
            "HEX 内容为空。"
        case .invalidToken(let token):
            "HEX 字节 “\(token)” 包含非法字符。"
        case .invalidLength(let token):
            "HEX 字节 “\(token)” 需要是 2 位。"
        }
    }
}

enum HexCodec {
    static func normalized(_ value: String) -> String {
        if let data = try? data(from: value) {
            return string(from: data)
        }

        return value
            .split(whereSeparator: { $0.isWhitespace || $0 == "," })
            .map { $0.uppercased() }
            .joined(separator: " ")
    }

    static func data(from value: String) throws -> Data {
        let compact = value.filter { !$0.isWhitespace && $0 != "," }
        guard !compact.isEmpty else { throw HexCodecError.empty }
        guard compact.count.isMultiple(of: 2) else { throw HexCodecError.invalidLength(compact) }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(compact.count / 2)

        var index = compact.startIndex
        while index < compact.endIndex {
            let nextIndex = compact.index(index, offsetBy: 2)
            let token = String(compact[index..<nextIndex]).uppercased()
            guard let byte = UInt8(token, radix: 16) else { throw HexCodecError.invalidToken(token) }
            bytes.append(byte)
            index = nextIndex
        }

        return Data(bytes)
    }

    static func string(from data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
