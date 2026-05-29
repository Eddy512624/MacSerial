import Foundation

@MainActor
final class SerialStore: ObservableObject {
    @Published var ports: [SerialPortInfo] = []
    @Published var connectionKind: ConnectionKind = .serial
    @Published var config = SerialConfig()
    @Published var telnetConfig = TelnetConfig()
    @Published var preferences = UserPreferences()
    @Published var messages: [SerialMessage] = [
        SerialMessage(date: .now, direction: .system, text: "MacSerial v0.3.27 已就绪。请选择连接方式并打开连接。")
    ]
    @Published var quickCommands: [QuickCommand] = [
        QuickCommand(title: "复位模块", payload: "AT+RST", group: "项圈"),
        QuickCommand(title: "读取版本", payload: "AT+GMR", group: "项圈"),
        QuickCommand(title: "查询信号", payload: "AT+CSQ", group: "项圈"),
        QuickCommand(title: "进入透传", payload: "AT+CIPMODE=1", group: "项圈"),
        QuickCommand(title: "读取保持寄存器", payload: "01 03 00 00 00 02 C4 0B", group: "基站", mode: .hex, lineEnding: .none),
        QuickCommand(title: "心跳包", payload: "AA 55 00 01 01", group: "项圈", mode: .hex, lineEnding: .none)
    ]
    @Published var draftText = ""
    @Published var searchText = ""
    @Published var sendHistory: [String] = []
    @Published var telnetHistory: [TelnetConfig] = []
    @Published private(set) var isConnected = false
    @Published private(set) var rxBytes = 0
    @Published private(set) var txBytes = 0
    @Published private(set) var reconnectMessage: String?
    @Published private(set) var isAutoSaving = false
    @Published private(set) var autoSaveURL: URL?
    private var serialConnection: SerialConnection?
    private var telnetConnection: TelnetConnection?
    private var timedSendTimer: Timer?
    private var reconnectTimer: Timer?
    private var autoSaveHandle: FileHandle?
    private var pendingReceiveText = ""
    private var pendingReceiveTextBytes = Data()
    private var pendingReceiveMessageID: UUID?
    private var pendingHexBytes = Data()
    private var pausedReceiveBytes = 0
    private var sendHistoryCursor: Int?
    private var userRequestedDisconnect = false

    init() {
        loadState()
    }

    func refreshPorts() {
        ports = SerialPortManager.availablePorts()
        if config.portPath == nil {
            config.portPath = ports.first?.path
        }
    }

    func toggleConnection() {
        if connectionKind == .telnet, !isConnected, telnetConnection != nil {
            userRequestedDisconnect = true
            closeActiveConnections()
            reconnectMessage = nil
            append(.system, "Telnet 连接已取消。")
            return
        }

        if isConnected {
            userRequestedDisconnect = true
            stopReconnectTimer()
            disconnect(message: "\(connectionKind.rawValue) 已断开。", direction: .system)
            return
        }

        userRequestedDisconnect = false
        stopReconnectTimer()
        openCurrentConnection(announceErrors: true)
    }

    func clearCounters() {
        rxBytes = 0
        txBytes = 0
        append(.system, "收发统计已清零。")
    }

    func clearSearch() {
        searchText.removeAll()
    }

    func toggleReceiveMode() {
        flushReceiveBuffers()
        preferences.receiveMode = preferences.receiveMode == .text ? .hex : .text
    }

    func flushReceiveBuffers() {
        flushPendingReceiveText()
        flushPendingHexBytes()
    }

    func applyConfigChange(from oldConfig: SerialConfig, to newConfig: SerialConfig) {
        saveState()

        guard connectionKind == .serial, isConnected, let serialConnection else { return }
        guard oldConfig != newConfig else { return }

        if oldConfig.portPath != newConfig.portPath {
            append(.system, "串口设备已切换，请重新打开串口。")
            return
        }

        do {
            flushReceiveBuffers()
            try serialConnection.update(config: newConfig)
            append(.system, "串口参数已更新，波特率 \(newConfig.baudRate)。")
        } catch {
            append(.error, error.localizedDescription)
        }
    }

    private func openCurrentConnection(announceErrors: Bool) {
        switch connectionKind {
        case .serial:
            openSerialConnection(announceErrors: announceErrors)
        case .telnet:
            openTelnetConnection(announceErrors: announceErrors)
        }
    }

