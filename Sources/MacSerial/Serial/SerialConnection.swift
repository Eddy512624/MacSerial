import Darwin
import Foundation

enum SerialConnectionError: LocalizedError {
    case openFailed(path: String, errno: Int32)
    case configureFailed(String)
    case notOpen
    case writeFailed(errno: Int32)

    var errorDescription: String? {
        switch self {
        case .openFailed(let path, let code):
            "无法打开串口 \(path)：\(String(cString: strerror(code)))。"
        case .configureFailed(let message):
            "串口参数配置失败：\(message)。"
        case .notOpen:
            "串口尚未打开。"
        case .writeFailed(let code):
            "发送失败：\(String(cString: strerror(code)))。"
        }
    }
}

final class SerialConnection {
    private let readQueue = DispatchQueue(label: "com.local.MacSerial.serial.read")
    private let writeQueue = DispatchQueue(label: "com.local.MacSerial.serial.write")
    private var readSource: DispatchSourceRead?
    private var fileDescriptor: Int32 = -1
    private let onReceive: (Data) -> Void
    private let onDisconnect: (String) -> Void

    init(onReceive: @escaping (Data) -> Void, onDisconnect: @escaping (String) -> Void) {
        self.onReceive = onReceive
        self.onDisconnect = onDisconnect
    }

    var isOpen: Bool {
        fileDescriptor >= 0
    }

    func open(config: SerialConfig) throws {
        close()

        guard let path = config.portPath else {
            throw SerialConnectionError.notOpen
        }

        let descriptor = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard descriptor >= 0 else {
            throw SerialConnectionError.openFailed(path: path, errno: errno)
        }

        do {
            try configure(descriptor: descriptor, config: config)
        } catch {
            Darwin.close(descriptor)
            throw error
        }

        fileDescriptor = descriptor
        startReading(descriptor: descriptor)
    }

    func close() {
        guard fileDescriptor >= 0 else { return }
        readSource?.cancel()
        readSource = nil
        fileDescriptor = -1
    }

    func update(config: SerialConfig) throws {
        guard fileDescriptor >= 0 else {
            throw SerialConnectionError.notOpen
        }

        try configure(descriptor: fileDescriptor, config: config)
    }

    func write(_ data: Data) throws {
        guard fileDescriptor >= 0 else {
            throw SerialConnectionError.notOpen
        }

        let descriptor = fileDescriptor
        try writeQueue.sync {
            try data.withUnsafeBytes { rawBuffer in
                guard let baseAddress = rawBuffer.baseAddress else { return }

                var offset = 0
                while offset < rawBuffer.count {
                    let result = Darwin.write(
                        descriptor,
                        baseAddress.advanced(by: offset),
                        rawBuffer.count - offset
                    )

                    if result > 0 {
                        offset += result
                    } else if result == -1 && errno == EINTR {
                        continue
                    } else {
                        throw SerialConnectionError.writeFailed(errno: errno)
                    }
                }
            }
        }
    }

    private func configure(descriptor: Int32, config: SerialConfig) throws {
        var options = termios()
        guard tcgetattr(descriptor, &options) == 0 else {
            throw SerialConnectionError.configureFailed(String(cString: strerror(errno)))
        }

        cfmakeraw(&options)
        options.c_cflag |= tcflag_t(CLOCAL | CREAD)
        options.c_cflag &= ~tcflag_t(CSIZE | PARENB | PARODD | CSTOPB | CRTSCTS)
        options.c_iflag &= ~tcflag_t(IXON | IXOFF | IXANY)

        switch config.dataBits {
        case 7:
            options.c_cflag |= tcflag_t(CS7)
        default:
            options.c_cflag |= tcflag_t(CS8)
        }

        switch config.parity {
        case .none:
            break
        case .odd:
            options.c_cflag |= tcflag_t(PARENB | PARODD)
        case .even:
            options.c_cflag |= tcflag_t(PARENB)
        }

        if config.stopBits == .two {
            options.c_cflag |= tcflag_t(CSTOPB)
        }

        if config.flowControl == .rtsCts {
            options.c_cflag |= tcflag_t(CRTSCTS)
        }

        let baudRate = supportedBaudRate(config.baudRate) ?? speed_t(B9600)
        guard cfsetspeed(&options, baudRate) == 0 else {
            throw SerialConnectionError.configureFailed("波特率 \(config.baudRate) 不可用。")
        }

        guard tcsetattr(descriptor, TCSANOW, &options) == 0 else {
            throw SerialConnectionError.configureFailed(String(cString: strerror(errno)))
        }

        if supportedBaudRate(config.baudRate) == nil {
            try setCustomBaudRate(config.baudRate, descriptor: descriptor)
        }

        tcflush(descriptor, TCIOFLUSH)
    }

    private func supportedBaudRate(_ baudRate: Int) -> speed_t? {
        switch baudRate {
        case 9_600: speed_t(B9600)
        case 19_200: speed_t(B19200)
        case 38_400: speed_t(B38400)
        case 57_600: speed_t(B57600)
        case 115_200: speed_t(B115200)
        case 230_400: speed_t(B230400)
        default: nil
        }
    }

    private func setCustomBaudRate(_ baudRate: Int, descriptor: Int32) throws {
        var speed = speed_t(baudRate)
        let iossiospeed = UInt(0x80085402)
        guard ioctl(descriptor, iossiospeed, &speed) != -1 else {
            throw SerialConnectionError.configureFailed("自定义波特率 \(baudRate) 不可用：\(String(cString: strerror(errno)))。")
        }
    }

    private func startReading(descriptor: Int32) {
        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: readQueue)

        source.setEventHandler { [weak self] in
            self?.readAvailableData(from: descriptor)
        }

        source.setCancelHandler {
            Darwin.close(descriptor)
        }

        readSource = source
        source.resume()
    }

    private func readAvailableData(from descriptor: Int32) {
        var buffer = [UInt8](repeating: 0, count: 4096)

        while true {
            let count = Darwin.read(descriptor, &buffer, buffer.count)
            if count > 0 {
                onReceive(Data(buffer.prefix(count)))
            } else if count == 0 {
                onDisconnect("串口已断开。")
                close()
                return
            } else if errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR {
                return
            } else {
                onDisconnect("读取失败：\(String(cString: strerror(errno)))。")
                close()
                return
            }
        }
    }
}
