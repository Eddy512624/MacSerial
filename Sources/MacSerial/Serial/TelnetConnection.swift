import Foundation
import Network

enum TelnetConnectionError: LocalizedError {
    case invalidHost
    case invalidPort(Int)
    case notOpen
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidHost:
            "Telnet 主机不能为空。"
        case .invalidPort(let port):
            "Telnet 端口不可用：\(port)。"
        case .notOpen:
            "Telnet 尚未连接。"
        case .writeFailed(let message):
            "Telnet 发送失败：\(message)。"
        }
    }
}

final class TelnetConnection: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.local.MacSerial.telnet")
    private var connection: NWConnection?
    private var isClosing = false
    private var negotiationState = NegotiationState()
    private let onReady: () -> Void
    private let onReceive: (Data) -> Void
    private let onDisconnect: (String) -> Void

    init(
        onReady: @escaping () -> Void,
        onReceive: @escaping (Data) -> Void,
        onDisconnect: @escaping (String) -> Void
    ) {
        self.onReady = onReady
        self.onReceive = onReceive
        self.onDisconnect = onDisconnect
    }

    var isOpen: Bool {
        connection != nil
    }

    func open(config: TelnetConfig) throws {
        close()

        let host = config.host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else {
            throw TelnetConnectionError.invalidHost
        }

        guard (1...65_535).contains(config.port),
              let port = NWEndpoint.Port(rawValue: UInt16(config.port)) else {
            throw TelnetConnectionError.invalidPort(config.port)
        }

        negotiationState = NegotiationState(handlesNegotiation: config.handlesNegotiation)
        isClosing = false

        let newConnection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
        connection = newConnection

        newConnection.stateUpdateHandler = { [weak self, weak newConnection] state in
            guard let self, let newConnection, self.connection === newConnection else { return }

            switch state {
            case .ready:
                self.onReady()
                self.receiveLoop(on: newConnection)
            case .failed(let error):
                self.close(notify: false)
                self.onDisconnect("Telnet 连接失败：\(error.localizedDescription)。")
            case .cancelled:
                if !self.isClosing {
                    self.onDisconnect("Telnet 已断开。")
                }
            default:
                break
            }
        }

        newConnection.start(queue: queue)
    }

    func close() {
        close(notify: false)
    }

    func write(_ data: Data) throws {
        guard let connection else {
            throw TelnetConnectionError.notOpen
        }

        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            guard let error else { return }
            self?.onDisconnect(TelnetConnectionError.writeFailed(error.localizedDescription).localizedDescription)
        })
    }

    private func close(notify: Bool) {
        guard let connection else { return }
        isClosing = true
        self.connection = nil
        connection.cancel()
        if notify {
            onDisconnect("Telnet 已断开。")
        }
    }

    private func receiveLoop(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self, weak connection] data, _, isComplete, error in
            guard let self, let connection, self.connection === connection else { return }

            if let data, !data.isEmpty {
                let result = self.negotiationState.consume(data)
                if !result.response.isEmpty {
                    connection.send(content: result.response, completion: .contentProcessed { _ in })
                }
                if !result.payload.isEmpty {
                    self.onReceive(result.payload)
                }
            }

            if let error {
                self.close(notify: false)
                self.onDisconnect("Telnet 读取失败：\(error.localizedDescription)。")
                return
            }

            if isComplete {
                self.close(notify: false)
                self.onDisconnect("Telnet 已断开。")
                return
            }

            self.receiveLoop(on: connection)
        }
    }
}

private struct NegotiationState {
    private enum State {
        case data
        case iac
        case command(UInt8)
        case subnegotiation
        case subnegotiationIAC
    }

    private let handlesNegotiation: Bool
    private var state: State = .data

    init(handlesNegotiation: Bool = true) {
        self.handlesNegotiation = handlesNegotiation
    }

    mutating func consume(_ data: Data) -> (payload: Data, response: Data) {
        guard handlesNegotiation else {
            return (data, Data())
        }

        var payload = Data()
        var response = Data()

        for byte in data {
            switch state {
            case .data:
                if byte == TelnetByte.iac {
                    state = .iac
                } else {
                    payload.append(byte)
                }
            case .iac:
                switch byte {
                case TelnetByte.iac:
                    payload.append(byte)
                    state = .data
                case TelnetByte.do, TelnetByte.dont, TelnetByte.will, TelnetByte.wont:
                    state = .command(byte)
                case TelnetByte.sb:
                    state = .subnegotiation
                default:
                    state = .data
                }
            case .command(let command):
                response.append(contentsOf: responseBytes(for: command, option: byte))
                state = .data
            case .subnegotiation:
                if byte == TelnetByte.iac {
                    state = .subnegotiationIAC
                }
            case .subnegotiationIAC:
                if byte == TelnetByte.se {
                    state = .data
                } else {
                    state = .subnegotiation
                }
            }
        }

        return (payload, response)
    }

    private func responseBytes(for command: UInt8, option: UInt8) -> [UInt8] {
        switch command {
        case TelnetByte.do, TelnetByte.dont:
            [TelnetByte.iac, TelnetByte.wont, option]
        case TelnetByte.will, TelnetByte.wont:
            [TelnetByte.iac, TelnetByte.dont, option]
        default:
            []
        }
    }
}

private enum TelnetByte {
    static let se: UInt8 = 240
    static let sb: UInt8 = 250
    static let will: UInt8 = 251
    static let wont: UInt8 = 252
    static let `do`: UInt8 = 253
    static let dont: UInt8 = 254
    static let iac: UInt8 = 255
}