    private func openSerialConnection(announceErrors: Bool) {
        guard let portPath = config.portPath else {
            if announceErrors {
                append(.error, "没有可用串口。")
            }
            return
        }

        let newConnection = SerialConnection(
            onReceive: { [weak self] data in
                Task { @MainActor in
                    self?.handleReceivedData(data)
                }
            },
            onDisconnect: { [weak self] message in
                Task { @MainActor in
                    self?.handleDisconnect(message)
                }
            }
        )

        do {
            try newConnection.open(config: config)
            serialConnection = newConnection
            isConnected = true
            reconnectMessage = nil
            append(.system, "已打开 \(portPath)，波特率 \(config.baudRate)。")
        } catch {
            if announceErrors {
                append(.error, error.localizedDescription)
            }
        }
    }

    private func openTelnetConnection(announceErrors: Bool) {
        let host = telnetConfig.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = telnetConfig.port

        let newConnection = TelnetConnection(
            onReady: { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    self.isConnected = true
                    self.reconnectMessage = nil
                    self.rememberTelnetHistory(host: host, port: port)
                    self.append(.system, "已连接 Telnet \(host):\(port)。")
                }
            },
            onReceive: { [weak self] data in
                Task { @MainActor in
                    self?.handleReceivedData(data)
                }
            },
            onDisconnect: { [weak self] message in
                Task { @MainActor in
                    self?.handleDisconnect(message)
                }
            }
        )

