# MacSerial

原生 macOS 串口 / Telnet 调试工具，使用 SwiftUI 构建。

## 功能

- 串口收发，支持常见串口参数和 460800 / 921600 波特率
- Telnet/TCP 连接，支持基础 Telnet 协商过滤
- 文本 / HEX 收发、CR/LF/CRLF 结尾
- 接收监视、自动滚动、时间戳、RX/TX 显示开关
- 快捷发送分组、分页和编辑
- 接收内容保存与自动保存
- 多窗口独立会话

## 开发运行

用 Xcode 打开 `Package.swift`，选择 `MacSerial` Scheme，然后按 `Cmd+R`。

也可以使用命令行：

```bash
swift run MacSerial
```

## 编译

```bash
swift build
```

生成 `.app`：

```bash
bash Scripts/build_app.sh
```

产物位置：

```text
.build/release/MacSerial.app
```
