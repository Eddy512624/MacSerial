# MacSerial

MacSerial 是一个原生 macOS 串口调试工具，同时支持 Telnet/TCP 调试。它使用 SwiftUI 构建，界面简洁，适合嵌入式开发、硬件调试、AT 指令测试、Modbus 数据收发、串口日志记录和网络透传测试。

MacSerial is a native macOS serial port and Telnet/TCP debugging tool built with SwiftUI.

## Keywords

macOS serial tool, serial port monitor, serial debugger, UART terminal, Telnet client, TCP debugging tool, SwiftUI serial app, Modbus test tool, AT command tool, 串口调试助手, 串口监视器, macOS 串口工具, Telnet 调试, TCP 调试, 上位机工具。

## Features

- Native macOS SwiftUI app
- Serial port receive/send with common port settings
- Baud rates including 9600, 115200, 460800 and 921600
- Telnet/TCP client with basic Telnet negotiation filtering
- Text and HEX receive/send modes
- CR, LF and CRLF line endings
- RX/TX counters, timestamp toggle and direction toggle
- Receive monitor with auto scroll, pause, clear and save
- Auto-save receive monitor content while connected
- Quick send commands with groups, pagination and editing
- Multi-window sessions for opening several serial/Telnet tools at once
- Compact layout for placing multiple windows on one desktop

## Screenshot

Screenshot coming soon.

## Requirements

- macOS 14 or later
- Swift 6 toolchain / Xcode

## Run From Source

Open `Package.swift` in Xcode, select the `MacSerial` scheme, then press `Cmd+R`.

Or run from the command line:

```bash
swift run MacSerial
```

## Build

Build the executable:

```bash
swift build
```

Build a macOS `.app` bundle:

```bash
bash Scripts/build_app.sh
```

The app bundle will be generated at:

```text
.build/release/MacSerial.app
```

You can drag `MacSerial.app` into `/Applications`.

## License

MacSerial is released under the MIT License. See [LICENSE](LICENSE).