        do {
            try newConnection.open(config: telnetConfig)
            telnetConnection = newConnection
            reconnectMessage = "Telnet 连接中..."
            append(.system, "正在连接 Telnet \(host):\(port)...")
        } catch {
            if announceErrors {
                append(.error, error.localizedDescription)
            }
        }
    }

    func updateTimedSendTimer() {
        timedSendTimer?.invalidate()
        timedSendTimer = nil

        guard preferences.timedSendEnabled else { return }

        let interval = TimeInterval(max(preferences.timedSendIntervalMS, 50)) / 1_000
        timedSendTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isConnected else { return }
                self.sendDraft()
            }
        }
    }

    func sendDraft() {
        send(draftText, mode: preferences.sendMode, lineEnding: preferences.lineEnding)
    }

    func recallSendHistory(up: Bool) -> Bool {
        guard !sendHistory.isEmpty else { return false }

        if let cursor = sendHistoryCursor {
            if up {
                sendHistoryCursor = min(cursor + 1, sendHistory.count - 1)
            } else if cursor == 0 {
                sendHistoryCursor = nil
                draftText.removeAll()
                return true
            } else {
                sendHistoryCursor = cursor - 1
            }
        } else {
            guard draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, up else {
                return false
            }
            sendHistoryCursor = 0
        }

        if let sendHistoryCursor {
            draftText = sendHistory[sendHistoryCursor]
        }
        return true
    }

    func sendQuickCommand(_ command: QuickCommand) {
        send(command.payload, mode: command.mode, lineEnding: command.lineEnding)
    }

    func clearMessages() {
        messages.removeAll()
        pendingReceiveText.removeAll()
        pendingReceiveTextBytes.removeAll()
        pendingReceiveMessageID = nil
        pendingHexBytes.removeAll()
    }

    func filteredMessages() -> [SerialMessage] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return messages }

        return messages.filter { message in
            message.text.localizedCaseInsensitiveContains(query)
                || message.direction.rawValue.localizedCaseInsensitiveContains(query)
                || TimestampFormatter.string(from: message.date).contains(query)
        }
    }

    func saveLog(to url: URL) throws {
        let content = messages.map { message in
            renderedMessageLine(message)
        }
        .joined(separator: "\n")

        try content.write(to: url, atomically: true, encoding: .utf8)
        append(.system, "日志已保存到 \(url.path)。")
    }

    func startAutoSave(to url: URL) throws {
        stopAutoSave(announce: false)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        autoSaveHandle = handle
        autoSaveURL = url
        isAutoSaving = true
        append(.system, "自动保存已开启：\(url.path)。")
    }

    func stopAutoSave(announce: Bool = true) {
        guard isAutoSaving || autoSaveHandle != nil else { return }

        flushReceiveBuffers()
        try? autoSaveHandle?.synchronize()
        try? autoSaveHandle?.close()
        autoSaveHandle = nil
        isAutoSaving = false

        let path = autoSaveURL?.path
        autoSaveURL = nil

        if announce, let path {
            append(.system, "自动保存已停止：\(path)。")
        }
    }

    func reportError(_ message: String) {
        append(.error, message)
    }

    func setPauseReceiveDisplay(_ isPaused: Bool) {
        preferences.pauseReceiveDisplay = isPaused
        if !isPaused, pausedReceiveBytes > 0 {
            append(.system, "暂停期间接收 \(pausedReceiveBytes) B。")
            pausedReceiveBytes = 0
        }
        saveState()
    }

    func addQuickCommand(_ command: QuickCommand) {
        quickCommands.append(command)
        saveState()
    }

    func updateQuickCommand(_ command: QuickCommand) {
        guard let index = quickCommands.firstIndex(where: { $0.id == command.id }) else { return }
        quickCommands[index] = command
        saveState()
    }

    func duplicateQuickCommand(_ command: QuickCommand) {
        quickCommands.append(
            QuickCommand(
                title: "\(command.title) 副本",
                payload: command.payload,
                group: command.group,
                mode: command.mode,
                lineEnding: command.lineEnding
            )
        )
        saveState()
    }

    func deleteQuickCommand(_ command: QuickCommand) {
        quickCommands.removeAll { $0.id == command.id }
        saveState()
    }

    func moveQuickCommand(_ command: QuickCommand, offset: Int) {
        guard let index = quickCommands.firstIndex(where: { $0.id == command.id }) else { return }
        let newIndex = min(max(index + offset, quickCommands.startIndex), quickCommands.index(before: quickCommands.endIndex))
        guard newIndex != index else { return }
        let item = quickCommands.remove(at: index)
        quickCommands.insert(item, at: newIndex)
        saveState()
    }

    func saveState() {
        if !preferences.autoReconnect {
            stopReconnectTimer()
        }

        let encoder = JSONEncoder()
        let defaults = UserDefaults.standard

        defaults.set(try? encoder.encode(config), forKey: StorageKey.config)
        defaults.set(try? encoder.encode(connectionKind), forKey: StorageKey.connectionKind)
        defaults.set(try? encoder.encode(telnetConfig), forKey: StorageKey.telnetConfig)
        defaults.set(try? encoder.encode(preferences), forKey: StorageKey.preferences)
        defaults.set(try? encoder.encode(quickCommands), forKey: StorageKey.quickCommands)
        defaults.set(try? encoder.encode(sendHistory), forKey: StorageKey.sendHistory)
        defaults.set(try? encoder.encode(telnetHistory), forKey: StorageKey.telnetHistory)
    }

    func useTelnetHistory(_ item: TelnetConfig) {
        telnetConfig.host = item.host
        telnetConfig.port = item.port
        telnetConfig.handlesNegotiation = item.handlesNegotiation
        saveState()
    }

    func shutdown() {
        timedSendTimer?.invalidate()
        timedSendTimer = nil
        stopReconnectTimer()
        stopAutoSave(announce: false)
        closeActiveConnections()
        isConnected = false
    }

    private func send(_ text: String, mode: DataMode, lineEnding: LineEnding) {
        guard isConnected else {
            append(.error, "请先建立连接。")
            return
        }

        do {
            let data = try encodedPayload(text, mode: mode, lineEnding: lineEnding)
            guard !data.isEmpty else { return }

            try write(data)
            txBytes += data.count
            rememberSendHistory(text)
            append(.transmit, displayText(for: data, originalText: text, mode: mode))
        } catch {
            append(.error, error.localizedDescription)
        }
    }

    private func encodedPayload(_ text: String, mode: DataMode, lineEnding: LineEnding) throws -> Data {
        switch mode {
        case .text:
            Data((text + lineEnding.stringValue).utf8)
        case .hex:
            try HexCodec.data(from: text)
        }
    }

    private func displayText(for data: Data, originalText: String, mode: DataMode) -> String {
        switch mode {
        case .text:
            originalText.trimmingCharacters(in: .newlines)
        case .hex:
            HexCodec.string(from: data)
        }
    }

    private func handleReceivedData(_ data: Data) {
        rxBytes += data.count
        guard !preferences.pauseReceiveDisplay else {
            pausedReceiveBytes += data.count
            return
        }

        switch preferences.receiveMode {
        case .text:
            appendReceivedText(data)
        case .hex:
            appendReceivedHex(data)
        }
    }

    private func handleDisconnect(_ message: String) {
        flushPendingReceiveText()
        flushPendingHexBytes()
        disconnect(message: message, direction: .error)
        if preferences.autoReconnect && !userRequestedDisconnect {
            startReconnectTimer()
        }
    }

    private func disconnect(message: String, direction: SerialMessage.Direction) {
        closeActiveConnections()
        isConnected = false
        reconnectMessage = nil
        stopAutoSave(announce: false)
        append(direction, message)
    }

    private func startReconnectTimer() {
        guard reconnectTimer == nil else { return }
        reconnectMessage = "自动重连中..."
        append(.system, "自动重连已启动，每 2 秒尝试一次。")

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isConnected else { return }
                self.refreshPorts()
                self.openCurrentConnection(announceErrors: false)
                if self.isConnected {
                    self.stopReconnectTimer()
                    self.append(.system, "自动重连成功。")
                }
            }
        }
    }

    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        reconnectMessage = nil
    }

    private func write(_ data: Data) throws {
        switch connectionKind {
        case .serial:
            guard let serialConnection else { throw SerialConnectionError.notOpen }
            try serialConnection.write(data)
        case .telnet:
            guard let telnetConnection else { throw TelnetConnectionError.notOpen }
            try telnetConnection.write(data)
        }
    }

    private func closeActiveConnections() {
        serialConnection?.close()
        serialConnection = nil
        telnetConnection?.close()
        telnetConnection = nil
    }

    private func appendReceivedText(_ data: Data) {
        pendingReceiveTextBytes.append(data)

        while let newlineIndex = pendingReceiveTextBytes.firstIndex(where: { $0 == 0x0A || $0 == 0x0D }) {
            let lineData = pendingReceiveTextBytes[..<newlineIndex]
            let delimiter = pendingReceiveTextBytes[newlineIndex]
            var removeEnd = pendingReceiveTextBytes.index(after: newlineIndex)

            if delimiter == 0x0D,
               removeEnd < pendingReceiveTextBytes.endIndex,
               pendingReceiveTextBytes[removeEnd] == 0x0A {
                removeEnd = pendingReceiveTextBytes.index(after: removeEnd)
            }

            let line = decodedReceiveText(Data(lineData))
            appendReceiveLine(line)
            pendingReceiveTextBytes.removeSubrange(..<removeEnd)
            pendingReceiveText.removeAll()
            pendingReceiveMessageID = nil
        }

        pendingReceiveText = decodedReceiveText(pendingReceiveTextBytes)
        if !pendingReceiveText.isEmpty {
            upsertPendingReceiveLine(pendingReceiveText)
        }
    }

    private func flushPendingReceiveText() {
        guard !pendingReceiveTextBytes.isEmpty || !pendingReceiveText.isEmpty else { return }
        let line = decodedReceiveText(pendingReceiveTextBytes)
        if !line.isEmpty {
            writeAutoSaveLine(line)
            upsertPendingReceiveLine(line)
        }
        pendingReceiveText.removeAll()
        pendingReceiveTextBytes.removeAll()
        pendingReceiveMessageID = nil
    }

    private func decodedReceiveText(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }
        return String(data: data, encoding: preferences.receiveTextEncoding.stringEncoding)
            ?? String(decoding: data, as: UTF8.self)
    }

    private func appendReceivedHex(_ data: Data) {
        pendingHexBytes.append(data)
        let lineWidth = max(preferences.hexBytesPerLine, 8)

        while pendingHexBytes.count >= lineWidth {
            appendReceiveLine(HexCodec.string(from: pendingHexBytes.prefix(lineWidth)))
            pendingHexBytes.removeFirst(lineWidth)
            pendingReceiveMessageID = nil
        }

        if !pendingHexBytes.isEmpty {
            upsertPendingReceiveLine(HexCodec.string(from: pendingHexBytes))
        }
    }

    private func flushPendingHexBytes() {
        guard !pendingHexBytes.isEmpty else { return }
        let line = HexCodec.string(from: pendingHexBytes)
        writeAutoSaveLine(line)
        upsertPendingReceiveLine(line)
        pendingHexBytes.removeAll()
        pendingReceiveMessageID = nil
    }

    private func appendReceiveLine(_ line: String) {
        if line.isEmpty {
            return
        }

        if let pendingReceiveMessageID,
           let index = messages.firstIndex(where: { $0.id == pendingReceiveMessageID }) {
            messages[index].text = line
        } else {
            append(.receive, line)
        }
        writeAutoSaveLine(line)
    }

    private func upsertPendingReceiveLine(_ line: String) {
        if let pendingReceiveMessageID,
           let index = messages.firstIndex(where: { $0.id == pendingReceiveMessageID }) {
            messages[index].text = line
        } else {
            pendingReceiveMessageID = append(.receive, line)
        }
    }

    @discardableResult
    private func append(_ direction: SerialMessage.Direction, _ text: String) -> UUID {
        let message = SerialMessage(date: .now, direction: direction, text: text)
        messages.append(message)
        trimMessagesIfNeeded()
        return message.id
    }

    private func trimMessagesIfNeeded() {
        let limit = 10_000
        guard messages.count > limit else { return }
        messages.removeFirst(messages.count - limit)
    }

    private func writeAutoSaveLine(_ line: String) {
        guard isAutoSaving, let autoSaveHandle else { return }

        var parts: [String] = []
        if preferences.showTimestamp {
            parts.append("[\(TimestampFormatter.string(from: .now))]")
        }
        if preferences.showDirection {
            parts.append("RX")
        }
        parts.append(line)

        let renderedLine = parts.joined(separator: parts.count > 2 ? "  " : " ") + "\n"

        guard let data = renderedLine.data(using: .utf8) else { return }

        do {
            try autoSaveHandle.seekToEnd()
            try autoSaveHandle.write(contentsOf: data)
        } catch {
            stopAutoSave(announce: false)
            append(.error, "自动保存失败：\(error.localizedDescription)")
        }
    }

    private func renderedMessageLine(_ message: SerialMessage) -> String {
        var parts: [String] = []
        if preferences.showTimestamp {
            parts.append("[\(TimestampFormatter.string(from: message.date))]")
        }
        if preferences.showDirection {
            parts.append(message.direction.rawValue)
        }
        parts.append(message.text)
        return parts.joined(separator: parts.count > 2 ? "  " : " ")
    }

    private func rememberSendHistory(_ text: String) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        sendHistory.removeAll { $0 == value }
        sendHistory.insert(value, at: 0)
        sendHistoryCursor = nil
        if sendHistory.count > 30 {
            sendHistory.removeLast(sendHistory.count - 30)
        }
        saveState()
    }

    private func rememberTelnetHistory(host: String, port: Int) {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedHost.isEmpty else { return }

        telnetHistory.removeAll {
            $0.host.localizedCaseInsensitiveCompare(normalizedHost) == .orderedSame
                && $0.port == port
        }
        telnetHistory.insert(
            TelnetConfig(
                host: normalizedHost,
                port: port,
                handlesNegotiation: telnetConfig.handlesNegotiation
            ),
            at: 0
        )

        if telnetHistory.count > 10 {
            telnetHistory.removeLast(telnetHistory.count - 10)
        }
        saveState()
    }

    private func loadState() {
        let decoder = JSONDecoder()
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: StorageKey.config),
           let storedConfig = try? decoder.decode(SerialConfig.self, from: data) {
            config = storedConfig
        }

        if let data = defaults.data(forKey: StorageKey.connectionKind),
           let storedKind = try? decoder.decode(ConnectionKind.self, from: data) {
            connectionKind = storedKind
        }

        if let data = defaults.data(forKey: StorageKey.telnetConfig),
           let storedTelnetConfig = try? decoder.decode(TelnetConfig.self, from: data) {
            telnetConfig = storedTelnetConfig
        }

        if let data = defaults.data(forKey: StorageKey.preferences),
           let storedPreferences = try? decoder.decode(UserPreferences.self, from: data) {
            preferences = storedPreferences
            preferences.timedSendEnabled = false
            preferences.pauseReceiveDisplay = false
        }

        if let data = defaults.data(forKey: StorageKey.quickCommands),
           let storedCommands = try? decoder.decode([QuickCommand].self, from: data),
           !storedCommands.isEmpty {
            quickCommands = storedCommands.map { command in
                var normalizedCommand = command
                normalizedCommand.group = QuickCommand.normalizedGroup(command.group)
                return normalizedCommand
            }
        }

        if let data = defaults.data(forKey: StorageKey.sendHistory),
           let storedHistory = try? decoder.decode([String].self, from: data) {
            sendHistory = storedHistory
        }

        if let data = defaults.data(forKey: StorageKey.telnetHistory),
           let storedTelnetHistory = try? decoder.decode([TelnetConfig].self, from: data) {
            telnetHistory = Array(storedTelnetHistory.prefix(10))
        }
    }
}

private enum StorageKey {
    static let config = "MacSerial.config"
    static let connectionKind = "MacSerial.connectionKind"
    static let telnetConfig = "MacSerial.telnetConfig"
    static let preferences = "MacSerial.preferences"
    static let quickCommands = "MacSerial.quickCommands"
    static let sendHistory = "MacSerial.sendHistory"
    static let telnetHistory = "MacSerial.telnetHistory"
}
