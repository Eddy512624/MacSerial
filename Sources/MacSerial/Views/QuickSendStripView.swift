import SwiftUI

struct QuickSendStripView: View {
    @EnvironmentObject private var serialStore: SerialStore
    @State private var selectedGroup = "项圈"
    @State private var editingCommand: QuickCommand?
    @State private var isCreatingCommand = false
    @State private var pageIndex = 0
    private let groups = ["项圈", "基站"]
    private let commandCardWidth: CGFloat = 176
    private let commandSpacing: CGFloat = 8
    private let horizontalPadding: CGFloat = 24

    private var visibleCommands: [QuickCommand] {
        serialStore.quickCommands.filter { $0.group == selectedGroup }
    }

    var body: some View {
        GeometryReader { geometry in
            let pageSize = commandsPerPage(for: geometry.size.width)
            let pageCount = pageCount(for: visibleCommands.count, pageSize: pageSize)
            let currentPage = min(pageIndex, max(pageCount - 1, 0))
            let pageCommands = commands(on: currentPage, pageSize: pageSize)

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Button {
                        serialStore.preferences.showQuickSend.toggle()
                    } label: {
                        Image(systemName: serialStore.preferences.showQuickSend ? "chevron.down" : "chevron.right")
                    }
                    .buttonStyle(.plain)
                    .help(serialStore.preferences.showQuickSend ? "折叠快捷发送" : "展开快捷发送")

                    Label("快捷发送", systemImage: "bolt.horizontal")
                        .font(.headline)
                        .lineLimit(1)
                        .fixedSize()

                    Picker("", selection: $selectedGroup) {
                        ForEach(groups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)

                    Spacer()

                    if serialStore.preferences.showQuickSend {
                        Button {
                            pageIndex = max(currentPage - 1, 0)
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(currentPage == 0)
                        .help("上一页快捷发送")

                        Button {
                            pageIndex = min(currentPage + 1, max(pageCount - 1, 0))
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(currentPage >= pageCount - 1)
                        .help("下一页快捷发送")

                        Text(pageCount == 0 ? "0/0" : "\(currentPage + 1)/\(pageCount)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .center)
                    }

                    Button {
                        isCreatingCommand = true
                    } label: {
                        Label("新建", systemImage: "plus")
                    }
                    .help("新建快捷命令")
                    .fixedSize()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                if serialStore.preferences.showQuickSend {
                    if pageCommands.isEmpty {
                        HStack {
                            Text("当前分组暂无快捷命令")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    } else {
                        HStack(spacing: 8) {
                            ForEach(pageCommands) { command in
                                QuickCommandButton(
                                    command: command,
                                    sendAction: {
                                        serialStore.sendQuickCommand(command)
                                    },
                                    editAction: {
                                        editingCommand = command
                                    },
                                    duplicateAction: {
                                        serialStore.duplicateQuickCommand(command)
                                    },
                                    moveLeftAction: {
                                        serialStore.moveQuickCommand(command, offset: -1)
                                    },
                                    moveRightAction: {
                                        serialStore.moveQuickCommand(command, offset: 1)
                                    },
                                    deleteAction: {
                                        serialStore.deleteQuickCommand(command)
                                    }
                                )
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                }
            }
        }
        .onChange(of: selectedGroup) {
            pageIndex = 0
        }
        .onChange(of: visibleCommands.count) {
            pageIndex = min(pageIndex, max(pageCount(for: visibleCommands.count, pageSize: 1) - 1, 0))
        }
        .sheet(isPresented: $isCreatingCommand) {
            QuickCommandEditorView(command: QuickCommand(title: "", payload: "", group: selectedGroup), groups: groups) { command in
                serialStore.addQuickCommand(command)
            }
        }
        .sheet(item: $editingCommand) { command in
            QuickCommandEditorView(command: command, groups: groups) { updatedCommand in
                serialStore.updateQuickCommand(updatedCommand)
            }
        }
    }

    private func commandsPerPage(for width: CGFloat) -> Int {
        let availableWidth = max(width - horizontalPadding, commandCardWidth)
        let footprint = commandCardWidth + commandSpacing
        return max(1, Int((availableWidth + commandSpacing) / footprint))
    }

    private func pageCount(for commandCount: Int, pageSize: Int) -> Int {
        guard commandCount > 0 else { return 0 }
        return Int(ceil(Double(commandCount) / Double(max(pageSize, 1))))
    }

    private func commands(on page: Int, pageSize: Int) -> [QuickCommand] {
        guard !visibleCommands.isEmpty else { return [] }
        let start = min(page * pageSize, visibleCommands.count)
        let end = min(start + pageSize, visibleCommands.count)
        return Array(visibleCommands[start..<end])
    }
}

private struct QuickCommandButton: View {
    let command: QuickCommand
    let sendAction: () -> Void
    let editAction: () -> Void
    let duplicateAction: () -> Void
    let moveLeftAction: () -> Void
    let moveRightAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        Button(action: sendAction) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(command.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(command.mode.rawValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(command.mode == .hex ? .orange : .blue)
                }

                Text(command.payload)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 154, height: 52, alignment: .leading)
            .padding(.horizontal, 10)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.16))
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("编辑", action: editAction)
            Button("复制", action: duplicateAction)
            Divider()
            Button("前移", action: moveLeftAction)
            Button("后移", action: moveRightAction)
            Divider()
            Button("删除", role: .destructive, action: deleteAction)
        }
    }
}

private struct QuickCommandEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var command: QuickCommand
    let groups: [String]
    let onSave: (QuickCommand) -> Void

    init(command: QuickCommand, groups: [String], onSave: @escaping (QuickCommand) -> Void) {
        _command = State(initialValue: command)
        self.groups = groups
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(command.title.isEmpty ? "新建快捷命令" : "编辑快捷命令")
                .font(.title3.weight(.semibold))

            Form {
                TextField("名称", text: $command.title)
                TextField("内容", text: $command.payload, axis: .vertical)
                    .font(.system(size: 13, design: command.mode == .hex ? .monospaced : .default))
                    .lineLimit(3...6)

                Picker("分组", selection: $command.group) {
                    ForEach(groups, id: \.self) { group in
                        Text(group).tag(group)
                    }
                }

                Picker("模式", selection: $command.mode) {
                    ForEach(DataMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Picker("结尾", selection: $command.lineEnding) {
                    ForEach(LineEnding.allCases) { ending in
                        Text(ending.rawValue).tag(ending)
                    }
                }
            }

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                Button("保存") {
                    onSave(command)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(command.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || command.payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}
